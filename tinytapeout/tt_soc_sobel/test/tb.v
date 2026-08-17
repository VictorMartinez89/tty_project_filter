`default_nettype none
`timescale 1ns/1ps
module tb;
    reg clk=0, rst_n=0; reg [7:0] ui_in=0, uio_in=0;
    wire [7:0] uo_out, uio_out, uio_oe;
    tt_um_soc_sobel_vic dut(.ui_in(ui_in), .uo_out(uo_out),
        .uio_in(uio_in), .uio_out(uio_out), .uio_oe(uio_oe),
        .ena(1'b1), .clk(clk), .rst_n(rst_n));
    wire out_valid = uio_out[1];
    wire cpu_wrote = uio_out[2];
    always #5 clk = ~clk;
    integer i;
    initial begin
        $dumpfile("tb.vcd"); $dumpvars(0, tb);
        rst_n=0; repeat(8) @(posedge clk); rst_n=1;
        // dar tiempo a que el CPU arranque y configure el filtro
        repeat(200) @(posedge clk);
        for (i=0; i<600; i=i+1) begin
            @(posedge clk); uio_in[0] <= 1'b1; ui_in <= (i*37) & 8'hFF;
        end
        uio_in[0] <= 1'b0; repeat(20) @(posedge clk); $finish;
    end
endmodule
`default_nettype wire
