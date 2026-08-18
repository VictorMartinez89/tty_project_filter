`timescale 1ns/1ps
// linebuf3x3.v — generador de ventana 3x3 con LINE-BUFFERS EN BRAM (reusable, parametrico).
// Guarda las 2 filas anteriores en BRAM (lectura sincrona + escritura, doble puerto) en vez
// de shift-registers. Entra un stream raster (in_valid/in_pix), salen los 9 taps + valid_o.
//   Ventana:  w00 w01 w02   (fila n-2)
//             w10 w11 w12   (fila n-1)   centro = w11 = (n-1, x-1)
//             w20 w21 w22   (fila n)     col: w*2=x(nuevo) w*1=x-1 w*0=x-2
module linebuf3x3 #(parameter W=160, parameter DW=8) (
    input  wire            clk,
    input  wire            in_valid,
    input  wire [DW-1:0]   in_pix,
    output reg             valid_o,
    output reg [DW-1:0]    w00,w01,w02, w10,w11,w12, w20,w21,w22
);
    reg [DW-1:0] lb_a [0:W-1];   // fila n-2
    reg [DW-1:0] lb_b [0:W-1];   // fila n-1
    reg [DW-1:0] q_a, q_b, cur;
    reg [8:0] x=0, xd=0; reg v1=0;

    // etapa 1: lectura sincrona + avanzar columna
    always @(posedge clk) begin
        v1 <= 1'b0;
        if (in_valid) begin
            q_a <= lb_a[x]; q_b <= lb_b[x]; cur <= in_pix;
            xd  <= x; x <= (x==W-1) ? 9'd0 : x+9'd1; v1 <= 1'b1;
        end
    end
    // etapa 2: escritura de retorno (rota filas) + ventana
    always @(posedge clk) begin
        valid_o <= 1'b0;
        if (v1) begin
            lb_a[xd] <= q_b;    // fila n-1 -> n-2
            lb_b[xd] <= cur;    // pixel nuevo -> n-1
            w00<=w01; w01<=w02; w02<=q_a;
            w10<=w11; w11<=w12; w12<=q_b;
            w20<=w21; w21<=w22; w22<=cur;
            valid_o <= 1'b1;
        end
    end
endmodule
