// =============================================================================
// canny_modular_full.sv  -- Canny MODULAR end-to-end: cadena + histeresis full.
//   gris --> canny_modular_top (compass->NMS->umbral) --> class por pixel
//        --> COLECTOR de frame (arma strong/weak en orden raster interior)
//        --> canny_hysteresis_frame (histeresis TRANSITIVA 8-conexa)  --> edge
//
//   La imagen interior mide IH x IW = (H-4) x (W-4). Cuando el colector junta
//   los IH*IW pixeles, pulsa 'start' a la histeresis; 'done_o' avisa cuando el
//   mapa de bordes 'edge_o' esta listo.
//   NOTA: la histeresis frame es el modelo conductual (vector plano IH*IW bits),
//   ideal para 16x16/verificacion; la version BRAM sintetizable para 160x120 es
//   el siguiente paso (misma semantica, memoria por BRAM + barridos raster).
// =============================================================================
`default_nettype none
module canny_modular_full #(
    parameter integer PIX = 8,
    parameter integer IH  = 12,           // alto  interior (H-4)
    parameter integer IW  = 12,           // ancho interior (W-4)
    parameter integer MAX_IMG_W = 1024
)(
    input  wire             clk_i,
    input  wire             nreset_i,     // activo-bajo (front streaming)
    input  wire [15:0]      img_w_i,      // ancho gris de entrada (W)
    input  wire             px_valid_i,
    input  wire [PIX-1:0]   px_i,
    input  wire [PIX-1:0]   low_i, high_i,
    output wire             done_o,
    output wire [IH*IW-1:0] edge_o
);
    // --- front streaming: gris -> class por pixel interior ---
    wire       cv;
    wire [1:0] cls;
    canny_modular_top #(.PIX(PIX), .MAX_IMG_W(MAX_IMG_W)) u_top (
        .clk_i(clk_i), .nreset_i(nreset_i), .img_w_i(img_w_i),
        .px_valid_i(px_valid_i), .px_i(px_i), .low_i(low_i), .high_i(high_i),
        .out_valid_o(cv), .mag_o(), .dir_o(), .class_o(cls));

    // --- colector: arma frames strong/weak en orden raster interior ---
    reg [IH*IW-1:0]              strong_f, weak_f;
    reg [$clog2(IH*IW+1)-1:0]    idx;
    reg                         start_h, filled;

    wire rst_h = ~nreset_i;                // histeresis usa reset activo-alto

    always @(posedge clk_i or negedge nreset_i) begin
        if (!nreset_i) begin
            idx <= 0; strong_f <= 0; weak_f <= 0; start_h <= 1'b0; filled <= 1'b0;
        end else begin
            start_h <= 1'b0;
            if (cv && !filled) begin
                strong_f[idx] <= (cls == 2'd2);
                weak_f[idx]   <= (cls == 2'd1);
                if (idx == IH*IW-1) begin filled <= 1'b1; start_h <= 1'b1; end
                else idx <= idx + 1'b1;
            end
        end
    end

    canny_hysteresis_frame #(.H(IH), .W(IW)) u_hyst (
        .clk(clk_i), .rst(rst_h), .start(start_h),
        .strong_i(strong_f), .weak_i(weak_f),
        .done(done_o), .edge_o(edge_o));
endmodule
`default_nettype wire
