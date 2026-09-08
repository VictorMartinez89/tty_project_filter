// cam_franjas.v — LOS 8 BITS DE cam_d EN FRANJAS **VERTICALES**.
//
//   POR QUE VERTICALES Y NO HORIZONTALES: la version anterior (cam_bandas) usaba bandas de
//   filas, y la lectura del framebuffer lleva `OFFSET = 2400` = 40 filas exactas. Eso corre la
//   imagen 40 filas y las bandas aparecen desplazadas: la franja medida cayo justo sobre el
//   envolvimiento y quedo ambigua entre el bit 7 y el bit 0.
//
//   El OFFSET es multiplo de 60 -el ancho del framebuffer-, asi que desplaza FILAS pero NO
//   COLUMNAS. Con franjas verticales el mapeo bit<->posicion es exacto, sin correccion.
//
//   La pantalla queda partida en 8 franjas verticales de ~7 columnas:
//       franja mas a la IZQUIERDA = bit 7 (el mas significativo)
//       franja mas a la DERECHA   = bit 0
//   Cada franja es blanca donde ese bit vale 1 y negra donde vale 0.
//
//   COMO SE LEE, tapando y destapando el lente:
//     * franja que CAMBIA             -> ese bit llega bien
//     * franja toda BLANCA fija       -> bit PEGADO EN 1
//     * franja toda NEGRA fija        -> bit PEGADO EN 0
//     * ruido que no responde a la luz -> bit FLOTANDO
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

    // ============ captura camara -> frame buffer (dominio pclk) ============
    // AUTO-SINCRONIZADO: el puntero envuelve en 4800 (=1 cuadro) y se alinea
    // solo. No usa VSYNC (el clon no lo entrega bien).
    reg href_d = 1'b0;
    reg        parity  = 1'b0;
    reg [7:0]  curY    = 8'd0;
    reg [3:0]  colkeep = 4'd0;
    reg [2:0]  rowkeep = 3'd0;
    reg [6:0]  fbx     = 7'd0;
    reg [12:0] waddr_wr= 13'd0;
    // COLUMNA actual dentro del framebuffer de 60 de ancho -> franja de 8 columnas.
    // `fbx` ya cuenta la columna en el codigo original, asi que sale gratis.
    wire [2:0] franja = fbx[6:3] > 3'd7 ? 3'd7 : fbx[6:3];   // 60 columnas / 8 = franjas de 8
    reg        we      = 1'b0;
    reg [12:0] wadr    = 13'd0;
    reg [7:0]  wdat    = 8'd0;

    always @(posedge cam_pclk) begin
        href_d <= cam_href;
        we     <= 1'b0;
        if (~cam_href) begin
            parity <= 1'b0; colkeep <= 4'd0; fbx <= 7'd0;
        end else begin
            if (parity == 1'b0) curY <= cam_d;
            else begin
                if (rowkeep==3'd0 && colkeep==4'd0 && fbx<7'd60) begin
                    we <= 1'b1; wadr <= waddr_wr; // FUENTE=1: en vez del dato de la camara se escribe una RAMPA generada dentro del
                    // FPGA, en el dominio de cam_pclk. Separa dos culpables que hasta ahora no se
                    // podian distinguir:
                    //   * si la rampa se ve LIMPIA -> PCLK y todo el camino al display estan bien,
                    //     y el problema es SOLO el bus cam_d[7:0] (cables).
                    //   * si la rampa se ve RUIDOSA -> el problema es PCLK: la rampa es sincrona,
                    //     asi que solo un reloj sucio puede ensuciarla. No hay cable de datos que
                    //     explique eso.
                    // banda = fila/10, y en cada banda se pinta UN bit de cam_d
                    wdat <= {8{curY[3'd7 - franja]}};   // izquierda = bit 7, derecha = bit 0
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

    // OFFSET de encuadre: ajustar de a ~600 para centrar la imagen partida.
    localparam [13:0] OFFSET = 14'd2400;

    reg [7:0] xcol = 8'd0;
    reg [8:0] ycol = 9'd0;
    wire [6:0] fx = xcol[7:2];
    wire [6:0] fy = ycol[8:2];
    wire [13:0] rsum  = fy*60 + fx + OFFSET;                 // desplaza la lectura
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
