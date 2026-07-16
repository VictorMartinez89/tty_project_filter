// cam_peak.v — Test DIRECTO del bus de datos D0-D7 (sin SCCB, sin config).
// Detector de PICO: muestra el valor mas alto visto en cam_d.
//
// UART cada ~0.35s:  "<RAW> <MAX>"
//   RAW = ultimo byte leido de D0-D7 (en un flanco de PCLK).
//   MAX = valor MAS ALTO visto desde la ultima impresion (se reinicia cada vez).
//         -> apunta a la luz: si algun dato llega, MAX sube (ej. 80, F0...).
//         -> si MAX queda 00 -> los cables D0-D7 estan flojos/desconectados.
//
//   AZUL late = FPGA viva.
// Pines: clk=35, cam_xclk=2, cam_pclk=28, cam_d[0..7]=48,46,44,43,38,34,31,42,
//        uart_tx=6, leds=39/40/41   (no usa SIOC/SIOD/HREF aqui)

module top (
    input  wire       clk,
    output wire       cam_xclk,
    input  wire       cam_pclk,
    input  wire [7:0] cam_d,
    output wire       uart_tx,
    output wire       led_r,
    output wire       led_g,
    output wire       led_b
);
    assign cam_xclk = clk;

    // ---- captura cruda en el dominio PCLK ----
    reg [7:0] praw = 8'd0;     // ultimo byte
    reg [7:0] pmax = 8'd0;     // pico
    reg       clrmax = 1'b0;   // pedido de reinicio (desde clk domain)
    reg       clrmax_p = 1'b0;
    always @(posedge cam_pclk) begin
        praw <= cam_d;
        // detectar flanco del pedido de clear
        clrmax_p <= clrmax;
        if (clrmax ^ clrmax_p) pmax <= cam_d;          // reiniciar al pico actual
        else if (cam_d > pmax) pmax <= cam_d;          // acumular maximo
    end

    // sincronizar al dominio clk para imprimir
    reg [7:0] praw_s0=0, praw_s1=0, pmax_s0=0, pmax_s1=0;
    always @(posedge clk) begin
        praw_s0 <= praw; praw_s1 <= praw_s0;
        pmax_s0 <= pmax; pmax_s1 <= pmax_s0;
    end

    // ---- UART ----
    reg  [7:0] tx_data  = 8'd0;
    reg        tx_start = 1'b0;
    wire       tx_busy;
    uart_tx u_tx (.clk(clk), .start(tx_start), .data(tx_data), .tx(uart_tx), .busy(tx_busy));
    function [7:0] hex; input [3:0] n;
        hex = (n < 4'd10) ? (8'h30 + {4'd0,n}) : (8'h41 + {4'd0,n} - 8'd10);
    endfunction
    reg [21:0] ptmr = 22'd0;
    wire ptick = &ptmr;
    always @(posedge clk) ptmr <= ptick ? 22'd0 : ptmr + 1'b1;
    reg [3:0] pst = 4'd0;
    reg [7:0] rw = 0, mx = 0;
    reg [7:0] pch;
    always @(*) case (pst)
        4'd1: pch = hex(rw[7:4]); 4'd2: pch = hex(rw[3:0]); 4'd3: pch = " ";
        4'd4: pch = hex(mx[7:4]); 4'd5: pch = hex(mx[3:0]);
        4'd6: pch = 8'h0D;        4'd7: pch = 8'h0A;
        default: pch = 8'h00;
    endcase
    always @(posedge clk) begin
        tx_start <= 1'b0;
        case (pst)
            4'd0: if (ptick) begin rw <= praw_s1; mx <= pmax_s1; clrmax <= ~clrmax; pst <= 4'd1; end
            4'd1,4'd2,4'd3,4'd4,4'd5,4'd6,4'd7:
                  if (!tx_busy && !tx_start) begin tx_data <= pch; tx_start <= 1'b1; pst <= pst + 1'b1; end
            default: pst <= 4'd0;
        endcase
    end

    reg [23:0] hb = 24'd0;
    always @(posedge clk) hb <= hb + 1'b1;
    SB_RGBA_DRV #(
        .CURRENT_MODE("0b1"),
        .RGB0_CURRENT("0b000001"), .RGB1_CURRENT("0b000001"), .RGB2_CURRENT("0b000001")
    ) rgba (
        .CURREN(1'b1), .RGBLEDEN(1'b1),
        .RGB0PWM(1'b0), .RGB1PWM(1'b0), .RGB2PWM(hb[23]),
        .RGB0(led_r), .RGB1(led_g), .RGB2(led_b)
    );
endmodule

module uart_tx #(
    parameter CLK_FREQ = 12_000_000, parameter BAUD = 115_200
)(
    input wire clk, input wire start, input wire [7:0] data,
    output wire tx, output reg busy
);
    localparam integer DIV = CLK_FREQ / BAUD;
    reg [12:0] clkcnt = 0; reg [3:0] nbits = 0; reg [9:0] shifter = 10'h3FF;
    assign tx = shifter[0];
    initial busy = 1'b0;
    always @(posedge clk) begin
        if (busy) begin
            if (clkcnt == DIV-1) begin
                clkcnt <= 0;
                if (nbits == 4'd9) busy <= 1'b0;
                else begin shifter <= {1'b1, shifter[9:1]}; nbits <= nbits + 1'b1; end
            end else clkcnt <= clkcnt + 1'b1;
        end else if (start) begin
            shifter <= {1'b1, data, 1'b0}; nbits <= 0; clkcnt <= 0; busy <= 1'b1;
        end
    end
endmodule
