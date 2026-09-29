// tb_clf98_lote.v — Canny-98 sobre un LOTE: por cada imagen carga los 128 contadores, fija n_bordes,
// arranca, espera done y escribe "digito valido score ciclos". Una sola simulacion para todo el lote.
`default_nettype none
`timescale 1ns/1ps
module tb_clf98_lote;
    localparam FW = 13;
    reg clk=0, reset=1, start=0, wr_en=0;
    reg [7:0] wr_addr=0; reg [FW-1:0] wr_data=0; reg [10:0] n_bordes=0;
    wire done, valido; wire [3:0] digito; wire signed [23:0] score;
    mnist_clf98 u(.clk(clk),.reset(reset),.wr_en(wr_en),.wr_addr(wr_addr),.wr_data(wr_data),
        .start(start),.n_bordes(n_bordes),.done(done),.digito(digito),.valido(valido),.score(score));
    always #5 clk=~clk;
    integer i,k,fd,n,N;
    reg [31:0] v [0:129*10000-1];
    initial begin
        if(!$value$plusargs("N=%d",N)) N=10000;
        $readmemh("tmp/c98_lote.hex", v);
        fd=$fopen("tmp/c98_rtl.txt","w");
        repeat(4) @(posedge clk); #1 reset=0;
        for(k=0;k<N;k=k+1) begin
            for(i=0;i<128;i=i+1) begin @(posedge clk); #1; wr_en=1; wr_addr=i[7:0]; wr_data=v[k*129+i][FW-1:0]; end
            @(posedge clk); #1; wr_en=0; n_bordes=v[k*129+128][10:0];
            @(posedge clk); #1; start=1;
            @(posedge clk); #1; start=0;
            n=0; while(!done && n<60000) begin @(posedge clk); n=n+1; end
            $fwrite(fd,"%0d %0d %0d %0d\n",digito,valido,score,n);
            if ((k+1)%1000==0) $display("  %0d/%0d", k+1, N);
        end
        $fclose(fd); $finish;
    end
endmodule
`default_nettype wire
