// Top de prueba: filter_dma + RAM src (CPU escribe / DMA lee) + RAM dst (DMA escribe / CPU lee)
`default_nettype none
module tb_dma_top #(parameter integer AW=17)(
    input  wire        clk, reset,
    // control DMA
    input  wire        start, mode,
    input  wire [AW-1:0] src_addr, dst_addr, npx,
    input  wire [15:0] img_w,
    input  wire [11:0] low, high,
    output wire        done,
    output wire [AW-1:0] rescount,
    // puerto del "CPU": precarga de src y lectura de dst
    input  wire        pl_we,
    input  wire [AW-1:0] pl_addr,
    input  wire [7:0]  pl_data,
    input  wire [AW-1:0] rb_addr,
    output wire [15:0] rb_data
);
    wire        dma_rd_en, dma_wr_en;
    wire [AW-1:0] dma_rd_addr, dma_wr_addr;
    wire [7:0]  dma_rd_data;
    wire [15:0] dma_wr_data;

    dpram #(.DW(8),  .AW(AW)) srcram (.clk(clk),
        .we(pl_we), .waddr(pl_addr), .wdata(pl_data),
        .raddr(dma_rd_addr), .rdata(dma_rd_data));
    dpram #(.DW(16), .AW(AW)) dstram (.clk(clk),
        .we(dma_wr_en), .waddr(dma_wr_addr), .wdata(dma_wr_data),
        .raddr(rb_addr), .rdata(rb_data));

    filter_dma #(.AW(AW)) dma (.clk(clk), .reset(reset),
        .start(start), .mode(mode), .src_addr(src_addr), .dst_addr(dst_addr), .npx(npx),
        .img_w(img_w), .low(low), .high(high), .done(done), .rescount(rescount),
        .rd_en(dma_rd_en), .rd_addr(dma_rd_addr), .rd_data(dma_rd_data),
        .wr_en(dma_wr_en), .wr_addr(dma_wr_addr), .wr_data(dma_wr_data));
endmodule
`default_nettype wire
