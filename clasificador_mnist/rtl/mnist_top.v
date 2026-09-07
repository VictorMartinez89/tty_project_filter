// mnist_top.v — el sistema completo: pixel -> bordes -> formas -> digito.
//   Entra el stream de la imagen, sale el digito reconocido. Es la jerarquia de 3Blue1Brown
//   -pixel, bordes, formas, digito- pero con las dos primeras capas ESCRITAS A MANO (Sobel de
//   1968) en vez de aprendidas, y solo la ultima entrenada. Ese es el argumento de la tesis:
//   a esta escala de silicio, la columna "escrito a mano" le gana a la columna "aprendido".
`default_nettype none
module mnist_top #(
    parameter integer H = 28, parameter integer W = 28, parameter integer CW = 9
)(
    input  wire       clk,
    input  wire       reset,
    input  wire       clr,
    input  wire       in_valid,
    input  wire [7:0] in_pix,
    input  wire [7:0] thr,
    output wire       done,
    output wire [3:0] digito,
    output wire       valido      // 0 = NADA
);
    wire [32*CW-1:0] cnt;
    wire [10:0] n_bordes;
    wire fdone;
    mnist_feat #(.H(H),.W(W),.CW(CW)) FEAT (
        .clk(clk),.reset(reset),.clr(clr),.in_valid(in_valid),.in_pix(in_pix),.thr(thr),
        .frame_done(fdone),.cnt_o(cnt),.n_bordes(n_bordes));
    mnist_clf #(.CW(CW)) CLF (
        .clk(clk),.reset(reset),.start(fdone),.cnt_i(cnt),.n_bordes(n_bordes),
        .done(done),.digito(digito),.valido(valido),.score());
endmodule
`default_nettype wire
