// uart_rx.v — receptor serie 8N1, el companero de uart_tx.v.
//   A 12 MHz con 115200 baudios, DIVISOR = 104. Muestrea cada bit en su MITAD: al ver el
//   flanco de bajada del start espera medio bit, confirma que sigue en 0 (si no, era ruido)
//   y desde ahi lee un bit cada DIVISOR ciclos. `valido` dura un ciclo con el byte en `dato`.
//
//   La entrada pasa por DOS biestables antes de usarse: viene de otro dominio de reloj (el del
//   iCELink) y sin sincronizar puede dejar un biestable metaestable que se lea distinto en dos
//   sitios del mismo ciclo. Es la version en pequeno del CDC de la camara.
`default_nettype none
module uart_rx #(parameter integer DIVISOR = 104) (
    input  wire       clk,
    input  wire       reset,
    input  wire       rx,
    output reg  [7:0] dato,
    output reg        valido
);
    reg rx1 = 1'b1, rx2 = 1'b1;
    always @(posedge clk) begin rx1 <= rx; rx2 <= rx1; end

    reg [3:0]  bit_n;         // 0 = inactivo; 1 = start; 2..9 = datos; 10 = stop
    reg [15:0] cnt;
    reg [7:0]  sh;

    always @(posedge clk) begin
        if (reset) begin
            bit_n <= 4'd0; cnt <= 16'd0; sh <= 8'd0; dato <= 8'd0; valido <= 1'b0;
        end else begin
            valido <= 1'b0;
            if (bit_n == 4'd0) begin
                if (!rx2) begin bit_n <= 4'd1; cnt <= 16'd0; end
            end else if (bit_n == 4'd1) begin
                // medio bit: confirmar el start en su mitad
                if (cnt == DIVISOR/2 - 1) begin
                    cnt <= 16'd0;
                    bit_n <= rx2 ? 4'd0 : 4'd2;          // si volvio a 1, era un pico
                end else cnt <= cnt + 16'd1;
            end else begin
                if (cnt == DIVISOR - 1) begin
                    cnt <= 16'd0;
                    if (bit_n == 4'd10) begin
                        bit_n <= 4'd0;
                        // sin stop valido el byte se descarta: mejor perder uno que meter basura
                        if (rx2) begin dato <= sh; valido <= 1'b1; end
                    end else begin
                        sh <= {rx2, sh[7:1]};             // LSB primero
                        bit_n <= bit_n + 4'd1;
                    end
                end else cnt <= cnt + 16'd1;
            end
        end
    end
endmodule
`default_nettype wire
