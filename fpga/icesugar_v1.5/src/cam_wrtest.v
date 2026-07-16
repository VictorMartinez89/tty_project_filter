// cam_wrtest.v — Prueba ESCRITURA+LECTURA del SCCB en un registro seguro.
// Escribe 0xA5 en el registro 0x01 (BLUE gain, NO apaga la camara), luego lo lee.
//
// UART imprime cada ~0.35s:  "<RR> <PP>"
//   RR = lo que se leyo del registro 0x01.  Debe ser A5 si la escritura anda.
//        Si RR != A5 -> la fase de escribir-VALOR tiene un bug (gran hallazgo).
//   PP = contador libre por PCLK. Si CAMBIA = camara sigue viva tras un write
//        a un registro inocuo (=> el que la apagaba era COM7).
//
//   ROJO=trabajando, VERDE=secuencia lista, AZUL=heartbeat.
// Pines igual que los demas (cam_config.pcf).

module top (
    input  wire       clk,
    output wire       cam_xclk,
    output wire       cam_scl,
    inout  wire       cam_sda,
    input  wire       cam_pclk,
    input  wire       cam_href,
    input  wire [7:0] cam_d,
    output wire       uart_tx,
    output wire       led_r,
    output wire       led_g,
    output wire       led_b
);
    assign cam_xclk = clk;

    reg sda_oe = 1'b0;
    assign cam_sda = sda_oe ? 1'b0 : 1'bz;
    wire sda_in = cam_sda;
    reg scl = 1'b1;
    assign cam_scl = scl;

    reg [5:0] tdiv = 6'd0;
    wire tick = (tdiv == 6'd29);
    always @(posedge clk) tdiv <= tick ? 6'd0 : tdiv + 1'b1;

    // ---- programa: write 0x01=0xA5, luego read 0x01 ----
    localparam ST=3'd0, WR=3'd1, RD=3'd2, SP=3'd3, DN=3'd4;
    reg [3:0] s = 4'd0;
    reg [2:0] op;
    reg [7:0] dat;
    always @(*) begin
        op = DN; dat = 8'h00;
        case (s)
            4'd0:  op = ST;
            4'd1:  begin op = WR; dat = 8'h42; end   // dir escritura
            4'd2:  begin op = WR; dat = 8'h01; end   // registro 0x01
            4'd3:  begin op = WR; dat = 8'hA5; end   // VALOR = 0xA5
            4'd4:  op = SP;
            4'd5:  op = ST;
            4'd6:  begin op = WR; dat = 8'h42; end   // dir escritura
            4'd7:  begin op = WR; dat = 8'h01; end   // registro 0x01
            4'd8:  op = SP;
            4'd9:  op = ST;
            4'd10: begin op = WR; dat = 8'h43; end   // dir lectura
            4'd11: op = RD;
            4'd12: op = SP;
            default: op = DN;
        endcase
    end

    reg [1:0] ph = 2'd0;
    reg [3:0] bi = 4'd0;
    reg [7:0] rid = 8'd0;
    reg       done = 1'b0;

    reg [19:0] boot = 20'd0;
    wire boot_ok = &boot;
    always @(posedge clk) if (!boot_ok) boot <= boot + 1'b1;

    always @(posedge clk) if (tick && boot_ok && !done) begin
        case (op)
        ST: begin
            case (ph)
                2'd0: begin sda_oe <= 1'b0; scl <= 1'b1; end
                2'd1: begin sda_oe <= 1'b1; scl <= 1'b1; end
                2'd2: scl <= 1'b0;
                2'd3: s <= s + 1'b1;
            endcase
            ph <= ph + 1'b1;
        end
        WR: begin
            case (ph)
                2'd0: begin scl <= 1'b0;
                            if (bi < 4'd8) sda_oe <= ~dat[3'd7 - bi[2:0]];
                            else           sda_oe <= 1'b0; end
                2'd1: scl <= 1'b1;
                2'd2: scl <= 1'b1;
                2'd3: begin scl <= 1'b0;
                            if (bi == 4'd8) begin bi <= 4'd0; s <= s + 1'b1; end
                            else bi <= bi + 1'b1; end
            endcase
            ph <= ph + 1'b1;
        end
        RD: begin
            case (ph)
                2'd0: begin scl <= 1'b0; sda_oe <= 1'b0; end
                2'd1: scl <= 1'b1;
                2'd2: begin scl <= 1'b1;
                            if (bi < 4'd8) rid[3'd7 - bi[2:0]] <= sda_in; end
                2'd3: begin scl <= 1'b0;
                            if (bi == 4'd8) begin bi <= 4'd0; s <= s + 1'b1; end
                            else bi <= bi + 1'b1; end
            endcase
            ph <= ph + 1'b1;
        end
        SP: begin
            case (ph)
                2'd0: begin scl <= 1'b0; sda_oe <= 1'b1; end
                2'd1: begin scl <= 1'b1; sda_oe <= 1'b1; end
                2'd2: begin scl <= 1'b1; sda_oe <= 1'b0; end
                2'd3: s <= s + 1'b1;
            endcase
            ph <= ph + 1'b1;
        end
        default: done <= 1'b1;
        endcase
    end

    // ---- PCLK vivo? ----
    reg [7:0] pcnt = 8'd0;
    always @(posedge cam_pclk) pcnt <= pcnt + 1'b1;
    reg [7:0] pcnt_s0 = 0, pcnt_s1 = 0;
    always @(posedge clk) begin pcnt_s0 <= pcnt; pcnt_s1 <= pcnt_s0; end

    // ---- UART "<RR> <PP>" ----
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
    reg [7:0] rr = 0, pp = 0;
    reg [7:0] pch;
    always @(*) case (pst)
        4'd1: pch = hex(rr[7:4]); 4'd2: pch = hex(rr[3:0]); 4'd3: pch = " ";
        4'd4: pch = hex(pp[7:4]); 4'd5: pch = hex(pp[3:0]);
        4'd6: pch = 8'h0D;        4'd7: pch = 8'h0A;
        default: pch = 8'h00;
    endcase
    always @(posedge clk) begin
        tx_start <= 1'b0;
        case (pst)
            4'd0: if (ptick && done) begin rr <= rid; pp <= pcnt_s1; pst <= 4'd1; end
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
        .RGB0PWM(done), .RGB1PWM(~done), .RGB2PWM(hb[23]),
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
