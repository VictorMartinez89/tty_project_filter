// peripheral_filter.v — periferico de CONTROL/ESTADO del filtro de imagen para el
// SoC femto2 (FemtoRV32). Sigue el MISMO patron de bus que peripheral_mult/uart:
//   (clk, reset, d_in, cs, addr, rd, wr, d_out).
//
// FILOSOFIA: los pixeles NO pasan por el bus del CPU (serian demasiados). El camino
// de imagen es en streaming: camara -> filter_core -> LCD. Este periferico solo
// EXPONE al CPU un puñado de registros para elegir el filtro EN VIVO y leer estado.
//
// Mapa de registros (base 0x0045_0000, offset = addr):
//   0x00  CTRL  (W): [1:0] mode (0=Sobel, 1=Canny1-salto, 2=Canny transitivo)
//                    [4]   enable        [5] eng_reset (pulso al motor transitivo)
//   0x04  THR   (W): [7:0] thr_lo        [15:8] thr_hi   (doble umbral)
//   0x08  STAT  (R): [0] cfg_done  [1] eng_busy  [2] vsync_alive  [23:8] frame_count
module peripheral_filter (
    input             clk,
    input             reset,
    input      [31:0] d_in,
    input             cs,
    input      [4:0]  addr,
    input             rd,
    input             wr,
    output reg [31:0] d_out,
    // ---- hacia/desde el datapath de imagen (dominio de la camara/pantalla) ----
    output reg [1:0]  mode,          // filtro activo
    output reg        enable,
    output reg        eng_reset,     // pulso de reset al motor transitivo
    output reg [7:0]  thr_hi,
    output reg [7:0]  thr_lo,
    input             cfg_done,      // SCCB configurado (LED verde)
    input             eng_busy,      // motor transitivo barriendo
    input             vsync_alive,   // llegan cuadros de la camara
    input      [15:0] frame_count
);
    // ------------------ escritura de registros ------------------
    always @(posedge clk) begin
        if (reset) begin
            mode <= 2'd0; enable <= 1'b1; eng_reset <= 1'b0;
            thr_hi <= 8'd110; thr_lo <= 8'd70;      // arranque = Canny transitivo tipico
        end else begin
            eng_reset <= 1'b0;                       // auto-limpia (pulso de 1 ciclo)
            if (cs && wr) case (addr)
                5'h00: begin mode <= d_in[1:0]; enable <= d_in[4]; eng_reset <= d_in[5]; end
                5'h04: begin thr_lo <= d_in[7:0]; thr_hi <= d_in[15:8]; end
                default: ;
            endcase
        end
    end
    // ------------------ lectura de registros ------------------
    always @(*) begin
        d_out = 32'd0;
        if (cs && rd) case (addr)
            5'h00: d_out = {26'd0, eng_reset, enable, 2'b00, mode};
            5'h04: d_out = {16'd0, thr_hi, thr_lo};
            5'h08: d_out = {8'd0, frame_count, 5'd0, vsync_alive, eng_busy, cfg_done};
            default: d_out = 32'd0;
        endcase
    end
endmodule
