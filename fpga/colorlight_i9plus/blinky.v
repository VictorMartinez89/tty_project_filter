// Blinky para Colorlight i9+ v6.1 (Xilinx Artix-7 XC7A50T-FGG484).
// Valida el toolchain openXC7 + la programacion CH347 antes de meter el SoC.
// clk = 25 MHz (pin K4), LED = D2 (pin A18).
module top (
    input  wire clk,
    output wire led
);
    reg [24:0] cnt = 25'd0;
    always @(posedge clk) cnt <= cnt + 1'b1;
    assign led = cnt[24];        // 25e6 / 2^25 ~ 0.75 Hz (parpadeo visible)
endmodule
