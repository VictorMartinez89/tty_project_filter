// cam_frontend_top.v — FRONT-END de la OV7670 AUTOCONTENIDO para ASIC sky130 (fase 7).
//   Une las 3 piezas verificadas en FPGA: SCCB (config) + captura (PCLK/HREF/VSYNC/D7:0 -> RGB565,
//   con sincronizadores 2-FF = CDC) + RGB565->gris. Entrega un STREAM DE GRIS (gray/gray_valid)
//   listo para cualquiera de los 6 filtros. La salida SCCB open-drain se parte en dato+enable
//   (siod_o/siod_oe): el tri-state vive en el anillo de I/O (Parte 114).
`default_nettype none
module cam_frontend_top #(
    parameter integer SYSCLK_HZ = 48_000_000,
    parameter integer XCLK_HZ   = 12_000_000
)(
    input  wire       sysclk,        // reloj del sistema (dominio del core)
    input  wire       rst_n,         // reset asincrono activo-bajo
    // ---- pines de la camara OV7670 ----
    input  wire [7:0] cam_d,         // D7..D0
    input  wire       cam_pclk,      // reloj de pixel (entra; se sincroniza -> CDC)
    input  wire       cam_href,      // linea valida
    input  wire       cam_vsync,     // inicio de cuadro
    output wire       cam_xclk,      // reloj que el chip da a la camara
    output wire       cam_sioc,      // SCCB clock
    output wire       cam_siod_o,    // SCCB data (open-drain: dato)
    output wire       cam_siod_oe,   // SCCB data (open-drain: enable) -> el pad hace el tri-state
    // ---- stream de gris (dominio del core) ----
    output wire [7:0] gray,
    output wire       gray_valid,
    output wire       frame_start,
    output wire       line_start,
    output wire       cfg_done
);
    // 1) SCCB: configura la camara al arrancar (start atado a 1)
    ov7670_sccb #(.SYSCLK_HZ(SYSCLK_HZ)) u_sccb (
        .clk(sysclk), .rst_n(rst_n), .start(1'b1),
        .sioc(cam_sioc), .siod_o(cam_siod_o), .siod_oe(cam_siod_oe),
        .done(cfg_done), .dbg_reg());

    // 2) captura PCLK/HREF/VSYNC/D -> RGB565 (con sincronizadores = CDC hacia sysclk)
    wire [15:0] px565; wire px_valid;
    ov7670_capture #(.SYSCLK_HZ(SYSCLK_HZ), .XCLK_HZ(XCLK_HZ)) u_cap (
        .sysclk(sysclk), .rst_n(rst_n),
        .cam_d(cam_d), .cam_pclk(cam_pclk), .cam_href(cam_href), .cam_vsync(cam_vsync),
        .cam_xclk(cam_xclk),
        .pixel_rgb565(px565), .pixel_valid(px_valid),
        .frame_start(frame_start), .line_start(line_start));

    // 3) RGB565 -> gris 8 bits
    rgb565_to_gray u_gray (.rgb565(px565), .gray(gray));
    assign gray_valid = px_valid;
endmodule
`default_nettype wire
