// tt_um_soc_sobel_vic.v — SoC Femto (FemtoRV32 + ROM + Sobel) de Victor (UNAL) para Tiny Tapeout.
//   AUTOCONTENIDO: el CPU arranca de una ROM SINTETIZADA interna (no necesita flash externa) y
//   configura el filtro Sobel (umbral=90) por software. Pixel en ui_in; in_valid en uio_in[0];
//   out_pix en uo_out; out_valid en uio_out[1]; cpu_wrote_filter (prueba de que el CPU corrio) en uio_out[2].
`default_nettype none
module tt_um_soc_sobel_vic (
    input  wire [7:0] ui_in,    // in_pix[7:0]
    output wire [7:0] uo_out,   // out_pix[7:0]
    input  wire [7:0] uio_in,   // uio_in[0] = in_valid
    output wire [7:0] uio_out,  // uio_out[1]=out_valid, uio_out[2]=cpu_wrote_filter
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n     // TT rst_n (0=reset) == resetn del SoC
);
    wire out_valid, cpu_wrote_filter;
    wire [7:0] thr_o;

    soc_sobel_top u_soc (
        .clk(clk), .resetn(rst_n),
        .in_valid(uio_in[0]), .in_pix(ui_in),
        .out_valid(out_valid), .out_pix(uo_out),
        .cpu_wrote_filter(cpu_wrote_filter), .thr_o(thr_o));

    assign uio_out = {5'b0, cpu_wrote_filter, out_valid, 1'b0};  // bit1=out_valid, bit2=cpu_wrote_filter
    assign uio_oe  = 8'b0000_0110;                               // bits 1,2 = salida
    wire _unused = &{ena, uio_in[7:1], thr_o, 1'b0};
endmodule
`default_nettype wire
