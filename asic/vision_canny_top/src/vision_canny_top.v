// vision_canny_top.v — EL CHIP QUE VE Y MUESTRA con CANNY, integrado para ASIC sky130 (fase 10).
//   camara OV7670 -> SCCB -> submuestreo 60x80 -> Gaussian 3x3 -> Sobel 3x3 -> doble umbral ->
//   HISTERESIS 1-salto -> framebuffer -> display ILI9341.  Bordes mas limpios y conectados que Sobel.
//   Portado del fisico verificado cam_canny2_display.v. Mismos 3 cambios ASIC que vision_top:
//     (1) rst_n explicito en los FSM de control, (2) cam_sda open-drain -> cam_sda_o/cam_sda_oe,
//     (3) sin SB_RGBA_DRV. DUAL-CLOCK (clk sistema / cam_pclk camara); el framebuffer no se resetea.
`default_nettype none
module vision_canny_top (
    input  wire       clk,
    input  wire       rst_n,
    output wire       cam_xclk,
    output reg        cam_scl,
    output wire       cam_sda_o,
    output wire       cam_sda_oe,
    input  wire       cam_pclk,
    input  wire       cam_href,
    input  wire [7:0] cam_d,
    output wire       tft_sck,
    output wire       tft_mosi,
    output wire       tft_cs,
    output wire       tft_dc,
    output reg        cfg_done
);
    assign cam_xclk = clk;

    // ==================== SCCB config (dominio clk) ====================
    reg sda_oe;
    assign cam_sda_o  = 1'b0;
    assign cam_sda_oe = sda_oe;

    reg [5:0] tdiv;
    wire tick = (tdiv == 6'd29);
    always @(posedge clk or negedge rst_n)
        if (!rst_n) tdiv <= 6'd0; else tdiv <= tick ? 6'd0 : tdiv + 1'b1;

    reg [4:0] idx;
    reg [15:0] rom;
    always @(*) case (idx)
        5'd0:  rom = 16'h12_00;
        5'd1:  rom = 16'h13_E7;
        5'd2:  rom = 16'h09_18;
        default: rom = 16'hFF_FF;
    endcase
    wire       tbl_end  = (rom == 16'hFF_FF);
    wire [7:0] reg_addr = rom[15:8];
    wire [7:0] reg_val  = rom[7:0];

    localparam C_START=3'd0, C_WR=3'd1, C_STOP=3'd2, C_DLY=3'd3, C_NEXT=3'd4;
    reg [2:0] cpc; reg [1:0] cph; reg [3:0] cbi; reg [15:0] cdly;
    reg [2:0] coptype;
    always @(*) case (cpc)
        3'd0: coptype=C_START; 3'd1: coptype=C_WR; 3'd2: coptype=C_WR;
        3'd3: coptype=C_WR;    3'd4: coptype=C_STOP; 3'd5: coptype=C_DLY;
        default: coptype=C_NEXT;
    endcase
    reg [7:0] cwbyte;
    always @(*) case (cpc)
        3'd1: cwbyte=8'h42; 3'd2: cwbyte=reg_addr; 3'd3: cwbyte=reg_val;
        default: cwbyte=8'h00;
    endcase
    reg [19:0] cboot;
    wire cboot_ok = &cboot;
    always @(posedge clk or negedge rst_n)
        if (!rst_n) cboot <= 20'd0; else if (!cboot_ok) cboot <= cboot + 1'b1;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sda_oe<=1'b0; cam_scl<=1'b1; cpc<=0; cph<=0; cbi<=0; cdly<=0; cfg_done<=1'b0; idx<=0;
        end else if (tick && cboot_ok && !cfg_done) begin
            case (coptype)
            C_START: begin
                if (tbl_end) cfg_done <= 1'b1;
                else begin
                    case (cph)
                        2'd0: begin sda_oe<=1'b0; cam_scl<=1'b1; end
                        2'd1: begin sda_oe<=1'b1; cam_scl<=1'b1; end
                        2'd2: cam_scl<=1'b0;
                        2'd3: cpc<=cpc+1'b1;
                    endcase
                    cph <= cph + 1'b1;
                end
            end
            C_WR: begin
                case (cph)
                    2'd0: begin cam_scl<=1'b0; if (cbi<4'd8) sda_oe<=~cwbyte[3'd7-cbi[2:0]]; else sda_oe<=1'b0; end
                    2'd1: cam_scl<=1'b1; 2'd2: cam_scl<=1'b1;
                    2'd3: begin cam_scl<=1'b0; if (cbi==4'd8) begin cbi<=4'd0; cpc<=cpc+1'b1; end else cbi<=cbi+1'b1; end
                endcase
                cph <= cph + 1'b1;
            end
            C_STOP: begin
                case (cph)
                    2'd0: begin cam_scl<=1'b0; sda_oe<=1'b1; end
                    2'd1: begin cam_scl<=1'b1; sda_oe<=1'b1; end
                    2'd2: begin cam_scl<=1'b1; sda_oe<=1'b0; end
                    2'd3: begin cpc<=cpc+1'b1; cdly<=16'd999; end
                endcase
                cph <= cph + 1'b1;
            end
            C_DLY: if (cdly==16'd0) cpc<=cpc+1'b1; else cdly<=cdly-1'b1;
            default: begin idx<=idx+1'b1; cpc<=3'd0; end
            endcase
        end
    end

    // ==== submuestreo 60x80 + Gaussian -> Sobel -> clase -> histeresis (dominio cam_pclk) ====
    reg href_d; reg parity; reg [7:0] curY; reg [3:0] colkeep; reg [2:0] rowkeep;
    reg [6:0] fbx; reg [12:0] waddr_wr; reg we; reg [12:0] wadr; reg [7:0] wdat;

    reg [7:0] gline1 [0:59]; reg [7:0] gline2 [0:59];
    reg [7:0] g00,g01,g02, g10,g11,g12, g20,g21,g22;
    wire [11:0] gsum = g00 + (g01<<1) + g02 + (g10<<1) + (g11<<2) + (g12<<1) + g20 + (g21<<1) + g22;
    wire [7:0]  gout = gsum[11:4];

    reg [7:0] sline1 [0:59]; reg [7:0] sline2 [0:59];
    reg [7:0] s00,s01,s02, s10,s11,s12, s20,s21,s22;
    wire [10:0] gxp = s00 + (s10<<1) + s20;
    wire [10:0] gxn = s02 + (s12<<1) + s22;
    wire [10:0] gyp = s22 + (s21<<1) + s20;
    wire [10:0] gyn = s02 + (s01<<1) + s00;
    wire [10:0] agx = (gxp>=gxn) ? (gxp-gxn) : (gxn-gxp);
    wire [10:0] agy = (gyp>=gyn) ? (gyp-gyn) : (gyn-gyp);
    wire [11:0] mag12 = agx + agy;
    wire [7:0]  mag = (mag12 > 12'd255) ? 8'd255 : mag12[7:0];

    localparam [1:0] CL_NADA=2'd0, CL_DEBIL=2'd1, CL_FUERTE=2'd2;
    wire [1:0] cls_in = (mag > 8'd70) ? CL_FUERTE : (mag > 8'd30) ? CL_DEBIL : CL_NADA;

    reg [1:0] cline1 [0:59]; reg [1:0] cline2 [0:59];
    reg [1:0] c00,c01,c02, c10,c11,c12, c20,c21,c22;
    wire any_strong = (c00==CL_FUERTE)|(c01==CL_FUERTE)|(c02==CL_FUERTE)|
                      (c10==CL_FUERTE)|                (c12==CL_FUERTE)|
                      (c20==CL_FUERTE)|(c21==CL_FUERTE)|(c22==CL_FUERTE);
    wire edge_px = (c11==CL_FUERTE) ? 1'b1 : (c11==CL_DEBIL) ? any_strong : 1'b0;

    integer k;
    always @(posedge cam_pclk or negedge rst_n) begin
        if (!rst_n) begin
            href_d<=0; parity<=0; curY<=0; colkeep<=0; rowkeep<=0; fbx<=0;
            waddr_wr<=0; we<=0; wadr<=0; wdat<=0;
            g00<=0;g01<=0;g02<=0;g10<=0;g11<=0;g12<=0;g20<=0;g21<=0;g22<=0;
            s00<=0;s01<=0;s02<=0;s10<=0;s11<=0;s12<=0;s20<=0;s21<=0;s22<=0;
            c00<=0;c01<=0;c02<=0;c10<=0;c11<=0;c12<=0;c20<=0;c21<=0;c22<=0;
        end else begin
            href_d <= cam_href;
            we     <= 1'b0;
            if (~cam_href) begin
                parity <= 1'b0; colkeep <= 4'd0; fbx <= 7'd0;
            end else begin
                if (parity == 1'b0) curY <= cam_d;
                else begin
                    if (rowkeep==3'd0 && colkeep==4'd0 && fbx<7'd60) begin
                        for (k=59; k>0; k=k-1) begin gline1[k]<=gline1[k-1]; gline2[k]<=gline2[k-1]; end
                        gline1[0] <= curY;  gline2[0] <= gline1[59];
                        g02<=g01; g01<=g00; g00<=gline2[59];
                        g12<=g11; g11<=g10; g10<=gline1[59];
                        g22<=g21; g21<=g20; g20<=curY;
                        for (k=59; k>0; k=k-1) begin sline1[k]<=sline1[k-1]; sline2[k]<=sline2[k-1]; end
                        sline1[0] <= gout;  sline2[0] <= sline1[59];
                        s02<=s01; s01<=s00; s00<=sline2[59];
                        s12<=s11; s11<=s10; s10<=sline1[59];
                        s22<=s21; s21<=s20; s20<=gout;
                        for (k=59; k>0; k=k-1) begin cline1[k]<=cline1[k-1]; cline2[k]<=cline2[k-1]; end
                        cline1[0] <= cls_in; cline2[0] <= cline1[59];
                        c02<=c01; c01<=c00; c00<=cline2[59];
                        c12<=c11; c11<=c10; c10<=cline1[59];
                        c22<=c21; c21<=c20; c20<=cls_in;
                        we <= 1'b1; wadr <= waddr_wr; wdat <= edge_px ? 8'hFF : 8'h00;
                        waddr_wr <= (waddr_wr==13'd4799) ? 13'd0 : waddr_wr + 1'b1;
                        fbx <= fbx + 1'b1;
                    end
                    colkeep <= (colkeep==4'd9) ? 4'd0 : colkeep + 1'b1;
                end
                parity <= ~parity;
            end
            if (href_d & ~cam_href)
                rowkeep <= (rowkeep==3'd5) ? 3'd0 : rowkeep + 1'b1;
        end
    end

    // ==================== frame buffer 60x80 (sin reset) ====================
    reg [7:0] fb [0:4799];
    reg [7:0] fb_rd;
    always @(posedge cam_pclk) if (we) fb[wadr] <= wdat;

    // ==================== display ILI9341 (dominio clk) ====================
    reg spi_start, spi_dcbit, spi_done; reg [7:0] spi_byte;
    reg sck, mosi, cs, dc;
    assign tft_sck=sck; assign tft_mosi=mosi; assign tft_cs=cs; assign tft_dc=dc;
    localparam S_IDLE=2'd0, S_LO=2'd1, S_HI=2'd2, S_END=2'd3;
    reg [1:0] sst; reg [2:0] sbit; reg [7:0] sbuf;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sst<=S_IDLE; sbit<=0; sbuf<=0; spi_done<=0; sck<=0; mosi<=0; cs<=1'b1; dc<=1'b1;
        end else begin
            spi_done <= 1'b0;
            case (sst)
                S_IDLE: if (spi_start) begin cs<=1'b0; dc<=spi_dcbit; sbuf<=spi_byte; sbit<=3'd0; sck<=1'b0; sst<=S_LO; end
                S_LO:  begin sck<=1'b0; mosi<=sbuf[7]; sst<=S_HI; end
                S_HI:  begin sck<=1'b1; sbuf<={sbuf[6:0],1'b0}; if (sbit==3'd7) sst<=S_END; else begin sbit<=sbit+1'b1; sst<=S_LO; end end
                S_END: begin sck<=1'b0; spi_done<=1'b1; sst<=S_IDLE; end
            endcase
        end
    end

    localparam T_CMD=2'd0, T_DAT=2'd1, T_DLY=2'd2, T_END=2'd3;
    localparam M_BOOT=2'd0, M_INIT=2'd1, M_FRAME=2'd2, M_FILL=2'd3;
    reg [1:0] mode; reg [4:0] ip; reg [1:0] rt; reg [7:0] rb;
    always @(*) begin
        rt=T_END; rb=8'h00;
        if (mode==M_INIT) case (ip)
            5'd0: begin rt=T_CMD; rb=8'h01; end 5'd1: begin rt=T_DLY; rb=8'h00; end
            5'd2: begin rt=T_CMD; rb=8'h11; end 5'd3: begin rt=T_DLY; rb=8'h00; end
            5'd4: begin rt=T_CMD; rb=8'h3A; end 5'd5: begin rt=T_DAT; rb=8'h55; end
            5'd6: begin rt=T_CMD; rb=8'h36; end 5'd7: begin rt=T_DAT; rb=8'h48; end
            5'd8: begin rt=T_CMD; rb=8'h29; end default: begin rt=T_END; rb=8'h00; end
        endcase
        else case (ip)
            5'd0:  begin rt=T_CMD; rb=8'h2A; end 5'd1:  begin rt=T_DAT; rb=8'h00; end
            5'd2:  begin rt=T_DAT; rb=8'h00; end 5'd3:  begin rt=T_DAT; rb=8'h00; end
            5'd4:  begin rt=T_DAT; rb=8'hEF; end 5'd5:  begin rt=T_CMD; rb=8'h2B; end
            5'd6:  begin rt=T_DAT; rb=8'h00; end 5'd7:  begin rt=T_DAT; rb=8'h00; end
            5'd8:  begin rt=T_DAT; rb=8'h01; end 5'd9:  begin rt=T_DAT; rb=8'h3F; end
            5'd10: begin rt=T_CMD; rb=8'h2C; end default: begin rt=T_END; rb=8'h00; end
        endcase
    end

    localparam [13:0] OFFSET = 14'd1861;
    reg [7:0] xcol; reg [8:0] ycol;
    wire [6:0] fx = xcol[7:2];
    wire [6:0] fy = ycol[8:2];
    wire [13:0] rsum  = fy*60 + fx + OFFSET;
    wire [12:0] raddr = (rsum >= 14'd4800) ? (rsum - 14'd4800) : rsum[12:0];
    always @(posedge clk) fb_rd <= fb[raddr];
    wire [15:0] pcolor = {fb_rd[7:3], fb_rd[7:2], fb_rd[7:3]};

    reg [20:0] dcnt; reg [16:0] px; reg pxhi; reg sending;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mode<=M_BOOT; ip<=0; dcnt<=0; px<=0; pxhi<=0; sending<=0;
            spi_start<=0; spi_byte<=0; spi_dcbit<=1'b1; xcol<=0; ycol<=0;
        end else begin
            spi_start <= 1'b0;
            case (mode)
            M_BOOT: begin
                dcnt <= dcnt + 1'b1;
                if (dcnt == 21'd1_800_000) begin dcnt <= 21'd0; mode <= M_INIT; ip <= 5'd0; end
            end
            M_INIT: begin
                if (!sending) begin
                    case (rt)
                        T_CMD,T_DAT: begin spi_byte<=rb; spi_dcbit<=(rt==T_DAT); spi_start<=1'b1; sending<=1'b1; end
                        T_DLY: if (dcnt==21'd1_800_000) begin dcnt<=21'd0; ip<=ip+1'b1; end else dcnt<=dcnt+1'b1;
                        default: begin mode<=M_FRAME; ip<=5'd0; end
                    endcase
                end else if (spi_done) begin sending<=1'b0; ip<=ip+1'b1; end
            end
            M_FRAME: begin
                if (!sending) begin
                    case (rt)
                        T_CMD,T_DAT: begin spi_byte<=rb; spi_dcbit<=(rt==T_DAT); spi_start<=1'b1; sending<=1'b1; end
                        default: begin mode<=M_FILL; px<=17'd0; pxhi<=1'b0; xcol<=8'd0; ycol<=9'd0; end
                    endcase
                end else if (spi_done) begin sending<=1'b0; ip<=ip+1'b1; end
            end
            M_FILL: begin
                if (!sending) begin
                    spi_byte  <= pxhi ? pcolor[7:0] : pcolor[15:8];
                    spi_dcbit <= 1'b1; spi_start <= 1'b1; sending <= 1'b1;
                end else if (spi_done) begin
                    sending <= 1'b0;
                    if (pxhi) begin
                        pxhi <= 1'b0;
                        if (px == 17'd76799) begin px<=17'd0; mode<=M_FRAME; ip<=5'd0; end
                        else begin
                            px <= px + 1'b1;
                            if (xcol == 8'd239) begin xcol<=8'd0; ycol<=ycol+1'b1; end
                            else xcol <= xcol + 1'b1;
                        end
                    end else pxhi <= 1'b1;
                end
            end
            endcase
        end
    end
endmodule
`default_nettype wire
