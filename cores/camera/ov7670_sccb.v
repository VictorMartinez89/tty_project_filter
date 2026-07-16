// ============================================================================
// ov7670_sccb.v
//
// Maestro SCCB (I2C-like de Omnivision) para configurar la OV7670 al arranque.
// Target: iCESugar v1.5 (iCE40UP5K-SG48).  Es la pieza que le faltaba a
// ov7670_capture.v ("implement in cores/camera/ov7670_sccb.v"): sin esto la
// camara no emite un stream util.
//
// SCCB = escritura de 3 fases:  START, [ID=0x42], [sub-addr=reg], [dato], STOP.
// Cada byte va MSB primero + un 9no bit "don't care" (SCCB no exige ACK: el
// maestro suelta SIOD y el esclavo puede o no bajarlo). SIOD es open-drain:
// se maneja 0 o se suelta a Z (pull-up externo -> 1).
//
// Recorre una tabla ROM de {reg, valor} y hace una escritura por registro;
// al terminar levanta 'done'. Reloj SCCB ~100 kHz derivado del sysclk.
//
// NOTA: la tabla de abajo es un STARTER minimo. Reemplazala por tu secuencia
// QQVGA/QVGA RGB565 conocida-buena (la que ya te anduvo con Sobel).
// ============================================================================
`default_nettype none
module ov7670_sccb #(
    parameter integer SYSCLK_HZ = 12_000_000,   // reloj de la iCESugar
    parameter integer SCCB_HZ   = 100_000,      // ~100 kHz
    parameter [7:0]   CAM_ADDR  = 8'h42,         // direccion de escritura OV7670
    parameter integer NREGS     = 5
)(
    input  wire       clk,
    input  wire       rst_n,       // activo-bajo
    input  wire       start,       // pulso: arranca la config
    output reg        sioc,        // SCCB clock  (PMOD3)
    output wire       siod,        // SCCB data   (PMOD3, open-drain)
    output reg        done,        // 1 = tabla enviada
    output reg [7:0]  dbg_reg      // registro que se esta enviando (debug/LED)
);
    // -------- tabla de init (STARTER; reemplazar con tu QQVGA RGB565) --------
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

    // -------- generador de "quarter tick" (4 por bit SCCB) --------
    localparam integer DIV = SYSCLK_HZ / (4 * SCCB_HZ);
    reg [15:0] div_cnt;
    wire tick = (div_cnt == DIV[15:0] - 1);
    always @(posedge clk or negedge rst_n)
        if (!rst_n) div_cnt <= 16'd0;
        else        div_cnt <= tick ? 16'd0 : div_cnt + 16'd1;

    // -------- latch del pulso start --------
    reg armed;
    always @(posedge clk or negedge rst_n)
        if (!rst_n)                 armed <= 1'b0;
        else if (start)             armed <= 1'b1;
        else if (sioc == 1'b0)      armed <= armed;   // (se limpia al arrancar, abajo)

    // -------- SIOD open-drain --------
    reg siod_low;                    // 1 => maneja 0 ; 0 => suelta (pull-up -> 1)
    assign siod = siod_low ? 1'b0 : 1'bz;

    localparam [2:0] S_IDLE=0, S_START=1, S_BIT=2, S_STOP=3, S_DELAY=4, S_DONE=5;
    reg [2:0] state;
    reg [1:0] q;                     // quarter dentro del bit (0..3)
    reg [3:0] bitc;                  // 0..8 (8 datos + 1 don't-care)
    reg [1:0] bytec;                 // 0..2  (ID / reg / dato)
    reg [7:0] regc;                  // indice de registro

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
            // START: con SIOC alto, SIOD hace 1->0
            S_START: begin
                case (q)
                    2'd0: begin siod_low<=1'b0; sioc<=1'b1; end   // ambos altos
                    2'd1: begin siod_low<=1'b1; sioc<=1'b1; end   // SIOD baja (START)
                    2'd2: begin siod_low<=1'b1; sioc<=1'b0; end   // SIOC baja
                    2'd3: begin bytec<=0; bitc<=0; state<=S_BIT; end
                endcase
                q<=q+2'd1;
            end
            // BIT: por cada bit -> set (SIOC=0) / high / high / low
            S_BIT: begin
                case (q)
                    2'd0: begin sioc<=1'b0;                        // set data con SIOC bajo
                                if (bitc<=4'd7) siod_low <= ~byte_sel[7-bitc[2:0]];
                                else            siod_low <= 1'b0;   // 9no bit: soltar
                          end
                    2'd1: sioc<=1'b1;                              // flanco de subida (muestreo)
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
            // STOP: con SIOC alto, SIOD hace 0->1
            S_STOP: begin
                case (q)
                    2'd0: begin siod_low<=1'b1; sioc<=1'b0; end
                    2'd1: begin siod_low<=1'b1; sioc<=1'b1; end   // SIOC sube con SIOD bajo
                    2'd2: begin siod_low<=1'b0; sioc<=1'b1; end   // SIOD sube (STOP)
                    2'd3: state<=S_DELAY;
                endcase
                q<=q+2'd1;
            end
            // DELAY entre registros
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
