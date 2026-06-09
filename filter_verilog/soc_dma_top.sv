// Top de integracion: CPU(port) + bus_arbiter + filter_dma_bus + spram (un puerto).
// El TB hace de CPU: precarga la imagen en RAM (cuando el DMA esta libre), programa
// el DMA y lo dispara; el arbitro le da el bus al DMA (CPU en stall); al terminar,
// el CPU lee los resultados de la RAM.
`default_nettype none
module soc_dma_top #(parameter integer AW=17)(
    input  wire        clk, reset,
    // puerto CPU (lo maneja el TB)
    input  wire        cpu_req, cpu_we,
    input  wire [AW-1:0] cpu_addr,
    input  wire [15:0] cpu_wdata,
    output wire [15:0] cpu_rdata,
    output wire        cpu_stall,
    // control del DMA
    input  wire        dma_start, dma_mode,
    input  wire [AW-1:0] src_addr, dst_addr, npx,
    input  wire [15:0] img_w,
    input  wire [11:0] low, high,
    output wire        dma_done,
    output wire [AW-1:0] rescount
);
    wire dma_req, dma_we; wire [AW-1:0] dma_addr; wire [15:0] dma_wdata, dma_rdata;
    wire mem_we; wire [AW-1:0] mem_addr; wire [15:0] mem_wdata, mem_rdata;

    bus_arbiter #(.AW(AW)) arb (
        .cpu_req(cpu_req), .cpu_we(cpu_we), .cpu_addr(cpu_addr), .cpu_wdata(cpu_wdata),
        .cpu_rdata(cpu_rdata), .cpu_stall(cpu_stall),
        .dma_req(dma_req), .dma_we(dma_we), .dma_addr(dma_addr), .dma_wdata(dma_wdata),
        .dma_rdata(dma_rdata),
        .mem_we(mem_we), .mem_addr(mem_addr), .mem_wdata(mem_wdata), .mem_rdata(mem_rdata));

    spram #(.DW(16), .AW(AW)) ram (.clk(clk), .we(mem_we), .addr(mem_addr),
        .wdata(mem_wdata), .rdata(mem_rdata));

    filter_dma_bus #(.AW(AW)) dma (.clk(clk), .reset(reset),
        .start(dma_start), .mode(dma_mode), .src_addr(src_addr), .dst_addr(dst_addr), .npx(npx),
        .img_w(img_w), .low(low), .high(high), .done(dma_done), .rescount(rescount),
        .req(dma_req), .we(dma_we), .addr(dma_addr), .wdata(dma_wdata), .rdata(dma_rdata));
endmodule
`default_nettype wire
