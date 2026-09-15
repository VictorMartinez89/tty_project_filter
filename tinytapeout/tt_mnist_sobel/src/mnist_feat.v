// mnist_feat.v — EXTRACTOR DE CARACTERISTICAS: pixel -> bordes -> histograma por zonas.
//
//   Es el front-end de la tesis (el mismo que corre en los 10 chips) con una cola nueva:
//   en vez de escribir el borde a un framebuffer, lo CUENTA por orientacion y por zona.
//
//     stream 8b -> Gauss 3x3 /16 -> Sobel 3x3 -> |Gx|+|Gy| sat 255 -> umbral
//                                             -> octante (3 comparaciones) -> contador[zona][bin]
//
//   POR QUE OCTANTE Y NO atan2: el bin es {sgn(Gy), sgn(Gx), |Gy|>|Gx|}. Tres comparaciones y
//   cero multiplicaciones; un atan2 pediria un CORDIC o una tabla. Son los mismos 8 sectores de
//   45 grados, con los bordes en 0/45/90... en vez de centrados. El golden de Python se cambio
//   para modelar ESTO, que es la regla de toda la tesis: el golden modela lo que el silicio hace.
//
//   `clr` limpia el histograma SIN tocar los line-buffers. Hace falta porque la imagen se manda
//   dos veces -los buffers arrancan vacios y la primera pasada trae basura, igual que en los
//   bancos de las Partes 29-35-: al empezar la segunda hay que poner los contadores en cero
//   pero conservar las dos filas ya cargadas. Un `reset` a secas borraria las dos cosas.
//
//   POR QUE 32 CONTADORES Y NO 40: la piramide es nivel 0+1 = 5 zonas x 8 orientaciones = 40
//   caracteristicas. Pero el nivel 0 (la imagen entera) es EXACTAMENTE la suma de los cuatro
//   cuadrantes -son una particion-, asi que no se guarda: se deriva sumando. Ocho contadores
//   menos, gratis. Es la misma idea de los metatiles: no guardes lo que podes reconstruir.
`default_nettype none
module mnist_feat #(
    parameter integer H   = 28,     // alto de la imagen de entrada
    parameter integer W   = 28,     // ancho
    parameter integer CW  = 9       // bits por contador (cuadrante de 12x12 = 144 -> 8 bits bastan)
)(
    input  wire            clk,
    input  wire            reset,          // sincrono, activo-alto: limpia TODO
    input  wire            clr,            // limpia solo histograma y posicion (deja los line-buffers)
    input  wire            in_valid,
    input  wire [7:0]      in_pix,
    input  wire [7:0]      thr,            // umbral de borde (el CPU lo puede escribir)
    output reg             frame_done,     // se conto el ultimo pixel util del cuadro
    output wire [32*CW-1:0] cnt_o,         // 4 cuadrantes x 8 orientaciones, empaquetados
    output reg  [10:0]      n_bordes       // total de pixeles de borde del cuadro (0..576)
);
    localparam integer HV = H-4, WV = W-4;   // area valida tras dos convoluciones 3x3

    // ---------------- etapa 1: Gaussiano 3x3 ----------------
    wire vg;
    wire [7:0] g00,g01,g02,g10,g11,g12,g20,g21,g22;
    linebuf3x3 #(.W(W),.DW(8)) LBG (
        .clk(clk),.reset(reset),.in_valid(in_valid),.in_pix(in_pix),.valid_o(vg),
        .w00(g00),.w01(g01),.w02(g02),.w10(g10),.w11(g11),.w12(g12),
        .w20(g20),.w21(g21),.w22(g22));
    wire [11:0] gsum = g00+(g01<<1)+g02 + (g10<<1)+(g11<<2)+(g12<<1) + g20+(g21<<1)+g22;
    wire [7:0]  gout = gsum[11:4];                       // /16 = shift, se trunca

    // ---------------- etapa 2: Sobel 3x3 ----------------
    wire vs;
    wire [7:0] s00,s01,s02,s10,s11,s12,s20,s21,s22;
    // OJO: .W(W) y NO .W(W-2). El linebuf3x3 emite UNA salida por cada entrada -no descarta
    // el borde-, asi que la segunda etapa sigue viendo filas de W. Ponerle W-2 le desalinea el
    // envolvimiento de fila y ensucia el resultado. Costo de este bug: media hora.
    linebuf3x3 #(.W(W),.DW(8)) LBS (
        .clk(clk),.reset(reset),.in_valid(vg),.in_pix(gout),.valid_o(vs),
        .w00(s00),.w01(s01),.w02(s02),.w10(s10),.w11(s11),.w12(s12),
        .w20(s20),.w21(s21),.w22(s22));
    wire [10:0] gxp = s02+(s12<<1)+s22, gxn = s00+(s10<<1)+s20;
    wire [10:0] gyp = s20+(s21<<1)+s22, gyn = s00+(s01<<1)+s02;
    wire        sgx = (gxp >= gxn);                      // signo de Gx
    wire        sgy = (gyp >= gyn);                      // signo de Gy
    wire [10:0] agx = sgx ? (gxp-gxn) : (gxn-gxp);       // |Gx|
    wire [10:0] agy = sgy ? (gyp-gyn) : (gyn-gyp);       // |Gy|
    wire [11:0] mag12 = agx + agy;
    wire [7:0]  mag   = (mag12 > 12'd255) ? 8'd255 : mag12[7:0];
    wire        es_borde = (mag > thr);
    wire [2:0]  bin = {sgy, sgx, (agy > agx)};           // <- el octante, sin una sola multiplicacion

    // ---------------- posicion, y la latencia del pipeline ----------------
    //   El linebuf3x3 emite UNA salida por cada entrada: el raster de salida tiene la misma
    //   forma HxW que el de entrada, con basura en el borde. Cada etapa retrasa W+2 muestras:
    //   W+1 porque la ventana centrada en (r,c) recien esta cuando entro (r+1,c+1) -eso es lo
    //   que midio la Parte 168- MAS 2 por el pipeline interno del propio linebuf (etapa de
    //   lectura + etapa de ventana)... y de esos 2 solo se ve 1 en el indice de muestra.
    //   El valor exacto se CALIBRO contra el golden barriendo LAT: 60 para W=28, o sea 2*(W+2).
    //   Con LAT=2*(W+1)=58 el histograma queda corrido DOS COLUMNAS y las zonas se mezclan,
    //   aunque el total de bordes sea correcto. Es la misma trampa de la Parte 168: el total
    //   no cambia con un corrimiento, asi que hay que mirar la distribucion, no la suma.
    localparam integer LAT = 2*(W+2);
    reg [$clog2(LAT+1)-1:0] lat_cnt;
    wire arrancado = (lat_cnt == LAT);
    reg [$clog2(W)-1:0] cx;
    reg [$clog2(H)-1:0] cy;
    wire interior = (cy >= 2) && (cy <= H-3) && (cx >= 2) && (cx <= W-3);
    wire [1:0] zona = {(cy-2) >= HV/2, (cx-2) >= WV/2};   // cuadrante sobre el area valida
    wire ult_pix = (cy == H-3) && (cx == W-3);

    // ---------------- los 32 contadores ----------------
    // `listo` congela el histograma cuando termina el cuadro: sin el, frame_done vuelve a
    //   pulsar al envolver el raster y el clasificador correria con los contadores moviendose
    //   debajo. Cuesta UN flip-flop y evita latchear los 32 contadores (288 FF).
    reg listo;
    reg [CW-1:0] cnt [0:31];
    // el total NO se deriva sumando los 32 contadores -serian 32 sumandos de 9 bits-:
    // sale gratis llevando un contador aparte que sube con cada pixel contado.
    wire [4:0] dir = {zona, bin};
    integer i;
    always @(posedge clk) begin
        if (reset || clr) begin
            cx <= 0; cy <= 0; lat_cnt <= 0; frame_done <= 1'b0; listo <= 1'b0; n_bordes <= 11'd0;
            for (i = 0; i < 32; i = i + 1) cnt[i] <= {CW{1'b0}};
        end else begin
            frame_done <= 1'b0;
            if (vs && !listo) begin
                if (!arrancado) lat_cnt <= lat_cnt + 1'b1;   // tragarse la latencia
                else begin
                    if (es_borde && interior && cnt[dir] != {CW{1'b1}}) begin
                        cnt[dir] <= cnt[dir] + 1'b1;         // satura, no envuelve
                        n_bordes <= n_bordes + 11'd1;
                    end
                    if (cx == W-1) begin
                        cx <= 0;
                        cy <= (cy == H-1) ? 0 : cy + 1'b1;
                    end else cx <= cx + 1'b1;
                    if (ult_pix) begin frame_done <= 1'b1; listo <= 1'b1; end   // arranca el clasificador y congela
                end
            end
        end
    end
    // se empaquetan en un bus: yosys no admite puertos de array en Verilog-2005, y un bus
    // plano es ademas lo que espera cualquier flujo de sintesis.
    genvar k;
    generate for (k = 0; k < 32; k = k + 1) begin : sal
        assign cnt_o[k*CW +: CW] = cnt[k];
    end endgenerate
endmodule
`default_nettype wire
