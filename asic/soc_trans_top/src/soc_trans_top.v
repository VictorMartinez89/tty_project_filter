// soc_trans_top.v — SoC femto (FemtoRV32 + ROM + periferico + MOTOR TRANSITIVO) para ASIC sky130.
//   El jefe final: un CPU RISC-V junto al motor de histeresis TRANSITIVA (reconstruccion morfologica),
//   cuyo framebuffer padded 62x82x2b se vuelve ~10 600 FLIP-FLOPS en silicio (no hay SPRAM en el ASIC).
//   El CPU corre un firmware de 7 instrucciones que elige el modo transitivo (mode=2) y fija los dos
//   umbrales (thr_hi=110, thr_lo=70) escribiendo el periferico 0x0045 (observabilidad / config).
//   El motor consume un stream externo de CLASE (0=nada/1=debil/2=fuerte) y, tras barrer el frame hasta
//   el punto fijo, emite el mapa de bordes (out_valid/edge_out/done). El periferico ve 'eng_busy' (~done)
//   para que el CPU pudiera sondear el estado.
//   CLAVE ASIC: el programa va en ROM SINTETIZADA (permanente); en silicio los FF arrancan aleatorios.
`default_nettype none
module soc_trans_top (
    input  wire       clk,
    input  wire       resetn,        // 0 = reset, 1 = corre
    input  wire       in_valid,      // hay una clase valida este ciclo (carga)
    input  wire [1:0] class_in,      // 0 nada / 1 debil / 2 fuerte
    output wire       load_ready,    // el motor esta listo para recibir el stream
    output wire       out_valid,     // emitiendo mapa de bordes
    output wire       edge_out,      // 1 = borde tras la reconstruccion
    output wire       done,          // barrido terminado
    output wire       cpu_wrote_filter,
    output wire [7:0] thr_hi_o,      // umbral alto que fijo el CPU (observabilidad)
    output wire [7:0] thr_lo_o,      // umbral bajo que fijo el CPU (observabilidad)
    output wire [1:0] mode_o         // modo elegido por el CPU (debe ser 2 = transitivo)
);
    // ---------------- CPU FemtoRV32 ----------------
    wire [31:0] mem_addr, mem_wdata; wire [3:0] mem_wmask; wire mem_rstrb;
    reg  [31:0] mem_rdata;
    FemtoRV32 CPU (
        .clk(clk), .reset(resetn),
        .mem_addr(mem_addr), .mem_wdata(mem_wdata), .mem_wmask(mem_wmask),
        .mem_rdata(mem_rdata), .mem_rstrb(mem_rstrb), .mem_rbusy(1'b0), .mem_wbusy(1'b0));
    wire cpu_wr = |mem_wmask;
    wire cpu_rd = mem_rstrb;
    wire cs_filter = (mem_addr[31:16] == 16'h0045);

    // ---------------- ROM de programa (7 instrucciones, lectura sincrona) ----------------
    reg [31:0] rom_q;
    always @(posedge clk) begin
        case (mem_addr[4:2])
            3'd0: rom_q <= 32'h004500b7;  // lui  x1,0x450
            3'd1: rom_q <= 32'h01200113;  // addi x2,x0,18   -> mode=transitivo(2), enable
            3'd2: rom_q <= 32'h0020a023;  // sw   x2,0(x1)   -> CTRL = 0x12
            3'd3: rom_q <= 32'h000071b7;  // lui  x3,0x7
            3'd4: rom_q <= 32'he4618193;  // addi x3,x3,-442 -> x3=0x6E46
            3'd5: rom_q <= 32'h0030a223;  // sw   x3,4(x1)   -> THR: thr_hi=110, thr_lo=70
            3'd6: rom_q <= 32'h0000006f;  // jal  x0,0       -> loop
            default: rom_q <= 32'h00000013; // NOP
        endcase
    end

    // ---------------- motor transitivo (stream externo de clase, mismo reloj) ----------------
    wire eng_done;
    trans_engine_top ENG (
        .clk(clk), .nreset(resetn),
        .in_valid(in_valid), .class_in(class_in),
        .load_ready(load_ready), .out_valid(out_valid), .edge_out(edge_out), .done(eng_done));
    assign done = eng_done;

    // ---------------- periferico del filtro ----------------
    wire [1:0] flt_mode; wire flt_enable, flt_engrst;
    wire [7:0] flt_thi, flt_tlo; wire [31:0] filt_dout;
    peripheral_filter PER (
        .clk(clk), .reset(~resetn),
        .d_in(mem_wdata), .cs(cs_filter), .addr(mem_addr[4:0]), .rd(cpu_rd), .wr(cpu_wr),
        .d_out(filt_dout),
        .mode(flt_mode), .enable(flt_enable), .eng_reset(flt_engrst),
        .thr_hi(flt_thi), .thr_lo(flt_tlo),
        .cfg_done(1'b1), .eng_busy(~eng_done), .vsync_alive(1'b1), .frame_count(16'd0));
    assign thr_hi_o = flt_thi;
    assign thr_lo_o = flt_tlo;
    assign mode_o   = flt_mode;

    // mux de lectura del bus: periferico o ROM
    always @(*) mem_rdata = cs_filter ? filt_dout : rom_q;

    reg wrote = 1'b0;
    always @(posedge clk) if (!resetn) wrote <= 1'b0; else if (cs_filter && cpu_wr) wrote <= 1'b1;
    assign cpu_wrote_filter = wrote;
endmodule
`default_nettype wire
