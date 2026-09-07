// uart_tx.v — transmisor serie 8N1, lo minimo para ver el resultado sin osciloscopio.
//   A 12 MHz con 115200 baudios, DIVISOR = 104. Un byte por vez: se pone `dato`, se pulsa
//   `enviar`, y `listo` avisa cuando se puede mandar el siguiente.
`default_nettype none
module uart_tx #(parameter integer DIVISOR = 104) (
    input  wire       clk,
    input  wire       reset,
    input  wire [7:0] dato,
    input  wire       enviar,
    output reg        tx,
    output wire       listo
);
    reg [3:0]  bit_n;         // 0 = inactivo; 1 = start; 2..9 = datos; 10 = stop
    reg [15:0] cnt;
    reg [7:0]  buf_;
    assign listo = (bit_n == 4'd0);

    always @(posedge clk) begin
        if (reset) begin
            tx <= 1'b1; bit_n <= 4'd0; cnt <= 16'd0; buf_ <= 8'd0;
        end else if (bit_n == 4'd0) begin
            tx <= 1'b1;
            if (enviar) begin buf_ <= dato; bit_n <= 4'd1; cnt <= 16'd0; tx <= 1'b0; end
        end else begin
            if (cnt == DIVISOR-1) begin
                cnt <= 16'd0;
                if (bit_n == 4'd10) begin bit_n <= 4'd0; tx <= 1'b1; end
                else begin
                    bit_n <= bit_n + 4'd1;
                    tx <= (bit_n == 4'd9) ? 1'b1 : buf_[0];   // tras el ultimo dato, stop
                    buf_ <= {1'b0, buf_[7:1]};
                end
            end else cnt <= cnt + 16'd1;
        end
    end
endmodule
`default_nettype wire
