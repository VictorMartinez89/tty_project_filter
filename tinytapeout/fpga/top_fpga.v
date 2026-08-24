// top_fpga.v — ADAPTADOR para probar un diseno de Tiny Tapeout en la iCE40UP5K.
//
//   El top de TT expone uio_in / uio_out / uio_oe como TRES buses separados (8+8+8), porque en el
//   chip real el tri-state vive en el anillo de pads del shuttle. Eso da 43 senales de nivel superior
//   (8 ui + 8 uo + 24 uio + clk + rst_n + ena) y la iCE40UP5K en sg48 solo tiene 39 pines.
//
//   Este adaptador hace lo que hace el anillo de pads: junta los tres buses en 8 pines INOUT reales
//   (uio[7:0]) usando el tri-state de la FPGA. Resultado: 8 + 8 + 8 + clk + rst_n = 27 pines. Entra.
//
//   El diseno bajo prueba se llama tt_um_dut: cada proyecto aporta un shim de 5 lineas que lo mapea
//   a su tt_um_*_vic (lo genera utilizacion_fpga.sh).
`default_nettype none
module top_fpga (
    input  wire       clk,
    input  wire       rst_n,
    input  wire [7:0] ui_in,      // entradas del usuario
    output wire [7:0] uo_out,     // salidas del usuario
    inout  wire [7:0] uio         // bidireccionales REALES (aqui si son inout)
);
    wire [7:0] uio_out, uio_oe;

    tt_um_dut dut (
        .ui_in(ui_in), .uo_out(uo_out),
        .uio_in(uio), .uio_out(uio_out), .uio_oe(uio_oe),
        .ena(1'b1),                       // en el shuttle lo pone el multiplexor; aqui siempre activo
        .clk(clk), .rst_n(rst_n));

    // el tri-state por bit: si uio_oe[i]=1 el diseno maneja el pin, si no queda en alta impedancia
    genvar i;
    generate
        for (i = 0; i < 8; i = i + 1) begin : g_uio
            assign uio[i] = uio_oe[i] ? uio_out[i] : 1'bz;
        end
    endgenerate
endmodule
`default_nettype wire
