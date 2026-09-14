// mnist_cam_soc.v — ESCRIBI UN DIGITO Y LA FPGA TE DICE CUAL ES, con CPU adentro.
//   Identico a mnist_cam_display.v salvo por una cosa: el umbral del filtro ya NO esta cableado.
//   Lo escribe el FemtoRV32 por el periferico 0x0045, igual que en el SoC de la tesis.
//   Existe para contestar si la cadena entera -camara + CPU + clasificador + TFT- entra en la
//   iCE40UP5K, que es la pregunta que la simulacion no contesta.
//
//   camara OV7670 -> ventana cuadrada central -> 28x28 -> clasificador -> TFT ILI9341
//
//   La pantalla muestra TRES cosas:
//     1. lo que el clasificador ve de verdad: las 28x28, ampliadas x8 (224x224 px)
//     2. un MARCO VERDE alrededor -la guia de encuadre-
//     3. el digito reconocido, grande, en siete segmentos, debajo
//
//   EL MARCO NO ES ADORNO. MNIST viene normalizado en tamano y centrado por centro de masa; lo
//   que ve una camara no. En vez de normalizar en hardware -caro y fragil- se hace lo que hace un
//   lector de QR: se fija una ventana y el centrado lo hace la persona metiendo el digito adentro.
//   Es co-diseno en su forma mas barata: mover un requisito del silicio a la interfaz de uso.
//
//   Escribir el digito GRUESO y OSCURO sobre papel blanco, llenando el marco. El modulo invierte
//   -MNIST es trazo claro sobre fondo oscuro- y promedia bloques de 16x16.
//
//   Pines: los mismos del cam_sobel_display probado (Parte 59). LEDs: verde=camara OK,
//   rojo=clasifico al menos una vez, azul=latido.
//
//   Adaptado de cam_sobel_display.v: el SCCB y el driver ILI9341 van VERBATIM -estan probados en
//   la placa-. Lo unico nuevo es el medio: la ventana, el clasificador y el dibujo.
`default_nettype none
module top #(
    // INVERTIR=1: trazo claro sobre fondo oscuro, como MNIST (modo normal).
    // INVERTIR=0: la camara TAL CUAL, para diagnosticar exposicion y foco. Si en modo crudo
    //             se ve una foto normal, la cadena optica esta bien y el problema es de nivel.
    parameter INVERTIR = 1
) (
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

    // ======== ventana central 448x448 -> 28x28 promediado e invertido (dominio pclk) ========
    //   La camara entrega YUV422: el byte de luminancia es uno de cada dos (parity).
    reg parity = 1'b0, href_d = 1'b0;
    reg [7:0] curY = 8'd0;
    reg py_valid = 1'b0;
    reg cam_sync = 1'b0;
    reg [16:0] pcount = 17'd0;                      // auto-sync: la OV7670 clon no da VSYNC usable
    always @(posedge cam_pclk) begin
        href_d <= cam_href; py_valid <= 1'b0;
        if (~cam_href) parity <= 1'b0;
        else begin
            // La luma es el SEGUNDO byte del par: la OV7670 emite U Y V Y. Capturar en
            // parity==0 tomaba la CROMA (~0x80 constante), que es lo que el diagnostico por
            // UART mostro con numeros: PIX=80 80 80 80 81 80 83.
            if (parity == 1'b1) begin curY <= cam_d; py_valid <= 1'b1; end
            parity <= ~parity;
        end
    end

    wire       w_valid; wire [7:0] w_pix; wire w_fin;
    cam_win28 #(.CAM_W(640),.CAM_H(480),.WIN(448),.N(28)) WIN (
        .pclk(cam_pclk), .sync(1'b0), .reset(~cfg_done), .href(cam_href),
        .pix_y(curY), .pix_valid(py_valid), .invertir(INVERTIR[0]),
        .out_valid(w_valid), .out_pix(w_pix), .frame_fin(w_fin));

    // ======== el clasificador (el MISMO verificado bit a bit contra el golden) ========
    wire       clf_done; wire [3:0] clf_dig; wire clf_val;
    // clr cuando TERMINA de clasificar, no en cada cuadro: el video es continuo y el raster
    // se encadena solo. Con clr por cuadro la latencia del pipeline se reinicia y el barrido
    // nunca se completa. El clasificador se autorregula: acumula, clasifica, limpia, repite.
    reg        clf_clr = 1'b0;
    always @(posedge cam_pclk) clf_clr <= clf_done;
    // el umbral lo pone el CPU, no el RTL
    wire [7:0] thr_cpu; wire cpu_wrote;
    soc_mnist_top #(.H(28),.W(28),.CW(9),.FUENTE_THR(0)) CLF (
        .clk(cam_pclk), .reset(~cfg_done), .clr(clf_clr),
        .in_valid(w_valid), .in_pix(w_pix),
        .done(clf_done), .digito(clf_dig), .valido(clf_val),
        .thr_usado(thr_cpu), .cpu_escribio(cpu_wrote));

    // digito reconocido, cruzado al dominio del display (es casi-estatico: 2 FF bastan)
    //   Si el clasificador dice NADA se muestra el codigo 10, que el glifo dibuja como una raya.
    //   Sin esto el chip esta OBLIGADO a elegir uno de diez, y con el cuadro vacio elige siempre
    //   el mismo -el sesgo solo ya favorece una clase-: eso es lo que se veia en la placa como un
    //   "1" fijo. Poder decir "no se" no es un adorno: entre los cuadros que si contesta, la
    //   precision sube de 89.2 % a 93.9 %.
    reg [3:0] dig_pclk = 4'd10;
    reg       hubo = 1'b0;
    always @(posedge cam_pclk) if (clf_done) begin
        dig_pclk <= clf_val ? clf_dig : 4'd10;
        hubo <= 1'b1;
    end
    reg [3:0] dig_s1 = 4'd10, dig_clk = 4'd10;
    reg       hubo_s1 = 1'b0, hubo_clk = 1'b0;
    always @(posedge clk) begin
        dig_s1 <= dig_pclk;  dig_clk  <= dig_s1;
        hubo_s1 <= hubo;     hubo_clk <= hubo_s1;
    end

    // ======== framebuffer de las 28x28 (784 bytes, doble puerto) ========
    reg [7:0]  fb [0:783];
    reg [9:0]  wadr = 10'd0;
    always @(posedge cam_pclk) begin
        if (w_valid) begin
            fb[wadr] <= w_pix;
            wadr <= (wadr == 10'd783) ? 10'd0 : wadr + 10'd1;
        end
        if (w_fin) wadr <= 10'd0;
    end
    reg [7:0] fb_rd = 8'd0;

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

    // ======== que color va en cada pixel de la pantalla (240x320) ========
    //   filas   0..223 : las 28x28 ampliadas x8, con marco verde de 3 px
    //   filas 232..319 : el digito reconocido en siete segmentos
    reg [7:0] xcol = 8'd0;
    reg [8:0] ycol = 9'd0;

    localparam integer IMG = 224;              // 28 * 8
    localparam integer BORDE = 3;
    // en_img mira las DOS coordenadas. Antes solo miraba ycol, asi que las columnas 224..239
    // -que estan fuera de la imagen- caian en el marco derecho y pintaban una franja verde de
    // 19 px en vez de 3. Se veia clarito en la placa.
    wire en_img  = (ycol < IMG) && (xcol < IMG);
    wire [4:0] ix = xcol[7:3];                 // /8
    wire [4:0] iy = ycol[7:3];
    wire [9:0] fbaddr = iy*28 + ix;
    always @(posedge clk) fb_rd <= fb[fbaddr];

    wire en_marco = en_img && ((xcol < BORDE) || (xcol >= IMG-BORDE) ||
                               (ycol < BORDE) || (ycol >= IMG-BORDE));

    // zona del glifo
    localparam integer GY0 = 232, GW = 60, GH = 80;
    wire en_glifo_caja = (ycol >= GY0) && (ycol < GY0+GH) &&
                         (xcol >= (240-GW)/2) && (xcol < (240-GW)/2 + GW);
    wire glifo_on;
    glifo #(.ANCHO(GW),.ALTO(GH),.GRUESO(11)) G (
        .digito(dig_clk),
        .gx(en_glifo_caja ? (xcol - (240-GW)/2) : 8'd0),
        .gy(en_glifo_caja ? (ycol - GY0)        : 8'd0),
        .encendido(glifo_on));

    wire [15:0] gris  = {fb_rd[7:3], fb_rd[7:2], fb_rd[7:3]};
    wire [15:0] VERDE = 16'b00000_111111_00000;
    wire [15:0] AMBAR = 16'b11111_101101_00000;
    wire [15:0] NEGRO = 16'h0000;
    wire [15:0] pcolor = en_marco                        ? VERDE :
                         en_img                          ? gris  :
                         (en_glifo_caja && glifo_on && hubo_clk) ? AMBAR : NEGRO;

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
