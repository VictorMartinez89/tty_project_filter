// uart_cmd.v — Interprete de comandos por UART en iCESugar v1.5
// Teclas: r/g/b = togglean rojo/verde/azul ; o = apaga todo. Tambien hace eco.
// 115200 8N1, reloj 12 MHz. uart_tx=pin6, uart_rx=pin4.

module top (
    input  wire clk,
    input  wire uart_rx,
    output wire uart_tx,
    output wire led_r,
    output wire led_g,
    output wire led_b
);
    // ---------- Receptor ----------
    wire [7:0] rx_data;
    wire       rx_valid;
    uart_rx #(.CLK_FREQ(12_000_000), .BAUD(115_200)) u_rx (
        .clk(clk), .rx(uart_rx), .data(rx_data), .valid(rx_valid)
    );

    // ---------- Transmisor ----------
    reg  [7:0] tx_data  = 8'h00;
    reg        tx_start = 1'b0;
    wire       tx_busy;
    uart_tx #(.CLK_FREQ(12_000_000), .BAUD(115_200)) u_tx (
        .clk(clk), .start(tx_start), .data(tx_data),
        .tx(uart_tx), .busy(tx_busy)
    );

    // ---------- Estado de cada color ----------
    // OJO color FISICO: verde=RGB0, rojo=RGB1, azul=RGB2
    reg red_on = 1'b0;
    reg grn_on = 1'b0;
    reg blu_on = 1'b0;

    // ---------- Recibir -> eco + interpretar comando ----------
    always @(posedge clk) begin
        tx_start <= 1'b0;
        if (rx_valid) begin
            tx_data  <= rx_data;     // eco: devuelve la tecla
            tx_start <= 1'b1;
            case (rx_data)
                "r", "R": red_on <= ~red_on;
                "g", "G": grn_on <= ~grn_on;
                "b", "B": blu_on <= ~blu_on;
                "o", "O": begin red_on <= 1'b0; grn_on <= 1'b0; blu_on <= 1'b0; end
                default:  ;          // otras teclas: no hacen nada
            endcase
        end
    end

    // ---------- Salida a los LEDs ----------
    SB_RGBA_DRV #(
        .CURRENT_MODE("0b1"),
        .RGB0_CURRENT("0b000001"),
        .RGB1_CURRENT("0b000001"),
        .RGB2_CURRENT("0b000001")
    ) rgba (
        .CURREN(1'b1), .RGBLEDEN(1'b1),
        .RGB0PWM(grn_on),    // RGB0 = verde fisico
        .RGB1PWM(red_on),    // RGB1 = rojo  fisico
        .RGB2PWM(blu_on),    // RGB2 = azul  fisico
        .RGB0(led_r), .RGB1(led_g), .RGB2(led_b)
    );
endmodule

// ================= UART RX 8N1 =================
module uart_rx #(
    parameter CLK_FREQ = 12_000_000,
    parameter BAUD     = 115_200
)(
    input  wire       clk,
    input  wire       rx,
    output reg [7:0]  data  = 8'h00,
    output reg        valid = 1'b0
);
    localparam integer DIV  = CLK_FREQ / BAUD;
    localparam integer HALF = DIV / 2;

    reg rx_s0 = 1'b1, rx_s1 = 1'b1;
    always @(posedge clk) begin rx_s0 <= rx; rx_s1 <= rx_s0; end

    localparam IDLE=2'd0, START=2'd1, DATA=2'd2, STOP=2'd3;
    reg [1:0]  state  = IDLE;
    reg [12:0] cnt    = 13'd0;
    reg [2:0]  bitidx = 3'd0;
    reg [7:0]  sh     = 8'h00;

    always @(posedge clk) begin
        valid <= 1'b0;
        case (state)
            IDLE:  if (rx_s1 == 1'b0) begin cnt <= 13'd0; state <= START; end
            START: if (cnt == HALF-1) begin
                       if (rx_s1 == 1'b0) begin cnt<=13'd0; bitidx<=3'd0; state<=DATA; end
                       else state <= IDLE;
                   end else cnt <= cnt + 1'b1;
            DATA:  if (cnt == DIV-1) begin
                       cnt <= 13'd0;
                       sh  <= {rx_s1, sh[7:1]};
                       if (bitidx == 3'd7) state <= STOP;
                       else bitidx <= bitidx + 1'b1;
                   end else cnt <= cnt + 1'b1;
            STOP:  if (cnt == DIV-1) begin
                       data  <= sh;
                       valid <= 1'b1;
                       state <= IDLE;
                   end else cnt <= cnt + 1'b1;
        endcase
    end
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
