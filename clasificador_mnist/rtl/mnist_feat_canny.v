// mnist_feat_canny.v — EXTRACTOR con front-end CANNY 1-SALTO en vez de umbral simple.
//
//   Es `mnist_feat.v` con una tercera etapa: doble umbral (clase 2/1/0) + histeresis de un salto.
//   Motivado por la §6 del cuaderno 2, donde se midio en simulacion que este front-end aguanta
//   +17 pp mejor la iluminacion despareja y -16 pp peor el ruido de sensor.
//
//   EL TRUCO DE LA TERCERA VENTANA: hace falta el vecindario 3x3 del mapa de CLASES, pero tambien
//   la orientacion del pixel CENTRAL de ese vecindario -que ya quedo tres etapas atras-. En vez de
//   agregar una linea de retardo aparte para la orientacion, viajan JUNTAS por el mismo
//   linebuf3x3, empaquetadas en 5 bits: {octante[2:0], clase[1:0]}. El tap central da las dos
//   cosas alineadas por construccion, y no hay forma de que se desincronicen.
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
module mnist_feat_canny #(
    parameter integer H   = 28,     // alto de la imagen de entrada
    parameter integer W   = 28,     // ancho
    parameter integer CW  = 9,      // bits por contador
    parameter integer LATP = 0      // 0 = usar 3*(W+2); >0 = forzar (para CALIBRAR)
)(
    input  wire            clk,
    input  wire            reset,          // sincrono, activo-alto: limpia TODO
    input  wire            clr,            // limpia solo histograma y posicion (deja los line-buffers)
    input  wire            in_valid,
    input  wire [7:0]      in_pix,
    input  wire [7:0]      thr_hi,         // umbral ALTO: borde fuerte
    input  wire [7:0]      thr_lo,         // umbral BAJO: borde debil (sobrevive si toca uno fuerte)
    output reg             frame_done,     // se conto el ultimo pixel util del cuadro
    output wire [32*CW-1:0] cnt_o,         // 4 cuadrantes x 8 orientaciones, empaquetados
    output reg  [10:0]      n_bordes,      // total de pixeles de borde del cuadro
    output wire             dbg_val,       // (diagnostico) hay muestra valida del pipeline
    output wire             dbg_borde,     // (diagnostico) esa muestra es borde
    output wire [4:0]       dbg_cx,
    output wire [4:0]       dbg_cy,
    output wire             dbg_arr,       // ya se trago la latencia
    output wire [7:0]       dbg_mag,       // (diag) magnitud |Gx|+|Gy| saturada
    output wire [1:0]       dbg_cls,       // (diag) clase del doble umbral
    output wire             dbg_vs,        // (diag) valida la etapa Sobel
    output wire             dbg_vc,        // (diag) valida la tercera ventana
    output wire [44:0]      dbg_win        // (diag) las 9 celdas de la tercera ventana
);
    localparam integer HV = H-6, WV = W-6;   // area valida tras TRES convoluciones 3x3

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
    wire [2:0]  bin_raw = {sgy, sgx, (agy > agx)};        // el octante, sin una sola multiplicacion

    // ---------------- etapa 3: doble umbral + histeresis de 1 salto ----------------
    wire [1:0] cls_in = (mag > thr_hi) ? 2'd2 : (mag > thr_lo) ? 2'd1 : 2'd0;
    wire vc;
    wire [4:0] c00,c01,c02,c10,c11,c12,c20,c21,c22;
    // viajan juntas la clase (bits 1:0) y la orientacion (bits 4:2)
    linebuf3x3 #(.W(W),.DW(5)) LBC (
        .clk(clk),.reset(reset),.in_valid(vs),.in_pix({bin_raw, cls_in}),.valid_o(vc),
        .w00(c00),.w01(c01),.w02(c02),.w10(c10),.w11(c11),.w12(c12),
        .w20(c20),.w21(c21),.w22(c22));
    wire any_strong = (c00[1:0]==2'd2)|(c01[1:0]==2'd2)|(c02[1:0]==2'd2)|(c10[1:0]==2'd2)|
                      (c12[1:0]==2'd2)|(c20[1:0]==2'd2)|(c21[1:0]==2'd2)|(c22[1:0]==2'd2);
    wire [1:0]  cen = c11[1:0];
    wire        es_borde = (cen == 2'd2) ? 1'b1 : (cen == 2'd1) ? any_strong : 1'b0;
    wire [2:0]  bin = c11[4:2];                          // la orientacion del MISMO pixel central

    // ---------------- posicion, y la latencia del pipeline ----------------
    //   El linebuf3x3 emite UNA salida por cada entrada: el raster de salida tiene la misma
    //   forma HxW que el de entrada, con basura en el borde. Cada etapa retrasa W+2 muestras:
    //   W+1 porque la ventana centrada en (r,c) recien esta cuando entro (r+1,c+1) -eso es lo
    //   que midio la Parte 168- MAS 2 por el pipeline interno del propio linebuf (etapa de
    //   lectura + etapa de ventana)... y de esos 2 solo se ve 1 en el indice de muestra.
    //   Son 3*(W+1) = 87 para W=28, y esto se MIDIO el 23-sep barriendo LATP y comparando el
    //   histograma CONTADOR POR CONTADOR con el golden. NO es 3*(W+2)=90, que es lo que decia
    //   antes: los dos ciclos del cauce interno de cada linebuf no los cuenta `lat_cnt`, porque
    //   mientras el encadenado se llena `vc` esta baja y la guarda es `if (vc && ...)`. El +2 se
    //   lo traga la propia ausencia de muestras validas; sumarlo lo cuenta dos veces.
    //
    //   La regla, comprobada en las dos profundidades: LAT = k*(W+1), con k el numero de
    //   ventanas 3x3 encadenadas. Dos etapas -> 58 (y no 60). Tres -> 87 (y no 90).
    //
    //   Y LA TRAMPA que dejo el valor viejo en su sitio tanto tiempo: `n_bordes`, el TOTAL,
    //   coincidia con el golden a 90, 91 y 92, justo donde la DISTRIBUCION estaba peor. Un
    //   corrimiento no cambia la suma. La calibracion vieja se hizo contra el total.
    localparam integer LAT = (LATP != 0) ? LATP : 3*(W+1);   // MEDIDO: 87 para W=28
    reg [$clog2(LAT+1)-1:0] lat_cnt;
    wire arrancado = (lat_cnt == LAT);
    reg [$clog2(W)-1:0] cx;
    reg [$clog2(H)-1:0] cy;
    wire interior = (cy >= 3) && (cy <= H-4) && (cx >= 3) && (cx <= W-4);
    wire [1:0] zona = {(cy-3) >= HV/2, (cx-3) >= WV/2};   // cuadrante sobre el area valida
    wire ult_pix = (cy == H-4) && (cx == W-4);

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
            if (vc && !listo) begin
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
    assign dbg_win   = {c22,c21,c20,c12,c11,c10,c02,c01,c00};
    assign dbg_mag   = mag;
    assign dbg_cls   = cls_in;
    assign dbg_vs    = vs;
    assign dbg_vc    = vc;
    assign dbg_val   = vc && !listo;
    assign dbg_borde = es_borde;
    assign dbg_cx    = cx;
    assign dbg_cy    = cy;
    assign dbg_arr   = arrancado;

    genvar k;
    generate for (k = 0; k < 32; k = k + 1) begin : sal
        assign cnt_o[k*CW +: CW] = cnt[k];
    end endgenerate
endmodule
`default_nettype wire
