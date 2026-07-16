// ============================================================================
// rgb565_to_gray.v
// Convierte un pixel RGB565 (el que sale de ov7670_capture) a gris de 8 bits.
// Luma aproximada SIN multiplicar (estilo Diana, solo sumas y shifts):
//     Y = (R + 2*G + B) >> 2
// RGB565:  [15:11]=R5  [10:5]=G6  [4:0]=B5  (se expanden a 8 bits replicando MSBs).
// ============================================================================
`default_nettype none
module rgb565_to_gray (
    input  wire [15:0] rgb565,
    output wire [7:0]  gray
);
    wire [4:0] r5 = rgb565[15:11];
    wire [5:0] g6 = rgb565[10:5];
    wire [4:0] b5 = rgb565[4:0];
    // expandir a 8 bits (replicar los bits altos para llenar el rango)
    wire [7:0] r8 = {r5, r5[4:2]};
    wire [7:0] g8 = {g6, g6[5:4]};
    wire [7:0] b8 = {b5, b5[4:2]};
    // Y = (R + 2G + B) >> 2   -> cabe en 10 bits, tomamos los 8 altos
    wire [9:0] sum = r8 + {g8, 1'b0} + b8;     // g8<<1 = {g8,1'b0}
    assign gray = sum[9:2];
endmodule
`default_nettype wire
