// sobel_completo.v — LA CADENA DE VISION COMPLETA en un chip, pieza a pieza (sin CPU), para ASIC sky130.
//   camara OV7670 --> [cam_frontend_top: SCCB + captura + CDC + RGB565->gris]
//                 --> [sobel_top: Sobel 3x3, umbral fijo]
//                 --> [framebuffer 60x80] (puente stream->pantalla; guarda bordes binarios)
//                 --> [lcd_ili9341_top: SPI + ROM ILI9341] --> PMOD TFTLCD
//   Ensamblado con los MODULOS reusables ya verificados (fases 7, 1, 8). UN SOLO RELOJ (clk): el
//   front-end sincroniza PCLK/HREF/VSYNC con 2-FF internos (Parte 152), asi que no hay dual-clock.
`default_nettype none
module sobel_completo (
    input  wire       clk,
    input  wire       rst_n,
    // ---- camara OV7670 ----
    input  wire [7:0] cam_d,
    input  wire       cam_pclk,
    input  wire       cam_href,
    input  wire       cam_vsync,
    output wire       cam_xclk,
    output wire       cam_sioc,
    output wire       cam_siod_o,
    output wire       cam_siod_oe,
    // ---- display PMOD TFTLCD ----
    output wire       tft_sck,
    output wire       tft_mosi,
    output wire       tft_cs,
    output wire       tft_dc,
    // ---- estado ----
    output wire       cfg_done,
    output wire       init_done
);
    // ===== 1) FRONT-END: camara -> stream de gris (dominio clk) =====
    wire [7:0] gray; wire gray_valid, fe_frame_start, fe_line_start;
    cam_frontend_top u_fe (
        .sysclk(clk), .rst_n(rst_n),
        .cam_d(cam_d), .cam_pclk(cam_pclk), .cam_href(cam_href), .cam_vsync(cam_vsync),
        .cam_xclk(cam_xclk), .cam_sioc(cam_sioc), .cam_siod_o(cam_siod_o), .cam_siod_oe(cam_siod_oe),
        .gray(gray), .gray_valid(gray_valid), .frame_start(fe_frame_start), .line_start(fe_line_start),
        .cfg_done(cfg_done));

    // ===== 2) FILTRO: Sobel 3x3 (umbral fijo 90) =====
    wire sob_v; wire [7:0] sob_p;
    sobel_top u_sob (
        .clk(clk), .reset(~rst_n),
        .in_valid(gray_valid), .in_pix(gray), .thr(8'd90),
        .out_valid(sob_v), .out_pix(sob_p));

    // ===== 3) FRAMEBUFFER 60x80 (bordes binarios -> se colapsa a ~1 bit/pixel) =====
    reg [7:0] fb [0:4799];
    reg [12:0] wadr;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) wadr <= 13'd0;
        else if (fe_frame_start) wadr <= 13'd0;                 // alinear con el cuadro
        else if (sob_v) begin
            fb[wadr] <= sob_p;
            wadr <= (wadr == 13'd4799) ? 13'd0 : wadr + 1'b1;
        end
    end

    // ===== 4) generador de direccion de lectura para el LCD (240x320 -> escala a 60x80) =====
    wire lcd_next, lcd_fs;
    reg [7:0] xcol; reg [8:0] ycol;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin xcol <= 8'd0; ycol <= 9'd0; end
        else if (lcd_fs) begin xcol <= 8'd0; ycol <= 9'd0; end
        else if (lcd_next) begin
            if (xcol == 8'd239) begin xcol <= 8'd0; ycol <= (ycol==9'd319)?9'd0:ycol+1'b1; end
            else xcol <= xcol + 1'b1;
        end
    end
    wire [6:0] fx = xcol[7:2];
    wire [6:0] fy = ycol[8:2];
    wire [13:0] raddr = fy*60 + fx;
    reg [7:0] fb_rd;
    always @(posedge clk) fb_rd <= fb[raddr[12:0]];

    // ===== 5) LCD DRIVER: pinta el framebuffer por SPI =====
    lcd_ili9341_top u_lcd (
        .clk(clk), .rst_n(rst_n),
        .pix_gray(fb_rd), .pix_next(lcd_next), .frame_start(lcd_fs), .init_done(init_done),
        .tft_sck(tft_sck), .tft_mosi(tft_mosi), .tft_cs(tft_cs), .tft_dc(tft_dc));

    wire _unused = &{fe_line_start, 1'b0};
endmodule
`default_nettype wire
