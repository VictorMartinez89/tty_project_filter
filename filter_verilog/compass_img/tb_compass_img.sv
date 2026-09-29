// tb_compass_img.sv — sobel_compass_control sobre una IMAGEN REAL (160x120), comparada bit a bit
// con el modelo entero de compass_img.py. A su lado, sobel_euclid_core calcula floor(sqrt(Gx^2+Gy^2))
// sobre la MISMA ventana, para tener en Verilog la columna euclidea de la Parte 12.B.
//
//   El flujo no es de pixeles consecutivos: cada 7.o pixel lleva una burbuja (px_valid=0) y entre
//   linea y linea hay 12 ciclos muertos, como en la camara. Un banco que solo alimenta pixeles
//   seguidos halaga al diseno; este lo obliga a sostener la ventana a traves de los huecos.
//
//   vvp compass.vvp +IMG=hex/monarch.hex +EXP=hex/monarch_exp.hex +OUT=out/monarch_rtl.hex [+VCD]
//   Cada linea de +OUT es la salida de un pixel interior: las 8 magnitudes N..NW, la magnitud
//   compass (la mayor), la direccion ganadora (0=N .. 7=NW) y la magnitud euclidea (11 bits).
`default_nettype none
`timescale 1ns/1ps
module tb_compass_img;
  localparam integer PIX = 8, W = 160, H = 120, NPX = W*H, NOUT = (W-2)*(H-2);
  reg clk = 0, nreset = 0, pv = 0;
  reg [7:0] px = 0;
  wire ov; wire [7:0] mag; wire [2:0] dir; wire [63:0] mags8; wire [10:0] eu;
  reg [7:0]  img [0:NPX-1];
  reg [87:0] expv [0:NOUT-1];            // {mags8[63:0], mag[7:0], 1'b0, dir[2:0], 1'b0, eu[10:0]}
  reg [8*256-1:0] f_img, f_exp, f_out;
  integer fo, i, r, c, oidx = 0, errores = 0;

  sobel_compass_control #(.PIX(PIX), .MAX_IMG_W(256)) dut (
      .clk_i(clk), .nreset_i(nreset), .img_w_i(16'd160), .px_valid_i(pv), .px_i(px),
      .out_valid_o(ov), .mag_o(mag), .dir_o(dir), .mags8_o(mags8));

  // la ventana que ve el compass, leida por jerarquia (el control no la saca a un puerto)
  sobel_euclid_core #(.PIX(PIX)) euc (
      .window_i({dut.w8, dut.w7, dut.w6, dut.w5, dut.w4, dut.w3, dut.w2, dut.w1, dut.w0}),
      .mag_o(eu));                       // combinacional sobre los mismos registros que mag_o:
                                         // queda alineada con out_valid sin retardo

  always #5 clk = ~clk;                  // 100 MHz nominales: solo marca el paso

  always @(posedge clk) if (nreset && ov) begin
      $fdisplay(fo, "%016h %02h %0d %03h", mags8, mag, dir, eu);
      if ({mags8, mag, 1'b0, dir, 1'b0, eu} !== expv[oidx]) begin
          if (errores < 10) $display("DIFIERE pixel %0d: rtl %016h %02h %0d %03h  golden %022h",
                                     oidx, mags8, mag, dir, eu, expv[oidx]);
          errores = errores + 1;
      end
      oidx = oidx + 1;
  end

  initial begin
    if (!$value$plusargs("IMG=%s", f_img)) f_img = "hex/monarch.hex";
    if (!$value$plusargs("EXP=%s", f_exp)) f_exp = "hex/monarch_exp.hex";
    if (!$value$plusargs("OUT=%s", f_out)) f_out = "out/monarch_rtl.hex";
    $readmemh(f_img, img);
    $readmemh(f_exp, expv);
    fo = $fopen(f_out, "w");
    if ($test$plusargs("VCD")) begin
      $dumpfile("compass.vcd"); $dumpvars(0, tb_compass_img);
    end
    repeat (3) @(negedge clk); nreset = 1;
    for (r = 0; r < H; r = r + 1) begin
      for (c = 0; c < W; c = c + 1) begin
        if (c % 7 == 6) begin @(negedge clk); pv = 0; end        // burbuja dentro de la linea
        @(negedge clk); px = img[r*W + c]; pv = 1;
      end
      @(negedge clk); pv = 0;
      repeat (11) @(negedge clk);                                // tiempo muerto entre lineas
    end
    repeat (4) @(negedge clk);
    $fclose(fo);
    $display("%0s: salidas %0d (esperadas %0d), diferencias %0d", f_img, oidx, NOUT, errores);
    if (errores == 0 && oidx == NOUT) $display("COMPASS IMAGEN: ALL TESTS PASSED");
    else                              $display("COMPASS IMAGEN: FALLO");
    $finish;
  end
endmodule
`default_nettype wire
