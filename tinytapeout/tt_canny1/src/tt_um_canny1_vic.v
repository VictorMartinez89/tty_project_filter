// tt_um_canny1_vic.v — Canny 1-streaming (Victor, UNAL) envuelto para Tiny Tapeout.
//   Interfaz TT (8 in + 8 out + 8 bidi + clk/rst_n/ena). Umbrales fijos (TT no alcanza para 16 pines mas).
//   Pixel entra por ui_in; in_valid por uio_in[0]; out_pix por uo_out; out_valid por uio_out[1].
`default_nettype none
module tt_um_canny1_vic (
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
    localparam [7:0] THR_HI = 8'd90;   // umbral alto (fijo)
    localparam [7:0] THR_LO = 8'd40;   // umbral bajo (fijo)

    canny1_top u_canny1 (
        .clk(clk), .reset(~rst_n),                 // canny1 usa reset activo-alto
        .in_valid(uio_in[0]), .in_pix(ui_in),
        .thr_hi(THR_HI), .thr_lo(THR_LO),
        .out_valid(out_valid), .out_pix(uo_out));

    assign uio_out = {6'b0, out_valid, 1'b0};       // out_valid en bit 1
    assign uio_oe  = 8'b0000_0010;                  // uio[1]=salida; resto entradas
    wire _unused = &{ena, uio_in[7:1], 1'b0};       // evita warnings de senales sin usar
endmodule
`default_nettype wire
