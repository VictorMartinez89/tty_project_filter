`default_nettype none
`timescale 1ns/1ps
module tb_canny_control;
  localparam PIX=8, MAGW=12, W=14, H=14, NPX=196, NOUT=64;
  reg clk=0,nreset=0,pv=0; reg [7:0] px=0; reg [11:0] low=40, high=200;
  wire ov, ed; wire [1:0] cl;
  reg [7:0] img [0:NPX-1]; reg [3:0] eedge [0:NOUT-1]; reg [3:0] ecls [0:NOUT-1];
  integer i, oidx=0, errors=0;
  canny_control #(.PIX(PIX),.MAGW(MAGW),.IMG_W(W)) dut
    (.clk_i(clk),.nreset_i(nreset),.px_valid_i(pv),.px_i(px),.low_i(low),.high_i(high),
     .out_valid_o(ov),.edge_o(ed),.class_o(cl));
  always #5 clk=~clk;
  always @(posedge clk) if (nreset && ov) begin
     if (ed !== eedge[oidx]) begin $display("FAIL edge[%0d] got %0d exp %0d",oidx,ed,eedge[oidx]); errors=errors+1; end
     if (cl !== ecls[oidx])  begin $display("FAIL cls[%0d] got %0d exp %0d",oidx,cl,ecls[oidx]);  errors=errors+1; end
     oidx=oidx+1;
  end
  initial begin
    $readmemh("cimg.hex",img); $readmemh("exp_edge.hex",eedge); $readmemh("exp_cls.hex",ecls);
    @(negedge clk); nreset=1;
    for (i=0;i<NPX;i=i+1) begin @(negedge clk); px=img[i]; pv=1; end
    @(negedge clk); pv=0; repeat(4) @(negedge clk);
    $display("comparadas=%0d (esperadas=%0d) errores=%0d", oidx, NOUT, errors);
    if (errors==0 && oidx==NOUT) $display("CANNY CONTROL (NMS+histeresis streaming): ALL TESTS PASSED");
    else $display("CANNY CONTROL: FALLO");
    $finish;
  end
endmodule
`default_nettype wire
