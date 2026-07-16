// cam_alive.v — "Camara viva" para OV7670 (18 pines, sin FIFO) en iCESugar v1.5
// Paso 3 del roadmap: le damos XCLK a la camara y detectamos sus frames (VSYNC).
//
// Interpretacion de los LEDs:
//   AZUL parpadeando  = la FPGA esta viva (siempre, aunque la camara no este).
//   VERDE parpadeando = LLEGAN frames de la camara (VSYNC detectado) = EXITO.
//   VERDE apagado     = no hay VSYNC -> revisar alimentacion / XCLK / cableado.
//
// Pines:  clk=35,  cam_xclk=2 (P1A2),  cam_vsync=47 (P1A3),  LEDs=39/40/41

module top (
    input  wire clk,         // 12 MHz de la placa
    output wire cam_xclk,    // -> OV7670 XCLK (le damos reloj)
    input  wire cam_vsync,   // <- OV7670 VSYNC (un pulso por frame)
    output wire led_r,
    output wire led_g,
    output wire led_b
);
    // 1) Reloj para la camara: le pasamos los 12 MHz de la placa
    assign cam_xclk = clk;

    // 2) Sincronizar VSYNC (entrada asincrona) y detectar su flanco de subida
    reg v0 = 1'b0, v1 = 1'b0, v2 = 1'b0;
    always @(posedge clk) begin
        v0 <= cam_vsync;
        v1 <= v0;
        v2 <= v1;
    end
    wire vsync_rise = v1 & ~v2;     // 0->1 = empieza un frame nuevo

    // 3) Contar frames; un bit alto del contador hace parpadear el verde
    reg [3:0] frames = 4'd0;
    always @(posedge clk) if (vsync_rise) frames <= frames + 1'b1;
    wire verde = frames[2];         // togglea cada 4 frames (~2 Hz si hay ~15 fps)

    // 4) Heartbeat azul = la FPGA esta corriendo
    reg [23:0] hb = 24'd0;
    always @(posedge clk) hb <= hb + 1'b1;

    SB_RGBA_DRV #(
        .CURRENT_MODE("0b1"),
        .RGB0_CURRENT("0b000001"),
        .RGB1_CURRENT("0b000001"),
        .RGB2_CURRENT("0b000001")
    ) rgba (
        .CURREN(1'b1), .RGBLEDEN(1'b1),
        .RGB0PWM(verde),     // VERDE (RGB0) = llegan frames de la camara
        .RGB1PWM(1'b0),      // rojo  off
        .RGB2PWM(hb[23]),    // AZUL  (RGB2) = heartbeat de la FPGA
        .RGB0(led_r), .RGB1(led_g), .RGB2(led_b)
    );
endmodule
