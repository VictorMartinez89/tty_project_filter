// tt_um_sobel_vic.v — Sobel 3x3 de bordes (Victor, UNAL) envuelto para Tiny Tapeout.
//   Interfaz TT (8 in + 8 out + 8 bidi + clk/rst_n/ena). Umbral fijo (TT no alcanza para 8 pines mas).
//   Pixel entra por ui_in; in_valid por uio_in[0]; out_pix por uo_out; out_valid por uio_out[1].
//   Es el filtro mas chico de los tres: solo 2 line-buffers y sumadores, sin Gaussiano ni CPU.
`default_nettype none
module tt_um_sobel_vic (
    input  wire [7:0] ui_in,    // in_pix[7:0]
    output wire [7:0] uo_out,   // out_pix[7:0]
    input  wire [7:0] uio_in,   // uio_in[0] = in_valid
    output wire [7:0] uio_out,  // uio_out[1] = out_valid
    output wire [7:0] uio_oe,   // habilitacion bidi (1=salida)
    input  wire       ena,      // 1 cuando el diseno esta activo
    input  wire       clk,
    input  wire       rst_n     // reset activo-bajo
);
    wire out_valid;
    localparam [7:0] THR = 8'd90;   // umbral de borde (fijo; el mismo del SoC en FPGA)

    sobel_top u_sobel (
        .clk(clk), .reset(~rst_n),                  // sobel_top usa reset activo-alto
        .in_valid(uio_in[0]), .in_pix(ui_in),
        .thr(THR),
        .out_valid(out_valid), .out_pix(uo_out));

    assign uio_out = {6'b0, out_valid, 1'b0};       // out_valid en bit 1
    assign uio_oe  = 8'b0000_0010;                  // uio[1]=salida; resto entradas
    wire _unused = &{ena, uio_in[7:1], 1'b0};       // evita warnings de senales sin usar
endmodule
`default_nettype wire
