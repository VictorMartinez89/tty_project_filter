// tb_clf78_bram.v — el clasificador con las caracteristicas en memoria.
// Carga los 128 contadores por el puerto de escritura, arranca, y escribe el veredicto.
`default_nettype none
`timescale 1ns/1ps
module tb_traza;
    localparam FW = 13;
    reg clk=0, reset=1, start=0, wr_en=0;
    reg [7:0]  wr_addr=0;
    reg [FW-1:0] wr_data=0;
    reg [10:0] n_bordes=0;
    wire done, valido; wire [3:0] digito; wire signed [23:0] score;
    mnist_clf78_bram u(.clk(clk),.reset(reset),.wr_en(wr_en),.wr_addr(wr_addr),.wr_data(wr_data),
        .start(start),.n_bordes(n_bordes),.done(done),.digito(digito),.valido(valido),.score(score));
    always #5 clk=~clk;
    integer i,fd,n;
    reg [31:0] v [0:128];
    reg [1023:0] fin,fout;
    initial begin
        if(!$value$plusargs("IN=%s",fin))  begin $display("falta +IN");  $finish; end
        if(!$value$plusargs("OUT=%s",fout))begin $display("falta +OUT"); $finish; end
        $readmemh(fin,v);
        repeat(4) @(posedge clk); reset=0; @(posedge clk);
        // cargar los 128 contadores
        for(i=0;i<128;i=i+1) begin
            wr_en=1; wr_addr=i[7:0]; wr_data=v[i][FW-1:0]; @(posedge clk);
        end
        wr_en=0; n_bordes=v[128][10:0]; @(posedge clk);
        start=1; @(posedge clk); start=0;
        $monitor("  t=%0t st=%0d t_=%0d fase=%0d fidx=%0d j=%0d c=%0d rd_a=%0d", $time, u.st, u.t, u.fase, u.fidx, u.j, u.c, u.rd_a);
        n=0; while(!done && n<60000) begin @(posedge clk); n=n+1; end
        fd=$fopen(fout,"w");
        $fwrite(fd,"%0d %0d %0d %0d\n",digito,valido,score,n);
        $fclose(fd);
        $finish;
    end
endmodule
