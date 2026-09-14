// soc_mnist_top.v — LA CADENA CON CPU: SoC femto + Sobel + clasificador MNIST.
//
//   cam_win28 (28x28)  ->  mnist_feat  ->  mnist_clf  ->  0..9 o NADA
//                              ^
//                              |  thr
//                     soc_sobel_top  (FemtoRV32 + ROM + periferico 0x0045 + Sobel)
//
//   QUE APORTA EL CPU, exactamente: el umbral del filtro deja de estar CABLEADO y pasa a ser un
//   registro que el firmware escribe. El datapath no cambia -la tesis midio 45 pares con y sin
//   CPU identicos pixel a pixel-; lo que cambia es QUIEN elige el numero.
//
//   La §12 del cuaderno 2 midio en Python cuanto vale eso: -1.67 pp sobre MNIST limpio y
//   +27.27 pp con ruido severo. Esta es la version en hardware de ese experimento.
//
//   FUENTE_THR permite comparar las dos situaciones en el MISMO banco:
//     0 = el umbral lo fija el CPU (lo que hace el SoC real; el firmware pone 90)
//     1 = umbral cableado THR_FIJO (lo que hace el diseno sin CPU)
`default_nettype none
module soc_mnist_top #(
    parameter integer H = 28, parameter integer W = 28, parameter integer CW = 9,
    parameter integer FUENTE_THR = 0,
    parameter [7:0]   THR_FIJO   = 8'd60
)(
    input  wire       clk,
    input  wire       reset,          // sincrono, activo-alto
    input  wire       clr,
    input  wire       in_valid,
    input  wire [7:0] in_pix,
    output wire       done,
    output wire [3:0] digito,
    output wire       valido,
    output wire [7:0] thr_usado,      // observabilidad: que umbral se uso de verdad
    output wire       cpu_escribio
);
    // ---- el SoC: corre el firmware y fija el umbral por el periferico 0x0045 ----
    wire [7:0] thr_cpu;
    // soc_ctrl = FemtoRV32 + ROM + periferico, SIN el datapath Sobel duplicado.
    // Ese filtro sobra aca (mnist_feat tiene el suyo) y son ~1 300 LUT4 de mas.
    soc_ctrl SOC (.clk(clk), .resetn(~reset),
                  .thr_o(thr_cpu), .cpu_wrote(cpu_escribio));

    assign thr_usado = (FUENTE_THR == 0) ? thr_cpu : THR_FIJO;

    // ---- el clasificador, usando ESE umbral ----
    wire [32*CW-1:0] cnt;
    wire [10:0] n_bordes;
    wire fdone;
    mnist_feat #(.H(H),.W(W),.CW(CW)) FEAT (
        .clk(clk), .reset(reset), .clr(clr),
        .in_valid(in_valid), .in_pix(in_pix), .thr(thr_usado),
        .frame_done(fdone), .cnt_o(cnt), .n_bordes(n_bordes));
    mnist_clf #(.CW(CW)) CLF (
        .clk(clk), .reset(reset), .start(fdone), .cnt_i(cnt), .n_bordes(n_bordes),
        .done(done), .digito(digito), .valido(valido), .score());
endmodule
`default_nettype wire
