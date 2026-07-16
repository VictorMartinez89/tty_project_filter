// cam_sccb_id.v — Lee el ID de la OV7670 por SCCB (iCESugar v1.5)
// Paso 4a: prueba minima del protocolo SCCB. Lee el registro 0x0A (PID).
// La OV7670 debe responder 0x76  (de "OV7670").
//
//   VERDE fijo  = leyo 0x76  -> SCCB FUNCIONA. 🎉
//   ROJO  fijo  = leyo otra cosa -> revisar SIOC/SIOD/pull-ups.
//   AZUL parpadea = FPGA viva.
//   Por UART (pin 6): imprime  ID=XX  cada ~1.4 s.
//
// Pines: clk=35, cam_xclk=2, cam_scl(SIOC)=27, cam_sda(SIOD)=26,
//        uart_tx=6, leds=39/40/41
// SCCB ~100 kHz. SDA es open-drain (pull-up externo de 4.7k a 3.3V). SCL push-pull.

module top (
    input  wire clk,
    output wire cam_xclk,
    output wire cam_scl,
    inout  wire cam_sda,
    output wire uart_tx,
    output wire led_r,
    output wire led_g,
    output wire led_b
);
    assign cam_xclk = clk;          // la camara necesita XCLK para responder

    // ---------- SDA open-drain ----------
    reg sda_oe = 1'b0;              // 1 = forzar 0 ; 0 = liberar (pull-up -> 1)
    assign cam_sda = sda_oe ? 1'b0 : 1'bz;
    wire sda_in = cam_sda;

    reg scl = 1'b1;
    assign cam_scl = scl;

    // ---------- tick de 1/4 de bit (~100 kHz) ----------
    reg [5:0] tdiv = 6'd0;
    wire tick = (tdiv == 6'd29);    // 12MHz/30 = 400kHz -> /4 fases = 100kHz
    always @(posedge clk) tdiv <= tick ? 6'd0 : tdiv + 1'b1;

    // ---------- secuencia SCCB para leer registro 0x0A ----------
    // pc: 0=START,1=WR 0x42,2=WR 0x0A,3=STOP,4=START,5=WR 0x43,6=RD,7=STOP,8=DONE
    localparam OP_START=3'd0, OP_WR=3'd1, OP_RD=3'd2, OP_STOP=3'd3, OP_DONE=3'd4;

    reg [3:0] pc  = 4'd0;
    reg [1:0] ph  = 2'd0;           // fase 0..3
    reg [3:0] bi  = 4'd0;           // indice de bit 0..8 (8 datos + ack/nack)
    reg [7:0] rid = 8'd0;           // ID leido
    reg       done = 1'b0;

    // tipo de operacion segun pc
    reg [2:0] optype;
    always @(*) case (pc)
        4'd0: optype = OP_START;
        4'd1: optype = OP_WR;
        4'd2: optype = OP_WR;
        4'd3: optype = OP_STOP;
        4'd4: optype = OP_START;
        4'd5: optype = OP_WR;
        4'd6: optype = OP_RD;
        4'd7: optype = OP_STOP;
        default: optype = OP_DONE;
    endcase

    // byte a escribir segun pc
    reg [7:0] wbyte;
    always @(*) case (pc)
        4'd1: wbyte = 8'h42;        // direccion de escritura (0x21<<1)
        4'd2: wbyte = 8'h0A;        // sub-direccion = registro PID
        4'd5: wbyte = 8'h43;        // direccion de lectura
        default: wbyte = 8'h00;
    endcase

    always @(posedge clk) if (tick) begin
        case (optype)
        // ---- START: SDA 1->0 con SCL alto ----
        OP_START: begin
            case (ph)
                2'd0: begin sda_oe <= 1'b0; scl <= 1'b1; end
                2'd1: begin sda_oe <= 1'b1; scl <= 1'b1; end   // baja SDA = START
                2'd2: begin scl <= 1'b0; end
                2'd3: begin pc <= pc + 1'b1; end
            endcase
            ph <= ph + 1'b1;
        end
        // ---- WR byte: 8 bits MSB primero + 1 bit ack (liberado) ----
        OP_WR: begin
            case (ph)
                2'd0: begin scl <= 1'b0;
                            if (bi < 4'd8) sda_oe <= ~wbyte[3'd7 - bi[2:0]];
                            else           sda_oe <= 1'b0; end   // ack: liberar
                2'd1: scl <= 1'b1;
                2'd2: scl <= 1'b1;
                2'd3: begin scl <= 1'b0;
                            if (bi == 4'd8) begin bi <= 4'd0; pc <= pc + 1'b1; end
                            else bi <= bi + 1'b1; end
            endcase
            ph <= ph + 1'b1;
        end
        // ---- RD byte: leer 8 bits + mandar NACK ----
        OP_RD: begin
            case (ph)
                2'd0: begin scl <= 1'b0; sda_oe <= 1'b0; end     // liberar SDA
                2'd1: scl <= 1'b1;
                2'd2: begin scl <= 1'b1;
                            if (bi < 4'd8) rid[3'd7 - bi[2:0]] <= sda_in; end
                2'd3: begin scl <= 1'b0;
                            if (bi == 4'd8) begin bi <= 4'd0; pc <= pc + 1'b1; end
                            else bi <= bi + 1'b1; end
            endcase
            ph <= ph + 1'b1;
        end
        // ---- STOP: SDA 0->1 con SCL alto ----
        OP_STOP: begin
            case (ph)
                2'd0: begin scl <= 1'b0; sda_oe <= 1'b1; end
                2'd1: begin scl <= 1'b1; sda_oe <= 1'b1; end
                2'd2: begin scl <= 1'b1; sda_oe <= 1'b0; end     // sube SDA = STOP
                2'd3: pc <= pc + 1'b1;
            endcase
            ph <= ph + 1'b1;
        end
        // ---- DONE ----
        default: done <= 1'b1;
        endcase
    end

    wire ok = done & (rid == 8'h76);

    // ---------- UART: imprime "ID=XX\r\n" cada ~1.4 s ----------
    reg  [7:0] tx_data  = 8'd0;
    reg        tx_start = 1'b0;
    wire       tx_busy;
    uart_tx u_tx (.clk(clk), .start(tx_start), .data(tx_data), .tx(uart_tx), .busy(tx_busy));

    function [7:0] hex; input [3:0] n;
        hex = (n < 4'd10) ? (8'h30 + {4'd0,n}) : (8'h41 + {4'd0,n} - 8'd10);
    endfunction

    reg [23:0] gap = 24'd0;
    reg [3:0]  pst = 4'd0;
    reg [7:0]  pch;
    always @(*) case (pst)
        4'd0: pch = "I";
        4'd1: pch = "D";
        4'd2: pch = "=";
        4'd3: pch = hex(rid[7:4]);
        4'd4: pch = hex(rid[3:0]);
        4'd5: pch = 8'h0D;
        4'd6: pch = 8'h0A;
        default: pch = 8'h00;
    endcase

    reg printing = 1'b0;
    always @(posedge clk) begin
        tx_start <= 1'b0;
        if (!printing) begin
            gap <= gap + 1'b1;
            if (&gap && done) begin printing <= 1'b1; pst <= 4'd0; end
        end else if (!tx_busy && !tx_start) begin
            if (pch == 8'h00) begin printing <= 1'b0; gap <= 24'd0; end
            else begin tx_data <= pch; tx_start <= 1'b1; pst <= pst + 1'b1; end
        end
    end

    // ---------- LEDs ----------
    reg [23:0] hb = 24'd0;
    always @(posedge clk) hb <= hb + 1'b1;

    SB_RGBA_DRV #(
        .CURRENT_MODE("0b1"),
        .RGB0_CURRENT("0b000001"),
        .RGB1_CURRENT("0b000001"),
        .RGB2_CURRENT("0b000001")
    ) rgba (
        .CURREN(1'b1), .RGBLEDEN(1'b1),
        .RGB0PWM(ok),               // VERDE = leyo 0x76
        .RGB1PWM(done & ~ok),       // ROJO  = leyo otra cosa
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
