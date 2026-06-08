// =============================================================================
// sobel_grad_core.sv  -- gradiente Sobel 3x3 (combinacional), estilo Diana.
//   Entrada: ventana 3x3 (gris) empacada row-major. Salidas:
//     mag_abs_o  = |Gx| + |Gy|            (BARATO: solo +,-,<<1  -> recomendado HW)
//     mag_sqrt_o = sqrt(Gx^2+Gy^2)        (EXACTO: usa cuadrados = multiplicadores)
//   Gx,Gy como Diana (sobel_core.sv): columnas/filas con peso central <<1.
// =============================================================================
`default_nettype none
module sobel_grad_core #(parameter integer PIX=8)(
    input  wire [9*PIX-1:0] window_i,
    output wire [PIX+3:0]   mag_abs_o,
    output wire [PIX+3:0]   mag_sqrt_o
);
    wire signed [PIX:0] p0=$signed({1'b0,window_i[PIX*0+:PIX]});
    wire signed [PIX:0] p1=$signed({1'b0,window_i[PIX*1+:PIX]});
    wire signed [PIX:0] p2=$signed({1'b0,window_i[PIX*2+:PIX]});
    wire signed [PIX:0] p3=$signed({1'b0,window_i[PIX*3+:PIX]});
    wire signed [PIX:0] p5=$signed({1'b0,window_i[PIX*5+:PIX]});
    wire signed [PIX:0] p6=$signed({1'b0,window_i[PIX*6+:PIX]});
    wire signed [PIX:0] p7=$signed({1'b0,window_i[PIX*7+:PIX]});
    wire signed [PIX:0] p8=$signed({1'b0,window_i[PIX*8+:PIX]});

    wire signed [PIX+3:0] gx = (p2-p0) + ((p5-p3)<<<1) + (p8-p6);
    wire signed [PIX+3:0] gy = (p6-p0) + ((p7-p1)<<<1) + (p8-p2);

    function automatic [PIX+3:0] absv(input signed [PIX+3:0] x);
        absv = x[PIX+3] ? (~x + 1'b1) : x;
    endfunction
    wire [PIX+3:0] ax = absv(gx), ay = absv(gy);
    assign mag_abs_o = ax + ay;                       // |Gx|+|Gy|

    // sqrt(Gx^2+Gy^2):  cuadrados (multiplicador) + isqrt
    localparam integer SQW = 22;                      // >= bits de (gx^2+gy^2), par
    wire [SQW-1:0] sumsq = (ax*ax) + (ay*ay);
    wire [SQW/2-1:0] root;
    isqrt #(.W(SQW)) u_sqrt (.x_i(sumsq), .y_o(root));
    assign mag_sqrt_o = root[PIX+3:0];
endmodule
`default_nettype wire
