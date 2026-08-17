// ov7670_sccb.v (VARIANTE ASIC) — identico al SCCB verificado en FPGA, PERO la salida
//   open-drain se parte en dato+enable (siod_o / siod_oe) en vez de 1'bz. En el ASIC el
//   tri-state vive en el ANILLO DE I/O (el pad hace: pad = siod_oe ? siod_o : Z). Ver Parte 114.
`default_nettype none
module ov7670_sccb #(
    parameter integer SYSCLK_HZ = 12_000_000,
    parameter integer SCCB_HZ   = 100_000,
    parameter [7:0]   CAM_ADDR  = 8'h42,
    parameter integer NREGS     = 5
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       start,
    output reg        sioc,
    output wire       siod_o,      // dato SCCB (en open-drain siempre 0 cuando activo)
    output wire       siod_oe,     // 1 = maneja 0 ; 0 = suelta (el pad -> Z, pull-up externo -> 1)
    output reg        done,
    output reg [7:0]  dbg_reg
);
    function [15:0] rom(input [7:0] i);
        case (i)
            8'd0: rom = 16'h12_14;   // COM7  : QVGA + RGB
            8'd1: rom = 16'h40_d0;   // COM15 : RGB565, rango full
            8'd2: rom = 16'h11_01;   // CLKRC : prescaler de reloj
            8'd3: rom = 16'h0C_04;   // COM3  : enable scaling
            8'd4: rom = 16'h3E_19;   // COM14 : divide para QQVGA
            default: rom = 16'h0000;
        endcase
    endfunction

    localparam integer DIV = SYSCLK_HZ / (4 * SCCB_HZ);
    reg [15:0] div_cnt;
    wire tick = (div_cnt == DIV[15:0] - 1);
    always @(posedge clk or negedge rst_n)
        if (!rst_n) div_cnt <= 16'd0;
        else        div_cnt <= tick ? 16'd0 : div_cnt + 16'd1;

    reg armed;
    always @(posedge clk or negedge rst_n)
        if (!rst_n)                 armed <= 1'b0;
        else if (start)             armed <= 1'b1;
        else if (sioc == 1'b0)      armed <= armed;

    reg siod_low;                    // 1 => maneja 0 ; 0 => suelta
    assign siod_o  = 1'b0;           // open-drain: el dato manejado es siempre 0
    assign siod_oe = siod_low;       // el enable decide 0 vs Z (el tri-state va en el pad)

    localparam [2:0] S_IDLE=0, S_START=1, S_BIT=2, S_STOP=3, S_DELAY=4, S_DONE=5;
    reg [2:0] state;
    reg [1:0] q;
    reg [3:0] bitc;
    reg [1:0] bytec;
    reg [7:0] regc;

    wire [15:0] cur      = rom(regc);
    wire [7:0]  byte_sel = (bytec == 2'd0) ? CAM_ADDR :
                           (bytec == 2'd1) ? cur[15:8] : cur[7:0];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state<=S_IDLE; sioc<=1'b1; siod_low<=1'b0; done<=1'b0;
            q<=0; bitc<=0; bytec<=0; regc<=0; dbg_reg<=0;
        end else if (tick) begin
            case (state)
            S_IDLE: begin
                sioc<=1'b1; siod_low<=1'b0; done<=1'b0;
                if (armed) begin
                    regc<=0; bytec<=0; bitc<=0; q<=0; dbg_reg<=cur[15:8];
                    state<=S_START;
                end
            end
            S_START: begin
                case (q)
                    2'd0: begin siod_low<=1'b0; sioc<=1'b1; end
                    2'd1: begin siod_low<=1'b1; sioc<=1'b1; end
                    2'd2: begin siod_low<=1'b1; sioc<=1'b0; end
                    2'd3: begin bytec<=0; bitc<=0; state<=S_BIT; end
                endcase
                q<=q+2'd1;
            end
            S_BIT: begin
                case (q)
                    2'd0: begin sioc<=1'b0;
                                if (bitc<=4'd7) siod_low <= ~byte_sel[7-bitc[2:0]];
                                else            siod_low <= 1'b0;
                          end
                    2'd1: sioc<=1'b1;
                    2'd2: sioc<=1'b1;
                    2'd3: begin sioc<=1'b0;
                                if (bitc==4'd8) begin
                                    if (bytec==2'd2) state<=S_STOP;
                                    else begin bytec<=bytec+2'd1; bitc<=0; end
                                end else bitc<=bitc+4'd1;
                          end
                endcase
                q<=q+2'd1;
            end
            S_STOP: begin
                case (q)
                    2'd0: begin siod_low<=1'b1; sioc<=1'b0; end
                    2'd1: begin siod_low<=1'b1; sioc<=1'b1; end
                    2'd2: begin siod_low<=1'b0; sioc<=1'b1; end
                    2'd3: state<=S_DELAY;
                endcase
                q<=q+2'd1;
            end
            S_DELAY: begin
                sioc<=1'b1; siod_low<=1'b0;
                if (q==2'd3) begin
                    if (regc==NREGS-1) state<=S_DONE;
                    else begin regc<=regc+8'd1; dbg_reg<=rom(regc+8'd1) >> 8; state<=S_START; end
                end
                q<=q+2'd1;
            end
            S_DONE: done<=1'b1;
            endcase
        end
    end
endmodule
`default_nettype wire
