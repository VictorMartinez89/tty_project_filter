// mnist_top_canny.v — el sistema completo con front-end CANNY 1-SALTO.
//   Identico a mnist_top.v salvo por las dos piezas que cambian: el extractor usa doble umbral
//   con histeresis, y el clasificador lleva pesos entrenados CON ese front-end (no son
//   intercambiables: usar los pesos del Sobel aca da resultados sin sentido).
//
//   ESTADO: el extractor NO esta verificado bit a bit contra el golden de Python (mejor
//   coincidencia medida: 97.3 % del mapa de bordes). Esta cadena SIRVE PARA VER CORRER EL
//   SISTEMA, no para reportar precision.
`default_nettype none
module mnist_top_canny_fw #(
    parameter integer H = 28, parameter integer W = 28, parameter integer CW = 9
)(
    input  wire       clk,
    input  wire       reset,
    input  wire       clr,
    input  wire       in_valid,
    input  wire [7:0] in_pix,
    input  wire [7:0] thr_hi,
    input  wire [7:0] thr_lo,
    output wire       done,
    output wire [3:0] digito,
    output wire       valido      // 0 = NADA
);
    wire [32*CW-1:0] cnt;
    wire [10:0] n_bordes;
    wire fdone;
    mnist_feat_canny #(.H(H),.W(W),.CW(CW)) FEAT (
        .clk(clk),.reset(reset),.clr(clr),.in_valid(in_valid),.in_pix(in_pix),
        .thr_hi(thr_hi),.thr_lo(thr_lo),
        .frame_done(fdone),.cnt_o(cnt),.n_bordes(n_bordes),
        .dbg_val(),.dbg_borde(),.dbg_cx(),.dbg_cy(),.dbg_arr());
    mnist_clf_canny_fw #(.CW(CW)) CLF (
        .clk(clk),.reset(reset),.start(fdone),.cnt_i(cnt),.n_bordes(n_bordes),
        .done(done),.digito(digito),.valido(valido),.score());
endmodule
`default_nettype wire
