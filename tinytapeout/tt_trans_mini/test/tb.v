`default_nettype none
`timescale 1ns/1ps
// Testbench-wrapper para cocotb: instancia el diseno; el estimulo va en test.py.
module tb ();
    initial begin $dumpfile("tb.vcd"); $dumpvars(0, tb); #1; end
    reg clk, rst_n, ena;
    reg  [7:0] ui_in, uio_in;
    wire [7:0] uo_out, uio_out, uio_oe;
    tt_um_trans_mini_vic user_project (
        .ui_in(ui_in), .uo_out(uo_out), .uio_in(uio_in),
        .uio_out(uio_out), .uio_oe(uio_oe), .ena(ena), .clk(clk), .rst_n(rst_n));
endmodule
`default_nettype wire
