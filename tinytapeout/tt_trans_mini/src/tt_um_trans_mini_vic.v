// tt_um_trans_mini_vic.v — MOTOR de histeresis TRANSITIVA (reconstruccion morfologica) para Tiny Tapeout.
//   Version "mini" del motor de la tesis: 36x26 en vez de 80x60. El frame de clase se vuelve
//   flip-flops (no hay SPRAM en el ASIC), asi que la resolucion es lo que decide si cabe:
//   a 80x60 son ~53 tiles (imposible); a 36x26 son ~10 (entra).
//
//   Entra un stream de CLASE de 2 bits (0=nada / 1=debil / 2=fuerte) y el motor barre el cuadro
//   entero K veces hasta el punto fijo: un debil sobrevive si toca a un fuerte, TRANSITIVAMENTE
//   (por toda la cadena, no solo el vecino pegado). Despues emite el mapa de bordes.
`default_nettype none
module tt_um_trans_mini_vic (
    input  wire [7:0] ui_in,    // ui_in[1:0] = class_in (0 nada / 1 debil / 2 fuerte)
    output wire [7:0] uo_out,   // uo_out[0] = edge_out
    input  wire [7:0] uio_in,   // uio_in[0] = in_valid
    output wire [7:0] uio_out,  // [1]=out_valid  [2]=done  [3]=load_ready
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);
    wire load_ready, out_valid, edge_out, done;

    hysteresis_frame_bram_sync #(.H(36), .W(26)) ENG (
        .clk_i(clk), .nreset_i(rst_n),              // reset asincrono activo-bajo
        .in_valid_i(uio_in[0]), .class_i(ui_in[1:0]),
        .load_ready_o(load_ready), .out_valid_o(out_valid),
        .edge_o(edge_out), .done_o(done));

    assign uo_out  = {7'b0, edge_out};              // 1 = borde tras la reconstruccion
    assign uio_out = {4'b0, load_ready, done, out_valid, 1'b0};
    assign uio_oe  = 8'b0000_1110;                  // uio[1..3] = salidas
    wire _unused = &{ena, ui_in[7:2], uio_in[7:1], 1'b0};
endmodule
`default_nettype wire
