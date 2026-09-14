// soc_mnist_canny_top.v — SoC femto + CANNY 1-salto + clasificador.
//   Igual que soc_mnist_top.v pero con el front-end Canny, y con el firmware PARAMETRIZADO:
//   la constante que el CPU escribe en 0x0045+4 lleva los DOS umbrales empaquetados.
//
//     UMBRALES = 16'h5A00  ->  thr_hi=90  thr_lo=0    (el firmware ORIGINAL, del Sobel)
//     UMBRALES = 16'h5A20  ->  thr_hi=90  thr_lo=32   (el firmware propio del Canny)
//
//   La §16 del cuaderno 2 midio que la diferencia son 2.10 puntos de exactitud sobre las
//   10 000 imagenes. Este banco la muestra sobre once escenas, en hardware simulado.
`default_nettype none
module soc_mnist_canny_top #(
    parameter integer H = 28, parameter integer W = 28, parameter integer CW = 9,
    parameter [15:0]  UMBRALES = 16'h5A20
)(
    input  wire       clk,
    input  wire       reset,
    input  wire       clr,
    input  wire       in_valid,
    input  wire [7:0] in_pix,
    output wire       done,
    output wire [3:0] digito,
    output wire       valido,
    output wire [7:0] thr_hi_o,
    output wire [7:0] thr_lo_o,
    output wire       cpu_escribio
);
    wire [7:0] thr_hi, thr_lo;
    soc_ctrl #(.UMBRALES(UMBRALES)) SOC (
        .clk(clk), .resetn(~reset), .thr_o(thr_hi), .cpu_wrote(cpu_escribio));
    // soc_ctrl expone thr_hi; el thr_lo sale del mismo periferico
    assign thr_lo   = SOC.flt_tlo;
    assign thr_hi_o = thr_hi;
    assign thr_lo_o = thr_lo;

    wire [32*CW-1:0] cnt;
    wire [10:0] n_bordes;
    wire fdone;
    mnist_feat_canny #(.H(H),.W(W),.CW(CW)) FEAT (
        .clk(clk),.reset(reset),.clr(clr),.in_valid(in_valid),.in_pix(in_pix),
        .thr_hi(thr_hi),.thr_lo(thr_lo),
        .frame_done(fdone),.cnt_o(cnt),.n_bordes(n_bordes),
        .dbg_val(),.dbg_borde(),.dbg_cx(),.dbg_cy(),.dbg_arr());
    mnist_clf_canny #(.CW(CW)) CLF (
        .clk(clk),.reset(reset),.start(fdone),.cnt_i(cnt),.n_bordes(n_bordes),
        .done(done),.digito(digito),.valido(valido),.score());
endmodule
`default_nettype wire
