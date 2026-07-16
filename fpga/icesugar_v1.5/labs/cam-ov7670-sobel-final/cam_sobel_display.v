// cam_sobel_display.v v2 — camara -> SOBEL sobre imagen chica (60x80) -> pantalla.
// PRIMERO submuestrea a 60x80, DESPUES aplica Sobel 3x3 sobre esa imagen chica
// (line buffers de 60 como shift-registers). Asi los bordes SI se ven (no se
// pierden por decimacion).  = ¡bordes en vivo en la pantalla! 🖼️✏️
//   VERDE = camara configurada, AZUL = heartbeat.
// Pines: clk=35, cam_xclk=2, cam_scl=26, cam_sda=27, cam_pclk=28, cam_href=32,
//        cam_d[0..7]=48,46,44,43,38,34,31,42,
//        tft_sck=37, tft_mosi=36, tft_cs=25, tft_dc=23, leds=39/40/41

module top (
    input  wire       clk,
    output wire       cam_xclk,
    output wire       cam_scl,
    inout  wire       cam_sda,
    input  wire       cam_pclk,
    input  wire       cam_href,
    input  wire [7:0] cam_d,
    output wire       tft_sck,
    output wire       tft_mosi,
    output wire       tft_cs,
    output wire       tft_dc,
    output wire       led_r,
    output wire       led_g,
    output wire       led_b
);
    assign cam_xclk = clk;

    // ==================== SCCB config (dominio clk) ====================
    reg sda_oe = 1'b0;
    assign cam_sda = sda_oe ? 1'b0 : 1'bz;
    reg scl = 1'b1;
    assign cam_scl = scl;

    reg [5:0] tdiv = 6'd0;
    wire tick = (tdiv == 6'd29);
    always @(posedge clk) tdiv <= tick ? 6'd0 : tdiv + 1'b1;

    reg [15:0] rom;
    reg [4:0]  idx = 5'd0;
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
    reg [2:0] cpc = 3'd0;
    reg [1:0] cph = 2'd0;
    reg [3:0] cbi = 4'd0;
    reg [15:0] cdly = 16'd0;
    reg        cfg_done = 1'b0;

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

    reg [19:0] cboot = 20'd0;
    wire cboot_ok = &cboot;
    always @(posedge clk) if (!cboot_ok) cboot <= cboot + 1'b1;

    always @(posedge clk) if (tick && cboot_ok && !cfg_done) begin
        case (coptype)
        C_START: begin
            if (tbl_end) cfg_done <= 1'b1;
            else begin
                case (cph)
                    2'd0: begin sda_oe<=1'b0; scl<=1'b1; end
                    2'd1: begin sda_oe<=1'b1; scl<=1'b1; end
                    2'd2: scl<=1'b0;
                    2'd3: cpc<=cpc+1'b1;
                endcase
                cph <= cph + 1'b1;
            end
        end
        C_WR: begin
            case (cph)
                2'd0: begin scl<=1'b0; if (cbi<4'd8) sda_oe<=~cwbyte[3'd7-cbi[2:0]]; else sda_oe<=1'b0; end
                2'd1: scl<=1'b1; 2'd2: scl<=1'b1;
                2'd3: begin scl<=1'b0; if (cbi==4'd8) begin cbi<=4'd0; cpc<=cpc+1'b1; end else cbi<=cbi+1'b1; end
            endcase
            cph <= cph + 1'b1;
        end
        C_STOP: begin
            case (cph)
                2'd0: begin scl<=1'b0; sda_oe<=1'b1; end
                2'd1: begin scl<=1'b1; sda_oe<=1'b1; end
                2'd2: begin scl<=1'b1; sda_oe<=1'b0; end
                2'd3: begin cpc<=cpc+1'b1; cdly<=16'd999; end
            endcase
            cph <= cph + 1'b1;
        end
        C_DLY: if (cdly==16'd0) cpc<=cpc+1'b1; else cdly<=cdly-1'b1;
        default: begin idx<=idx+1'b1; cpc<=3'd0; end
        endcase
    end

    // ======== submuestreo a 60x80 + SOBEL sobre imagen chica (dominio pclk) ========
    reg href_d  = 1'b0;
    reg        parity  = 1'b0;
    reg [7:0]  curY    = 8'd0;
    reg [3:0]  colkeep = 4'd0;
    reg [2:0]  rowkeep = 3'd0;
    reg [6:0]  fbx     = 7'd0;
    reg [12:0] waddr_wr= 13'd0;
    reg        we      = 1'b0;
    reg [12:0] wadr    = 13'd0;
    reg [7:0]  wdat    = 8'd0;

    // line buffers de 60 (shift-registers): filas anteriores de la imagen chica
    reg [7:0] dline1 [0:59];   // fila n-1
    reg [7:0] dline2 [0:59];   // fila n-2
    // ventana 3x3 (taps): fila0=n-2, fila1=n-1, fila2=n ; tapC=col actual,c-1,c-2
    reg [7:0] t00=0,t01=0,t02=0, t10=0,t11=0,t12=0, t20=0,t21=0,t22=0;

    // Sobel:  a b c / d e f / g h i  (a=t02 arriba-izq ... i=t20 abajo-der)
    wire [10:0] gxp = t00 + (t10<<1) + t20;   // c + 2f + i
    wire [10:0] gxn = t02 + (t12<<1) + t22;   // a + 2d + g
    wire [10:0] gyp = t22 + (t21<<1) + t20;   // g + 2h + i
    wire [10:0] gyn = t02 + (t01<<1) + t00;   // a + 2b + c
    wire [10:0] agx = (gxp>=gxn) ? (gxp-gxn) : (gxn-gxp);
    wire [10:0] agy = (gyp>=gyn) ? (gyp-gyn) : (gyn-gyp);
    wire [11:0] mag12 = agx + agy;
    wire [7:0]  mag = (mag12 > 12'd255) ? 8'd255 : mag12[7:0];

    integer k;
    always @(posedge cam_pclk) begin
        href_d <= cam_href;
        we     <= 1'b0;
        if (~cam_href) begin
            parity <= 1'b0; colkeep <= 4'd0; fbx <= 7'd0;
        end else begin
            if (parity == 1'b0) curY <= cam_d;
            else begin
                if (rowkeep==3'd0 && colkeep==4'd0 && fbx<7'd60) begin
                    // desplazar line buffers (SR de 60): entra curY, sale fila anterior
                    for (k=59; k>0; k=k-1) begin dline1[k]<=dline1[k-1]; dline2[k]<=dline2[k-1]; end
                    dline1[0] <= curY;
                    dline2[0] <= dline1[59];
                    // desplazar ventana 3x3 (vertical: curY, dline1[59]=n-1, dline2[59]=n-2)
                    t02<=t01; t01<=t00; t00<=dline2[59];
                    t12<=t11; t11<=t10; t10<=dline1[59];
                    t22<=t21; t21<=t20; t20<=curY;
                    // umbral: borde = blanco, plano = negro (contornos nitidos)
                    we <= 1'b1; wadr <= waddr_wr; wdat <= (mag > 8'd40) ? 8'hFF : 8'h00;
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

    // ==================== frame buffer 60x80 (doble puerto) ====================
    reg [7:0] fb [0:4799];
    reg [7:0] fb_rd = 8'd0;
    always @(posedge cam_pclk) if (we) fb[wadr] <= wdat;

    // ==================== display ILI9341 (dominio clk) ====================
    reg        spi_start = 1'b0;
    reg  [7:0] spi_byte  = 8'd0;
    reg        spi_dcbit = 1'b1;
    reg        spi_done  = 1'b0;
    reg sck=1'b0, mosi=1'b0, cs=1'b1, dc=1'b1;
    assign tft_sck=sck; assign tft_mosi=mosi; assign tft_cs=cs; assign tft_dc=dc;

    localparam S_IDLE=2'd0, S_LO=2'd1, S_HI=2'd2, S_END=2'd3;
    reg [1:0] sst = S_IDLE;
    reg [2:0] sbit = 3'd0;
    reg [7:0] sbuf = 8'd0;
    always @(posedge clk) begin
        spi_done <= 1'b0;
        case (sst)
            S_IDLE: if (spi_start) begin cs<=1'b0; dc<=spi_dcbit; sbuf<=spi_byte; sbit<=3'd0; sck<=1'b0; sst<=S_LO; end
            S_LO:  begin sck<=1'b0; mosi<=sbuf[7]; sst<=S_HI; end
            S_HI:  begin sck<=1'b1; sbuf<={sbuf[6:0],1'b0}; if (sbit==3'd7) sst<=S_END; else begin sbit<=sbit+1'b1; sst<=S_LO; end end
            S_END: begin sck<=1'b0; spi_done<=1'b1; sst<=S_IDLE; end
        endcase
    end

    localparam T_CMD=2'd0, T_DAT=2'd1, T_DLY=2'd2, T_END=2'd3;
    localparam M_BOOT=2'd0, M_INIT=2'd1, M_FRAME=2'd2, M_FILL=2'd3;
    reg [1:0] mode = M_BOOT;
    reg [4:0] ip   = 5'd0;

    reg [1:0] rt; reg [7:0] rb;
    always @(*) begin
        rt=T_END; rb=8'h00;
        if (mode==M_INIT) case (ip)
            5'd0: begin rt=T_CMD; rb=8'h01; end
            5'd1: begin rt=T_DLY; rb=8'h00; end
            5'd2: begin rt=T_CMD; rb=8'h11; end
            5'd3: begin rt=T_DLY; rb=8'h00; end
            5'd4: begin rt=T_CMD; rb=8'h3A; end
            5'd5: begin rt=T_DAT; rb=8'h55; end
            5'd6: begin rt=T_CMD; rb=8'h36; end
            5'd7: begin rt=T_DAT; rb=8'h48; end
            5'd8: begin rt=T_CMD; rb=8'h29; end
            default: begin rt=T_END; rb=8'h00; end
        endcase
        else case (ip)
            5'd0:  begin rt=T_CMD; rb=8'h2A; end
            5'd1:  begin rt=T_DAT; rb=8'h00; end
            5'd2:  begin rt=T_DAT; rb=8'h00; end
            5'd3:  begin rt=T_DAT; rb=8'h00; end
            5'd4:  begin rt=T_DAT; rb=8'hEF; end
            5'd5:  begin rt=T_CMD; rb=8'h2B; end
            5'd6:  begin rt=T_DAT; rb=8'h00; end
            5'd7:  begin rt=T_DAT; rb=8'h00; end
            5'd8:  begin rt=T_DAT; rb=8'h01; end
            5'd9:  begin rt=T_DAT; rb=8'h3F; end
            5'd10: begin rt=T_CMD; rb=8'h2C; end
            default: begin rt=T_END; rb=8'h00; end
        endcase
    end

    localparam [13:0] OFFSET = 14'd1920;   // encuadre: 0,600,1200,...,4200
    reg [7:0] xcol = 8'd0;
    reg [8:0] ycol = 9'd0;
    wire [6:0] fx = xcol[7:2];
    wire [6:0] fy = ycol[8:2];
    wire [13:0] rsum  = fy*60 + fx + OFFSET;
    wire [12:0] raddr = (rsum >= 14'd4800) ? (rsum - 14'd4800) : rsum[12:0];
    always @(posedge clk) fb_rd <= fb[raddr];
    wire [15:0] pcolor = {fb_rd[7:3], fb_rd[7:2], fb_rd[7:3]};

    reg [20:0] dcnt = 21'd0;
    reg [16:0] px   = 17'd0;
    reg        pxhi = 1'b0;
    reg        sending = 1'b0;

    always @(posedge clk) begin
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

    reg [23:0] hb = 24'd0;
    always @(posedge clk) hb <= hb + 1'b1;
    SB_RGBA_DRV #(
        .CURRENT_MODE("0b1"),
        .RGB0_CURRENT("0b000001"), .RGB1_CURRENT("0b000001"), .RGB2_CURRENT("0b000001")
    ) rgba (
        .CURREN(1'b1), .RGBLEDEN(1'b1),
        .RGB0PWM(cfg_done), .RGB1PWM(1'b0), .RGB2PWM(hb[23]),
        .RGB0(led_r), .RGB1(led_g), .RGB2(led_b)
    );
endmodule
