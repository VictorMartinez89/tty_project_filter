// tt_um_soc_canny1_vic.v — SoC RISC-V (FemtoRV32) + Canny 1-streaming, envuelto para Tiny Tapeout.
//   El CPU corre 7 instrucciones desde una ROM sintetizada y escribe el periferico 0x0045:
//   modo = Canny1 y los DOS umbrales (thr_hi=90, thr_lo=40). El camino de imagen sigue en streaming.
//   Es el mas grande de los cuatro candidatos: el Action de Tiny Tapeout dira si entra en 8x2 tiles.
`default_nettype none
module tt_um_soc_canny1_vic (
    input  wire [7:0] ui_in,    // in_pix[7:0]
    output wire [7:0] uo_out,   // out_pix[7:0]
    input  wire [7:0] uio_in,   // uio_in[0] = in_valid
    output wire [7:0] uio_out,  // uio_out[1] = out_valid, [2] = cpu_wrote_filter
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);
    wire out_valid, cpu_wrote;
    wire [7:0] thr_hi_o, thr_lo_o;

    soc_canny1_top u_soc (
        .clk(clk), .resetn(rst_n),                  // soc_canny1_top usa resetn activo-bajo
        .in_valid(uio_in[0]), .in_pix(ui_in),
        .out_valid(out_valid), .out_pix(uo_out),
        .cpu_wrote_filter(cpu_wrote),
        .thr_hi_o(thr_hi_o), .thr_lo_o(thr_lo_o));

    assign uio_out = {5'b0, cpu_wrote, out_valid, 1'b0};
    assign uio_oe  = 8'b0000_0110;                  // uio[1] y uio[2] = salidas
    wire _unused = &{ena, uio_in[7:1], thr_hi_o, thr_lo_o, 1'b0};
endmodule
`default_nettype wire
