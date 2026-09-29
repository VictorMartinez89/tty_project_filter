// tb_canny98.v — Canny-98 (mnist_top98) en marcha, hecho para MIRARSE en GTKWave.
//
//   Las cuatro primeras imagenes del test de MNIST —un 7, un 2, un 1 y un 0— encadenadas. A diferencia de
//   tb_canny78, el pixel llega cada 32 ciclos (GAP=31), como con la camara o el puerto serie: el clasificador
//   tarda ~22 000 ciclos por imagen y la siguiente no debe llegar antes. Reloj de 10 ns, reset de 4 ciclos.
//   Senales, con nombres legibles en la raiz del banco:
//     clk reset in_valid in_pix                         -> lo que entra
//     frame_done n_bordes trasvase cuenta               -> el extractor y el trasvase de los 128 contadores
//     estado neurona clase indice acc h8 escribe_h      -> el clasificador: capa oculta y capa de salida
//     mejor mejor_clase                                 -> el argmax
//     done digito valido                                -> lo que sale
//   Se juzga contra el modelo entero (+EXP): imprime ALL TESTS PASSED si los cuatro veredictos cuadran.
`default_nettype none
`timescale 1ns/1ps
module tb_canny98;
    parameter integer NIMG = 4, GAP = 31;
    reg        clk = 1'b0, reset = 1'b1, in_valid = 1'b0;
    reg  [7:0] in_pix = 8'd0;
    always #5 clk = ~clk;
    wire       done, valido;
    wire [3:0] digito;
    mnist_top98 dut (.clk(clk), .reset(reset), .in_valid(in_valid), .in_pix(in_pix),
                     .thr_hi(8'd90), .thr_lo(8'd32), .done(done), .digito(digito), .valido(valido));
    // ---- el interior, con nombres legibles para GTKWave ----
    wire              frame_done  = dut.frame_done;
    wire [10:0]       n_bordes    = dut.n_bordes;
    wire [1:0]        trasvase    = dut.ts;             // 0 espera · 1 copiando · 2 arranca
    wire [7:0]        cuenta      = dut.cnt;            // 0..128 contadores copiados
    wire [2:0]        estado      = dut.clf.st;         // 0 IDLE 1 DERIV 2 CAPA1 3 CAPA2 4 DONE
    wire [6:0]        neurona     = dut.clf.j;          // 0..119 en la capa oculta
    wire [3:0]        clase       = dut.clf.c;          // 0..9 en la capa de salida
    wire [7:0]        indice      = dut.clf.ka;         // rasgo (0..167) o neurona (0..119) que se pide
    wire signed [23:0] acc        = dut.clf.acc;
    wire [7:0]        h8          = dut.clf.h8;         // la activacion que se escribe en la SPRAM
    wire              escribe_h   = dut.clf.sp_we;
    wire signed [23:0] mejor      = dut.clf.mejor;
    wire [3:0]        mejor_clase = dut.clf.mejor_c;

    reg [7:0] img [0:784*NIMG-1];
    reg [7:0] esp [0:NIMG-1];
    reg [1023:0] fimg, fexp;
    integer i, k, nv = 0, nbien = 0;
    reg [7:0] codigo;
    always @(posedge clk) if (done) begin
        codigo = {3'b010, valido, digito};
        if (codigo == esp[nv]) nbien = nbien + 1;
        $display("  imagen %0d: dice %s  (%s)   modelo %s   %s   t = %0.1f us", nv,
                 valido ? "habla" : "calla", {"0" + digito}, {"0" + esp[nv][3:0]},
                 (codigo == esp[nv]) ? "ok" : "!! DISTINTO", $realtime/1000.0);
        nv = nv + 1;
    end
    initial begin
        if (!$value$plusargs("IMG=%s", fimg)) fimg = "img4.hex";
        if (!$value$plusargs("EXP=%s", fexp)) fexp = "exp4.hex";
        $readmemh(fimg, img); $readmemh(fexp, esp);
        $dumpfile("canny98.vcd");
        $dumpvars(1, tb_canny98);
        repeat (4) @(posedge clk); #1 reset = 1'b0;
        for (i = 0; i < NIMG*784; i = i + 1) begin
            @(posedge clk); #1 in_valid = 1'b1; in_pix = img[i];
            for (k = 0; k < GAP; k = k + 1) begin @(posedge clk); #1 in_valid = 1'b0; end
        end
        for (i = 0; i < 8; i = i + 1) begin @(posedge clk); #1 in_valid = 1'b1; in_pix = 8'd0;
            for (k = 0; k < GAP; k = k + 1) begin @(posedge clk); #1 in_valid = 1'b0; end end
        repeat (26000) @(posedge clk);
        $display("  %0d/%0d veredictos iguales al modelo", nbien, NIMG);
        if (nbien == NIMG && nv == NIMG) $display("ALL TESTS PASSED"); else $display("!! HAY FALLOS");
        $finish;
    end
endmodule
`default_nettype wire
