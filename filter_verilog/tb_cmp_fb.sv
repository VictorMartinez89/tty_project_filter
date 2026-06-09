// 16.B -- compara: peripheral_sobel_fb FRAMEBUFFER. Cuenta ciclos de CARGA y de PROCESO.
`default_nettype none
`timescale 1ns/1ps
module tb_cmp_fb;
  localparam W=16,H=16,NPX=256;
  localparam A_CTRL=0,A_IMGW=4,A_NPX=8,A_WRPIX=16,A_START=24;
  reg clk=0,reset=1,cs=0,rd=0,wr=0; reg [4:0] adr; reg [31:0] din; wire [31:0] dout;
  peripheral_sobel_fb #(.MAXPX(512)) dut(.clk(clk),.reset(reset),.d_in(din),.cs(cs),.addr(adr),.rd(rd),.wr(wr),.d_out(dout));
  always #5 clk=~clk;
  integer cyc=0; always @(posedge clk) cyc=cyc+1;
  reg [7:0] img [0:NPX-1]; integer i,tl0,tl1,tp0,tp1;
  task bw(input [4:0]a,input[31:0]d);begin @(negedge clk);cs=1;adr=a;din=d;wr=1;rd=0;@(negedge clk);cs=0;wr=0;end endtask
  initial begin
    for(i=0;i<NPX;i=i+1) img[i]=(i*37+ (i/W)*13) & 8'hFF;
    @(negedge clk);@(negedge clk);reset=0;
    bw(A_CTRL,0|2); bw(A_IMGW,W); bw(A_NPX,NPX);     // compass + clear, ancho, npx
    tl0=cyc; for(i=0;i<NPX;i=i+1) bw(A_WRPIX,img[i]); tl1=cyc;   // CARGA
    bw(A_START,1); tp0=cyc;
    wait(dut.done); tp1=cyc;                          // PROCESO autonomo
    $display("FB_LOAD=%0d FB_PROC=%0d RESULTS=%0d (imagen %0dx%0d)", tl1-tl0, tp1-tp0, dut.optr, W, H);
    $finish;
  end
endmodule
`default_nettype wire
