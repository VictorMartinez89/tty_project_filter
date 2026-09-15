// tt_um_mnist_canny_vic.v — "PAN HABLAS": un chip que RECONOCE, no que dibuja.
//
//   Canny 1-salto (Gauss -> Sobel -> doble umbral -> histeresis 1 salto) -> histograma de 32 contadores -> piramide de 40 rasgos ->
//   400 MAC de 4 bits -> argmax -> un digito de 0 a 9, o NADA.
//
//   Es el primero de los proyectos de esta tesis cuya salida NO es una imagen. Entran
//   pixeles de 8 bits y salen CUATRO BITS y un bit de "me lo creo". Los 400 pesos viven
//   en una ROM combinacional (mnist_weights.vh): no cuestan un solo flip-flop.
//
//   Los umbrales van CABLEADOS a 90/32 -- los mismos con el que se entrenaron los pesos-- porque
//   TT no da pines para escribirlo. La version con CPU que lo hace registro escribible
//   NO CABE: son ~21 600 celdas contra las ~18 800 que entran en un 8x2.
`default_nettype none
module tt_um_mnist_canny_vic (
    input  wire [7:0] ui_in,    // in_pix[7:0]
    output wire [7:0] uo_out,   // {2'b0, done, valido, digito[3:0]}
    input  wire [7:0] uio_in,   // [0]=in_valid  [1]=clr
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n     // activo-bajo
);
    // Los DOS umbrales del firmware (constante 0x5A20), que son los mismos con los que
    // se entrenaron estos pesos. En el SoC llegan por un solo `sw` de 32 bits; aca van
    // cableados porque TT no da 16 pines para escribirlos.
    localparam [7:0] THR_HI = 8'd90, THR_LO = 8'd32;

    wire       done, valido;
    wire [3:0] digito;

    mnist_top_canny_fw #(.H(28), .W(28), .CW(9)) u_mnist (
        .clk(clk), .reset(~rst_n),          // reset activo-alto
        .clr(uio_in[1]),
        .in_valid(uio_in[0]), .in_pix(ui_in),
        .thr_hi(THR_HI), .thr_lo(THR_LO),
        .done(done), .digito(digito), .valido(valido));

    assign uo_out  = {2'b00, done, valido, digito};
    assign uio_out = 8'b0;
    assign uio_oe  = 8'b0;                   // los 8 bidi quedan como ENTRADAS
    wire _unused = &{ena, uio_in[7:2], 1'b0};
endmodule
`default_nettype wire
