// tt_um_soc_trans_mini_vic.v — SoC RISC-V (FemtoRV32) + MOTOR TRANSITIVO mini, para Tiny Tapeout.
//   Completa la matriz de la tesis en el shuttle: 3 filtros x (sin CPU / con CPU).
//
//   El CPU corre 7 instrucciones desde una ROM sintetizada y escribe el periferico 0x0045:
//   modo = transitivo (2) y los dos umbrales (110/70). El motor consume un stream de CLASE de
//   2 bits y barre el cuadro hasta el punto fijo: un debil sobrevive si toca un fuerte por
//   CUALQUIER cadena de vecinos.
//
//   CUADRO 24x18 (432 px) — ES EL SUBMITIBLE, Y ESTA MEDIDO POR QUE:
//   ~16 870 instancias = 1 054 celdas/tile en los 16 tiles del maximo 8x2. El mismo cuadro que
//   usa la version SIN CPU (36x26) se midio el 2026-08-30 y da 22 855 instancias = 1 428/tile:
//   NO cabe (el shuttle ya fallo a 1 378 y a 1 163). Desglose de esa medicion, en celdas
//   genericas de yosys:
//                       FemtoRV32   periferico   motor    total
//        16x12 (192 px)     6 858        111     3 042   10 122
//        24x18 (432 px)     6 915        111     5 063   12 200
//        36x26 (936 px)     6 915        111     9 391   16 528
//   El CPU es PLANO (6 858 -> 6 915 -> 6 915); el motor cuesta 8.53 celdas por pixel. Y de esas
//   8.53 solo ~2.2 son flip-flops del frame: el 74 % restante es la LOGICA DE ACCESO (el OR de
//   8 vecinos por celda y el mux de lectura). Sin macro de SRAM, un pixel no cuesta 2 bits.
//   OJO al submitir: 24x18 queda en ~43.5 % de utilizacion y el muro empirico esta en ~45 %.
//   El unico run real de este proyecto es el de 16x12 -> conviene correr el flujo antes de fiarse.
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
