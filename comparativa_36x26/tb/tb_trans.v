// tb_trans.v — motor transitivo a 16x12. Una semilla FUERTE y una cadena de DEBILes:
// la histeresis transitiva tiene que salvar la cadena ENTERA (la de 1 salto solo salvaria 2).
`timescale 1ns/1ps
`default_nettype none
module tb_trans;
    localparam H = 16, W = 12;
    reg clk = 0, nreset = 0, in_valid = 0;
    reg  [1:0] class_in = 0;
    wire load_ready, out_valid, edge_out, done;
    integer f, c, bordes = 0, salidas = 0, espera;
    reg [1:0] frame [0:H*W-1];

    always #5 clk = ~clk;

    trans_engine_top DUT (.clk(clk), .nreset(nreset), .in_valid(in_valid), .class_in(class_in),
                          .load_ready(load_ready), .out_valid(out_valid),
                          .edge_out(edge_out), .done(done));

    always @(posedge clk) if (out_valid) begin
        salidas = salidas + 1;
        if (edge_out) bordes = bordes + 1;
    end

    initial begin
        $dumpfile("trans.vcd"); $dumpvars(0, tb_trans);
        // frame: fila 8 -> un FUERTE en la col 1 y debiles de la 2 a la 10
        for (f = 0; f < H*W; f = f + 1) frame[f] = 2'd0;
        frame[8*W + 1] = 2'd2;
        for (c = 2; c < W-1; c = c + 1) frame[8*W + c] = 2'd1;

        repeat (8) @(posedge clk); nreset = 1;
        espera = 0;
        while (!load_ready && espera < 5000) begin @(posedge clk); espera = espera + 1; end
        for (f = 0; f < H*W; f = f + 1) begin
            class_in <= frame[f]; in_valid <= 1'b1; @(posedge clk);
        end
        in_valid <= 1'b0;
        espera = 0;
        while (!done && espera < 200000) begin @(posedge clk); espera = espera + 1; end
        $display("TRANSITIVO 16x12 -> bordes=%0d (cadena esperada=10)  pixeles=%0d  ciclos=%0d",
                 bordes, salidas, espera);
        $finish;
    end
endmodule
`default_nettype wire
