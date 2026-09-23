// tb_clf78.v — el clasificador con los sesgos calibrados, contador por contador.
//
// Alimenta los 32 contadores desde un fichero y escribe el veredicto. No simula el raster:
// lo que cambio son los 10 sesgos, y el extractor de caracteristicas ya esta verificado
// aparte. Aislar el cambio es lo que hace que la prueba signifique algo.
`default_nettype none
`timescale 1ns/1ps
module tb_clf78;
    localparam CW = 9;
    reg clk = 0, reset = 1, start = 0;
    reg [128*CW-1:0] cnt_i = 0;
    reg [10:0] n_bordes = 0;
    wire done, valido; wire [3:0] digito; wire signed [23:0] score;

    mnist_clf78 u (.clk(clk), .reset(reset), .start(start), .cnt_i(cnt_i),
        .n_bordes(n_bordes), .done(done), .digito(digito), .valido(valido), .score(score));

    always #5 clk = ~clk;

    integer i, fd, n;
    reg [31:0] v [0:128];          // 32 contadores + n_bordes
    reg [1023:0] fin, fout;   // 128 caracteres: una ruta absoluta no cabe en 32
    initial begin
        if (!$value$plusargs("IN=%s",  fin))  begin $display("falta +IN");  $finish; end
        if (!$value$plusargs("OUT=%s", fout)) begin $display("falta +OUT"); $finish; end
        $readmemh(fin, v);
        for (i = 0; i < 128; i = i + 1) cnt_i[i*CW +: CW] = v[i][CW-1:0];
        n_bordes = v[128][10:0];
        repeat (4) @(posedge clk); reset = 0;
        @(posedge clk); start = 1; @(posedge clk); start = 0;
        n = 0;
        while (!done && n < 20000) begin @(posedge clk); n = n + 1; end
        fd = $fopen(fout, "w");
        $fwrite(fd, "%0d %0d %0d\n", digito, valido, score);
        $fclose(fd);
        $finish;
    end
endmodule
