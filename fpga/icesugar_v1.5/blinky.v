// Blinky para iCESugar v1.5 (MuseLab) -- Lattice iCE40UP5K-SG48.
// Reloj 12 MHz. Usa el LED RGB de la placa via el driver hardened SB_RGBA_DRV.
// Valida el toolchain yosys+nextpnr-ice40+icestorm (nativo arm64) antes del SoC.
module top (
    input  wire clk,
    output wire led_r, led_g, led_b
);
    reg [23:0] cnt = 24'd0;
    always @(posedge clk) cnt <= cnt + 1'b1;   // 12e6 / 2^24 ~ 0.7 Hz
    wire blink = cnt[23];

    SB_RGBA_DRV #(
        .CURRENT_MODE("0b1"),
        .RGB0_CURRENT("0b000001"),
        .RGB1_CURRENT("0b000001"),
        .RGB2_CURRENT("0b000001")
    ) rgb (
        .CURREN  (1'b1),
        .RGBLEDEN(1'b1),
        .RGB0PWM (blink),   // parpadea el canal 0
        .RGB1PWM (1'b0),
        .RGB2PWM (1'b0),
        .RGB0(led_r), .RGB1(led_g), .RGB2(led_b)
    );
endmodule
