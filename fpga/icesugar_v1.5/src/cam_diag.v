// cam_diag.v — diagnostico VSYNC para OV7670 en iCESugar v1.5
// VERDE fijo = VSYNC subio a alto al menos una vez (cámara genera frames).
// VERDE apagado tras varios segundos = VSYNC nunca sube -> cableado o la cámara
//                                       no esta transmitiendo (necesita SCCB).
// AZUL parpadea = la FPGA esta viva.
// Pines: clk=35, cam_xclk=2, cam_vsync=47, LEDs=39/40/41

module top (
    input  wire clk,
    output wire cam_xclk,
    input  wire cam_vsync,
    output wire led_r,
    output wire led_g,
    output wire led_b
);
    assign cam_xclk = clk;          // 12 MHz a la camara

    // sincronizar VSYNC
    reg v0 = 1'b0, v1 = 1'b0;
    always @(posedge clk) begin v0 <= cam_vsync; v1 <= v0; end

    // latch: si VSYNC alguna vez esta en alto, queda marcado para siempre
    reg seen = 1'b0;
    always @(posedge clk) if (v1) seen <= 1'b1;

    // heartbeat
    reg [23:0] hb = 24'd0;
    always @(posedge clk) hb <= hb + 1'b1;

    SB_RGBA_DRV #(
        .CURRENT_MODE("0b1"),
        .RGB0_CURRENT("0b000001"),
        .RGB1_CURRENT("0b000001"),
        .RGB2_CURRENT("0b000001")
    ) rgba (
        .CURREN(1'b1), .RGBLEDEN(1'b1),
        .RGB0PWM(seen),      // VERDE fijo = VSYNC subio alguna vez
        .RGB1PWM(1'b0),
        .RGB2PWM(hb[23]),    // AZUL = heartbeat
        .RGB0(led_r), .RGB1(led_g), .RGB2(led_b)
    );
endmodule
