// cam_config4.v — Config grises CON auto-exposicion/ganancia (arregla imagen negra).
// La imagen quedaba negra con solo COM7=0x00 porque el control automatico de luz
// estaba apagado. COM8 lo enciende (AGC/AEC/AWB).
//
// Tabla:  COM7=0x00 (YUV/grises), COM8=0xE7 (auto gain/exp/wb), COM9=0x18 (techo ganancia)
//
// UART cada ~0.35s:  "<PP> <H> <LL>"
//   PP=contador PCLK (cambia=vivo), H=HREF visto, LL=brillo.
//   -> Tapa el lente: LL baja.  Apunta a la luz: LL sube. (ahora deberia moverse!)
//   ROJO=configurando, VERDE=config lista, AZUL=heartbeat.
// Pines: cam_config.pcf (PCLK28, HREF32, SIOC26, SIOD27, etc.)

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
    reg scl = 1'b1;
    assign cam_scl = scl;

    reg [5:0] tdiv = 6'd0;
    wire tick = (tdiv == 6'd29);
    always @(posedge clk) tdiv <= tick ? 6'd0 : tdiv + 1'b1;

    // ---- tabla: formato + auto-exposicion/ganancia ----
    reg [15:0] rom;
    reg [4:0]  idx = 5'd0;
    always @(*) case (idx)
        5'd0:  rom = 16'h12_00;   // COM7 = YUV (grises)
        5'd1:  rom = 16'h13_E7;   // COM8 = AGC + AEC + AWB ON (auto luz)
        5'd2:  rom = 16'h09_18;   // COM9 = techo de ganancia
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

    // ---- PCLK vivo ----
    reg [7:0] pcnt = 8'd0;
    always @(posedge cam_pclk) pcnt <= pcnt + 1'b1;
    reg [7:0] pcnt_s0 = 0, pcnt_s1 = 0;
    always @(posedge clk) begin pcnt_s0 <= pcnt; pcnt_s1 <= pcnt_s0; end

    // ---- HREF ----
    reg href_seen = 1'b0;
    always @(posedge clk) if (cam_href) href_seen <= 1'b1;

    // ---- brillo: PICO de luma (bytes pares) para ver bien el rango ----
    reg       parity = 1'b0;
    reg [7:0] ymax = 8'd0;
    reg       clrm = 1'b0, clrm_p = 1'b0;
    always @(posedge cam_pclk) begin
        clrm_p <= clrm;
        if (!cam_href) parity <= 1'b0;
        else begin
            if (parity == 1'b0) begin
                if (clrm ^ clrm_p)     ymax <= cam_d;
                else if (cam_d > ymax) ymax <= cam_d;
            end
            parity <= ~parity;
        end
    end
    reg [7:0] ym_s0=0, ym_s1=0;
    always @(posedge clk) begin ym_s0 <= ymax; ym_s1 <= ym_s0; end

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
    reg [7:0] pp = 0, ll = 0;
    reg [7:0] pch;
    always @(*) case (pst)
        4'd1: pch = hex(pp[7:4]);  4'd2: pch = hex(pp[3:0]);  4'd3: pch = " ";
        4'd4: pch = href_seen ? "1" : "0"; 4'd5: pch = " ";
        4'd6: pch = hex(ll[7:4]);  4'd7: pch = hex(ll[3:0]);
        4'd8: pch = 8'h0D;         4'd9: pch = 8'h0A;
        default: pch = 8'h00;
    endcase
    always @(posedge clk) begin
        tx_start <= 1'b0;
        case (pst)
            4'd0: if (ptick && cfg_done) begin pp <= pcnt_s1; ll <= ym_s1; clrm <= ~clrm; pst <= 4'd1; end
            4'd1,4'd2,4'd3,4'd4,4'd5,4'd6,4'd7,4'd8,4'd9:
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
        .RGB0PWM(cfg_done), .RGB1PWM(~cfg_done), .RGB2PWM(hb[23]),
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
