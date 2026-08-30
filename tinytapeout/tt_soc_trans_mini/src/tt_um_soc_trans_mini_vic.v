// tt_um_soc_trans_mini_vic.v — SoC RISC-V (FemtoRV32) + MOTOR TRANSITIVO mini, para Tiny Tapeout.
//   Completa la matriz de la tesis en el shuttle: 3 filtros x (sin CPU / con CPU).
//
//   El CPU corre 7 instrucciones desde una ROM sintetizada y escribe el periferico 0x0045:
//   modo = transitivo (2) y los dos umbrales (110/70). El motor consume un stream de CLASE de
//   2 bits y barre el cuadro hasta el punto fijo: un debil sobrevive si toca un fuerte por
//   CUALQUIER cadena de vecinos.
//
//   CUADRO 36x26 — EL MISMO QUE LA VERSION SIN CPU, Y NO CABE (medido el 2026-08-30):
//   16 528 celdas genericas -> ~22 855 instancias finales -> 1 428 celdas/tile en los 16 tiles del
//   maximo 8x2. El shuttle ya fallo (GPL-0302 / sin converger) a 1 378 y a 1 163 celdas/tile, asi
//   que este cuadro pide ~25 tiles y el techo son 16. Se deja MEDIDO, no para submitir: la version
//   submitible es 24x18 (16 870 instancias, 1 054/tile) -> `git checkout -- .` para volver a ella.
//   El numero es el argumento de la tesis: en los MISMOS 16 tiles, el motor solo guarda 36x26 = 936
//   pixeles (14 004 instancias reales, 875/tile) y con el FemtoRV32 adentro solo 24x18 = 432. La
//   diferencia, ~8 850 celdas, es el cerebro: cuesta fijo y NO encoge. El cuadro si.
//   Es un DEMOSTRADOR de la arquitectura, no un procesador de imagen util: lo que prueba es que
//   el CPU configura el motor y que la histeresis transitiva propaga la cadena entera.
`default_nettype none
module tt_um_soc_trans_mini_vic (
    input  wire [7:0] ui_in,    // ui_in[1:0] = class_in (0 nada / 1 debil / 2 fuerte)
    output wire [7:0] uo_out,   // uo_out[0] = edge_out
    input  wire [7:0] uio_in,   // uio_in[0] = in_valid
    output wire [7:0] uio_out,  // [1]=out_valid [2]=done [3]=load_ready [4]=cpu_wrote_filter
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);
    wire load_ready, out_valid, edge_out, done, cpu_wrote;
    wire [7:0] thr_hi_o, thr_lo_o; wire [1:0] mode_o;

    soc_trans_top u_soc (
        .clk(clk), .resetn(rst_n),
        .in_valid(uio_in[0]), .class_in(ui_in[1:0]),
        .load_ready(load_ready), .out_valid(out_valid), .edge_out(edge_out), .done(done),
        .cpu_wrote_filter(cpu_wrote),
        .thr_hi_o(thr_hi_o), .thr_lo_o(thr_lo_o), .mode_o(mode_o));

    assign uo_out  = {7'b0, edge_out};
    assign uio_out = {3'b0, cpu_wrote, load_ready, done, out_valid, 1'b0};
    assign uio_oe  = 8'b0001_1110;                  // uio[1..4] = salidas
    wire _unused = &{ena, ui_in[7:2], uio_in[7:1], thr_hi_o, thr_lo_o, mode_o, 1'b0};
endmodule
`default_nettype wire
