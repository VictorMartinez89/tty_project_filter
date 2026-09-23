`default_nettype none
`timescale 1ns/1ps
module tb_w;
    reg clk=0,reset=1,start=0,wr_en=0; reg [7:0] wr_addr=0; reg [12:0] wr_data=0;
    reg [10:0] n_bordes=300; wire done,valido; wire [3:0] digito; wire signed [23:0] score;
    mnist_clf78_x2 u(.clk(clk),.reset(reset),.wr_en(wr_en),.wr_addr(wr_addr),.wr_data(wr_data),
        .start(start),.n_bordes(n_bordes),.done(done),.digito(digito),.valido(valido),.score(score));
    always #5 clk=~clk;
    integer i,n;
    initial begin
        repeat(4) @(posedge clk); #1 reset=0;
        for(i=0;i<128;i=i+1) begin @(posedge clk); #1; wr_en=1; wr_addr=i[7:0]; wr_data=13'd1; end
        @(posedge clk); #1; wr_en=0;
        @(posedge clk); #1; start=1; @(posedge clk); #1; start=0;
        n=0;
        while(u.st != 3'd2 && n<2000) begin @(posedge clk); #1; n=n+1; end
        for(i=0;i<6;i=i+1) begin
            $display("  cp=%0d j=%0d  w2=%02h  w0=%0d w1=%0d  rd_d=%0d  acc0=%0d acc1=%0d",
                     u.cp,u.j,u.w2,$signed(u.w0),$signed(u.w1),u.rd_d,$signed(u.acc0),$signed(u.acc1));
            @(posedge clk); #1;
        end
        $finish;
    end
endmodule
