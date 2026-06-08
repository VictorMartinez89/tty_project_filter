// =============================================================================
// canny_datapath.sv  -- datapath de Canny por pixel (DESPUES del suavizado).
//   Entrada: ventana 3x3 YA suavizada (gris) + umbrales low/high.
//   gradiente (sobel_grad_core) -> magnitud -> doble umbral (canny_grad_threshold_core).
//   USE_SQRT=1 usa sqrt(Gx^2+Gy^2) (exacto); =0 usa |Gx|+|Gy| (barato).
//   NOTA: NMS + histeresis NO van aqui (no son por-pixel) -> modulo de control futuro.
// =============================================================================
`default_nettype none
module canny_datapath #(
    parameter integer PIX=8,
    parameter integer USE_SQRT=0
)(
    input  wire [9*PIX-1:0] sm_window_i,   // ventana 3x3 suavizada
    input  wire [PIX+3:0]   low_i,
    input  wire [PIX+3:0]   high_i,
    output wire [PIX+3:0]   g_low_o,
    output wire [PIX+3:0]   g_high_o,
    output wire [1:0]       class_o,
    output wire [(PIX+4+1)/2:0] combo_o
);
    wire [PIX+3:0] mabs, msq;
    sobel_grad_core #(.PIX(PIX)) u_g (.window_i(sm_window_i), .mag_abs_o(mabs), .mag_sqrt_o(msq));
    wire [PIX+3:0] mag = USE_SQRT ? msq : mabs;
    canny_grad_threshold_core #(.MAGW(PIX+4)) u_t (
        .mag_i(mag), .low_i(low_i), .high_i(high_i),
        .g_low_o(g_low_o), .g_high_o(g_high_o), .class_o(class_o), .combo_o(combo_o));
endmodule
`default_nettype wire
