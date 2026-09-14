// soc_ctrl.v — el SoC SIN su datapath: solo FemtoRV32 + ROM + periferico 0x0045.
//
//   `soc_sobel_top` trae su propio Sobel, y en la cadena del clasificador ESE datapath sobra:
//   mnist_feat ya calcula el suyo. Lo unico que hace falta del SoC es la parte que escribe el
//   umbral. Sacar el filtro duplicado es la diferencia entre entrar en la iCE40UP5K y no entrar.
//
//   El firmware es el MISMO de la tesis, verbatim: siete instrucciones que eligen Sobel y fijan
//   thr=90 escribiendo el periferico 0x0045.
`default_nettype none
module soc_ctrl (
    input  wire       clk,
    input  wire       resetn,        // 0 = reset, 1 = corre
    output wire [7:0] thr_o,         // el umbral que fijo el CPU
    output wire       cpu_wrote      // ya escribio el periferico
);
    wire [31:0] mem_addr, mem_wdata; wire [3:0] mem_wmask; wire mem_rstrb;
    reg  [31:0] mem_rdata;
    FemtoRV32 CPU (
        .clk(clk), .reset(resetn),
        .mem_addr(mem_addr), .mem_wdata(mem_wdata), .mem_wmask(mem_wmask),
        .mem_rdata(mem_rdata), .mem_rstrb(mem_rstrb), .mem_rbusy(1'b0), .mem_wbusy(1'b0));
    wire cpu_wr = |mem_wmask;
    wire cpu_rd = mem_rstrb;
    wire cs_filter = (mem_addr[31:16] == 16'h0045);

    // ROM de programa — las MISMAS 7 instrucciones de soc_sobel_top.v
    reg [31:0] rom_q;
    always @(posedge clk) begin
        case (mem_addr[4:2])
            3'd0: rom_q <= 32'h004500b7;  // lui  x1,0x450
            3'd1: rom_q <= 32'h01000113;  // addi x2,x0,16
            3'd2: rom_q <= 32'h0020a023;  // sw   x2,0(x1)    -> mode=Sobel, enable
            3'd3: rom_q <= 32'h000061b7;  // lui  x3,0x6
            3'd4: rom_q <= 32'ha0018193;  // addi x3,x3,-1536 -> x3=0x5A00
            3'd5: rom_q <= 32'h0030a223;  // sw   x3,4(x1)    -> thr_hi=90
            3'd6: rom_q <= 32'h0000006f;  // jal  x0,0        -> loop
            default: rom_q <= 32'h00000013;
        endcase
    end

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

    always @(*) mem_rdata = cs_filter ? filt_dout : rom_q;

    reg wrote = 1'b0;
    always @(posedge clk) if (!resetn) wrote <= 1'b0; else if (cs_filter && cpu_wr) wrote <= 1'b1;
    assign cpu_wrote = wrote;
endmodule
`default_nettype wire
