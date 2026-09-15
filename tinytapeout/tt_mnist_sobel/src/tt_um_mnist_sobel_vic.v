// tt_um_mnist_sobel_vic.v — "PAN HABLAS": un chip que RECONOCE, no que dibuja.
//
//   Sobel 3x3 -> histograma de 32 contadores -> piramide de 40 rasgos ->
//   400 MAC de 4 bits -> argmax -> un digito de 0 a 9, o NADA.
//
//   Es el primero de los proyectos de esta tesis cuya salida NO es una imagen. Entran
//   pixeles de 8 bits y salen CUATRO BITS y un bit de "me lo creo". Los 400 pesos viven
//   en una ROM combinacional (mnist_weights.vh): no cuestan un solo flip-flop.
//
//   El umbral va CABLEADO a 60 -- el mismo con el que se entrenaron los pesos-- porque
//   TT no da pines para escribirlo. La version con CPU que lo hace registro escribible
//   NO CABE: son ~21 600 celdas contra las ~18 800 que entran en un 8x2.
`default_nettype none
module tt_um_mnist_sobel_vic (
    input  wire [7:0] ui_in,    // in_pix[7:0]
    output wire [7:0] uo_out,   // {2'b0, done, valido, digito[3:0]}
    input  wire [7:0] uio_in,   // [0]=in_valid  [1]=clr
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n     // activo-bajo
);
    localparam [7:0] THR = 8'd60;   // el umbral con el que se entrenaron los pesos

    wire       done, valido;
    wire [3:0] digito;

    mnist_top #(.H(28), .W(28), .CW(9)) u_mnist (
        .clk(clk), .reset(~rst_n),          // mnist_top usa reset activo-alto
        .clr(uio_in[1]),
        .in_valid(uio_in[0]), .in_pix(ui_in),
        .thr(THR),
        .done(done), .digito(digito), .valido(valido));

    assign uo_out  = {2'b00, done, valido, digito};
    assign uio_out = 8'b0;
    assign uio_oe  = 8'b0;                   // los 8 bidi quedan como ENTRADAS
    wire _unused = &{ena, uio_in[7:2], 1'b0};
endmodule
`default_nettype wire
