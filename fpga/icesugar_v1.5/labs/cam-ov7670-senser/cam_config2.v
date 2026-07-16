// cam_config2.v — Config OV7670 (grises+QQVGA) por SCCB, v2 con diagnostico claro
//   ROJO fijo  = configurando (FSM trabajando)
//   VERDE fijo = configuracion TERMINADA (cfg_done) — NO depende del brillo
//   AZUL parpadea = FPGA viva
//   UART (pin 6): tras terminar, imprime el brillo en hex ~3/seg (debe abrir 00..FF)
//
// Cambios vs v1: (1) verde = cfg_done puro (diagnostico inequivoco)
//                (2) pausa ~25ms despues del RESET + pausitas entre registros
//                (3) sin escritura basura al final de la tabla
//
// Pines: clk=35, cam_xclk=2, cam_scl=26, cam_sda=27,
//        cam_pclk=45, cam_href=3, cam_d[0..7]=48,46,44,43,38,34,31,42,
//        uart_tx=6, leds=39/40/41

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

    // ---------- SCCB pins ----------
    reg sda_oe = 1'b0;
    assign cam_sda = sda_oe ? 1'b0 : 1'bz;
    reg scl = 1'b1;
    assign cam_scl = scl;

    reg [5:0] tdiv = 6'd0;
    wire tick = (tdiv == 6'd29);
    always @(posedge clk) tdiv <= tick ? 6'd0 : tdiv + 1'b1;

    // ---------- tabla {addr,val}, 16'hFFFF = fin ----------
    reg [15:0] rom;
    reg [4:0]  idx = 5'd0;
    always @(*) case (idx)
        5'd0:  rom = 16'h12_80;   // COM7 RESET (necesita pausa despues)
        5'd1:  rom = 16'h12_00;   // COM7 YUV (luma = grises)
        5'd2:  rom = 16'h0C_04;   // COM3 DCW enable
        5'd3:  rom = 16'h3E_1A;   // COM14 PCLK escalado
        5'd4:  rom = 16'h70_3A;   // SCALING_XSC
        5'd5:  rom = 16'h71_35;   // SCALING_YSC
        5'd6:  rom = 16'h72_22;   // DCWCTR /4 -> QQVGA
        5'd7:  rom = 16'h73_F2;   // PCLK_DIV /4
        5'd8:  rom = 16'hA2_02;   // PCLK_DELAY
        5'd9:  rom = 16'h11_01;   // CLKRC
        5'd10: rom = 16'h1E_00;   // MVFP
        default: rom = 16'hFF_FF; // FIN
    endcase
    wire       tbl_end  = (rom == 16'hFF_FF);
    wire [7:0] reg_addr = rom[15:8];
    wire [7:0] reg_val  = rom[7:0];

    // ---------- FSM: START,WR42,WRaddr,WRval,STOP,DELAY,NEXT ----------
    localparam OP_START=3'd0, OP_WR=3'd1, OP_STOP=3'd2, OP_DELAY=3'd3, OP_NEXT=3'd4;
    reg [2:0] pc = 3'd0;
    reg [1:0] ph = 2'd0;
    reg [3:0] bi = 4'd0;
    reg [15:0] dly = 16'd0;
    reg       cfg_done = 1'b0;

    reg [2:0] optype;
    always @(*) case (pc)
        3'd0: optype = OP_START;
        3'd1: optype = OP_WR;
        3'd2: optype = OP_WR;
        3'd3: optype = OP_WR;
        3'd4: optype = OP_STOP;
        3'd5: optype = OP_DELAY;
        default: optype = OP_NEXT;
    endcase

    reg [7:0] wbyte;
    always @(*) case (pc)
        3'd1: wbyte = 8'h42;
        3'd2: wbyte = reg_addr;
        3'd3: wbyte = reg_val;
        default: wbyte = 8'h00;
    endcase

    reg [19:0] boot = 20'd0;
    wire boot_ok = &boot;
    always @(posedge clk) if (!boot_ok) boot <= boot + 1'b1;

    always @(posedge clk) if (tick && boot_ok && !cfg_done) begin
        case (optype)
        OP_START: begin
            if (tbl_end) cfg_done <= 1'b1;           // fin de tabla -> listo
            else begin
                case (ph)
                    2'd0: begin sda_oe <= 1'b0; scl <= 1'b1; end
                    2'd1: begin sda_oe <= 1'b1; scl <= 1'b1; end
                    2'd2: begin scl <= 1'b0; end
                    2'd3: begin pc <= pc + 1'b1; end
                endcase
                ph <= ph + 1'b1;
            end
        end
        OP_WR: begin
            case (ph)
                2'd0: begin scl <= 1'b0;
                            if (bi < 4'd8) sda_oe <= ~wbyte[3'd7 - bi[2:0]];
                            else           sda_oe <= 1'b0; end
                2'd1: scl <= 1'b1;
                2'd2: scl <= 1'b1;
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
                2'd3: begin pc <= pc + 1'b1;
                            // carga la pausa: larga tras el RESET (idx==0), corta el resto
                            dly <= (idx == 5'd0) ? 16'd9999 : 16'd99; end
            endcase
            ph <= ph + 1'b1;
        end
        OP_DELAY: begin
            if (dly == 16'd0) pc <= pc + 1'b1;       // pausa terminada -> NEXT
            else dly <= dly - 1'b1;
        end
        default: begin                               // OP_NEXT
            idx <= idx + 1'b1;
            pc  <= 3'd0;
        end
        endcase
    end

    // ---------- brillo (solo para UART) ----------
    reg [11:0] acc = 12'd0;
    always @(posedge cam_pclk)
        if (cam_href) acc <= acc - (acc >> 4) + {4'd0, cam_d};
    wire [7:0] lum = acc[11:4];
    reg [7:0] lum_s0 = 8'd0, lum_s1 = 8'd0;
    always @(posedge clk) begin lum_s0 <= lum; lum_s1 <= lum_s0; end

    // ---------- UART telemetry ----------
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
    reg [2:0] pst = 3'd0;
    reg [7:0] val = 8'd0;
    always @(posedge clk) begin
        tx_start <= 1'b0;
        case (pst)
            3'd0: if (ptick && cfg_done) begin val <= lum_s1; pst <= 3'd1; end
            3'd1: if (!tx_busy && !tx_start) begin tx_data <= hex(val[7:4]); tx_start <= 1'b1; pst <= 3'd2; end
            3'd2: if (!tx_busy && !tx_start) begin tx_data <= hex(val[3:0]); tx_start <= 1'b1; pst <= 3'd3; end
            3'd3: if (!tx_busy && !tx_start) begin tx_data <= 8'h0D;         tx_start <= 1'b1; pst <= 3'd4; end
            3'd4: if (!tx_busy && !tx_start) begin tx_data <= 8'h0A;         tx_start <= 1'b1; pst <= 3'd0; end
            default: pst <= 3'd0;
        endcase
    end

    // ---------- LEDs (diagnostico claro) ----------
    reg [23:0] hb = 24'd0;
    always @(posedge clk) hb <= hb + 1'b1;

    SB_RGBA_DRV #(
        .CURRENT_MODE("0b1"),
        .RGB0_CURRENT("0b000001"),
        .RGB1_CURRENT("0b000001"),
        .RGB2_CURRENT("0b000001")
    ) rgba (
        .CURREN(1'b1), .RGBLEDEN(1'b1),
        .RGB0PWM(cfg_done),         // VERDE fijo = config termino
        .RGB1PWM(~cfg_done),        // ROJO  fijo = configurando
        .RGB2PWM(hb[23]),           // AZUL  = heartbeat
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
