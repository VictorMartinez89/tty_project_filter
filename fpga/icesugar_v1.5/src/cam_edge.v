// cam_edge.v — line buffer + gradiente vertical, con detector de PICO (mas sensible).
// UART cada ~0.35s:  "<YM> <GM>"
//   YM = pico de LUMA  (confirma imagen viva; alto = hay imagen).
//   GM = pico de BORDE vertical |actual - fila_arriba| (sube al apuntar a lineas).
// Diagnostico:
//   YM alto + GM alto al apuntar a bordes  -> line buffer OK + detecta bordes 🎉
//   YM alto + GM = 00 siempre              -> line buffer no devuelve la fila anterior
//   YM = 00                                -> imagen negra (config)
//
//   VERDE = pico de bordes (brillo), ROJO=configurando, AZUL=heartbeat.
// Config: COM7=00, COM8=E7, COM9=18. Pines: cam_config.pcf.

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

    // ======== SCCB config (COM7/COM8/COM9) ========
    reg sda_oe = 1'b0;
    assign cam_sda = sda_oe ? 1'b0 : 1'bz;
    reg scl = 1'b1;
    assign cam_scl = scl;

    reg [5:0] tdiv = 6'd0;
    wire tick = (tdiv == 6'd29);
    always @(posedge clk) tdiv <= tick ? 6'd0 : tdiv + 1'b1;

    reg [15:0] rom;
    reg [4:0]  idx = 5'd0;
    always @(*) case (idx)
        5'd0:  rom = 16'h12_00;
        5'd1:  rom = 16'h13_E7;
        5'd2:  rom = 16'h09_18;
        default: rom = 16'hFF_FF;
    endcase
    wire       tbl_end  = (rom == 16'hFF_FF);
    wire [7:0] reg_addr = rom[15:8];
    wire [7:0] reg_val  = rom[7:0];

    localparam OP_START=3'd0, OP_WR=3'd1, OP_STOP=3'd2, OP_DELAY=3'd3, OP_NEXT=3'd4;
    reg [2:0] pc = 3'd0;
    reg [1:0] ph = 2'd0;
    reg [3:0] bi = 4'd0;
    reg [15:0] dly = 16'd0;
    reg       cfg_done = 1'b0;

    reg [2:0] optype;
    always @(*) case (pc)
        3'd0: optype = OP_START; 3'd1: optype = OP_WR; 3'd2: optype = OP_WR;
        3'd3: optype = OP_WR;    3'd4: optype = OP_STOP; 3'd5: optype = OP_DELAY;
        default: optype = OP_NEXT;
    endcase
    reg [7:0] wbyte;
    always @(*) case (pc)
        3'd1: wbyte = 8'h42; 3'd2: wbyte = reg_addr; 3'd3: wbyte = reg_val;
        default: wbyte = 8'h00;
    endcase

    reg [19:0] boot = 20'd0;
    wire boot_ok = &boot;
    always @(posedge clk) if (!boot_ok) boot <= boot + 1'b1;

    always @(posedge clk) if (tick && boot_ok && !cfg_done) begin
        case (optype)
        OP_START: begin
            if (tbl_end) cfg_done <= 1'b1;
            else begin
                case (ph)
                    2'd0: begin sda_oe <= 1'b0; scl <= 1'b1; end
                    2'd1: begin sda_oe <= 1'b1; scl <= 1'b1; end
                    2'd2: scl <= 1'b0;
                    2'd3: pc <= pc + 1'b1;
                endcase
                ph <= ph + 1'b1;
            end
        end
        OP_WR: begin
            case (ph)
                2'd0: begin scl <= 1'b0;
                            if (bi < 4'd8) sda_oe <= ~wbyte[3'd7 - bi[2:0]];
                            else           sda_oe <= 1'b0; end
                2'd1: scl <= 1'b1; 2'd2: scl <= 1'b1;
                2'd3: begin scl <= 1'b0;
                            if (bi == 4'd8) begin bi <= 4'd0; pc <= pc + 1'b1; end
                            else bi <= bi + 1'b1; end
            endcase
            ph <= ph + 1'b1;
        end
        OP_STOP: begin
            case (ph)
                2'd0: begin scl <= 1'b0; sda_oe <= 1'b1; end
                2'd1: begin scl <= 1'b1; sda_oe <= 1'b1; end
                2'd2: begin scl <= 1'b1; sda_oe <= 1'b0; end
                2'd3: begin pc <= pc + 1'b1; dly <= 16'd999; end
            endcase
            ph <= ph + 1'b1;
        end
        OP_DELAY: if (dly == 16'd0) pc <= pc + 1'b1; else dly <= dly - 1'b1;
        default:  begin idx <= idx + 1'b1; pc <= 3'd0; end
        endcase
    end

    // ======== LINE BUFFER (BRAM) ========
    reg        parity = 1'b0;
    reg [9:0]  col    = 10'd0;
    reg [7:0]  curY   = 8'd0;

    reg [7:0] linebuf [0:1023];
    reg [7:0] rdata = 8'd0;
    wire wr_en = cam_href & parity;
    always @(posedge cam_pclk) begin
        rdata <= linebuf[col];
        if (wr_en) linebuf[col] <= curY;
    end
    wire [7:0] grad = (curY >= rdata) ? (curY - rdata) : (rdata - curY);

    // ======== picos de luma y de borde ========
    reg [7:0] ymax = 8'd0, gmax = 8'd0;
    reg       clr = 1'b0, clr_p = 1'b0;
    always @(posedge cam_pclk) begin
        if (!cam_href) begin
            parity <= 1'b0;
            col    <= 10'd0;
        end else begin
            if (parity == 1'b0) begin
                curY <= cam_d;
            end else begin
                if (clr != clr_p) begin        // reinicio de picos
                    ymax  <= curY;
                    gmax  <= grad;
                    clr_p <= clr;
                end else begin
                    if (curY > ymax) ymax <= curY;
                    if (grad > gmax) gmax <= grad;
                end
                col <= col + 1'b1;
            end
            parity <= ~parity;
        end
    end

    // cruce a dominio clk
    reg [7:0] ym_s0=0, ym_s1=0, gm_s0=0, gm_s1=0;
    always @(posedge clk) begin
        ym_s0 <= ymax; ym_s1 <= ym_s0;
        gm_s0 <= gmax; gm_s1 <= gm_s0;
    end

    // ======== UART "<YM> <GM>" ========
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
    reg [7:0] ym = 0, gm = 0;
    reg [7:0] pch;
    always @(*) case (pst)
        4'd1: pch = hex(ym[7:4]); 4'd2: pch = hex(ym[3:0]); 4'd3: pch = " ";
        4'd4: pch = hex(gm[7:4]); 4'd5: pch = hex(gm[3:0]);
        4'd6: pch = 8'h0D;        4'd7: pch = 8'h0A;
        default: pch = 8'h00;
    endcase
    always @(posedge clk) begin
        tx_start <= 1'b0;
        case (pst)
            4'd0: if (ptick && cfg_done) begin ym <= ym_s1; gm <= gm_s1; clr <= ~clr; pst <= 4'd1; end
            4'd1,4'd2,4'd3,4'd4,4'd5,4'd6,4'd7:
                  if (!tx_busy && !tx_start) begin tx_data <= pch; tx_start <= 1'b1; pst <= pst + 1'b1; end
            default: pst <= 4'd0;
        endcase
    end

    // ======== LEDs ========
    reg [7:0]  pwm = 8'd0;
    reg [23:0] hb  = 24'd0;
    always @(posedge clk) begin pwm <= pwm + 1'b1; hb <= hb + 1'b1; end
    wire green = cfg_done & (pwm < gm_s1);      // brillo = pico de bordes

    SB_RGBA_DRV #(
        .CURRENT_MODE("0b1"),
        .RGB0_CURRENT("0b000011"), .RGB1_CURRENT("0b000001"), .RGB2_CURRENT("0b000001")
    ) rgba (
        .CURREN(1'b1), .RGBLEDEN(1'b1),
        .RGB0PWM(green), .RGB1PWM(~cfg_done), .RGB2PWM(hb[23]),
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
