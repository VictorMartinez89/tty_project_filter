// =============================================================================
// tb_demo.sv -- DEMO en Verilog: emula al FemtoRV32 manejando el peripheral_sobel
//   por el bus (CTRL/IMGW/LOW/HIGH, feed pixel-a-pixel, poll STATUS, lee RESULT)
//   y dibuja los bordes detectados como ASCII art. Imagen: un cuadrado brillante.
//   Modo Canny. Corre:  iverilog -g2012 -o d.out tb_demo.sv peripheral_sobel.v \
//     sobel_compass_control.sv sobel_compass_core.sv canny_control.sv canny_full_core.sv ; vvp d.out
// =============================================================================
`default_nettype none
`timescale 1ns/1ps
module tb_demo;
  localparam IW=16, IH=16, NPX=IW*IH;
  localparam A_CTRL=5'h00,A_IMGW=5'h04,A_LOW=5'h08,A_HIGH=5'h0C,A_PIXEL=5'h10,A_STATUS=5'h14,A_RESULT=5'h18;

  reg clk=0, reset=1, csr=0, rdr=0, wrr=0; reg [4:0] adr=0; reg [31:0] din=0;
  wire [31:0] dout;
  peripheral_sobel dut(.clk(clk),.reset(reset),.d_in(din),.cs(csr),.addr(adr),.rd(rdr),.wr(wrr),.d_out(dout));
  always #5 clk=~clk;

  reg [7:0] img [0:NPX-1];
  reg [0:99] dummy;            // no usado
  reg edges [0:(IH-6)*(IW-6)-1];
  integer i,j,n,k,p;
  reg [31:0] rv;

  task bus_write(input [4:0] a, input [31:0] d);
    begin @(negedge clk); csr=1; adr=a; din=d; wrr=1; rdr=0; @(negedge clk); csr=0; wrr=0; end
  endtask
  task bus_read(input [4:0] a);
    begin @(negedge clk); csr=1; adr=a; rdr=1; wrr=0; @(posedge clk); #1 rv=dout; @(negedge clk); csr=0; rdr=0; end
  endtask

  initial begin
    // imagen: cuadrado brillante (200) sobre fondo (20)
    for (i=0;i<IH;i=i+1) for (j=0;j<IW;j=j+1)
        img[i*IW+j] = (i>=4 && i<12 && j>=4 && j<12) ? 8'd200 : 8'd20;

    @(negedge clk); @(negedge clk); reset=0;
    bus_write(A_IMGW, IW);
    bus_write(A_LOW , 32'd40);
    bus_write(A_HIGH, 32'd200);
    bus_write(A_CTRL, 32'd1 | 32'd2);     // modo Canny (bit0=1) + frame_reset (bit1)

    n = 0;
    for (i=0;i<NPX;i=i+1) begin
        bus_write(A_PIXEL, img[i]);
        for (k=0;k<5;k=k+1) begin
            bus_read(A_STATUS);
            if (rv[0]) begin bus_read(A_RESULT); edges[n] = rv[0]; n=n+1; k=5; end
        end
    end

    $display("\n=== DEMO Verilog: Canny sobre cuadrado %0dx%0d ===", IW, IH);
    $display("entrada: cuadrado brillante en [4..11]x[4..11]");
    $display("bordes detectados (interior %0dx%0d):", IH-6, IW-6);
    p = 0;
    for (i=0;i<IH-6;i=i+1) begin
        for (j=0;j<IW-6;j=j+1) begin $write("%s", edges[p] ? "#" : "."); p=p+1; end
        $write("\n");
    end
    $display("resultados leidos = %0d (esperado %0d)", n, (IH-6)*(IW-6));
    $finish;
  end
endmodule
`default_nettype wire
