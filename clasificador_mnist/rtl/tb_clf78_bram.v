// tb_clf78_bram.v — el clasificador con las caracteristicas en memoria.
// Carga los 128 contadores por el puerto de escritura, arranca, y escribe el veredicto.
`default_nettype none
`timescale 1ns/1ps
module tb_clf78_bram;
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
        // Las senales se mueven UN paso DESPUES del flanco. Si se asignan justo en el
        // flanco compiten con el always del modulo y el pulso puede perderse: es lo que
        // pasaba, y el clasificador se quedaba en reposo para siempre.
        repeat(4) @(posedge clk); #1 reset=0;
        // cargar los 128 contadores
        for(i=0;i<128;i=i+1) begin
            @(posedge clk); #1; wr_en=1; wr_addr=i[7:0]; wr_data=v[i][FW-1:0];
        end
        @(posedge clk); #1; wr_en=0; n_bordes=v[128][10:0];
        @(posedge clk); #1; start=1;
        @(posedge clk); #1; start=0;
        n=0; while(!done && n<60000) begin @(posedge clk); n=n+1; end
        fd=$fopen(fout,"w");
        $fwrite(fd,"%0d %0d %0d %0d\n",digito,valido,score,n);
        $fclose(fd);
        $finish;
    end
endmodule
