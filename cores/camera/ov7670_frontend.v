// ============================================================================
// ov7670_frontend.v
// Front-end completo de la OV7670 para la iCESugar: une las 3 piezas y entrega
// un STREAM DE GRIS listo para el filtro (Sobel o Canny):
//
//   ov7670_sccb   -> configura la camara al arranque (SCCB)
//   ov7670_capture-> PCLK/HREF/VSYNC/D[7:0]  ->  pixel RGB565 + pulsos de sync
//   rgb565_to_gray-> RGB565 -> gris 8 bits
//
// Salida:  gray[7:0] + gray_valid (1 pulso/pixel) + frame_start + line_start.
// El filtro downstream consume gray con gray_valid como su px_valid.
// ============================================================================
`default_nettype none
module ov7670_frontend #(
    parameter integer SYSCLK_HZ = 48_000_000,
    parameter integer XCLK_HZ   = 12_000_000
)(
    input  wire        sysclk,
    input  wire        rst_n,
    // ---- pines de la camara ----
    input  wire [7:0]  cam_d,
    input  wire        cam_pclk,
    input  wire        cam_href,
    input  wire        cam_vsync,
    output wire        cam_xclk,
    output wire        cam_sioc,
    output wire        cam_siod,
    // ---- stream de gris ----
    output wire [7:0]  gray,
    output wire        gray_valid,
    output wire        frame_start,
    output wire        line_start,
    output wire        cfg_done
);
    // 1) SCCB: configura la camara (start atado a 1 -> arranca al salir de reset)
    ov7670_sccb #(.SYSCLK_HZ(SYSCLK_HZ)) u_sccb (
        .clk(sysclk), .rst_n(rst_n), .start(1'b1),
        .sioc(cam_sioc), .siod(cam_siod), .done(cfg_done), .dbg_reg());

    // 2) captura -> RGB565
    wire [15:0] px565;
    wire        px_valid;
    ov7670_capture #(.SYSCLK_HZ(SYSCLK_HZ), .XCLK_HZ(XCLK_HZ)) u_cap (
        .sysclk(sysclk), .rst_n(rst_n),
        .cam_d(cam_d), .cam_pclk(cam_pclk), .cam_href(cam_href), .cam_vsync(cam_vsync),
        .cam_xclk(cam_xclk),
        .pixel_rgb565(px565), .pixel_valid(px_valid),
        .frame_start(frame_start), .line_start(line_start));

    // 3) RGB565 -> gris
    rgb565_to_gray u_gray (.rgb565(px565), .gray(gray));
    assign gray_valid = px_valid;
endmodule
`default_nettype wire
