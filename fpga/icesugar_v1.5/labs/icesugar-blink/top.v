// top.v — Blink del LED RGB en iCESugar v1.5 (Lattice iCE40UP5K)
module top (
    input  wire clk,     // reloj 12 MHz desde iCELink (pin 35)
    output wire led_r,    // canal rojo  del LED RGB
    output wire led_g,    // canal verde del LED RGB
    output wire led_b     // canal azul  del LED RGB
);
    // Contador divisor de reloj.
    // A 12 MHz, el bit 23 cambia de estado cada ~0.7 s -> parpadeo visible.
    reg [23:0] cnt = 24'd0;
    always @(posedge clk)
        cnt <= cnt + 1'b1;

    wire blink = cnt[23];

    // En el iCE40UP5K el LED RGB NO se maneja como pin de IO normal:
    // tiene un hard-IP de corriente constante (SB_RGBA_DRV). Si manejas
    // los pines 39/40/41 como salidas comunes, el LED no enciende.
    SB_RGBA_DRV #(
        .CURRENT_MODE("0b1"),        // modo de media corriente
        .RGB0_CURRENT("0b000001"),   // brillo bajo
        .RGB1_CURRENT("0b000001"),
        .RGB2_CURRENT("0b000001")
    ) rgba (
        .CURREN  (1'b1),
        .RGBLEDEN(1'b1),
        .RGB0PWM (blink),    // rojo  parpadea
        .RGB1PWM (~blink),   // verde en contrafase
        .RGB2PWM (1'b0),     // azul  apagado
        .RGB0    (led_r),
        .RGB1    (led_g),
        .RGB2    (led_b)
    );
endmodule
