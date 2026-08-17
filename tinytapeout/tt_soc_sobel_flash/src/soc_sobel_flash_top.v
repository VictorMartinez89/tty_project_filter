// soc_sobel_flash_top.v — SoC Femto + Sobel que ARRANCA DE FLASH SPI EXTERNA (estilo Johan/femtoRV).
//   A diferencia de soc_sobel_top (ROM sintetizada interna), aqui el programa vive en un chip de
//   flash SPI AFUERA: el FemtoRV32 hace fetch por MappedSPIFlash (CLK/CS_N/MOSI/MISO) y se estanca
//   con mem_rbusy mientras el SPI trae la instruccion. El periferico 0x0045 sigue eligiendo Sobel/thr.
//   Es la otra respuesta a "el firmware no se carga solo": leerlo de afuera, como un microcontrolador.
`default_nettype none
module soc_sobel_flash_top (
    input  wire       clk,
    input  wire       resetn,        // 0 = reset
    input  wire       in_valid,
    input  wire [7:0] in_pix,
    output reg        out_valid,
    output reg  [7:0] out_pix,
    output wire       cpu_wrote_filter,
    // ---- flash SPI externa (programa) ----
    output wire       flash_clk,
    output wire       flash_cs_n,
    output wire       flash_mosi,
    input  wire       flash_miso
);
    wire [31:0] mem_addr, mem_wdata; wire [3:0] mem_wmask; wire mem_rstrb;
    reg  [31:0] mem_rdata;
    wire flash_rbusy;

    FemtoRV32 CPU (
        .clk(clk), .reset(resetn),
        .mem_addr(mem_addr), .mem_wdata(mem_wdata), .mem_wmask(mem_wmask),
        .mem_rdata(mem_rdata), .mem_rstrb(mem_rstrb),
        .mem_rbusy(flash_rbusy), .mem_wbusy(1'b0));
    wire cpu_wr = |mem_wmask;
    wire cpu_rd = mem_rstrb;
    wire cs_filter = (mem_addr[31:16] == 16'h0045);
    wire cs_flash  = ~cs_filter;              // todo lo demas = programa en flash

    // ---- programa desde flash SPI externa ----
    wire [31:0] flash_rdata;
    MappedSPIFlash u_flash (
        .clk(clk), .rstrb(mem_rstrb & cs_flash), .word_address(mem_addr[21:2]),
        .rdata(flash_rdata), .rbusy(flash_rbusy),
        .CLK(flash_clk), .CS_N(flash_cs_n), .MOSI(flash_mosi), .MISO(flash_miso));

    // ---- periferico del filtro ----
    wire [1:0] flt_mode; wire flt_enable, flt_engrst; wire [7:0] flt_thi, flt_tlo; wire [31:0] filt_dout;
    peripheral_filter PER (
        .clk(clk), .reset(~resetn),
        .d_in(mem_wdata), .cs(cs_filter), .addr(mem_addr[4:0]), .rd(cpu_rd), .wr(cpu_wr),
        .d_out(filt_dout),
        .mode(flt_mode), .enable(flt_enable), .eng_reset(flt_engrst),
        .thr_hi(flt_thi), .thr_lo(flt_tlo),
        .cfg_done(1'b1), .eng_busy(1'b0), .vsync_alive(1'b1), .frame_count(16'd0));

    always @(*) mem_rdata = cs_filter ? filt_dout : flash_rdata;

    reg wrote = 1'b0;
    always @(posedge clk) if (!resetn) wrote <= 1'b0; else if (cs_filter && cpu_wr) wrote <= 1'b1;
    assign cpu_wrote_filter = wrote;

    // ---- datapath Sobel (stream externo) ----
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
        else begin out_valid <= vin; out_pix <= (mag > flt_thi) ? 8'hFF : 8'h00; end
    end
endmodule
`default_nettype wire
