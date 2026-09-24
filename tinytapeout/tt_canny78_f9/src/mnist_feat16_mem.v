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
module mnist_feat16_mem #(
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
    // NO hay bus paralelo de salida. Sacar los 128 contadores a la vez obliga a
    // que sean registros: una memoria tiene UN puerto de lectura. En su lugar se
    // expone el puerto, y el clasificador lee de a uno cuando el cuadro termino.
    input  wire [6:0]      rd_a,           // que contador quiere el clasificador
    output reg  [CW-1:0]   rd_d,           // ...y su valor, un ciclo despues
    // VACIAR AL LEER. El histograma hay que ponerlo a cero entre cuadro y cuadro, y el bucle
    // de 128 ciclos de `borrando` NO CABE: desde `frame_done` hasta la primera posicion util
    // del cuadro siguiente hay 172 ciclos, y el trasvase ya se lleva 130. Pero el trasvase
    // LEE los 128 contadores uno por uno, asi que puede vaciarlos de paso, gratis y en el
    // mismo viaje. Es la misma idea que gobierna todo el diseno: aprovechar el viaje.
    input  wire            rd_clr,         // pone a cero el contador que se esta leyendo
    input  wire            reanuda,        // descongela el conteo (deja posicion y contadores)
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
    //   Con la tercera etapa del Canny son 3*(W+1) = 87 para W=28. NO 3*(W+2)=90: los dos
    //   ciclos del cauce interno de cada linebuf NO los cuenta `lat_cnt`, porque mientras el
    //   encadenado se llena `vc` esta baja y la guarda es `if (vc && !listo)`. El +2 se lo
    //   traga la propia ausencia de muestras validas; contarlo otra vez lo cuenta dos veces.
    //
    //   ESTO SE MIDIO, no se dedujo (23-sep): se barrio LATP de 84 a 92 volcando el mapa de
    //   bordes posicion por posicion y comparandolo con el golden. Encaje: 74.7 % a 84, 99.6 %
    //   a 87, y de vuelta a 75.1 % a 90. Con 87 y una pasada desde reset, 484/484 exactas en
    //   cinco imagenes.  Y LA TRAMPA, en la misma tabla: `n_bordes` -el TOTAL- coincidia
    //   perfecto a 90, 91 y 92, donde el mapa estaba PEOR. Un corrimiento no cambia la suma.
    //   El 3*(W+2) anterior venia justo de calibrar contra el total. Es la trampa que este
    //   mismo comentario advertia, y aun asi se cayo en ella.
    localparam integer LAT = (LATP != 0) ? LATP : 3*(W+1);   // MEDIDO: 87 para W=28
    reg [$clog2(LAT+1)-1:0] lat_cnt;
    wire arrancado = (lat_cnt == LAT);
    reg [$clog2(W)-1:0] cx;
    reg [$clog2(H)-1:0] cy;
    wire interior = (cy >= 3) && (cy <= H-4) && (cx >= 3) && (cx <= W-4);
    // 16 zonas (4x4) en vez de 4. Los cortes tienen que ser LOS MISMOS que los de
    // la piramide de Python, que trocea con zy*HV//4: para HV=22 salen en 5, 11 y 16.
    // Con division entera de Verilog, HV/4=5, 2*HV/4=11 y 3*HV/4=16. Coinciden.
    wire [4:0] vy = cy - 3, vx = cx - 3;
    wire [1:0] zy = {1'b0,(vy >= HV/4)} + {1'b0,(vy >= 2*HV/4)} + {1'b0,(vy >= 3*HV/4)};
    wire [1:0] zx = {1'b0,(vx >= WV/4)} + {1'b0,(vx >= 2*WV/4)} + {1'b0,(vx >= 3*WV/4)};
    wire [3:0] zona = {zy, zx};   // igual que Python: zona = zy*4 + zx
    wire ult_pix = (cy == H-4) && (cx == W-4);

    // ---------------- los 32 contadores ----------------
    // `listo` congela el histograma cuando termina el cuadro: sin el, frame_done vuelve a
    //   pulsar al envolver el raster y el clasificador correria con los contadores moviendose
    //   debajo. Cuesta UN flip-flop y evita latchear los 32 contadores (288 FF).
    reg listo;
    // `frame_done` NO se anuncia en el mismo flanco que `listo`, sino una muestra valida
    // despues, cuando el histograma ya esta CERRADO. Razon: el incremento del ultimo pixel
    // util se desagua en esa muestra, y el trasvase -que arranca con `frame_done`- vacia
    // cada casilla al leerla. Con los dos en el mismo ciclo pelean por el UNICO puerto de
    // escritura de la BRAM y uno de los dos se pierde. Con tiempo muerto entre pixeles la
    // pelea es segura, porque el trasvase corre a ritmo de reloj y el desague espera la
    // proxima muestra valida: medido el 23-sep, una casilla de menos en una imagen de cada
    // sesenta y cuatro a partir de GAP=4. No se anuncia un cuadro que aun se esta escribiendo.
    reg fd_pend;
    // Los 128 contadores en MEMORIA, no en registros. Con registros son 1545
    // biestables y un multiplexor por cada lectura; en BRAM son 17 LUT.
    // El incremento es lectura-modificacion-escritura: se lee en un ciclo y se
    // escribe en el siguiente, con PUENTE para el caso de dos pixeles seguidos
    // en la misma casilla, que si no perderia una cuenta.
    reg [CW-1:0] cnt [0:127];
    // Una BRAM no se borra entera en un ciclo: hay que recorrerla. Son 128 ciclos
    // al empezar el cuadro, y el extractor ya se traga 90 de latencia del pipeline,
    // asi que caben en el mismo hueco sin costar nada de tiempo util.
    reg        borrando;
    reg [6:0]  badr;
    reg [6:0]  q_dir;        // direccion leida el ciclo anterior
    reg        q_val;        // ...y si habia que incrementarla
    reg [CW-1:0] q_rd;       // el valor leido
    // el total NO se deriva sumando los 32 contadores -serian 32 sumandos de 9 bits-:
    // sale gratis llevando un contador aparte que sube con cada pixel contado.
    wire [6:0] dir = {zona, bin};
    // EL PUENTE. Al leer en un ciclo y escribir en el siguiente, la lectura del ciclo t no ve
    // la escritura que ocurre EN ESE MISMO flanco -la del pixel t-1-. Si los dos pixeles caen
    // en la misma casilla, la cuenta se pierde. Hay que comparar con LO QUE SE ESCRIBIO, no
    // con lo que viene:
    //
    //   La version anterior hacia `(q_val && q_dir == dir) ? q_rd+1 : q_rd`, o sea comparaba
    //   la casilla ya leida con la del pixel que ENTRA AHORA -mirando hacia adelante en vez
    //   de hacia atras- y le sumaba dos de golpe. Sobre una racha de tres o mas pixeles
    //   seguidos en la misma casilla -que es lo normal recorriendo un contorno- descontaba.
    //   Medido el 23-sep: 206 de 238 cuentas, con `n_bordes` perfecto. Otra vez el total
    //   tapando el error en la distribucion.
    reg [6:0]    p_dir;      // casilla escrita en el flanco anterior
    reg [CW-1:0] p_val;      // ...y el valor que se le escribio
    reg          p_en;
    wire [CW-1:0] base = (p_en && p_dir == q_dir) ? p_val : q_rd;
    wire [CW-1:0] inc  = base + 1'b1;

    // UN SOLO PUERTO DE ESCRITURA, con direccion y dato multiplexados. Son tres cosas las que
    // escriben en `cnt` -el borrado inicial, el incremento, y el vaciado al leer del trasvase-
    // y si cada una va en su propio `if`, yosys deja de inferir la BRAM y pone los 128
    // contadores en biestables. Medido el 23-sep, y no es un detalle: 4261 LUT4 y 7 BRAM con
    // tres escrituras sueltas, contra 2001 LUT4 y 9 BRAM con una sola multiplexada. Son 2260
    // LUT4, la mitad de la FPGA, por como esta ESCRITO y no por lo que hace. La BRAM de la
    // iCE40 tiene un puerto de escritura: hay que ofrecerle exactamente uno.
    wire cw_borra = vc && borrando;
    wire cw_inc   = vc && arrancado && !borrando && q_val && (base != {CW{1'b1}});
    wire cw_en    = rd_clr | cw_borra | cw_inc;
    wire [6:0]    cw_a = rd_clr ? rd_a : cw_borra ? badr : q_dir;
    wire [CW-1:0] cw_d = (rd_clr | cw_borra) ? {CW{1'b0}} : inc;
    integer i;
    always @(posedge clk) if (cw_en) cnt[cw_a] <= cw_d;
    always @(posedge clk) rd_d <= cnt[rd_a];   // puerto del clasificador

    always @(posedge clk) begin
        if (reset || clr) begin
            cx <= 0; cy <= 0; lat_cnt <= 0; frame_done <= 1'b0; listo <= 1'b0; n_bordes <= 11'd0;
            q_dir <= 0; q_val <= 0; q_rd <= 0; borrando <= 1'b1; badr <= 7'd0;
            p_dir <= 0; p_val <= 0; p_en <= 1'b0; fd_pend <= 1'b0;
        end else begin
            frame_done <= 1'b0;
            // `reanuda` descongela SIN tocar cx/cy/lat_cnt. Eso es a proposito: una vez que la
            // posicion quedo alineada por el reset, se envuelve sola cada 784 muestras y sigue
            // alineada para siempre. Volver a ponerla a cero -que es lo que hace `clr`- obliga
            // a tragarse la latencia otra vez y DESALINEA el cuadro siguiente: medido el 23-sep,
            // el raster tras `clr` encajaba 317/484 contra 484/484 del primero.
            if (reanuda) begin
                listo <= 1'b0; n_bordes <= 11'd0; q_val <= 1'b0; p_en <= 1'b0; fd_pend <= 1'b0;
            end
            if (vc) begin
                // El borrado avanza TAMBIEN mientras se traga la latencia. Antes vivia dentro
                // del `else`, o sea que arrancaba DESPUES de los 87 ciclos y se comia las 35
                // primeras posiciones interiores (toda la fila cy=3 y media de la cy=4): sus
                // incrementos quedaban suprimidos por el `if (borrando)` que tiene prioridad.
                // Aca son 88 ciclos de latencia + las 84 posiciones de cabecera (cy<3, que no
                // son interior) = 172 huecos para 128 ciclos de borrado. El borrado termina en
                // la posicion 40 -cy=1-, muy antes de la primera posicion util.
                if (borrando) begin
                    if (badr == 7'd127) borrando <= 1'b0; else badr <= badr + 1'b1;
                end
                if (!arrancado) lat_cnt <= lat_cnt + 1'b1;   // tragarse la latencia
                else begin
                    // LA POSICION AVANZA SIEMPRE, tambien mientras el clasificador trabaja.
                    // Estaba dentro del `!listo`, asi que los 130 ciclos del trasvase
                    // congelaban el raster y el cuadro siguiente entraba 130 muestras
                    // corrido -y el siguiente 260, y asi-. El sintoma era limpio: el primer
                    // cuadro daba `n_bordes` exacto y del segundo en adelante no. Una vez
                    // alineada por el reset, la posicion se envuelve sola cada H*W muestras
                    // y se queda alineada para siempre; lo unico que hay que congelar es el
                    // histograma, para que el clasificador no lea con los contadores
                    // moviendose debajo.
                    if (cx == W-1) begin
                        cx <= 0;
                        cy <= (cy == H-1) ? 0 : cy + 1'b1;
                    end else cx <= cx + 1'b1;
                    if (ult_pix) begin listo <= 1'b1; fd_pend <= 1'b1; end   // congela
                    // ciclo 1: leer.  ciclo 2: escribir el incrementado.
                    if (!listo) begin
                        q_dir <= dir;
                        q_val <= es_borde && interior;
                        q_rd  <= cnt[dir];
                        if (es_borde && interior) n_bordes <= n_bordes + 11'd1;
                    end else begin
                        q_val <= 1'b0;        // deja de enclavar, pero no de escribir
                        // en ESTE flanco desagua el ultimo incremento: recien ahora el
                        // histograma esta cerrado y se puede avisar
                        if (fd_pend) begin frame_done <= 1'b1; fd_pend <= 1'b0; end
                    end
                    // LA ESCRITURA CORRE UN CICLO MAS QUE LA LECTURA, a proposito. El
                    // incremento del ULTIMO pixel util se enclava en `q_val` en el mismo
                    // flanco en que se levanta `listo`; si la escritura se congelara con
                    // `listo`, ese incremento no se escribiria nunca. Solo se nota cuando
                    // la esquina (H-4,W-4) resulta ser borde -una imagen de cada treinta y
                    // pico-, y se veia como UNA casilla de 128 con una cuenta de menos,
                    // siempre en la zona 15. `q_val <= 0` de arriba la desagua en un ciclo.
                    p_en <= 1'b0;
                    if (cw_inc) begin p_dir <= q_dir; p_val <= inc; p_en <= 1'b1; end
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
    // (el empaquetado de los 128 a un bus desaparece: era justo lo que lo impedia)
endmodule
`default_nettype wire
