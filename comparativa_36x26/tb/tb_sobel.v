// tb_sobel.v — Sobel 3x3 a 16x12. Imagen sintetica con un escalon vertical en la columna 6.
`timescale 1ns/1ps
`default_nettype none
module tb_sobel;
    localparam H = 16, W = 12;
    reg clk = 0, reset = 1, in_valid = 0;
    reg  [7:0] in_pix = 0;
    wire       out_valid;
    wire [7:0] out_pix;
    integer f, c, bordes = 0, planos = 0;

    always #5 clk = ~clk;                       // 100 MHz en simulacion

    sobel_top DUT (.clk(clk), .reset(reset), .in_valid(in_valid), .in_pix(in_pix),
                   .thr(8'd90), .out_valid(out_valid), .out_pix(out_pix));

    always @(posedge clk) if (out_valid) begin
        if (out_pix == 8'hFF) bordes = bordes + 1; else planos = planos + 1;
    end

    initial begin
        $dumpfile("sobel.vcd"); $dumpvars(0, tb_sobel);
        repeat (6) @(posedge clk); reset = 0; @(posedge clk);
        for (f = 0; f < H; f = f + 1)
            for (c = 0; c < W; c = c + 1) begin
                in_valid <= 1'b1;
                in_pix   <= (c < W/2) ? 8'd20 : 8'd200;   // escalon: oscuro | claro
                @(posedge clk);
            end
        in_valid <= 1'b0;
        repeat (20) @(posedge clk);
        $display("SOBEL      16x12 -> bordes=%0d  planos=%0d", bordes, planos);
        $finish;
    end
endmodule
`default_nettype wire
