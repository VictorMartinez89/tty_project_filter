// trans_engine_top.v — MOTOR de histeresis TRANSITIVA (reconstruccion morfologica de Canny)
// AUTOCONTENIDO para ASIC sky130. Envuelve hysteresis_frame_bram_sync al tamano MINI 16x12 (lo que cabe en Tiny Tapeout con CPU adentro).
//   Entra un stream de CLASE (0=nada/1=debil/2=fuerte); el motor barre el frame en bucle hasta el
//   punto fijo (un debil sobrevive si toca un fuerte, transitivamente) y emite el mapa de bordes.
//   El "frame buffer" (padded 62x82 x 2 bits) en la iCE40 iba a SPRAM; en el ASIC NO hay SPRAM ->
//   se vuelve FLIP-FLOPS. Es "la memoria ya no es gratis" en su forma extrema.
`default_nettype none
module trans_engine_top (
    input  wire       clk,
    input  wire       nreset,       // reset asincrono, activo-bajo (0=reset, 1=corre)
    input  wire       in_valid,     // carga: hay una clase valida este ciclo
    input  wire [1:0] class_in,     // 0 nada / 1 debil / 2 fuerte
    output wire       load_ready,   // el motor esta listo para recibir el stream de clase
    output wire       out_valid,    // emitiendo mapa de bordes
    output wire       edge_out,     // 1 = borde (tras la reconstruccion)
    output wire       done          // barrido terminado, frame emitido
);
    hysteresis_frame_bram_sync #(.H(16), .W(12)) ENG (
        .clk_i(clk), .nreset_i(nreset), .in_valid_i(in_valid), .class_i(class_in),
        .load_ready_o(load_ready), .out_valid_o(out_valid), .edge_o(edge_out), .done_o(done));
endmodule
`default_nettype wire
