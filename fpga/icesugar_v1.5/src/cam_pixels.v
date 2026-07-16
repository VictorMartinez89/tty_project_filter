// cam_pixels.v — Captura de pixeles OV7670 (18 pines) en iCESugar v1.5
// "Fotometro": el LED VERDE sigue el brillo promedio de lo que ve la camara.
//   Tapa el lente  -> verde se apaga.
//   Apunta a la luz -> verde brilla.
//   => prueba que D0-D7 traen datos REALES sincronizados a PCLK/HREF.
// AZUL parpadea = la FPGA esta viva.
//
// Pines: clk=35, cam_xclk=2, leds=39/40/41
//        cam_pclk=45, cam_href=3, cam_d[0..7]=48,46,44,43,38,34,31,42

module top (
    input  wire       clk,        // 12 MHz de la placa
    output wire       cam_xclk,    // -> OV7670 XCLK
    input  wire       cam_pclk,    // <- OV7670 PCLK (reloj de pixel)
    input  wire       cam_href,    // <- OV7670 HREF (alto = pixeles validos)
    input  wire [7:0] cam_d,       // <- OV7670 D0..D7
    output wire       led_r,
    output wire       led_g,
    output wire       led_b
);
    assign cam_xclk = clk;         // le damos 12 MHz a la camara

    // ---- Dominio PCLK: promedio movil (IIR) del brillo de los bytes ----
    // acc tiende a 16 * (promedio de los bytes). Auto-escala, sin desbordar.
    reg [11:0] acc = 12'd0;
    always @(posedge cam_pclk) begin
        if (cam_href)
            acc <= acc - (acc >> 4) + {4'd0, cam_d};
    end
    wire [7:0] lum = acc[11:4];    // brillo promedio (0..255) ~ la escena

    // ---- Dominio system clk: PWM (siempre corre) + heartbeat ----
    reg [7:0]  pwm = 8'd0;
    reg [23:0] hb  = 24'd0;
    always @(posedge clk) begin
        pwm <= pwm + 1'b1;
        hb  <= hb  + 1'b1;
    end
    // lum es lento (IIR sobre miles de pixeles): cruzarlo aqui para un LED es benigno.
    wire verde = (pwm < lum);      // duty del PWM = brillo -> el LED sigue la luz

    SB_RGBA_DRV #(
        .CURRENT_MODE("0b1"),
        .RGB0_CURRENT("0b000011"),   // verde con un poco mas de rango para ver el degrade
        .RGB1_CURRENT("0b000001"),
        .RGB2_CURRENT("0b000001")
    ) rgba (
        .CURREN(1'b1), .RGBLEDEN(1'b1),
        .RGB0PWM(verde),     // VERDE = brillo de la escena
        .RGB1PWM(1'b0),      // rojo off
        .RGB2PWM(hb[23]),    // AZUL = heartbeat
        .RGB0(led_r), .RGB1(led_g), .RGB2(led_b)
    );
endmodule
