// tb_canny78.v — Canny-78 (mnist_top78) en marcha, hecho para MIRARSE en GTKWave.
//
//   Cuatro imagenes del test de MNIST encadenadas —un 7, un 2, un 1 y un 0, las cuatro primeras—,
//   un pixel cada DOS ciclos (in_valid sube y baja, como con una camara), y al final 8 muestras de
//   cola para que el cauce desague la ultima. Reloj de 10 ns y reset sincrono de 4 ciclos.
//
//   Se vuelcan SOLO las senales que cuentan la historia, con nombres legibles en la raiz del banco:
//     clk reset in_valid in_pix                 -> lo que entra
//     frame_done n_bordes                       -> el extractor termino un cuadro
//     trasvase cuenta                           -> los 128 contadores pasan al clasificador
//     estado pareja acc0 acc1 mejor mejor_clase -> el clasificador trabajando (dos clases por pasada)
//     done digito valido                        -> lo que sale
//   Se juzga solo contra el golden (+EXP): imprime ALL TESTS PASSED si los cuatro veredictos cuadran.
`default_nettype none
`timescale 1ns/1ps
module tb_canny78;
    parameter integer NIMG = 4, GAP = 1;
    // ---- lo que entra ----
    reg        clk = 1'b0, reset = 1'b1, in_valid = 1'b0;
    reg  [7:0] in_pix = 8'd0;
    always #5 clk = ~clk;
    // ---- lo que sale ----
    wire       done, valido;
    wire [3:0] digito;
    mnist_top78 dut (.clk(clk), .reset(reset), .in_valid(in_valid), .in_pix(in_pix),
                     .thr_hi(8'd90), .thr_lo(8'd32), .done(done), .digito(digito), .valido(valido));
    // ---- el interior, con nombres legibles para GTKWave ----
    wire              frame_done  = dut.frame_done;
    wire [10:0]       n_bordes    = dut.n_bordes;
    wire [1:0]        trasvase    = dut.ts;             // 0 espera · 1 copiando · 2 arranca
    wire [7:0]        cuenta      = dut.cnt;            // 0..128 contadores copiados
    wire [2:0]        estado      = dut.clf.st;         // 0 IDLE 1 DERIV 2 MAC 3 ARGMAX 4 DONE (5,6 PRE)
    wire [2:0]        pareja      = dut.clf.cp;         // pareja de clases en curso: (0,1) (2,3) ...
    wire signed [23:0] acc0       = dut.clf.acc0;
    wire signed [23:0] acc1       = dut.clf.acc1;
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
        $display("  imagen %0d: dice %s  (%s)   golden %s   %s   t = %0.2f us", nv,
                 valido ? "habla" : "calla", {"0" + digito}, {"0" + esp[nv][3:0]},
                 (codigo == esp[nv]) ? "ok" : "!! DISTINTO", $realtime/1000.0);
        nv = nv + 1;
    end

    initial begin
        if (!$value$plusargs("IMG=%s", fimg)) fimg = "img4.hex";
        if (!$value$plusargs("EXP=%s", fexp)) fexp = "exp4.hex";
        $readmemh(fimg, img); $readmemh(fexp, esp);
        $dumpfile("canny78.vcd");
        $dumpvars(1, tb_canny78);                 // solo la raiz: los wires con nombre legible
        repeat (4) @(posedge clk); #1 reset = 1'b0;
        for (i = 0; i < NIMG*784; i = i + 1) begin
            @(posedge clk); #1 in_valid = 1'b1; in_pix = img[i];
            for (k = 0; k < GAP; k = k + 1) begin @(posedge clk); #1 in_valid = 1'b0; end
        end
        for (i = 0; i < 8; i = i + 1) begin @(posedge clk); #1 in_valid = 1'b1; in_pix = 8'd0; end
        @(posedge clk); #1 in_valid = 1'b0;
        repeat (1500) @(posedge clk);
        $display("  %0d/%0d veredictos iguales al golden", nbien, NIMG);
        if (nbien == NIMG && nv == NIMG) $display("ALL TESTS PASSED"); else $display("!! HAY FALLOS");
        $finish;
    end
endmodule
`default_nettype wire
