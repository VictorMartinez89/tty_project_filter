// uart_top.v — UART TX en iCESugar v1.5 (iCE40UP5K)
// Manda un mensaje por el serial del iCELink cada ~1.4 s, a 115200 8N1.
// Reloj 12 MHz (pin 35). uart_tx = pin 6 (FPGA -> PC).

module top (
    input  wire clk,
    output wire uart_tx,
    output wire led_r,
    output wire led_g,
    output wire led_b
);
    // ---------------- UART transmisor ----------------
    reg        tx_start = 1'b0;
    reg  [7:0] tx_data  = 8'h00;
    wire       tx_busy;

    uart_tx #(.CLK_FREQ(12_000_000), .BAUD(115_200)) u_tx (
        .clk   (clk),
        .start (tx_start),
        .data  (tx_data),
        .tx    (uart_tx),
        .busy  (tx_busy)
    );

    // ---------------- ROM del mensaje (0x00 = fin) ----------------
    function [7:0] msg;
        input [6:0] idx;
        case (idx)
            7'd0:  msg = "H";   7'd1:  msg = "o";   7'd2:  msg = "l";
            7'd3:  msg = "a";   7'd4:  msg = " ";   7'd5:  msg = "V";
            7'd6:  msg = "i";   7'd7:  msg = "c";   7'd8:  msg = "t";
            7'd9:  msg = "o";   7'd10: msg = "r";   7'd11: msg = "!";
            7'd12: msg = " ";   7'd13: msg = "T";   7'd14: msg = "u";
            7'd15: msg = " ";   7'd16: msg = "i";   7'd17: msg = "C";
            7'd18: msg = "E";   7'd19: msg = "S";   7'd20: msg = "u";
            7'd21: msg = "g";   7'd22: msg = "a";   7'd23: msg = "r";
            7'd24: msg = " ";   7'd25: msg = "h";   7'd26: msg = "a";
            7'd27: msg = "b";   7'd28: msg = "l";   7'd29: msg = "a";
            7'd30: msg = "!";   7'd31: msg = 8'h0D; 7'd32: msg = 8'h0A;
            default: msg = 8'h00;   // fin de mensaje
        endcase
    endfunction

    // ---------------- Controlador de envio ----------------
    reg [6:0]  addr    = 7'd0;
    reg        sending = 1'b1;
    reg [23:0] gap     = 24'd0;

    always @(posedge clk) begin
        tx_start <= 1'b0;                       // pulso, por defecto en 0
        if (sending) begin
            if (!tx_busy && !tx_start) begin
                if (msg(addr) == 8'h00) begin
                    sending <= 1'b0;            // mensaje completo
                    addr    <= 7'd0;
                    gap     <= 24'd0;
                end else begin
                    tx_data  <= msg(addr);
                    tx_start <= 1'b1;           // dispara 1 byte
                    addr     <= addr + 1'b1;
                end
            end
        end else begin
            gap <= gap + 1'b1;                  // pausa entre mensajes (~1.4 s)
            if (&gap) sending <= 1'b1;
        end
    end

    // ---------------- LED heartbeat (azul = "vivo") ----------------
    reg [23:0] hb = 24'd0;
    always @(posedge clk) hb <= hb + 1'b1;

    SB_RGBA_DRV #(
        .CURRENT_MODE("0b1"),
        .RGB0_CURRENT("0b000001"),
        .RGB1_CURRENT("0b000001"),
        .RGB2_CURRENT("0b000001")
    ) rgba (
        .CURREN(1'b1), .RGBLEDEN(1'b1),
        .RGB0PWM(1'b0), .RGB1PWM(1'b0), .RGB2PWM(hb[23]),
        .RGB0(led_r), .RGB1(led_g), .RGB2(led_b)
    );
endmodule

// =================== UART TX 8N1 ===================
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
    localparam integer DIV = CLK_FREQ / BAUD;   // ciclos por bit (~104)

    reg [12:0] clkcnt  = 13'd0;
    reg [3:0]  nbits   = 4'd0;
    reg [9:0]  shifter = 10'h3FF;   // todo 1 = linea en reposo

    assign tx = shifter[0];         // la linea saca el bit mas bajo
    initial busy = 1'b0;

    always @(posedge clk) begin
        if (busy) begin
            if (clkcnt == DIV-1) begin
                clkcnt <= 13'd0;
                if (nbits == 4'd9) begin
                    busy <= 1'b0;                     // termino el stop
                end else begin
                    shifter <= {1'b1, shifter[9:1]};  // desplaza, rellena con 1
                    nbits   <= nbits + 1'b1;
                end
            end else begin
                clkcnt <= clkcnt + 1'b1;
            end
        end else if (start) begin
            shifter <= {1'b1, data, 1'b0};   // stop(1) + 8 datos + start(0)
            nbits   <= 4'd0;
            clkcnt  <= 13'd0;
            busy    <= 1'b1;
        end
    end
endmodule
