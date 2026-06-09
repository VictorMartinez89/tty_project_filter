// =============================================================================
// bus_arbiter.sv -- arbitro de bus para integrar el DMA al SoC (un solo puerto
//   de memoria compartido entre el CPU y el DMA). PRIORIDAD al DMA: mientras el
//   DMA pide el bus (dma_req), controla la memoria y el CPU queda en STALL.
//   Asi el DMA procesa el frame; el CPU se pausa y reanuda al terminar.
// =============================================================================
`default_nettype none
module bus_arbiter #(parameter integer AW=17, parameter integer DW=16)(
    // maestro CPU
    input  wire           cpu_req, cpu_we,
    input  wire [AW-1:0]  cpu_addr,
    input  wire [DW-1:0]  cpu_wdata,
    output wire [DW-1:0]  cpu_rdata,
    output wire           cpu_stall,
    // maestro DMA
    input  wire           dma_req, dma_we,
    input  wire [AW-1:0]  dma_addr,
    input  wire [DW-1:0]  dma_wdata,
    output wire [DW-1:0]  dma_rdata,
    // memoria (un puerto)
    output wire           mem_we,
    output wire [AW-1:0]  mem_addr,
    output wire [DW-1:0]  mem_wdata,
    input  wire [DW-1:0]  mem_rdata
);
    wire dma_owns = dma_req;                  // prioridad al DMA
    assign mem_we    = dma_owns ? dma_we    : cpu_we;
    assign mem_addr  = dma_owns ? dma_addr  : cpu_addr;
    assign mem_wdata = dma_owns ? dma_wdata : cpu_wdata;
    assign cpu_rdata = mem_rdata;
    assign dma_rdata = mem_rdata;
    assign cpu_stall = dma_owns & cpu_req;    // CPU espera si pide el bus y el DMA lo tiene
endmodule
`default_nettype wire
