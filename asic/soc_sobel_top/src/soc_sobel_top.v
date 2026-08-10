// soc_sobel_top.v — SoC femto (FemtoRV32 + ROM + periferico + Sobel) AUTOCONTENIDO para ASIC sky130.
//   El CPU corre un firmware de 7 instrucciones que elige Sobel y fija el umbral (thr=90) escribiendo
//   el periferico 0x0045; el datapath Sobel usa ESE umbral (no cableado). Sin camara/display/LED.
//   CLAVE ASIC: el programa va en una ROM SINTETIZADA (permanente), no en RAM init'd (que en silicio
//   arrancaria aleatoria). El firmware no usa RAM de datos -> no hace falta RAM writable.
`default_nettype none
module soc_sobel_top (
    input  wire       clk,
    input  wire       resetn,        // 0 = reset, 1 = corre
    input  wire       in_valid,
    input  wire [7:0] in_pix,
    output reg        out_valid,
    output reg  [7:0] out_pix,       // FF=borde / 00=plano
    output wire       cpu_wrote_filter,
    output wire [7:0] thr_o          // el umbral que fijo el CPU (observabilidad)
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
            3'd1: rom_q <= 32'h01000113;  // addi x2,x0,16
            3'd2: rom_q <= 32'h0020a023;  // sw   x2,0(x1)   -> mode=Sobel, enable
            3'd3: rom_q <= 32'h000061b7;  // lui  x3,0x6
            3'd4: rom_q <= 32'ha0018193;  // addi x3,x3,-1536 -> x3=0x5A00
            3'd5: rom_q <= 32'h0030a223;  // sw   x3,4(x1)   -> thr_hi=90
            3'd6: rom_q <= 32'h0000006f;  // jal  x0,0       -> loop
            default: rom_q <= 32'h00000013; // NOP (addi x0,x0,0)
        endcase
    end

    // ---------------- periferico del filtro ----------------
    wire [1:0] flt_mode; wire flt_enable, flt_engrst;
    wire [7:0] flt_thi, flt_tlo; wire [31:0] filt_dout;
    peripheral_filter PER (
        .clk(clk), .reset(~resetn),
        .d_in(mem_wdata), .cs(cs_filter), .addr(mem_addr[4:0]), .rd(cpu_rd), .wr(cpu_wr),
        .d_out(filt_dout),
        .mode(flt_mode), .enable(flt_enable), .eng_reset(flt_engrst),
        .thr_hi(flt_thi), .thr_lo(flt_tlo),
        .cfg_done(1'b1), .eng_busy(1'b0), .vsync_alive(1'b1), .frame_count(16'd0));
    assign thr_o = flt_thi;

    // mux de lectura del bus: periferico o ROM
    always @(*) mem_rdata = cs_filter ? filt_dout : rom_q;

    reg wrote = 1'b0;
    always @(posedge clk) if (!resetn) wrote <= 1'b0; else if (cs_filter && cpu_wr) wrote <= 1'b1;
    assign cpu_wrote_filter = wrote;

    // ---------------- datapath Sobel (stream externo, mismo reloj) ----------------
    wire vin;
    wire [7:0] w00,w01,w02, w10,w11,w12, w20,w21,w22;
    linebuf3x3 #(.W(60), .DW(8)) LB (
        .clk(clk), .in_valid(in_valid), .in_pix(in_pix), .valid_o(vin),
        .w00(w00),.w01(w01),.w02(w02), .w10(w10),.w11(w11),.w12(w12),
        .w20(w20),.w21(w21),.w22(w22));
    wire [10:0] gxp = w02 + (w12<<1) + w22;
    wire [10:0] gxn = w00 + (w10<<1) + w20;
    wire [10:0] gyp = w20 + (w21<<1) + w22;
    wire [10:0] gyn = w00 + (w01<<1) + w02;
    wire [10:0] agx = (gxp>=gxn) ? (gxp-gxn) : (gxn-gxp);
    wire [10:0] agy = (gyp>=gyn) ? (gyp-gyn) : (gyn-gyp);
    wire [11:0] mag12 = agx + agy;
    wire [7:0]  mag = (mag12 > 12'd255) ? 8'd255 : mag12[7:0];

    always @(posedge clk) begin
        if (!resetn) begin out_valid <= 1'b0; out_pix <= 8'd0; end
        else begin
            out_valid <= vin;
            out_pix   <= (mag > flt_thi) ? 8'hFF : 8'h00;   // umbral puesto por el CPU
        end
    end
endmodule
`default_nettype wire
