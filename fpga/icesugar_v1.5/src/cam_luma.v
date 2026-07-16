// cam_luma.v — Aisla la LUMA (Y) del stream YUV y mide su pico. Sin SCCB/config.
// En YUV422 el orden es Y U Y V... -> la luma Y esta en los bytes PARES.
// Usa HREF para alinear: al empezar la linea, el primer byte es Y.
//
// UART cada ~0.35s:  "<YL> <YM>"
//   YL = ultima luma leida.   YM = pico de luma desde la ultima impresion.
//   -> Tapa el lente: YM baja (oscuro).  Apunta a la luz: YM sube (claro).
//   Si YM se mueve con la luz = la camara VE de verdad. 🎉
//
//   AZUL late = FPGA viva.
// Pines: clk=35, cam_xclk=2, cam_pclk=28, cam_href=32,
//        cam_d[0..7]=48,46,44,43,38,34,31,42, uart_tx=6, leds=39/40/41

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

    // ---- aislar luma (bytes pares dentro de la linea) ----
    reg       parity = 1'b0;    // 0 = byte Y (luma) ; 1 = croma
    reg [7:0] ylast  = 8'd0;
    reg [7:0] ymax   = 8'd0;
    reg       clrm = 1'b0, clrm_p = 1'b0;
    always @(posedge cam_pclk) begin
        clrm_p <= clrm;
        if (!cam_href) begin
            parity <= 1'b0;                 // blanking: el proximo byte sera Y
        end else begin
            if (parity == 1'b0) begin       // este byte es luma Y
                ylast <= cam_d;
                if (clrm ^ clrm_p)      ymax <= cam_d;       // reiniciar pico
                else if (cam_d > ymax)  ymax <= cam_d;       // acumular pico
            end
            parity <= ~parity;
        end
    end

    reg [7:0] yl_s0=0, yl_s1=0, ym_s0=0, ym_s1=0;
    always @(posedge clk) begin
        yl_s0 <= ylast; yl_s1 <= yl_s0;
        ym_s0 <= ymax;  ym_s1 <= ym_s0;
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
    reg [7:0] yl = 0, ym = 0;
    reg [7:0] pch;
    always @(*) case (pst)
        4'd1: pch = hex(yl[7:4]); 4'd2: pch = hex(yl[3:0]); 4'd3: pch = " ";
        4'd4: pch = hex(ym[7:4]); 4'd5: pch = hex(ym[3:0]);
        4'd6: pch = 8'h0D;        4'd7: pch = 8'h0A;
        default: pch = 8'h00;
    endcase
    always @(posedge clk) begin
        tx_start <= 1'b0;
        case (pst)
            4'd0: if (ptick) begin yl <= yl_s1; ym <= ym_s1; clrm <= ~clrm; pst <= 4'd1; end
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
