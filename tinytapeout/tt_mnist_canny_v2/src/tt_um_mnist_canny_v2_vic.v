// tt_um_mnist_canny_v2_vic.v — el reconocedor MNIST de 40 rasgos, VERSION 2, para la lanzadera SKY26d.
//
//   Canny 1-salto 90/32 -> 32 contadores (4 cuadrantes x 8 octantes) -> piramide de 40 rasgos ->
//   400 MAC de 4 bits -> argmax -> un digito 0..9, o NADA.
//
//   Que cambia respecto de tt_mnist_canny (v1, IHP26b):
//     1. LA LATENCIA del extractor es 3*(W+1) = 87, no 3*(W+2) = 90. Con 90 los histogramas salian
//        corridos (0 de 6 exactos); con 87, 10000/10000 identicos al golden. Y dos fallos de
//        sincronia corregidos (`listo` congelaba el raster; `clr` se comia su propio ciclo).
//     2. LOS 10 SESGOS RECALIBRADOS sobre train: 92,46 % -> 94,20 %, con los MISMOS 400 pesos y el
//        mismo circuito. Cero celdas de mas.
//     3. `clr` se genera DENTRO (un ciclo despues de `done`), como en el SoC y en el banco verificado.
//        En la v1 venia de un pin y habia que pulsarlo a mano en el momento justo.
//   Verificado: 10000/10000 (contadores, n_bordes y veredicto) contra el golden, con 2 ciclos libres
//   entre pixeles. REQUISITO DE USO: al menos 2 ciclos sin in_valid entre pixel y pixel (el
//   clasificador tarda 412 ciclos y el cuadro siguiente tiene que dejarle sitio).
`default_nettype none
module tt_um_mnist_canny_v2_vic (
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
    reg        clr;
    always @(posedge clk) if (!rst_n) clr <= 1'b0; else clr <= done;
    mnist_top_canny_calib #(.H(28), .W(28), .CW(9)) u_mnist (
        .clk(clk), .reset(~rst_n), .clr(clr),
        .in_valid(uio_in[0]), .in_pix(ui_in),
        .thr_hi(8'd90), .thr_lo(8'd32),
        .done(done), .digito(digito), .valido(valido));
    assign uo_out  = {2'b00, done, valido, digito};
    assign uio_out = 8'b0;
    assign uio_oe  = 8'b0;
    wire _unused = &{ena, uio_in[7:1], 1'b0};
endmodule
`default_nettype wire
