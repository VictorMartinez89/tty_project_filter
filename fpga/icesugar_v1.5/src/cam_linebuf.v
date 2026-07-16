// cam_linebuf.v — Paso 5a: UN line buffer + gradiente vertical (medio Sobel).
// Configura la camara (COM7/COM8/COM9), extrae luma (Y), guarda 1 fila en BRAM,
// y calcula |pixel_actual - pixel_fila_de_arriba| = bordes horizontales.
// El brillo del LED VERDE sube con la cantidad de bordes en la escena.
//   -> Apunta a algo liso (pared): LED tenue.
//   -> Apunta a algo con lineas/texto/tu mano: LED brilla. = line buffer OK!
//
//   ROJO=configurando, VERDE=bordes (tras configurar), AZUL=heartbeat.
//   UART: imprime el nivel de bordes en hex (para verificar por numeros).
// Pines: cam_config.pcf (PCLK28, HREF32, SIOC26, SIOD27, D0-7, ...).

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

    // ======================= SCCB config =======================
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
        5'd0:  rom = 16'h12_00;   // COM7 YUV/grises
        5'd1:  rom = 16'h13_E7;   // COM8 auto gain/exp/wb
        5'd2:  rom = 16'h09_18;   // COM9 techo ganancia
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

    // ================= LINE BUFFER + gradiente vertical =================
    // Dominio cam_pclk. Stream YUV: Y en bytes pares (parity==0), croma en impares.
    // En el ciclo de croma la BRAM lee/escribe tranquila (ciclo "libre").
    reg        parity = 1'b0;
    reg [9:0]  col    = 10'd0;      // columna (indice de pixel Y en la fila)
    reg [7:0]  curY   = 8'd0;       // pixel de luma actual

    // BRAM de 1 fila (1024 x 8). Guarda la fila ANTERIOR.
    reg [7:0] linebuf [0:1023];
    reg [7:0] rdata = 8'd0;
    wire wr_en = cam_href & parity;              // escribir en el ciclo de croma
    always @(posedge cam_pclk) begin
        rdata <= linebuf[col];                   // lectura registrada (1 ciclo)
        if (wr_en) linebuf[col] <= curY;         // guardar pixel de la fila actual
    end

    // gradiente vertical = |actual - fila_de_arriba|
    wire [7:0] grad = (curY >= rdata) ? (curY - rdata) : (rdata - curY);

    // acumulador IIR del nivel de bordes
    reg [15:0] edge_acc = 16'd0;
    always @(posedge cam_pclk) begin
        if (!cam_href) begin
            parity <= 1'b0;
            col    <= 10'd0;
        end else begin
            if (parity == 1'b0) begin
                curY <= cam_d;                   // capturar luma (Y)
            end else begin
                // ciclo de croma: rdata = pixel de arriba en 'col'; grad listo
                edge_acc <= edge_acc - (edge_acc >> 6) + {8'd0, grad};
                col <= col + 1'b1;
            end
            parity <= ~parity;
        end
    end
    wire [7:0] edge_level = edge_acc[13:6];       // nivel promedio de bordes

    // ================= cruce a dominio clk =================
    reg [7:0] el_s0 = 0, el_s1 = 0;
    always @(posedge clk) begin el_s0 <= edge_level; el_s1 <= el_s0; end

    // ================= UART: imprime nivel de bordes =================
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
    reg [7:0] ev = 0;
    always @(posedge clk) begin
        tx_start <= 1'b0;
        case (pst)
            3'd0: if (ptick && cfg_done) begin ev <= el_s1; pst <= 3'd1; end
            3'd1: if (!tx_busy && !tx_start) begin tx_data <= hex(ev[7:4]); tx_start <= 1'b1; pst <= 3'd2; end
            3'd2: if (!tx_busy && !tx_start) begin tx_data <= hex(ev[3:0]); tx_start <= 1'b1; pst <= 3'd3; end
            3'd3: if (!tx_busy && !tx_start) begin tx_data <= 8'h0D;         tx_start <= 1'b1; pst <= 3'd4; end
            3'd4: if (!tx_busy && !tx_start) begin tx_data <= 8'h0A;         tx_start <= 1'b1; pst <= 3'd0; end
            default: pst <= 3'd0;
        endcase
    end

    // ================= LEDs =================
    reg [7:0]  pwm = 8'd0;
    reg [23:0] hb  = 24'd0;
    always @(posedge clk) begin pwm <= pwm + 1'b1; hb <= hb + 1'b1; end
    wire green = cfg_done & (pwm < el_s1);       // brillo = nivel de bordes

    SB_RGBA_DRV #(
        .CURRENT_MODE("0b1"),
        .RGB0_CURRENT("0b000011"), .RGB1_CURRENT("0b000001"), .RGB2_CURRENT("0b000001")
    ) rgba (
        .CURREN(1'b1), .RGBLEDEN(1'b1),
        .RGB0PWM(green),        // VERDE = actividad de bordes
        .RGB1PWM(~cfg_done),    // ROJO  = configurando
        .RGB2PWM(hb[23]),       // AZUL  = heartbeat
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
