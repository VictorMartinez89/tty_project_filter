// RAM dual-port simple (1 puerto escritura + 1 puerto lectura, latencia 1 ciclo).
// En HW real = BRAM. Sirve para src (CPU escribe / DMA lee) y dst (DMA escribe / CPU lee).
`default_nettype none
module dpram #(parameter integer DW=8, parameter integer AW=17, parameter integer DEPTH=80000)(
    input  wire            clk,
    input  wire            we,
    input  wire [AW-1:0]   waddr,
    input  wire [DW-1:0]   wdata,
    input  wire [AW-1:0]   raddr,
    output reg  [DW-1:0]   rdata
);
    reg [DW-1:0] mem [0:DEPTH-1];
    always @(posedge clk) begin
        if (we) mem[waddr] <= wdata;
        rdata <= mem[raddr];                 // lectura sincrona (1 ciclo)
    end
endmodule
`default_nettype wire
