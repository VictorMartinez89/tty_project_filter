// cam_uart.v — Debug de pixeles OV7670 por UART en iCESugar v1.5
// Manda el BRILLO promedio de la camara como numero hex (~5/seg) por el serial
// del iCELink. Tambien el LED verde sigue el brillo y el azul late.
//
//   Apunta a la luz -> el numero sube (ej. C8, E0...).
//   Tapa el lente    -> el numero baja (ej. 10, 08...).
//   Si el numero NO cambia o queda fijo -> algun cable D0-D7 esta mal.
//
// Pines: clk=35, cam_xclk=2, cam_pclk=45, cam_href=3,
//        cam_d[0..7]=48,46,44,43,38,34,31,42,  uart_tx=6,  leds=39/40/41

module top (
    input  wire       clk,
    output wire       cam_xclk,
    input  wire       cam_pclk,
    input  wire       cam_href,
    input  wire [7:0] cam_d,
    output wire       uart_tx,
    output wire       led_r,
    output wire       led_g,
    output wire       led_b
);
    assign cam_xclk = clk;

    // ---- Dominio PCLK: brillo promedio (IIR) ----
    reg [11:0] acc = 12'd0;
    always @(posedge cam_pclk)
        if (cam_href) acc <= acc - (acc >> 4) + {4'd0, cam_d};
    wire [7:0] lum = acc[11:4];

    // ---- Dominio system clk ----
    // sincronizar lum (cambia lento, cruce benigno)
    reg [7:0] lum_s0 = 8'd0, lum_s1 = 8'd0;
    always @(posedge clk) begin lum_s0 <= lum; lum_s1 <= lum_s0; end

    // timer ~0.35 s
    reg [21:0] tmr = 22'd0;
    wire tick = &tmr;
    always @(posedge clk) tmr <= tick ? 22'd0 : tmr + 1'b1;

    // UART TX
    reg  [7:0] tx_data  = 8'd0;
    reg        tx_start = 1'b0;
    wire       tx_busy;
    uart_tx u_tx (.clk(clk), .start(tx_start), .data(tx_data), .tx(uart_tx), .busy(tx_busy));

    // nibble -> ASCII hex
    function [7:0] hex;
        input [3:0] n;
        hex = (n < 4'd10) ? (8'h30 + {4'd0,n}) : (8'h41 + {4'd0,n} - 8'd10);
    endfunction

    // FSM: en cada tick manda  hexAlto hexBajo CR LF
    reg [2:0] st  = 3'd0;
    reg [7:0] val = 8'd0;
    always @(posedge clk) begin
        tx_start <= 1'b0;
        case (st)
            3'd0: if (tick) begin val <= lum_s1; st <= 3'd1; end
            3'd1: if (!tx_busy && !tx_start) begin tx_data <= hex(val[7:4]); tx_start <= 1'b1; st <= 3'd2; end
            3'd2: if (!tx_busy && !tx_start) begin tx_data <= hex(val[3:0]); tx_start <= 1'b1; st <= 3'd3; end
            3'd3: if (!tx_busy && !tx_start) begin tx_data <= 8'h0D;         tx_start <= 1'b1; st <= 3'd4; end
            3'd4: if (!tx_busy && !tx_start) begin tx_data <= 8'h0A;         tx_start <= 1'b1; st <= 3'd0; end
            default: st <= 3'd0;
        endcase
    end

    // LEDs: verde = brillo (PWM), azul = heartbeat
    reg [7:0]  pwm = 8'd0;
    reg [23:0] hb  = 24'd0;
    always @(posedge clk) begin pwm <= pwm + 1'b1; hb <= hb + 1'b1; end
    wire verde = (pwm < lum_s1);

    SB_RGBA_DRV #(
        .CURRENT_MODE("0b1"),
        .RGB0_CURRENT("0b000011"),
        .RGB1_CURRENT("0b000001"),
        .RGB2_CURRENT("0b000001")
    ) rgba (
        .CURREN(1'b1), .RGBLEDEN(1'b1),
        .RGB0PWM(verde), .RGB1PWM(1'b0), .RGB2PWM(hb[23]),
        .RGB0(led_r), .RGB1(led_g), .RGB2(led_b)
    );
endmodule

// ================= UART TX 8N1 =================
module uart_tx #(
    parameter CLK_FREQ = 12_000_000,
    parameter BAUD     = 115_200
)(
    input  wire       clk,
    input  wire       start,
    input  wire [7:0] data,
    output wire       tx,
    output reg        busy
);
    localparam integer DIV = CLK_FREQ / BAUD;
    reg [12:0] clkcnt  = 13'd0;
    reg [3:0]  nbits   = 4'd0;
    reg [9:0]  shifter = 10'h3FF;
    assign tx = shifter[0];
    initial busy = 1'b0;
    always @(posedge clk) begin
        if (busy) begin
            if (clkcnt == DIV-1) begin
                clkcnt <= 13'd0;
                if (nbits == 4'd9) busy <= 1'b0;
                else begin shifter <= {1'b1, shifter[9:1]}; nbits <= nbits + 1'b1; end
            end else clkcnt <= clkcnt + 1'b1;
        end else if (start) begin
            shifter <= {1'b1, data, 1'b0};
            nbits   <= 4'd0;
            clkcnt  <= 13'd0;
            busy    <= 1'b1;
        end
    end
endmodule
