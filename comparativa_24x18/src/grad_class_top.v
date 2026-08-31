// grad_class_top.v — genera la CLASE (2 bits) para el motor transitivo, sin CPU.
//   gray stream -> Gaussian 3x3 -> Sobel 3x3 -> doble umbral -> class_out (0 nada / 1 debil / 2 fuerte).
//   Es la MISMA cabeza del canny1_top, pero SIN la histeresis de 1 salto: aqui la histeresis la hace
//   el motor transitivo (por-cuadro, K barridos). Umbrales altos: la transitiva conecta semillas escasas.
`default_nettype none
module grad_class_top (
    input  wire       clk,
    input  wire       reset,       // sincrono, activo-alto
    input  wire       in_valid,
    input  wire [7:0] in_pix,
    input  wire [7:0] thr_hi,       // umbral fuerte
    input  wire [7:0] thr_lo,       // umbral debil
    output reg        out_valid,
    output reg  [1:0] class_out     // 0 nada / 1 debil / 2 fuerte
);
    // etapa 1: Gaussian 3x3
    wire vg;
    wire [7:0] gw00,gw01,gw02,gw10,gw11,gw12,gw20,gw21,gw22;
    linebuf3x3 #(.W(18),.DW(8)) LBG (
        .clk(clk),.reset(reset),.in_valid(in_valid),.in_pix(in_pix),.valid_o(vg),
        .w00(gw00),.w01(gw01),.w02(gw02),.w10(gw10),.w11(gw11),.w12(gw12),
        .w20(gw20),.w21(gw21),.w22(gw22));
    wire [11:0] gsum = gw00+(gw01<<1)+gw02 + (gw10<<1)+(gw11<<2)+(gw12<<1) + gw20+(gw21<<1)+gw22;
    wire [7:0]  gout = gsum[11:4];   // /16
    // etapa 2: Sobel 3x3 sobre la Gaussiana
    wire vs;
    wire [7:0] sw00,sw01,sw02,sw10,sw11,sw12,sw20,sw21,sw22;
    linebuf3x3 #(.W(18),.DW(8)) LBS (
        .clk(clk),.reset(reset),.in_valid(vg),.in_pix(gout),.valid_o(vs),
        .w00(sw00),.w01(sw01),.w02(sw02),.w10(sw10),.w11(sw11),.w12(sw12),
        .w20(sw20),.w21(sw21),.w22(sw22));
    wire [10:0] gxp=sw02+(sw12<<1)+sw22, gxn=sw00+(sw10<<1)+sw20;
    wire [10:0] gyp=sw20+(sw21<<1)+sw22, gyn=sw00+(sw01<<1)+sw02;
    wire [10:0] agx=(gxp>=gxn)?(gxp-gxn):(gxn-gxp);
    wire [10:0] agy=(gyp>=gyn)?(gyp-gyn):(gyn-gyp);
    wire [11:0] mag12=agx+agy;
    wire [7:0]  mag=(mag12>12'd255)?8'd255:mag12[7:0];
    wire [1:0]  cls = (mag>thr_hi)?2'd2 : (mag>thr_lo)?2'd1 : 2'd0;   // doble umbral
    always @(posedge clk) begin
        if (reset) begin out_valid<=1'b0; class_out<=2'd0; end
        else begin out_valid<=vs; class_out<=cls; end
    end
endmodule
`default_nettype wire
