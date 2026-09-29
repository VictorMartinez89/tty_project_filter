// =============================================================================
// sobel_euclid_core.sv -- magnitud EUCLIDEA del Sobel, floor(sqrt(Gx^2 + Gy^2)).
//   Companero de sobel_compass_core: toma la MISMA ventana 3x3 empacada y da la
//   magnitud que el compass aproxima con un maximo. Sirve para comparar las dos
//   en el mismo simulador contra la columna sqrt(Gx^2+Gy^2) de la Parte 12.B.
//
//   Sin el operador '*': el cuadrado se escribe como suma de desplazamientos
//   (x^2 = sum_i x_i * (x << i)), que es lo que haria un multiplicador -- y por eso
//   NO forma parte de los filtros sintetizados: cuesta un multiplicador de 11x11
//   por cada eje. La raiz es isqrt.sv (no restaurador, solo restas y desplazamientos).
//   Gx es el gradiente E y Gy el N del compass; el signo no importa al cuadrado.
// =============================================================================
`default_nettype none
module sobel_euclid_core #(
    parameter integer PIX = 8
)(
    input  wire [9*PIX-1:0] window_i,
    output wire [PIX+2:0]   mag_o            // 11 bits: hasta floor(sqrt(2*1020^2)) = 1442
);
    wire signed [PIX:0] p0 = $signed({1'b0, window_i[PIX*0 +: PIX]});
    wire signed [PIX:0] p1 = $signed({1'b0, window_i[PIX*1 +: PIX]});
    wire signed [PIX:0] p2 = $signed({1'b0, window_i[PIX*2 +: PIX]});
    wire signed [PIX:0] p3 = $signed({1'b0, window_i[PIX*3 +: PIX]});
    wire signed [PIX:0] p5 = $signed({1'b0, window_i[PIX*5 +: PIX]});
    wire signed [PIX:0] p6 = $signed({1'b0, window_i[PIX*6 +: PIX]});
    wire signed [PIX:0] p7 = $signed({1'b0, window_i[PIX*7 +: PIX]});
    wire signed [PIX:0] p8 = $signed({1'b0, window_i[PIX*8 +: PIX]});

    wire signed [PIX+3:0] gx = (p0 + (p3<<1) + p6) - (p2 + (p5<<1) + p8);   // = gE del compass
    wire signed [PIX+3:0] gy = (p0 + (p1<<1) + p2) - (p6 + (p7<<1) + p8);   // = gN del compass

    function automatic [PIX+2:0] absv(input signed [PIX+3:0] x);
        absv = x[PIX+3] ? (~x + 1'b1) : x;
    endfunction
    // cuadrado por sumas desplazadas: 11 bits -> 22 bits
    function automatic [2*PIX+5:0] sq(input [PIX+2:0] x);
        integer i;
        begin
            sq = 0;
            for (i = 0; i < PIX+3; i = i + 1)
                if (x[i]) sq = sq + ({{(PIX+3){1'b0}}, x} << i);
        end
    endfunction

    wire [PIX+2:0]   ax = absv(gx), ay = absv(gy);
    wire [2*PIX+5:0] s2 = sq(ax) + sq(ay);                  // < 2^22
    isqrt #(.W(2*PIX+6)) u_sqrt (.x_i(s2), .y_o(mag_o));
endmodule
`default_nettype wire
