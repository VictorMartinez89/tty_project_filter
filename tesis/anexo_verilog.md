# Anexo G. Código Verilog

Este anexo reúne el código de los diseños de la §4.3. Los fuentes completos están ordenados por
diseño en el repositorio `Verilog_Repo`, una carpeta por circuito; cada carpeta lleva un `LEEME.md` con
el origen y la suma md5 de cada fichero, de modo que puede comprobarse que el texto impreso es el mismo
que se entregó al sintetizador o al flujo a silicio.

Se incluyen los módulos escritos para este trabajo. El núcleo del procesador, `femtorv32_quark.v`, es
de B. Levy [ref. 1] y se cita en lugar de reproducirse. En los listados, sólo las líneas de comentario
que no cabían en la página se han partido en dos; el código no se ha tocado.

## G.1 Filtro Sobel (§4.3.1)

Es el circuito que la §5.2 lleva a silicio: 0,167 mm² en sky130. Recibe un flujo de píxeles en orden
de barrido, arma la ventana de 3×3 con `linebuf3x3` y decide borde o plano con un umbral. **La versión
para silicio omite el suavizado gaussiano** del Algoritmo 1: pasa de la ventana directamente al
gradiente, y su ancho de línea es de 60 píxeles.

Carpeta: `Verilog_Repo/sobel/`.

### `sobel_top.v`

```verilog
// sobel_top.v — Sobel de bordes AUTOCONTENIDO para ASIC (sky130), datapath de Victor.
//   Stream raster de pixeles (in_valid/in_pix 8-bit) -> ventana 3x3 (linebuf3x3) ->
//   |Gx|+|Gy| (satura a 255) -> umbral -> out_pix (FF=borde / 00=plano).
// Misma matematica que el SoC femto (cam_femto_display.v), sin CPU ni camara: listo
//   para OpenLane.
module sobel_top (
    input  wire       clk,
    input  wire       reset,       // sincrono, activo-alto
    input  wire       in_valid,
    input  wire [7:0] in_pix,
    input  wire [7:0] thr,         // umbral de borde
    output reg        out_valid,
    output reg  [7:0] out_pix      // 8'hFF borde / 8'h00 plano
);
    // ventana 3x3 por line-buffers
    wire [7:0] w00,w01,w02, w10,w11,w12, w20,w21,w22;
    wire       vin;
    linebuf3x3 #(.W(60), .DW(8)) LB (
        .clk(clk), .in_valid(in_valid), .in_pix(in_pix), .valid_o(vin),
        .w00(w00),.w01(w01),.w02(w02), .w10(w10),.w11(w11),.w12(w12),
        .w20(w20),.w21(w21),.w22(w22));

    // Sobel 3x3: Gx/Gy con centro x2, magnitud Manhattan |Gx|+|Gy|
    wire [10:0] gxp = w02 + (w12<<1) + w22;
    wire [10:0] gxn = w00 + (w10<<1) + w20;
    wire [10:0] gyp = w20 + (w21<<1) + w22;
    wire [10:0] gyn = w00 + (w01<<1) + w02;
    wire [10:0] agx = (gxp>=gxn) ? (gxp-gxn) : (gxn-gxp);
    wire [10:0] agy = (gyp>=gyn) ? (gyp-gyn) : (gyn-gyp);
    wire [11:0] mag12 = agx + agy;
    wire [7:0]  mag = (mag12 > 12'd255) ? 8'd255 : mag12[7:0];

    always @(posedge clk) begin
        if (reset) begin out_valid <= 1'b0; out_pix <= 8'd0; end
        else begin
            out_valid <= vin;
            out_pix   <= (mag > thr) ? 8'hFF : 8'h00;
        end
    end
endmodule
```

### `linebuf3x3.v`

El mismo generador de ventana sirve a los tres filtros; en los de Canny se instancia tres veces.

```verilog
`timescale 1ns/1ps
// linebuf3x3.v — generador de ventana 3x3 con LINE-BUFFERS EN BRAM (reusable,
//   parametrico).
// Guarda las 2 filas anteriores en BRAM (lectura sincrona + escritura, doble puerto)
//   en vez
// de shift-registers. Entra un stream raster (in_valid/in_pix), salen los 9 taps +
//   valid_o.
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
```

## G.2 Filtro Canny 1-streaming (§4.3.2)

Es el circuito `canny1` de la §5.2: 0,360 mm² en sky130. Encadena tres ventanas de 3×3 —suavizado
gaussiano, gradiente y clase— sobre tres instancias de `linebuf3x3` (Anexo G.1), todas de 60 píxeles de
ancho. **La versión para silicio lleva por la tercera memoria sólo la clase, dos bits**, y no el octante
que el Algoritmo 2 empaqueta con ella: el octante sólo lo necesita el reconocedor del Capítulo 6.

Carpeta: `Verilog_Repo/canny1/`.

### `canny1_top.v`

```verilog
// canny1_top.v — Canny 1-salto (streaming) AUTOCONTENIDO para ASIC (sky130).
//   Stream raster de pixeles (in_valid/in_pix 8-bit) -> Gaussian 3x3 -> Sobel 3x3 ->
// doble umbral (clase 0/1/2) -> histeresis de 1 salto -> out_pix (FF=borde /
//   00=plano).
// Mismo datapath modo-1 que el SoC femto (cam_femto_multi.v), sin CPU ni camara.
module canny1_top (
    input  wire       clk,
    input  wire       reset,       // sincrono, activo-alto
    input  wire       in_valid,
    input  wire [7:0] in_pix,
    input  wire [7:0] thr_hi,      // umbral alto (borde fuerte)
    input  wire [7:0] thr_lo,      // umbral bajo (borde debil)
    output reg        out_valid,
    output reg  [7:0] out_pix      // 8'hFF borde / 8'h00 plano
);
    // ===== etapa 1: Gaussian 3x3 (line-buffer) =====
    wire vg;
    wire [7:0] gw00,gw01,gw02,gw10,gw11,gw12,gw20,gw21,gw22;
    linebuf3x3 #(.W(60),.DW(8)) LBG (
        .clk(clk),.in_valid(in_valid),.in_pix(in_pix),.valid_o(vg),
        .w00(gw00),.w01(gw01),.w02(gw02),.w10(gw10),.w11(gw11),.w12(gw12),
        .w20(gw20),.w21(gw21),.w22(gw22));
    wire [11:0] gsum = gw00+(gw01<<1)+gw02 + (gw10<<1)+(gw11<<2)+(gw12<<1) + gw20+(gw21<<1)+gw22;
    wire [7:0]  gout = gsum[11:4];   // /16

    // ===== etapa 2: Sobel 3x3 sobre la Gaussiana (line-buffer) =====
    wire vs;
    wire [7:0] sw00,sw01,sw02,sw10,sw11,sw12,sw20,sw21,sw22;
    linebuf3x3 #(.W(60),.DW(8)) LBS (
        .clk(clk),.in_valid(vg),.in_pix(gout),.valid_o(vs),
        .w00(sw00),.w01(sw01),.w02(sw02),.w10(sw10),.w11(sw11),.w12(sw12),
        .w20(sw20),.w21(sw21),.w22(sw22));
    wire [10:0] gxp=sw02+(sw12<<1)+sw22, gxn=sw00+(sw10<<1)+sw20;
    wire [10:0] gyp=sw20+(sw21<<1)+sw22, gyn=sw00+(sw01<<1)+sw02;
    wire [10:0] agx=(gxp>=gxn)?(gxp-gxn):(gxn-gxp);
    wire [10:0] agy=(gyp>=gyn)?(gyp-gyn):(gyn-gyp);
    wire [11:0] mag12=agx+agy;
    wire [7:0]  mag=(mag12>12'd255)?8'd255:mag12[7:0];
    wire [1:0]  cls_in = (mag>thr_hi)?2'd2 : (mag>thr_lo)?2'd1 : 2'd0;  // doble umbral

    // ===== etapa 3: clase (line-buffer DW=2) -> histeresis 1-salto =====
    wire vc;
    wire [1:0] cw00,cw01,cw02,cw10,cw11,cw12,cw20,cw21,cw22;
    linebuf3x3 #(.W(60),.DW(2)) LBC (
        .clk(clk),.in_valid(vs),.in_pix(cls_in),.valid_o(vc),
        .w00(cw00),.w01(cw01),.w02(cw02),.w10(cw10),.w11(cw11),.w12(cw12),
        .w20(cw20),.w21(cw21),.w22(cw22));
    wire any_strong = (cw00==2'd2)|(cw01==2'd2)|(cw02==2'd2)|(cw10==2'd2)|
                      (cw12==2'd2)|(cw20==2'd2)|(cw21==2'd2)|(cw22==2'd2);
    wire edge_1hop  = (cw11==2'd2) ? 1'b1 : (cw11==2'd1) ? any_strong : 1'b0;

    always @(posedge clk) begin
        if (reset) begin out_valid <= 1'b0; out_pix <= 8'd0; end
        else begin
            out_valid <= vc;
            out_pix   <= edge_1hop ? 8'hFF : 8'h00;
        end
    end
endmodule
```
