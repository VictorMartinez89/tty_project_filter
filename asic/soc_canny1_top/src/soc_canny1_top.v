// soc_canny1_top.v — SoC femto (FemtoRV32 + ROM + periferico + Canny 1-salto) AUTOCONTENIDO para ASIC sky130.
//   El CPU corre un firmware de 7 instrucciones que elige Canny1 y fija LOS DOS umbrales
//   (thr_hi=90, thr_lo=40) escribiendo el periferico 0x0045; el datapath Canny1 usa ESOS
//   umbrales (no cableados). Sin camara/display/LED.
//   CLAVE ASIC: el programa va en una ROM SINTETIZADA (permanente), no en RAM init'd (que en
//   silicio arrancaria aleatoria). El firmware no usa RAM de datos -> no hace falta RAM writable.
//   Fase 4 del roadmap ASIC: el SoC con el datapath Canny (Gaussian->Sobel->doble umbral->histeresis).
`default_nettype none
module soc_canny1_top (
    input  wire       clk,
    input  wire       resetn,        // 0 = reset, 1 = corre
    input  wire       in_valid,
    input  wire [7:0] in_pix,
    output reg        out_valid,
    output reg  [7:0] out_pix,       // FF=borde / 00=plano
    output wire       cpu_wrote_filter,
    output wire [7:0] thr_hi_o,      // umbral alto que fijo el CPU (observabilidad)
    output wire [7:0] thr_lo_o       // umbral bajo que fijo el CPU (observabilidad)
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
            3'd1: rom_q <= 32'h01100113;  // addi x2,x0,17    -> mode=Canny1(1), enable
            3'd2: rom_q <= 32'h0020a023;  // sw   x2,0(x1)    -> CTRL = 0x11
            3'd3: rom_q <= 32'h000061b7;  // lui  x3,0x6
            3'd4: rom_q <= 32'ha2818193;  // addi x3,x3,-1496 -> x3=0x5A28
            3'd5: rom_q <= 32'h0030a223;  // sw   x3,4(x1)    -> THR: thr_hi=90, thr_lo=40
            3'd6: rom_q <= 32'h0000006f;  // jal  x0,0        -> loop
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
    assign thr_hi_o = flt_thi;
    assign thr_lo_o = flt_tlo;

    // mux de lectura del bus: periferico o ROM
    always @(*) mem_rdata = cs_filter ? filt_dout : rom_q;

    reg wrote = 1'b0;
    always @(posedge clk) if (!resetn) wrote <= 1'b0; else if (cs_filter && cpu_wr) wrote <= 1'b1;
    assign cpu_wrote_filter = wrote;

    // ================= datapath Canny 1-salto (stream externo, mismo reloj) =================
    // etapa 1: Gaussian 3x3
    wire vg;
    wire [7:0] gw00,gw01,gw02,gw10,gw11,gw12,gw20,gw21,gw22;
    linebuf3x3 #(.W(60),.DW(8)) LBG (
        .clk(clk),.in_valid(in_valid),.in_pix(in_pix),.valid_o(vg),
        .w00(gw00),.w01(gw01),.w02(gw02),.w10(gw10),.w11(gw11),.w12(gw12),
        .w20(gw20),.w21(gw21),.w22(gw22));
    wire [11:0] gsum = gw00+(gw01<<1)+gw02 + (gw10<<1)+(gw11<<2)+(gw12<<1) + gw20+(gw21<<1)+gw22;
    wire [7:0]  gout = gsum[11:4];   // /16

    // etapa 2: Sobel 3x3 sobre la Gaussiana
    wire vs;
    wire [7:0] sw00,sw01,sw02,sw10,sw11,sw12,sw20,sw21,sw22;
    linebuf3x3 #(.W(60),.DW(8)) LBS (
        .clk(clk),.in_valid(vg),.in_pix(gout),.valid_o(vs),
        .w00(sw00),.w01(sw01),.w02(sw02),.w10(sw10),.w11(sw11),.w12(sw12),
        .w20(sw20),.w21(sw21),.w22(sw22));
    wire [10:0] gxp=sw02+(sw12<<1)+sw22, gxn=sw00+(sw10<<1)+sw20;
    wire [10:0] gyp=sw20+(sw21<<1)+sw22, gyn=sw00+(sw01<<1)+sw02;
    wire [10:0] agx=(gxp>=gxn)?(gxp-gxn):(gxn-gxp);
    wire [10:0] agy=(gyp>=gyn)?(gyp-gyn):(gyn-gyp);
    wire [11:0] mag12=agx+agy;
    wire [7:0]  mag=(mag12>12'd255)?8'd255:mag12[7:0];
    wire [1:0]  cls_in = (mag>flt_thi)?2'd2 : (mag>flt_tlo)?2'd1 : 2'd0;  // doble umbral del CPU

    // etapa 3: clase (line-buffer DW=2) -> histeresis 1-salto
    wire vc;
    wire [1:0] cw00,cw01,cw02,cw10,cw11,cw12,cw20,cw21,cw22;
    linebuf3x3 #(.W(60),.DW(2)) LBC (
        .clk(clk),.in_valid(vs),.in_pix(cls_in),.valid_o(vc),
        .w00(cw00),.w01(cw01),.w02(cw02),.w10(cw10),.w11(cw11),.w12(cw12),
        .w20(cw20),.w21(cw21),.w22(cw22));
    wire any_strong = (cw00==2'd2)|(cw01==2'd2)|(cw02==2'd2)|(cw10==2'd2)|
                      (cw12==2'd2)|(cw20==2'd2)|(cw21==2'd2)|(cw22==2'd2);
    wire edge_1hop  = (cw11==2'd2) ? 1'b1 : (cw11==2'd1) ? any_strong : 1'b0;

    always @(posedge clk) begin
        if (!resetn) begin out_valid <= 1'b0; out_pix <= 8'd0; end
        else begin
            out_valid <= vc;
            out_pix   <= edge_1hop ? 8'hFF : 8'h00;
        end
    end
endmodule
`default_nettype wire
