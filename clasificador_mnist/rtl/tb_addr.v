`default_nettype none
`timescale 1ns/1ps
module tb_addr;
    localparam FW=13;
    reg clk=0,reset=1,start=0,wr_en=0; reg [7:0] wr_addr=0; reg [FW-1:0] wr_data=0;
    reg [10:0] n_bordes=0; wire done,valido; wire [3:0] digito; wire signed [23:0] score;
    mnist_clf78_bram u(.clk(clk),.reset(reset),.wr_en(wr_en),.wr_addr(wr_addr),.wr_data(wr_data),
        .start(start),.n_bordes(n_bordes),.done(done),.digito(digito),.valido(valido),.score(score));
    always #5 clk=~clk;
    integer i,n;
    initial begin
        repeat(4) @(posedge clk); #1 reset=0;
        for(i=0;i<128;i=i+1) begin @(posedge clk); #1; wr_en=1; wr_addr=i[7:0]; wr_data=i[FW-1:0]; end
        @(posedge clk); #1; wr_en=0;
        @(posedge clk); #1; start=1;
        @(posedge clk); #1; start=0;
        for(n=0;n<14;n=n+1) begin
            @(posedge clk); #1;
            $display("  ciclo %2d  st=%0d t=%0d fidx=%2d  rd_a=%3d  rd_d=%3d  acc_d=%3d  we=%0d wa=%3d wd=%3d",
                     n, u.st, u.t, u.fidx, u.rd_a, u.rd_d, u.acc_d, u.we_i, u.wa_i, u.wd_i);
        end
        $finish;
    end
endmodule
