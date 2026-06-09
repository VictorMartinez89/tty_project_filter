// RAM single-port (1 puerto: lee O escribe por ciclo). BRAM en HW.
`default_nettype none
module spram #(parameter integer DW=16, parameter integer AW=17, parameter integer DEPTH=80000)(
    input  wire           clk,
    input  wire           we,
    input  wire [AW-1:0]  addr,
    input  wire [DW-1:0]  wdata,
    output reg  [DW-1:0]  rdata
);
    reg [DW-1:0] mem [0:DEPTH-1];
    always @(posedge clk) begin
        if (we) mem[addr] <= wdata;
        rdata <= mem[addr];
    end
endmodule
`default_nettype wire
