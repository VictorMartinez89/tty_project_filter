// tt_um_canny78_f9_vic.v — Canny-78 en Tiny Tapeout: el reconocedor del 97,22 % (fmem 168x9).
//
//   Canny 1-salto 90/32 -> 16 zonas x 8 octantes (128 contadores) -> 78 rasgos elegidos ->
//   clasificador lineal de 4 bits, dos clases por pasada -> un digito 0..9, o NADA.
//   El mismo RTL (mnist_top78_f9) que se verifico contra el golden sobre las 10 000 del test.
//   Entra un pixel por ciclo con in_valid; el veredicto de un cuadro sale cuando llegan las
//   primeras muestras del SIGUIENTE (el cauce desagua), ~778 ciclos despues.
//   Los umbrales van cableados a 90/32, los del entrenamiento: TT no da pines para escribirlos.
`default_nettype none
module tt_um_canny78_f9_vic (
    input  wire [7:0] ui_in,    // in_pix[7:0]
    output wire [7:0] uo_out,   // {2'b0, done, valido, digito[3:0]}
    input  wire [7:0] uio_in,   // [0] = in_valid
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n     // activo-bajo
);
    wire       done, valido;
    wire [3:0] digito;
    mnist_top78_f9 u_canny78 (
        .clk(clk), .reset(~rst_n),
        .in_valid(uio_in[0]), .in_pix(ui_in),
        .thr_hi(8'd90), .thr_lo(8'd32),
        .done(done), .digito(digito), .valido(valido));
    assign uo_out  = {2'b00, done, valido, digito};
    assign uio_out = 8'b0;
    assign uio_oe  = 8'b0;
    wire _unused = &{ena, uio_in[7:1], 1'b0};
endmodule
`default_nettype wire
