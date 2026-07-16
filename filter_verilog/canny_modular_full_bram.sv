// =============================================================================
// canny_modular_full_bram.sv -- Canny MODULAR end-to-end con histeresis en BRAM.
//   Igual que canny_modular_full pero reemplaza el colector + el modelo conductual
//   (canny_hysteresis_frame, vector plano) por hysteresis_frame_bram_sync (BRAM,
//   lectura sincrona). Cadena completa, todo sintetizable:
//
//   gris --> canny_modular_top (compass->NMS->umbral) --> class por pixel
//        --> hysteresis_frame_bram_sync (transitiva, BRAM)  --> stream de borde
//
//   SECUENCIA (importante): la histeresis hace CLR de su RAM (~ (IH+2)*(IW+2)
//   ciclos) antes de aceptar clase -> se expone load_ready_o. El que maneja el
//   stream de gris debe esperar load_ready_o=1 antes de empezar a streamear, para
//   no perder pixeles de clase. La clase llega intermitente (solo en pixeles
//   interiores) y la histeresis la consume con in_valid (avanza solo con valid).
//   La imagen interior es IH x IW = (H-4) x (W-4).
// =============================================================================
`default_nettype none
module canny_modular_full_bram #(
    parameter integer PIX = 8,
    parameter integer IH  = 12,           // alto  interior (H-4)
    parameter integer IW  = 12,           // ancho interior (W-4)
    parameter integer MAX_IMG_W = 1024
)(
    input  wire           clk_i,
    input  wire           nreset_i,       // activo-bajo
    input  wire [15:0]    img_w_i,        // ancho gris de entrada (W)
    input  wire           px_valid_i,
    input  wire [PIX-1:0] px_i,
    input  wire [PIX-1:0] low_i, high_i,
    output wire           load_ready_o,   // 1 = histeresis lista (streamear gris)
    output wire           out_valid_o,    // stream de borde
    output wire           edge_o,
    output wire           done_o
);
    // --- front streaming: gris -> class por pixel interior ---
    wire       cv;
    wire [1:0] cls;
    canny_modular_top #(.PIX(PIX), .MAX_IMG_W(MAX_IMG_W)) u_top (
        .clk_i(clk_i), .nreset_i(nreset_i), .img_w_i(img_w_i),
        .px_valid_i(px_valid_i), .px_i(px_i), .low_i(low_i), .high_i(high_i),
        .out_valid_o(cv), .mag_o(), .dir_o(), .class_o(cls));

    // --- histeresis transitiva en BRAM: consume class, emite borde ---
    hysteresis_frame_bram_sync #(.H(IH), .W(IW)) u_hyst (
        .clk_i(clk_i), .nreset_i(nreset_i),
        .in_valid_i(cv), .class_i(cls), .load_ready_o(load_ready_o),
        .out_valid_o(out_valid_o), .edge_o(edge_o), .done_o(done_o));
endmodule
`default_nettype wire
