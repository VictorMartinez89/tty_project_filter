`default_nettype none
`timescale 1ns/1ps
module tb_compass_control;
  localparam PIX=8, W=8, H=8, NPX=H*W, NOUT=(H-2)*(W-2);
  reg clk=0, nreset=0, pv=0; reg [7:0] px=0;
  wire ov; wire [7:0] mag; wire [2:0] dir;
  reg [7:0] img [0:NPX-1];
  reg [7:0] emag [0:NOUT-1]; reg [3:0] edir [0:NOUT-1];
  integer i, oidx=0, errors=0;

  sobel_compass_control #(.PIX(PIX), .IMG_W(W)) dut
    (.clk_i(clk), .nreset_i(nreset), .px_valid_i(pv), .px_i(px),
     .out_valid_o(ov), .mag_o(mag), .dir_o(dir), .mags8_o());

  always #5 clk = ~clk;

  // capturar y comparar salidas interiores
  always @(posedge clk) if (nreset && ov) begin
     if (mag !== emag[oidx]) begin $display("FAIL mag[%0d]: got %0d exp %0d",oidx,mag,emag[oidx]); errors=errors+1; end
     if (dir !== edir[oidx]) begin $display("FAIL dir[%0d]: got %0d exp %0d",oidx,dir,edir[oidx]); errors=errors+1; end
     oidx = oidx + 1;
  end

  initial begin
    $readmemh("img.hex", img);
    $readmemh("exp_mag.hex", emag);
    $readmemh("exp_dir.hex", edir);
    @(negedge clk); nreset=1;
    for (i=0;i<NPX;i=i+1) begin
       @(negedge clk); px=img[i]; pv=1;
    end
    @(negedge clk); pv=0;
    repeat(4) @(negedge clk);
    $display("salidas comparadas=%0d (esperadas=%0d), errores=%0d", oidx, NOUT, errors);
    if (errors==0 && oidx==NOUT) $display("COMPASS CONTROL: ALL TESTS PASSED");
    else $display("COMPASS CONTROL: FALLO");
    $finish;
  end
endmodule
`default_nettype wire
