// tb_soc_sobel.v — SoC RISC-V + Sobel a 16x12. Ademas de filtrar, se ve al CPU
// arrancar de su ROM y configurar el filtro (cpu_wrote_filter). Imagen sintetica con un escalon vertical en la columna 6.
`timescale 1ns/1ps
`default_nettype none
module tb_soc_sobel;
    localparam H = 16, W = 12;
    reg clk = 0, resetn = 0, in_valid = 0;
    reg  [7:0] in_pix = 0;
    wire       out_valid;
    wire [7:0] out_pix;
    integer f, c, bordes = 0, planos = 0;

    always #5 clk = ~clk;                       // 100 MHz en simulacion

    wire cpu_wrote_filter;
    wire [7:0] thr_o;
    soc_sobel_top DUT (.clk(clk), .resetn(resetn), .in_valid(in_valid), .in_pix(in_pix),
                       .out_valid(out_valid), .out_pix(out_pix),
                       .cpu_wrote_filter(cpu_wrote_filter), .thr_o(thr_o));

    always @(posedge clk) if (out_valid) begin
        if (out_pix == 8'hFF) bordes = bordes + 1; else planos = planos + 1;
    end

    initial begin
        $dumpfile("soc_sobel.vcd"); $dumpvars(0, tb_soc_sobel);
        repeat (8) @(posedge clk); resetn = 1;
        repeat (200) @(posedge clk);            // el CPU corre su firmware
        $display("SOC+SOBEL  el CPU configuro el filtro: %0d, umbral=%0d", cpu_wrote_filter, thr_o);
        for (f = 0; f < H; f = f + 1)
            for (c = 0; c < W; c = c + 1) begin
                in_valid <= 1'b1;
                in_pix   <= (c < W/2) ? 8'd20 : 8'd200;   // escalon: oscuro | claro
                @(posedge clk);
            end
        in_valid <= 1'b0;
        repeat (20) @(posedge clk);
        $display("SOC+SOBEL  16x12 -> bordes=%0d  planos=%0d", bordes, planos);
        $finish;
    end
endmodule
`default_nettype wire
