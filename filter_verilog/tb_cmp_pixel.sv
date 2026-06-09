// 16.A -- compara: peripheral_sobel PIXEL-A-PIXEL (polling). Cuenta ciclos de reloj.
`default_nettype none
`timescale 1ns/1ps
module tb_cmp_pixel;
  localparam W=16,H=16,NPX=256;
  localparam A_CTRL=0,A_IMGW=4,A_PIXEL=16,A_STATUS=20,A_RESULT=24;
  reg clk=0,reset=1,cs=0,rd=0,wr=0; reg [4:0] adr; reg [31:0] din; wire [31:0] dout;
  peripheral_sobel dut(.clk(clk),.reset(reset),.d_in(din),.cs(cs),.addr(adr),.rd(rd),.wr(wr),.d_out(dout));
  always #5 clk=~clk;
  integer cyc=0; always @(posedge clk) cyc=cyc+1;
  reg [7:0] img [0:NPX-1]; integer i,k,n,t0,t1; reg [31:0] rv;
  task bw(input [4:0]a,input[31:0]d);begin @(negedge clk);cs=1;adr=a;din=d;wr=1;rd=0;@(negedge clk);cs=0;wr=0;end endtask
  task br(input [4:0]a);begin @(negedge clk);cs=1;adr=a;rd=1;wr=0;@(posedge clk);#1 rv=dout;@(negedge clk);cs=0;rd=0;end endtask
  initial begin
    for(i=0;i<NPX;i=i+1) img[i]=(i*37+ (i/W)*13) & 8'hFF;
    @(negedge clk);@(negedge clk);reset=0;
    bw(A_IMGW,W); bw(A_CTRL,0|2);            // compass + clear
    t0=cyc; n=0;
    for(i=0;i<NPX;i=i+1) begin
      bw(A_PIXEL,img[i]);
      for(k=0;k<6;k=k+1) begin br(A_STATUS); if(rv[0]) begin br(A_RESULT); n=n+1; k=6; end end
    end
    t1=cyc;
    $display("PIXEL_CYCLES=%0d RESULTS=%0d (imagen %0dx%0d)", t1-t0, n, W, H);
    $finish;
  end
endmodule
`default_nettype wire
