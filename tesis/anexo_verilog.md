# Anexo G. Código Verilog

Este anexo reúne el código de los diseños de las §4.3 y §6.3. Los fuentes completos están ordenados por
diseño en el repositorio `Verilog_Repo`, una carpeta por circuito; cada carpeta lleva un `LEEME.md` con
el origen y la suma md5 de cada fichero, de modo que puede comprobarse que el texto impreso es el mismo
que se entregó al sintetizador o al flujo a silicio.

Se incluyen los módulos escritos para este trabajo. El núcleo del procesador, `femtorv32_quark.v`, es
de B. Levy [ref. 1] y se cita en lugar de reproducirse. En los listados, sólo las líneas de comentario
que no cabían en la página se han partido en dos; el código no se ha tocado, salvo en un sentido: las
líneas de código demasiado largas se parten entre dos sentencias, dos argumentos, dos sumandos o dos ramas de una condición, y los
comentarios al final de ellas suben a la línea anterior. En Verilog un salto de línea equivale a un
espacio, de modo que el circuito descrito es el mismo; se comprobó fichero por fichero, comparando el
código sin espacios ni comentarios. Por la misma razón pudieron tocarse los comentarios en un segundo
sentido: los que remitían a documentos internos de trabajo se retiraron, o se cambiaron por la sección
equivalente de esta tesis.

## G.1 Filtro Sobel (§4.3.1)

Es el circuito que la §5.2 lleva a silicio: 0,167 mm² en sky130. Recibe un flujo de píxeles en orden
de barrido, arma la ventana de 3×3 con `linebuf3x3` y decide borde o plano con un umbral. **La versión
para silicio omite el suavizado gaussiano** del Algoritmo 1: pasa de la ventana directamente al
gradiente, y su ancho de línea es de 60 píxeles.

Carpeta: `Verilog_Repo/sobel/`.

### `sobel_top.v`

```verilog
// sobel_top.v — Sobel de bordes AUTOCONTENIDO para ASIC (sky130).
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

## G.3 Filtro Canny Framebuffer Transitivo (§4.3.3)

Es el circuito `transitivo` de la §5.2: 3,13 mm² en sky130, el más grande de los tres filtros.
`trans_engine_top.v` sólo envuelve el motor; el trabajo lo hace `hysteresis_frame_bram_sync.sv`, una
máquina de estados que borra el cuadro, lo carga con la clase de cada píxel, lo barre hasta que un
barrido completo no cambia nada y lo lee. Una línea del segundo fichero, con varias sentencias, se ha
partido entre dos de ellas para que quepa en la página.

Carpeta: `Verilog_Repo/transitivo/`.

### `trans_engine_top.v`

```verilog
// trans_engine_top.v — MOTOR de histeresis TRANSITIVA (reconstruccion morfologica de
//   Canny)
// AUTOCONTENIDO para ASIC sky130. Envuelve hysteresis_frame_bram_sync al tamano 60x80
//   de la tesis.
// Entra un stream de CLASE (0=nada/1=debil/2=fuerte); el motor barre el frame en bucle
//   hasta el
// punto fijo (un debil sobrevive si toca un fuerte, transitivamente) y emite el mapa
//   de bordes.
// El "frame buffer" (padded 62x82 x 2 bits) en la iCE40 iba a SPRAM; en el ASIC NO hay
//   SPRAM ->
//   se vuelve FLIP-FLOPS. Es "la memoria ya no es gratis" en su forma extrema.
`default_nettype none
module trans_engine_top (
    input  wire       clk,
    input  wire       nreset,       // reset asincrono, activo-bajo (0=reset, 1=corre)
    input  wire       in_valid,     // carga: hay una clase valida este ciclo
    input  wire [1:0] class_in,     // 0 nada / 1 debil / 2 fuerte
    output wire       load_ready,   // el motor esta listo para recibir el stream de clase
    output wire       out_valid,    // emitiendo mapa de bordes
    output wire       edge_out,     // 1 = borde (tras la reconstruccion)
    output wire       done          // barrido terminado, frame emitido
);
    hysteresis_frame_bram_sync #(.H(80), .W(60)) ENG (
        .clk_i(clk), .nreset_i(nreset), .in_valid_i(in_valid), .class_i(class_in),
        .load_ready_o(load_ready), .out_valid_o(out_valid), .edge_o(edge_out), .done_o(done));
endmodule
`default_nettype wire
```

### `hysteresis_frame_bram_sync.sv`

```verilog
// =============================================================================
// hysteresis_frame_bram_sync.sv -- Histeresis TRANSITIVA de Canny, mapeable a BRAM.
//   Igual semantica que hysteresis_frame_bram.sv (verificado vs golden) pero con
//   LECTURA SINCRONA para que 'mem' infiera BRAM de verdad:
//     - 'mem' vive en un always @(posedge clk) SIN reset (la BRAM no se resetea;
//       para poner el frame a 0 esta la fase CLR). 1 escritura + 1 lectura por
//       ciclo -> BRAM de doble puerto simple.
//     - 'rdata <= mem[mem_ra]' -> el dato llega 1 ciclo despues de direccionar.
//
//   Ese 1 ciclo de latencia agrega una etapa de pipeline al barrido:
//     ra  -> (lee)      direcciona mem
//     a1  = ra retrasado 1 -> rdata (pixel entrante 'bot') corresponde a a1; se
//                             mete en la ventana (line buffers indexados por pcol1)
//     a2  = ra retrasado 2 -> la ventana ya esta formada; su centro es w4 =
//                             celda (a2 - PW - 1); ahi se calcula y ESCRIBE newc.
//   Frame PADDED (H+2 x W+2), borde=0 -> toda celda real tiene ventana 3x3 completa.
//   Escritura in-place = converge al MISMO punto fijo que el golden; termina cuando
//   un barrido no confirma nada ('changed'==0).
// =============================================================================
`default_nettype none
module hysteresis_frame_bram_sync #(
    parameter integer H = 12,
    parameter integer W = 12
)(
    input  wire       clk_i,
    input  wire       nreset_i,
    input  wire       in_valid_i,
    input  wire [1:0] class_i,        // 0 nada / 1 debil / 2 fuerte
    output wire       load_ready_o,
    output reg        out_valid_o,
    output reg        edge_o,
    output reg        done_o
);
    localparam integer PW = W + 2;
    localparam integer PH = H + 2;
    localparam integer N  = PW * PH;
    localparam integer AW = $clog2(N);
    localparam integer ROWSKIP = PW - W + 1;
    localparam integer NPIX = H * W;

    // ---------------- BRAM: 1 escritura + 1 lectura SINCRONA, sin reset ----------
    reg [1:0] mem [0:N-1];
    reg [1:0] rdata;
    reg [AW-1:0] mem_ra, mem_wa;
    reg          mem_we;
    reg [1:0]    mem_wd;
    always @(posedge clk_i) begin
        if (mem_we) mem[mem_wa] <= mem_wd;
        rdata <= mem[mem_ra];
    end

    // ---------------- line buffers + ventana (async, pequenos) -------------------
    reg [1:0] line1 [0:PW-1];
    reg [1:0] line2 [0:PW-1];
    reg [1:0] w0,w1,w2,w3,w4,w5,w6,w7,w8;

    localparam [2:0] S_CLR=0, S_LOAD=1, S_SWEEP=2, S_CHK=3, S_READ=4, S_DONE=5;
    reg [2:0]    state;
    reg [AW-1:0] addr;               // CLR / LOAD / READ: puntero
    reg [15:0]   rr, cc;
    reg          changed;
    // pipeline del barrido
    reg [AW-1:0] ra, a1, a2;
    reg [15:0]   prow, pcol, prow1, pcol1, prow2, pcol2;
    // pipeline de lectura de READ
    reg          iss;
    reg [15:0]   issue_cnt, emit_cnt;

    // centro de la ventana actual (w4 = celda a2 - PW - 1)
    wire conf_c = w4[0];
    wire weak_c = w4[1];
    wire nb8 = w0[0]|w1[0]|w2[0]|w3[0]|w5[0]|w6[0]|w7[0]|w8[0];
    wire newc = conf_c | (weak_c & nb8);
    wire center_valid2 = (prow2 >= 2) && (pcol2 >= 2);

    assign load_ready_o = (state == S_LOAD);

    // ---------------- control combinacional de la BRAM --------------------------
    always @* begin
        mem_we = 1'b0; mem_wa = {AW{1'b0}}; mem_wd = 2'b00; mem_ra = {AW{1'b0}};
        case (state)
            S_CLR:  begin mem_we = 1'b1;       mem_wa = addr; mem_wd = 2'b00; end
            S_LOAD: begin mem_we = in_valid_i; mem_wa = addr;
                          mem_wd = {class_i==2'd1, class_i==2'd2}; end
            S_SWEEP:begin mem_ra = ra;                       // leer pixel entrante
                          if (center_valid2) begin
                              mem_we = 1'b1; mem_wa = a2 - PW - 1; mem_wd = {weak_c, newc};
                          end end
            S_READ: begin mem_ra = addr; end                 // leer para emitir
            default: ;
        endcase
    end

    integer i;
    always @(posedge clk_i or negedge nreset_i) begin
        if (!nreset_i) begin
            state<=S_CLR; addr<=0; rr<=0; cc<=0; changed<=0;
            ra<=0; a1<=0; a2<=0; prow<=0; pcol<=0; prow1<=0; pcol1<=0; prow2<=0; pcol2<=0;
            iss<=0; issue_cnt<=0; emit_cnt<=0;
            w0<=0;w1<=0;w2<=0;w3<=0;w4<=0;w5<=0;w6<=0;w7<=0;w8<=0;
            out_valid_o<=0; edge_o<=0; done_o<=0;
        end else begin
            out_valid_o <= 1'b0;
            case (state)
            // ---- poner la RAM a 0 (incluye padding) ----
            S_CLR: begin
                if (addr==N-1) begin addr<=PW+1; rr<=0; cc<=0; state<=S_LOAD; end
                else addr<=addr+1'b1;
            end
            // ---- cargar el stream de clase en celdas interiores ----
            S_LOAD: if (in_valid_i) begin
                if (rr==H-1 && cc==W-1) begin
                    ra<=0; a1<=0; a2<=0; prow<=0; pcol<=0;
                    prow1<=0; pcol1<=0; prow2<=0; pcol2<=0; changed<=1'b0;
                    w0<=0;w1<=0;w2<=0;w3<=0;w4<=0;w5<=0;w6<=0;w7<=0;w8<=0;
                    state<=S_SWEEP;
                end else if (cc==W-1) begin
                    cc<=0; rr<=rr+1'b1; addr<=addr+ROWSKIP;
                end else begin
                    cc<=cc+1'b1; addr<=addr+1'b1;
                end
            end
            // ---- barrido con ventana deslizante + lectura sincrona (in-place) ----
            S_SWEEP: begin
                if (center_valid2 && (newc != conf_c)) changed <= 1'b1;
                // ventana con el pixel entrante rdata (coords a1 -> pcol1)
                w0<=w1; w1<=w2; w2<=line2[pcol1];
                w3<=w4; w4<=w5; w5<=line1[pcol1];
                w6<=w7; w7<=w8; w8<=rdata;
                line2[pcol1] <= line1[pcol1];
                line1[pcol1] <= rdata;
                // avanzar el pipeline de latencia
                a1<=ra;  prow1<=prow;  pcol1<=pcol;
                a2<=a1;  prow2<=prow1;  pcol2<=pcol1;
                // avanzar lectura (drenar hasta procesar el ultimo centro a2==N-1)
                if (a2 == N-1) begin
                    state <= S_CHK;
                end else if (ra != N-1) begin
                    if (pcol==PW-1) begin pcol<=0; prow<=prow+1'b1; end
                    else pcol<=pcol+1'b1;
                    ra <= ra + 1'b1;
                end
            end
            // ---- otro barrido si cambio; si no -> leer ----
            S_CHK: begin
                ra<=0; a1<=0; a2<=0; prow<=0; pcol<=0; prow1<=0; pcol1<=0; prow2<=0; pcol2<=0;
                w0<=0;w1<=0;w2<=0;w3<=0;w4<=0;w5<=0;w6<=0;w7<=0;w8<=0;
                if (changed) begin changed<=1'b0; state<=S_SWEEP; end
                else begin addr<=PW+1; rr<=0; cc<=0; iss<=0; issue_cnt<=0; emit_cnt<=0;
                    state<=S_READ; end
            end
            // ---- emitir el mapa de bordes (lectura sincrona, salida +1 ciclo) ----
            S_READ: begin
                out_valid_o <= iss;
                edge_o      <= rdata[0];
                if (iss) emit_cnt <= emit_cnt + 1'b1;
                if (issue_cnt < NPIX) begin
                    iss <= 1'b1; issue_cnt <= issue_cnt + 1'b1;
                    if (cc==W-1) begin cc<=0; rr<=rr+1'b1; addr<=addr+ROWSKIP; end
                    else begin cc<=cc+1'b1; addr<=addr+1'b1; end
                end else begin
                    iss <= 1'b0;
                end
                if (iss && emit_cnt==NPIX-1) state <= S_DONE;
            end
            S_DONE: done_o <= 1'b1;
            endcase
        end
    end
endmodule
`default_nettype wire
```

## G.4 SoC Femto con filtro Sobel (§4.3.4)

Es el circuito `soc_sobel` de la §5.2: 0,37 mm² en sky130. `soc_sobel_top.v` reúne el FemtoRV32, la ROM
de siete instrucciones, el periférico y el Sobel; el programa está escrito en la propia ROM, con cada
instrucción comentada. `peripheral_filter.v` es el periférico de control en `0x0045`, el mismo que usan
los otros dos SoC. El núcleo `femtorv32_quark.v` es de Levy [ref. 1] y no se reproduce; `linebuf3x3.v`
está en el Anexo G.1. Una línea de `soc_sobel_top.v` con dos sentencias se ha partido entre ellas.

Carpeta: `Verilog_Repo/soc_sobel/`.

### `soc_sobel_top.v`

```verilog
// soc_sobel_top.v — SoC femto (FemtoRV32 + ROM + periferico + Sobel) AUTOCONTENIDO
//   para ASIC sky130.
// El CPU corre un firmware de 7 instrucciones que elige Sobel y fija el umbral
//   (thr=90) escribiendo
// el periferico 0x0045; el datapath Sobel usa ESE umbral (no cableado). Sin
//   camara/display/LED.
// CLAVE ASIC: el programa va en una ROM SINTETIZADA (permanente), no en RAM init'd
//   (que en silicio
// arrancaria aleatoria). El firmware no usa RAM de datos -> no hace falta RAM
//   writable.
`default_nettype none
module soc_sobel_top (
    input  wire       clk,
    input  wire       resetn,        // 0 = reset, 1 = corre
    input  wire       in_valid,
    input  wire [7:0] in_pix,
    output reg        out_valid,
    output reg  [7:0] out_pix,       // FF=borde / 00=plano
    output wire       cpu_wrote_filter,
    output wire [7:0] thr_o          // el umbral que fijo el CPU (observabilidad)
);
    // ---------------- CPU FemtoRV32 ----------------
    wire [31:0] mem_addr, mem_wdata; wire [3:0] mem_wmask; wire mem_rstrb;
    reg  [31:0] mem_rdata;
    FemtoRV32 CPU (
        .clk(clk), .reset(resetn),
        .mem_addr(mem_addr), .mem_wdata(mem_wdata), .mem_wmask(mem_wmask),
        .mem_rdata(mem_rdata), .mem_rstrb(mem_rstrb), .mem_rbusy(1'b0), .mem_wbusy(1'b0));
    wire cpu_wr = |mem_wmask;
    wire cpu_rd = mem_rstrb;
    wire cs_filter = (mem_addr[31:16] == 16'h0045);

    // ---------------- ROM de programa (7 instrucciones, lectura sincrona)
    //   ----------------
    reg [31:0] rom_q;
    always @(posedge clk) begin
        case (mem_addr[4:2])
            3'd0: rom_q <= 32'h004500b7;  // lui  x1,0x450
            3'd1: rom_q <= 32'h01000113;  // addi x2,x0,16
            3'd2: rom_q <= 32'h0020a023;  // sw   x2,0(x1)   -> mode=Sobel, enable
            3'd3: rom_q <= 32'h000061b7;  // lui  x3,0x6
            3'd4: rom_q <= 32'ha0018193;  // addi x3,x3,-1536 -> x3=0x5A00
            3'd5: rom_q <= 32'h0030a223;  // sw   x3,4(x1)   -> thr_hi=90
            3'd6: rom_q <= 32'h0000006f;  // jal  x0,0       -> loop
            default: rom_q <= 32'h00000013; // NOP (addi x0,x0,0)
        endcase
    end

    // ---------------- periferico del filtro ----------------
    wire [1:0] flt_mode; wire flt_enable, flt_engrst;
    wire [7:0] flt_thi, flt_tlo; wire [31:0] filt_dout;
    peripheral_filter PER (
        .clk(clk), .reset(~resetn),
        .d_in(mem_wdata), .cs(cs_filter), .addr(mem_addr[4:0]), .rd(cpu_rd), .wr(cpu_wr),
        .d_out(filt_dout),
        .mode(flt_mode), .enable(flt_enable), .eng_reset(flt_engrst),
        .thr_hi(flt_thi), .thr_lo(flt_tlo),
        .cfg_done(1'b1), .eng_busy(1'b0), .vsync_alive(1'b1), .frame_count(16'd0));
    assign thr_o = flt_thi;

    // mux de lectura del bus: periferico o ROM
    always @(*) mem_rdata = cs_filter ? filt_dout : rom_q;

    reg wrote = 1'b0;
    always @(posedge clk) if (!resetn) wrote <= 1'b0;
        else if (cs_filter && cpu_wr) wrote <= 1'b1;
    assign cpu_wrote_filter = wrote;

    // ---------------- datapath Sobel (stream externo, mismo reloj) ----------------
    wire vin;
    wire [7:0] w00,w01,w02, w10,w11,w12, w20,w21,w22;
    linebuf3x3 #(.W(60), .DW(8)) LB (
        .clk(clk), .in_valid(in_valid), .in_pix(in_pix), .valid_o(vin),
        .w00(w00),.w01(w01),.w02(w02), .w10(w10),.w11(w11),.w12(w12),
        .w20(w20),.w21(w21),.w22(w22));
    wire [10:0] gxp = w02 + (w12<<1) + w22;
    wire [10:0] gxn = w00 + (w10<<1) + w20;
    wire [10:0] gyp = w20 + (w21<<1) + w22;
    wire [10:0] gyn = w00 + (w01<<1) + w02;
    wire [10:0] agx = (gxp>=gxn) ? (gxp-gxn) : (gxn-gxp);
    wire [10:0] agy = (gyp>=gyn) ? (gyp-gyn) : (gyn-gyp);
    wire [11:0] mag12 = agx + agy;
    wire [7:0]  mag = (mag12 > 12'd255) ? 8'd255 : mag12[7:0];

    always @(posedge clk) begin
        if (!resetn) begin out_valid <= 1'b0; out_pix <= 8'd0; end
        else begin
            out_valid <= vin;
            out_pix   <= (mag > flt_thi) ? 8'hFF : 8'h00;   // umbral puesto por el CPU
        end
    end
endmodule
`default_nettype wire
```

### `peripheral_filter.v`

```verilog
// peripheral_filter.v — periferico de CONTROL/ESTADO del filtro de imagen para el
// SoC femto2 (FemtoRV32). Sigue el MISMO patron de bus que peripheral_mult/uart:
//   (clk, reset, d_in, cs, addr, rd, wr, d_out).
//
// FILOSOFIA: los pixeles NO pasan por el bus del CPU (serian demasiados). El camino
// de imagen es en streaming: camara -> filter_core -> LCD. Este periferico solo
// EXPONE al CPU un puñado de registros para elegir el filtro EN VIVO y leer estado.
//
// Mapa de registros (base 0x0045_0000, offset = addr):
//   0x00  CTRL  (W): [1:0] mode (0=Sobel, 1=Canny1-salto, 2=Canny transitivo)
//                    [4]   enable        [5] eng_reset (pulso al motor transitivo)
//   0x04  THR   (W): [7:0] thr_lo        [15:8] thr_hi   (doble umbral)
//   0x08  STAT  (R): [0] cfg_done  [1] eng_busy  [2] vsync_alive  [23:8] frame_count
module peripheral_filter (
    input             clk,
    input             reset,
    input      [31:0] d_in,
    input             cs,
    input      [4:0]  addr,
    input             rd,
    input             wr,
    output reg [31:0] d_out,
    // ---- hacia/desde el datapath de imagen (dominio de la camara/pantalla) ----
    output reg [1:0]  mode,          // filtro activo
    output reg        enable,
    output reg        eng_reset,     // pulso de reset al motor transitivo
    output reg [7:0]  thr_hi,
    output reg [7:0]  thr_lo,
    input             cfg_done,      // SCCB configurado (LED verde)
    input             eng_busy,      // motor transitivo barriendo
    input             vsync_alive,   // llegan cuadros de la camara
    input      [15:0] frame_count
);
    // ------------------ escritura de registros ------------------
    always @(posedge clk) begin
        if (reset) begin
            mode <= 2'd0; enable <= 1'b1; eng_reset <= 1'b0;
            thr_hi <= 8'd110; thr_lo <= 8'd70;      // arranque = Canny transitivo tipico
        end else begin
            eng_reset <= 1'b0;                       // auto-limpia (pulso de 1 ciclo)
            if (cs && wr) case (addr)
                5'h00: begin mode <= d_in[1:0]; enable <= d_in[4]; eng_reset <= d_in[5]; end
                5'h04: begin thr_lo <= d_in[7:0]; thr_hi <= d_in[15:8]; end
                default: ;
            endcase
        end
    end
    // ------------------ lectura de registros ------------------
    always @(*) begin
        d_out = 32'd0;
        if (cs && rd) case (addr)
            5'h00: d_out = {26'd0, eng_reset, enable, 2'b00, mode};
            5'h04: d_out = {16'd0, thr_hi, thr_lo};
            5'h08: d_out = {8'd0, frame_count, 5'd0, vsync_alive, eng_busy, cfg_done};
            default: d_out = 32'd0;
        endcase
    end
endmodule
```

## G.5 SoC Femto con filtro Canny 1-streaming (§4.3.5)

Es el circuito `soc_canny1` de la §5.2: 0,67 mm² en sky130. Tiene la misma estructura que el de la G.4;
cambian el filtro y dos constantes del programa, que elige el Canny y escribe sus dos umbrales. El
periférico `peripheral_filter.v` es idéntico al de la G.4 y no se repite. Una línea con dos sentencias
se ha partido entre ellas.

Carpeta: `Verilog_Repo/soc_canny1/`.

### `soc_canny1_top.v`

```verilog
// soc_canny1_top.v — SoC femto (FemtoRV32 + ROM + periferico + Canny 1-salto)
//   AUTOCONTENIDO para ASIC sky130.
// El CPU corre un firmware de 7 instrucciones que elige Canny1 y fija LOS DOS umbrales
// (thr_hi=90, thr_lo=40) escribiendo el periferico 0x0045; el datapath Canny1 usa ESOS
//   umbrales (no cableados). Sin camara/display/LED.
// CLAVE ASIC: el programa va en una ROM SINTETIZADA (permanente), no en RAM init'd
//   (que en
// silicio arrancaria aleatoria). El firmware no usa RAM de datos -> no hace falta RAM
//   writable.
// El SoC con el datapath Canny (Gaussian->Sobel->doble
//   umbral->histeresis).
`default_nettype none
module soc_canny1_top (
    input  wire       clk,
    input  wire       resetn,        // 0 = reset, 1 = corre
    input  wire       in_valid,
    input  wire [7:0] in_pix,
    output reg        out_valid,
    output reg  [7:0] out_pix,       // FF=borde / 00=plano
    output wire       cpu_wrote_filter,
    output wire [7:0] thr_hi_o,      // umbral alto que fijo el CPU (observabilidad)
    output wire [7:0] thr_lo_o       // umbral bajo que fijo el CPU (observabilidad)
);
    // ---------------- CPU FemtoRV32 ----------------
    wire [31:0] mem_addr, mem_wdata; wire [3:0] mem_wmask; wire mem_rstrb;
    reg  [31:0] mem_rdata;
    FemtoRV32 CPU (
        .clk(clk), .reset(resetn),
        .mem_addr(mem_addr), .mem_wdata(mem_wdata), .mem_wmask(mem_wmask),
        .mem_rdata(mem_rdata), .mem_rstrb(mem_rstrb), .mem_rbusy(1'b0), .mem_wbusy(1'b0));
    wire cpu_wr = |mem_wmask;
    wire cpu_rd = mem_rstrb;
    wire cs_filter = (mem_addr[31:16] == 16'h0045);

    // ---------------- ROM de programa (7 instrucciones, lectura sincrona)
    //   ----------------
    reg [31:0] rom_q;
    always @(posedge clk) begin
        case (mem_addr[4:2])
            3'd0: rom_q <= 32'h004500b7;  // lui  x1,0x450
            3'd1: rom_q <= 32'h01100113;  // addi x2,x0,17    -> mode=Canny1(1), enable
            3'd2: rom_q <= 32'h0020a023;  // sw   x2,0(x1)    -> CTRL = 0x11
            3'd3: rom_q <= 32'h000061b7;  // lui  x3,0x6
            3'd4: rom_q <= 32'ha2818193;  // addi x3,x3,-1496 -> x3=0x5A28
            3'd5: rom_q <= 32'h0030a223;  // sw   x3,4(x1)    -> THR: thr_hi=90, thr_lo=40
            3'd6: rom_q <= 32'h0000006f;  // jal  x0,0        -> loop
            default: rom_q <= 32'h00000013; // NOP (addi x0,x0,0)
        endcase
    end

    // ---------------- periferico del filtro ----------------
    wire [1:0] flt_mode; wire flt_enable, flt_engrst;
    wire [7:0] flt_thi, flt_tlo; wire [31:0] filt_dout;
    peripheral_filter PER (
        .clk(clk), .reset(~resetn),
        .d_in(mem_wdata), .cs(cs_filter), .addr(mem_addr[4:0]), .rd(cpu_rd), .wr(cpu_wr),
        .d_out(filt_dout),
        .mode(flt_mode), .enable(flt_enable), .eng_reset(flt_engrst),
        .thr_hi(flt_thi), .thr_lo(flt_tlo),
        .cfg_done(1'b1), .eng_busy(1'b0), .vsync_alive(1'b1), .frame_count(16'd0));
    assign thr_hi_o = flt_thi;
    assign thr_lo_o = flt_tlo;

    // mux de lectura del bus: periferico o ROM
    always @(*) mem_rdata = cs_filter ? filt_dout : rom_q;

    reg wrote = 1'b0;
    always @(posedge clk) if (!resetn) wrote <= 1'b0;
        else if (cs_filter && cpu_wr) wrote <= 1'b1;
    assign cpu_wrote_filter = wrote;

    // ================= datapath Canny 1-salto (stream externo, mismo reloj)
    //   =================
    // etapa 1: Gaussian 3x3
    wire vg;
    wire [7:0] gw00,gw01,gw02,gw10,gw11,gw12,gw20,gw21,gw22;
    linebuf3x3 #(.W(60),.DW(8)) LBG (
        .clk(clk),.in_valid(in_valid),.in_pix(in_pix),.valid_o(vg),
        .w00(gw00),.w01(gw01),.w02(gw02),.w10(gw10),.w11(gw11),.w12(gw12),
        .w20(gw20),.w21(gw21),.w22(gw22));
    wire [11:0] gsum = gw00+(gw01<<1)+gw02 + (gw10<<1)+(gw11<<2)+(gw12<<1) + gw20+(gw21<<1)+gw22;
    wire [7:0]  gout = gsum[11:4];   // /16

    // etapa 2: Sobel 3x3 sobre la Gaussiana
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
    wire [1:0]  cls_in = (mag>flt_thi)?2'd2 : (mag>flt_tlo)?2'd1 : 2'd0;  // doble umbral del CPU

    // etapa 3: clase (line-buffer DW=2) -> histeresis 1-salto
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
        if (!resetn) begin out_valid <= 1'b0; out_pix <= 8'd0; end
        else begin
            out_valid <= vc;
            out_pix   <= edge_1hop ? 8'hFF : 8'h00;
        end
    end
endmodule
`default_nettype wire
```

## G.6 SoC Femto con filtro Canny Framebuffer Transitivo (§4.3.6)

Es el circuito `soc_trans` de la §5.2: 3,42 mm² en sky130. Tiene la misma estructura que los otros dos
SoC, con el motor transitivo en lugar del filtro en flujo; el programa elige el modo 2 y escribe los
umbrales 110 y 70. El motor (`trans_engine_top.v` y `hysteresis_frame_bram_sync.sv`) es el de la G.3, y
el periférico, el de la G.4. Una línea con dos sentencias se ha partido entre ellas.

Carpeta: `Verilog_Repo/soc_trans/`.

### `soc_trans_top.v`

```verilog
// soc_trans_top.v — SoC femto (FemtoRV32 + ROM + periferico + MOTOR TRANSITIVO) para
//   ASIC sky130.
// Un CPU RISC-V junto al motor de histeresis TRANSITIVA (reconstruccion
//   morfologica),
// cuyo framebuffer padded 62x82x2b se vuelve ~10 600 FLIP-FLOPS en silicio (no hay
//   SPRAM en el ASIC).
// El CPU corre un firmware de 7 instrucciones que elige el modo transitivo (mode=2) y
//   fija los dos
// umbrales (thr_hi=110, thr_lo=70) escribiendo el periferico 0x0045 (observabilidad /
//   config).
// El motor consume un stream externo de CLASE (0=nada/1=debil/2=fuerte) y, tras barrer
//   el frame hasta
// el punto fijo, emite el mapa de bordes (out_valid/edge_out/done). El periferico ve
//   'eng_busy' (~done)
//   para que el CPU pudiera sondear el estado.
// CLAVE ASIC: el programa va en ROM SINTETIZADA (permanente); en silicio los FF
//   arrancan aleatorios.
`default_nettype none
module soc_trans_top (
    input  wire       clk,
    input  wire       resetn,        // 0 = reset, 1 = corre
    input  wire       in_valid,      // hay una clase valida este ciclo (carga)
    input  wire [1:0] class_in,      // 0 nada / 1 debil / 2 fuerte
    output wire       load_ready,    // el motor esta listo para recibir el stream
    output wire       out_valid,     // emitiendo mapa de bordes
    output wire       edge_out,      // 1 = borde tras la reconstruccion
    output wire       done,          // barrido terminado
    output wire       cpu_wrote_filter,
    output wire [7:0] thr_hi_o,      // umbral alto que fijo el CPU (observabilidad)
    output wire [7:0] thr_lo_o,      // umbral bajo que fijo el CPU (observabilidad)
    output wire [1:0] mode_o         // modo elegido por el CPU (debe ser 2 = transitivo)
);
    // ---------------- CPU FemtoRV32 ----------------
    wire [31:0] mem_addr, mem_wdata; wire [3:0] mem_wmask; wire mem_rstrb;
    reg  [31:0] mem_rdata;
    FemtoRV32 CPU (
        .clk(clk), .reset(resetn),
        .mem_addr(mem_addr), .mem_wdata(mem_wdata), .mem_wmask(mem_wmask),
        .mem_rdata(mem_rdata), .mem_rstrb(mem_rstrb), .mem_rbusy(1'b0), .mem_wbusy(1'b0));
    wire cpu_wr = |mem_wmask;
    wire cpu_rd = mem_rstrb;
    wire cs_filter = (mem_addr[31:16] == 16'h0045);

    // ---------------- ROM de programa (7 instrucciones, lectura sincrona)
    //   ----------------
    reg [31:0] rom_q;
    always @(posedge clk) begin
        case (mem_addr[4:2])
            3'd0: rom_q <= 32'h004500b7;  // lui  x1,0x450
            3'd1: rom_q <= 32'h01200113;  // addi x2,x0,18   -> mode=transitivo(2), enable
            3'd2: rom_q <= 32'h0020a023;  // sw   x2,0(x1)   -> CTRL = 0x12
            3'd3: rom_q <= 32'h000071b7;  // lui  x3,0x7
            3'd4: rom_q <= 32'he4618193;  // addi x3,x3,-442 -> x3=0x6E46
            3'd5: rom_q <= 32'h0030a223;  // sw   x3,4(x1)   -> THR: thr_hi=110, thr_lo=70
            3'd6: rom_q <= 32'h0000006f;  // jal  x0,0       -> loop
            default: rom_q <= 32'h00000013; // NOP
        endcase
    end

    // ---------------- motor transitivo (stream externo de clase, mismo reloj)
    //   ----------------
    wire eng_done;
    trans_engine_top ENG (
        .clk(clk), .nreset(resetn),
        .in_valid(in_valid), .class_in(class_in),
        .load_ready(load_ready), .out_valid(out_valid), .edge_out(edge_out), .done(eng_done));
    assign done = eng_done;

    // ---------------- periferico del filtro ----------------
    wire [1:0] flt_mode; wire flt_enable, flt_engrst;
    wire [7:0] flt_thi, flt_tlo; wire [31:0] filt_dout;
    peripheral_filter PER (
        .clk(clk), .reset(~resetn),
        .d_in(mem_wdata), .cs(cs_filter), .addr(mem_addr[4:0]), .rd(cpu_rd), .wr(cpu_wr),
        .d_out(filt_dout),
        .mode(flt_mode), .enable(flt_enable), .eng_reset(flt_engrst),
        .thr_hi(flt_thi), .thr_lo(flt_tlo),
        .cfg_done(1'b1), .eng_busy(~eng_done), .vsync_alive(1'b1), .frame_count(16'd0));
    assign thr_hi_o = flt_thi;
    assign thr_lo_o = flt_tlo;
    assign mode_o   = flt_mode;

    // mux de lectura del bus: periferico o ROM
    always @(*) mem_rdata = cs_filter ? filt_dout : rom_q;

    reg wrote = 1'b0;
    always @(posedge clk) if (!resetn) wrote <= 1'b0;
        else if (cs_filter && cpu_wr) wrote <= 1'b1;
    assign cpu_wrote_filter = wrote;
endmodule
`default_nettype wire
```

## G.7 Sobel completo (§4.3.7)

Es el circuito `sobel_completo`, el primero de la §5.3: 2,45 mm² en sky130. `sobel_completo.v` conecta el
front-end de cámara, el Sobel de la G.1, el framebuffer de 60×80 bits y el controlador de pantalla. Los
bloques de interfaz —las cuatro piezas del front-end y el controlador de la ILI9341— son los mismos que
usan las demás cadenas completas y los sistemas de visión, y sólo se reproducen aquí.

Carpeta: `Verilog_Repo/completos/sobel_completo/`.

### `sobel_completo.v`

```verilog
// sobel_completo.v — LA CADENA DE VISION COMPLETA en un chip, pieza a pieza (sin CPU),
//   para ASIC sky130.
//   camara OV7670 --> [cam_frontend_top: SCCB + captura + CDC + RGB565->gris]
//                 --> [sobel_top: Sobel 3x3, umbral fijo]
// --> [framebuffer 60x80] (puente stream->pantalla; guarda bordes binarios)
//                 --> [lcd_ili9341_top: SPI + ROM ILI9341] --> PMOD TFTLCD
// Ensamblado con los MODULOS reusables ya verificados. UN SOLO RELOJ
//   (clk): el
// front-end sincroniza PCLK/HREF/VSYNC con 2-FF internos (§4.2), asi que no hay
//   dual-clock.
`default_nettype none
module sobel_completo (
    input  wire       clk,
    input  wire       rst_n,
    // ---- camara OV7670 ----
    input  wire [7:0] cam_d,
    input  wire       cam_pclk,
    input  wire       cam_href,
    input  wire       cam_vsync,
    output wire       cam_xclk,
    output wire       cam_sioc,
    output wire       cam_siod_o,
    output wire       cam_siod_oe,
    // ---- display PMOD TFTLCD ----
    output wire       tft_sck,
    output wire       tft_mosi,
    output wire       tft_cs,
    output wire       tft_dc,
    // ---- estado ----
    output wire       cfg_done,
    output wire       init_done
);
    // ===== 1) FRONT-END: camara -> stream de gris (dominio clk) =====
    wire [7:0] gray; wire gray_valid, fe_frame_start, fe_line_start;
    cam_frontend_top u_fe (
        .sysclk(clk), .rst_n(rst_n),
        .cam_d(cam_d), .cam_pclk(cam_pclk), .cam_href(cam_href), .cam_vsync(cam_vsync),
        .cam_xclk(cam_xclk), .cam_sioc(cam_sioc), .cam_siod_o(cam_siod_o),
            .cam_siod_oe(cam_siod_oe),
        .gray(gray), .gray_valid(gray_valid), .frame_start(fe_frame_start),
            .line_start(fe_line_start),
        .cfg_done(cfg_done));

    // ===== 2) FILTRO: Sobel 3x3 (umbral fijo 90) =====
    wire sob_v; wire [7:0] sob_p;
    sobel_top u_sob (
        .clk(clk), .reset(~rst_n),
        .in_valid(gray_valid), .in_pix(gray), .thr(8'd90),
        .out_valid(sob_v), .out_pix(sob_p));

    // ===== 3) FRAMEBUFFER 60x80 (bordes binarios -> 1 bit/pixel EXPLICITO) =====
    // El Sobel entrega 0xFF/0x00, asi que basta 1 bit por pixel: 4800 flops (no 38400)
    // y el mux de lectura queda 8x mas angosto -> muchisima menos congestion de ruteo.
    reg fb [0:4799];
    reg [12:0] wadr;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) wadr <= 13'd0;
        else if (fe_frame_start) wadr <= 13'd0;                 // alinear con el cuadro
        else if (sob_v) begin
            // 0xFF->1 (borde) / 0x00->0 (plano)
            fb[wadr] <= sob_p[7];
            wadr <= (wadr == 13'd4799) ? 13'd0 : wadr + 1'b1;
        end
    end

    // ===== 4) generador de direccion de lectura para el LCD (240x320 -> escala a
    //   60x80) =====
    wire lcd_next, lcd_fs;
    reg [7:0] xcol; reg [8:0] ycol;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin xcol <= 8'd0; ycol <= 9'd0; end
        else if (lcd_fs) begin xcol <= 8'd0; ycol <= 9'd0; end
        else if (lcd_next) begin
            if (xcol == 8'd239) begin xcol <= 8'd0; ycol <= (ycol==9'd319)?9'd0:ycol+1'b1; end
            else xcol <= xcol + 1'b1;
        end
    end
    wire [6:0] fx = xcol[7:2];
    wire [6:0] fy = ycol[8:2];
    wire [13:0] raddr = fy*60 + fx;
    reg fb_rd_bit;
    always @(posedge clk) fb_rd_bit <= fb[raddr[12:0]];        // lee 1 bit
    wire [7:0] fb_rd = fb_rd_bit ? 8'hFF : 8'h00;              // expande a 8 bits para el LCD

    // ===== 5) LCD DRIVER: pinta el framebuffer por SPI =====
    lcd_ili9341_top u_lcd (
        .clk(clk), .rst_n(rst_n),
        .pix_gray(fb_rd), .pix_next(lcd_next), .frame_start(lcd_fs), .init_done(init_done),
        .tft_sck(tft_sck), .tft_mosi(tft_mosi), .tft_cs(tft_cs), .tft_dc(tft_dc));

    wire _unused = &{fe_line_start, 1'b0};
endmodule
`default_nettype wire
```

### `cam_frontend_top.v`

```verilog
// cam_frontend_top.v — FRONT-END de la OV7670 AUTOCONTENIDO para ASIC sky130.
// Une las 3 piezas verificadas en FPGA: SCCB (config) + captura (PCLK/HREF/VSYNC/D7:0
//   -> RGB565,
// con sincronizadores 2-FF = CDC) + RGB565->gris. Entrega un STREAM DE GRIS
//   (gray/gray_valid)
// listo para cualquiera de los 6 filtros. La salida SCCB open-drain se parte en
//   dato+enable
//   (siod_o/siod_oe): el tri-state vive en el anillo de I/O.
`default_nettype none
module cam_frontend_top #(
    parameter integer SYSCLK_HZ = 48_000_000,
    parameter integer XCLK_HZ   = 12_000_000
)(
    input  wire       sysclk,        // reloj del sistema (dominio del core)
    input  wire       rst_n,         // reset asincrono activo-bajo
    // ---- pines de la camara OV7670 ----
    input  wire [7:0] cam_d,         // D7..D0
    input  wire       cam_pclk,      // reloj de pixel (entra; se sincroniza -> CDC)
    input  wire       cam_href,      // linea valida
    input  wire       cam_vsync,     // inicio de cuadro
    output wire       cam_xclk,      // reloj que el chip da a la camara
    output wire       cam_sioc,      // SCCB clock
    output wire       cam_siod_o,    // SCCB data (open-drain: dato)
    // SCCB data (open-drain: enable) -> el pad hace el tri-state
    output wire       cam_siod_oe,
    // ---- stream de gris (dominio del core) ----
    output wire [7:0] gray,
    output wire       gray_valid,
    output wire       frame_start,
    output wire       line_start,
    output wire       cfg_done
);
    // 1) SCCB: configura la camara al arrancar (start atado a 1)
    ov7670_sccb #(.SYSCLK_HZ(SYSCLK_HZ)) u_sccb (
        .clk(sysclk), .rst_n(rst_n), .start(1'b1),
        .sioc(cam_sioc), .siod_o(cam_siod_o), .siod_oe(cam_siod_oe),
        .done(cfg_done), .dbg_reg());

    // 2) captura PCLK/HREF/VSYNC/D -> RGB565 (con sincronizadores = CDC hacia sysclk)
    wire [15:0] px565; wire px_valid;
    ov7670_capture #(.SYSCLK_HZ(SYSCLK_HZ), .XCLK_HZ(XCLK_HZ)) u_cap (
        .sysclk(sysclk), .rst_n(rst_n),
        .cam_d(cam_d), .cam_pclk(cam_pclk), .cam_href(cam_href), .cam_vsync(cam_vsync),
        .cam_xclk(cam_xclk),
        .pixel_rgb565(px565), .pixel_valid(px_valid),
        .frame_start(frame_start), .line_start(line_start));

    // 3) RGB565 -> gris 8 bits
    rgb565_to_gray u_gray (.rgb565(px565), .gray(gray));
    assign gray_valid = px_valid;
endmodule
`default_nettype wire
```

### `ov7670_sccb.v`

```verilog
// ov7670_sccb.v (VARIANTE ASIC) — identico al SCCB verificado en FPGA, PERO la salida
//   open-drain se parte en dato+enable (siod_o / siod_oe) en vez de 1'bz. En el ASIC el
// tri-state vive en el ANILLO DE I/O (el pad hace: pad = siod_oe ? siod_o : Z).
`default_nettype none
module ov7670_sccb #(
    parameter integer SYSCLK_HZ = 12_000_000,
    parameter integer SCCB_HZ   = 100_000,
    parameter [7:0]   CAM_ADDR  = 8'h42,
    parameter integer NREGS     = 5
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       start,
    output reg        sioc,
    output wire       siod_o,      // dato SCCB (en open-drain siempre 0 cuando activo)
    // 1 = maneja 0 ; 0 = suelta (el pad -> Z, pull-up externo -> 1)
    output wire       siod_oe,
    output reg        done,
    output reg [7:0]  dbg_reg
);
    function [15:0] rom(input [7:0] i);
        case (i)
            8'd0: rom = 16'h12_14;   // COM7  : QVGA + RGB
            8'd1: rom = 16'h40_d0;   // COM15 : RGB565, rango full
            8'd2: rom = 16'h11_01;   // CLKRC : prescaler de reloj
            8'd3: rom = 16'h0C_04;   // COM3  : enable scaling
            8'd4: rom = 16'h3E_19;   // COM14 : divide para QQVGA
            default: rom = 16'h0000;
        endcase
    endfunction

    localparam integer DIV = SYSCLK_HZ / (4 * SCCB_HZ);
    reg [15:0] div_cnt;
    wire tick = (div_cnt == DIV[15:0] - 1);
    always @(posedge clk or negedge rst_n)
        if (!rst_n) div_cnt <= 16'd0;
        else        div_cnt <= tick ? 16'd0 : div_cnt + 16'd1;

    reg armed;
    always @(posedge clk or negedge rst_n)
        if (!rst_n)                 armed <= 1'b0;
        else if (start)             armed <= 1'b1;
        else if (sioc == 1'b0)      armed <= armed;

    reg siod_low;                    // 1 => maneja 0 ; 0 => suelta
    assign siod_o  = 1'b0;           // open-drain: el dato manejado es siempre 0
    assign siod_oe = siod_low;       // el enable decide 0 vs Z (el tri-state va en el pad)

    localparam [2:0] S_IDLE=0, S_START=1, S_BIT=2, S_STOP=3, S_DELAY=4, S_DONE=5;
    reg [2:0] state;
    reg [1:0] q;
    reg [3:0] bitc;
    reg [1:0] bytec;
    reg [7:0] regc;

    wire [15:0] cur      = rom(regc);
    wire [7:0]  byte_sel = (bytec == 2'd0) ? CAM_ADDR :
                           (bytec == 2'd1) ? cur[15:8] : cur[7:0];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state<=S_IDLE; sioc<=1'b1; siod_low<=1'b0; done<=1'b0;
            q<=0; bitc<=0; bytec<=0; regc<=0; dbg_reg<=0;
        end else if (tick) begin
            case (state)
            S_IDLE: begin
                sioc<=1'b1; siod_low<=1'b0; done<=1'b0;
                if (armed) begin
                    regc<=0; bytec<=0; bitc<=0; q<=0; dbg_reg<=cur[15:8];
                    state<=S_START;
                end
            end
            S_START: begin
                case (q)
                    2'd0: begin siod_low<=1'b0; sioc<=1'b1; end
                    2'd1: begin siod_low<=1'b1; sioc<=1'b1; end
                    2'd2: begin siod_low<=1'b1; sioc<=1'b0; end
                    2'd3: begin bytec<=0; bitc<=0; state<=S_BIT; end
                endcase
                q<=q+2'd1;
            end
            S_BIT: begin
                case (q)
                    2'd0: begin sioc<=1'b0;
                                if (bitc<=4'd7) siod_low <= ~byte_sel[7-bitc[2:0]];
                                else            siod_low <= 1'b0;
                          end
                    2'd1: sioc<=1'b1;
                    2'd2: sioc<=1'b1;
                    2'd3: begin sioc<=1'b0;
                                if (bitc==4'd8) begin
                                    if (bytec==2'd2) state<=S_STOP;
                                    else begin bytec<=bytec+2'd1; bitc<=0; end
                                end else bitc<=bitc+4'd1;
                          end
                endcase
                q<=q+2'd1;
            end
            S_STOP: begin
                case (q)
                    2'd0: begin siod_low<=1'b1; sioc<=1'b0; end
                    2'd1: begin siod_low<=1'b1; sioc<=1'b1; end
                    2'd2: begin siod_low<=1'b0; sioc<=1'b1; end
                    2'd3: state<=S_DELAY;
                endcase
                q<=q+2'd1;
            end
            S_DELAY: begin
                sioc<=1'b1; siod_low<=1'b0;
                if (q==2'd3) begin
                    if (regc==NREGS-1) state<=S_DONE;
                    else begin regc<=regc+8'd1; dbg_reg<=rom(regc+8'd1) >> 8; state<=S_START; end
                end
                q<=q+2'd1;
            end
            S_DONE: done<=1'b1;
            endcase
        end
    end
endmodule
`default_nettype wire
```

### `ov7670_capture.v`

```verilog
// ============================================================================
// ov7670_capture.v
//
// Captura de la camara OV7670 para el SoC femto2 (esta tesis).
// Tarjeta:      iCESugar v1.5  (Lattice iCE40UP5K-SG48)
// Conexion:     PMOD2 = datos de pixel D[7:0],  PMOD3 = relojes/sincronismo/SCCB
//
// Lo que hace este modulo:
//   1) Genera XCLK (~24 MHz) para la OV7670.
//   2) Sincroniza PCLK/HREF/VSYNC al dominio sysclk de la FPGA.
//   3) Captura un byte de pixel en cada flanco de subida de PCLK mientras HREF=1.
//   4) Junta dos bytes consecutivos en un pixel RGB565 de 16 bits.
//   5) Emite los pulsos frame_start / line_start para sincronizar lo que sigue.
//
// Lo que NO hace (va en otros modulos):
//   - el maestro SCCB (parecido a I2C) que configura la camara al arrancar
//     -> en cores/camera/ov7670_sccb.v
//   - guardar lineas o copiarlas por DMA a la RAM para que las lea el femto2
//     -> es trabajo de quien consume el flujo
//
// Verilog-2001, escrito para leerse como ejemplo didactico.
// ============================================================================

`default_nettype none

module ov7670_capture #(
    parameter integer SYSCLK_HZ = 48_000_000,   // reloj del sistema de la FPGA (Hz)
    parameter integer XCLK_HZ   = 24_000_000    // XCLK deseado para la camara (Hz)
) (
    // -------- Reloj y reinicio --------
    input  wire        sysclk,                 // reloj del sistema (>= 2 * PCLK)
    input  wire        rst_n,                  // reinicio activo en bajo

    // -------- Pines de la OV7670 (cruzan el PMOD) --------
    input  wire [7:0]  cam_d,                  // byte de pixel     (PMOD2)
    input  wire        cam_pclk,               // reloj de pixel    (PMOD3, entrada)
    input  wire        cam_href,               // linea valida      (PMOD3, entrada)
    input  wire        cam_vsync,              // sincronismo de cuadro (PMOD3, entrada)
    output wire        cam_xclk,               // reloj que genera la FPGA (PMOD3, salida, ~24 MHz)

    // -------- Flujo de pixeles de salida (dominio sysclk) --------
    output reg  [15:0] pixel_rgb565,           // pixel RGB565 de 16 bits
    output reg         pixel_valid,            // pulso de 1 ciclo cuando pixel_rgb565 es nuevo
    output reg         frame_start,            // pulso al comienzo de cada cuadro
    output reg         line_start              // pulso al comienzo de cada linea
);

    // ========================================================================
    // 1) Generador de XCLK: divide sysclk hasta ~XCLK_HZ
    // ------------------------------------------------------------------------
    // Para menos fluctuacion conviene el PLL de la iCE40UP5K (SB_PLL40_PAD); este
    // divisor con contador basta para la OV7670 (tolera un XCLK amplio).
    // ========================================================================
    localparam integer DIVIDER = (SYSCLK_HZ / (2 * XCLK_HZ));   // conmuta cada DIVIDER ciclos
    reg [15:0] xclk_cnt;
    reg        xclk_r;
    always @(posedge sysclk or negedge rst_n) begin
        if (!rst_n) begin
            xclk_cnt <= 16'd0;
            xclk_r   <= 1'b0;
        end else if (xclk_cnt == DIVIDER[15:0] - 1) begin
            xclk_cnt <= 16'd0;
            xclk_r   <= ~xclk_r;
        end else begin
            xclk_cnt <= xclk_cnt + 16'd1;
        end
    end
    assign cam_xclk = xclk_r;

    // ========================================================================
    // 2) Sincronizadores de 2 FF para las entradas de la camara, que llegan como asincronas
    //    (PCLK sale de cam_xclk, pero vuelve a traves de la camara y el cable:
    //     se trata como asincrono y se sincroniza.)
    // ========================================================================
    reg [1:0] pclk_s, href_s, vsync_s;
    always @(posedge sysclk or negedge rst_n) begin
        if (!rst_n) begin
            pclk_s  <= 2'b00;
            href_s  <= 2'b00;
            vsync_s <= 2'b00;
        end else begin
            pclk_s  <= {pclk_s [0], cam_pclk };
            href_s  <= {href_s [0], cam_href };
            vsync_s <= {vsync_s[0], cam_vsync};
        end
    end
    wire pclk_now  = pclk_s [1];
    wire href_now  = href_s [1];
    wire vsync_now = vsync_s[1];

    // Deteccion de flancos: se guarda el valor anterior y se compara con el actual.
    reg pclk_prev, href_prev, vsync_prev;
    always @(posedge sysclk or negedge rst_n) begin
        if (!rst_n) begin
            pclk_prev  <= 1'b0;
            href_prev  <= 1'b0;
            vsync_prev <= 1'b0;
        end else begin
            pclk_prev  <= pclk_now;
            href_prev  <= href_now;
            vsync_prev <= vsync_now;
        end
    end
    wire pclk_rising  =  pclk_now  & ~pclk_prev;
    wire href_rising  =  href_now  & ~href_prev;
    wire vsync_rising =  vsync_now & ~vsync_prev;

    // ========================================================================
    // 3) Captura de bytes y union de cada par en un pixel RGB565
    //    La OV7670 envia cada pixel RGB565 de 16 bits como dos bytes seguidos:
    //        byte 0 (alto) = { R[4:0] , G[5:3] }
    //        byte 1 (bajo) = { G[2:0] , B[4:0] }
    //    Se realinea al comienzo de cada linea con href_rising.
    // ========================================================================
    reg       byte_phase;     // 0 -> espera el byte alto ; 1 -> espera el byte bajo
    reg [7:0] upper_byte;

    always @(posedge sysclk or negedge rst_n) begin
        if (!rst_n) begin
            byte_phase   <= 1'b0;
            upper_byte   <= 8'h00;
            pixel_rgb565 <= 16'h0000;
            pixel_valid  <= 1'b0;
            frame_start  <= 1'b0;
            line_start   <= 1'b0;
        end else begin
            // Por defecto, los pulsos de salida duran un ciclo.
            pixel_valid <= 1'b0;
            frame_start <= vsync_rising;
            line_start  <= href_rising;

            // Realinear al comienzo de cada linea para no partir nunca un pixel.
            if (href_rising)
                byte_phase <= 1'b0;

            // Muestrear el dato en el flanco de subida de PCLK mientras la linea esta activa.
            if (pclk_rising && href_now) begin
                if (byte_phase == 1'b0) begin
                    upper_byte <= cam_d;
                end else begin
                    pixel_rgb565 <= {upper_byte, cam_d};
                    pixel_valid  <= 1'b1;
                end
                byte_phase <= ~byte_phase;
            end
        end
    end

endmodule

`default_nettype wire
```

### `rgb565_to_gray.v`

```verilog
// ============================================================================
// rgb565_to_gray.v
// Convierte un pixel RGB565 (el que sale de ov7670_capture) a gris de 8 bits.
// Luma aproximada SIN multiplicar (como en el chip de Maldonado, solo sumas y shifts):
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
```

### `lcd_ili9341_top.v`

```verilog
// lcd_ili9341_top.v — DRIVER del PMOD TFTLCD (ILI9341, SPI) AUTOCONTENIDO para ASIC
//   sky130.
// El otro extremo de la cadena: toma un STREAM de pixeles en gris (pix_gray, con
//   handshake pix_next)
// y lo pinta en la pantalla por SPI. Hace: (1) delay de arranque, (2) secuencia de
//   INIT del ILI9341,
// (3) por cada cuadro CASET/RASET/RAMWR, (4) FILL: 240x320 pixeles RGB565 (2 bytes
//   c/u).
// Logica de SPI + ROM de comandos reusada del driver verificado en FPGA
//   (cam_femto_display.v).
//
//   DECISIONES ASIC (para la tesis):
// - SIN framebuffer interno: los pixeles vienen de AFUERA (del filtro). La memoria se
//   queda fuera
// -> el driver es "pegamento" barato. Handshake: pix_next pulsa cuando consume un
//   pixel.
// - RESET EXPLICITO: el original usaba valores `initial` (valen en FPGA por el
//   bitstream, NO en ASIC
//     donde los FF arrancan aleatorios). Aqui todo el estado se inicializa con rst_n.
//   - gris -> RGB565 en grises: {g[7:3], g[7:2], g[7:3]}.
`default_nettype none
module lcd_ili9341_top #(
    parameter integer BOOT_DELAY = 1_800_000,   // ~36 ms @50MHz (reset del ILI9341)
    parameter integer NPIX       = 76800        // 240 x 320
)(
    input  wire       clk,
    input  wire       rst_n,          // reset asincrono activo-bajo (ASIC: obligatorio)
    // ---- stream de pixeles desde el filtro (upstream) ----
    input  wire [7:0] pix_gray,       // pixel actual (gris); debe mantenerse hasta pix_next
    output reg        pix_next,       // pulso 1 ciclo: consumi un pixel, dame el siguiente
    output reg        frame_start,    // pulso: empieza un cuadro (upstream resetea su direccion)
    output wire       init_done,      // 1 = ILI9341 ya inicializado
    // ---- pines del PMOD TFTLCD (SPI) ----
    output reg        tft_sck,
    output reg        tft_mosi,
    output reg        tft_cs,
    output reg        tft_dc
);
    // ============ shifter SPI (modo 0, MSB primero) ============
    reg        spi_start, spi_dcbit, spi_done;
    reg  [7:0] spi_byte;
    localparam S_IDLE=2'd0, S_LO=2'd1, S_HI=2'd2, S_END=2'd3;
    reg [1:0] sst;
    reg [2:0] sbit;
    reg [7:0] sbuf;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sst<=S_IDLE; sbit<=3'd0; sbuf<=8'd0; spi_done<=1'b0;
            tft_sck<=1'b0; tft_mosi<=1'b0; tft_cs<=1'b1; tft_dc<=1'b1;
        end else begin
            spi_done <= 1'b0;
            case (sst)
                S_IDLE: if (spi_start) begin tft_cs<=1'b0; tft_dc<=spi_dcbit; sbuf<=spi_byte;
                    sbit<=3'd0; tft_sck<=1'b0; sst<=S_LO; end
                S_LO:  begin tft_sck<=1'b0; tft_mosi<=sbuf[7]; sst<=S_HI; end
                S_HI:  begin tft_sck<=1'b1; sbuf<={sbuf[6:0],1'b0};
                             if (sbit==3'd7) sst<=S_END; else begin sbit<=sbit+1'b1;
                                 sst<=S_LO; end end
                S_END: begin tft_sck<=1'b0; spi_done<=1'b1; sst<=S_IDLE; end
            endcase
        end
    end

    // ============ ROM de comandos (INIT + FRAME) ============
    localparam T_CMD=2'd0, T_DAT=2'd1, T_DLY=2'd2, T_END=2'd3;
    localparam M_BOOT=2'd0, M_INIT=2'd1, M_FRAME=2'd2, M_FILL=2'd3;
    reg [1:0] dmode;
    reg [4:0] ip;
    reg [1:0] rt; reg [7:0] rb;
    always @(*) begin
        rt=T_END; rb=8'h00;
        if (dmode==M_INIT) case (ip)
            5'd0: begin rt=T_CMD; rb=8'h01; end   // SW reset
            5'd1: begin rt=T_DLY; rb=8'h00; end
            5'd2: begin rt=T_CMD; rb=8'h11; end   // sleep out
            5'd3: begin rt=T_DLY; rb=8'h00; end
            5'd4: begin rt=T_CMD; rb=8'h3A; end   // pixel format
            5'd5: begin rt=T_DAT; rb=8'h55; end   //   RGB565
            5'd6: begin rt=T_CMD; rb=8'h36; end   // MADCTL
            5'd7: begin rt=T_DAT; rb=8'h48; end
            5'd8: begin rt=T_CMD; rb=8'h29; end   // display ON
            default: begin rt=T_END; rb=8'h00; end
        endcase
        else case (ip)                            // M_FRAME: ventana + RAMWR
            5'd0:  begin rt=T_CMD; rb=8'h2A; end   // CASET
            5'd1:  begin rt=T_DAT; rb=8'h00; end
            5'd2:  begin rt=T_DAT; rb=8'h00; end
            5'd3:  begin rt=T_DAT; rb=8'h00; end
            5'd4:  begin rt=T_DAT; rb=8'hEF; end   //   239
            5'd5:  begin rt=T_CMD; rb=8'h2B; end   // RASET
            5'd6:  begin rt=T_DAT; rb=8'h00; end
            5'd7:  begin rt=T_DAT; rb=8'h00; end
            5'd8:  begin rt=T_DAT; rb=8'h01; end
            5'd9:  begin rt=T_DAT; rb=8'h3F; end   //   319
            5'd10: begin rt=T_CMD; rb=8'h2C; end   // RAMWR
            default: begin rt=T_END; rb=8'h00; end
        endcase
    end

    // ============ FSM de display ============
    reg [20:0] dcnt;
    reg [16:0] px;
    reg        pxhi;
    reg        sending;
    reg [15:0] pcolor_l;
    wire [15:0] pcolor_w = {pix_gray[7:3], pix_gray[7:2], pix_gray[7:3]}; // gris -> RGB565

    assign init_done = (dmode==M_FRAME) || (dmode==M_FILL);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dmode<=M_BOOT; ip<=5'd0; dcnt<=21'd0; px<=17'd0; pxhi<=1'b0; sending<=1'b0;
            spi_start<=1'b0; spi_byte<=8'd0; spi_dcbit<=1'b1; pix_next<=1'b0;
                frame_start<=1'b0; pcolor_l<=16'd0;
        end else begin
            spi_start   <= 1'b0;
            pix_next    <= 1'b0;
            frame_start <= 1'b0;
            case (dmode)
            M_BOOT: begin
                dcnt <= dcnt + 1'b1;
                if (dcnt == BOOT_DELAY[20:0]) begin dcnt<=21'd0; dmode<=M_INIT; ip<=5'd0; end
            end
            M_INIT: begin
                if (!sending) begin
                    case (rt)
                        T_CMD,T_DAT: begin spi_byte<=rb; spi_dcbit<=(rt==T_DAT);
                            spi_start<=1'b1; sending<=1'b1; end
                        T_DLY: if (dcnt==BOOT_DELAY[20:0]) begin dcnt<=21'd0; ip<=ip+1'b1;
                            end else dcnt<=dcnt+1'b1;
                        default: begin dmode<=M_FRAME; ip<=5'd0; end
                    endcase
                end else if (spi_done) begin sending<=1'b0; ip<=ip+1'b1; end
            end
            M_FRAME: begin
                if (!sending) begin
                    case (rt)
                        T_CMD,T_DAT: begin spi_byte<=rb; spi_dcbit<=(rt==T_DAT);
                            spi_start<=1'b1; sending<=1'b1; end
                        default: begin dmode<=M_FILL; px<=17'd0; pxhi<=1'b0;
                            frame_start<=1'b1; end
                    endcase
                end else if (spi_done) begin sending<=1'b0; ip<=ip+1'b1; end
            end
            M_FILL: begin
                if (!sending) begin
                    if (!pxhi) begin pcolor_l<=pcolor_w; spi_byte<=pcolor_w[15:8]; end
                    else                                  spi_byte<=pcolor_l[7:0];
                    spi_dcbit<=1'b1; spi_start<=1'b1; sending<=1'b1;
                end else if (spi_done) begin
                    sending<=1'b0;
                    if (pxhi) begin
                        // pixel completo -> pide el siguiente
                        pxhi<=1'b0; pix_next<=1'b1;
                        if (px==NPIX[16:0]-17'd1) begin px<=17'd0; dmode<=M_FRAME; ip<=5'd0; end
                        else px<=px+1'b1;
                    end else pxhi<=1'b1;
                end
            end
            endcase
        end
    end
endmodule
`default_nettype wire
```

## G.8 Canny 1-streaming completo (§4.3.8)

Es el circuito `canny1_completo`, el segundo de la §5.3: 2,90 mm² en sky130. `canny1_completo.v` conecta el
front-end de cámara, el Canny de un salto de la G.2, el framebuffer de 60×80 bits y el controlador de
pantalla. Los bloques de interfaz son idénticos a los de la G.7 y no se repiten.

Carpeta: `Verilog_Repo/completos/canny1_completo/`.

### `canny1_completo.v`

```verilog
// canny1_completo.v — LA CADENA DE VISION COMPLETA con Canny 1-salto (streaming), sin
//   CPU, para ASIC sky130.
//   camara OV7670 --> [cam_frontend_top: SCCB + captura + CDC + RGB565->gris]
// --> [canny1_top: Gaussian 3x3 -> Sobel 3x3 -> doble umbral -> histeresis 1-salto]
// --> [framebuffer 60x80, 1 bit/pixel] (puente stream->pantalla; bordes binarios)
//                 --> [lcd_ili9341_top: SPI + ROM ILI9341] --> PMOD TFTLCD
// Misma receta ganadora del sobel_completo (framebuffer de 1 bit). UN SOLO RELOJ
//   (clk): el front-end
// sincroniza PCLK/HREF/VSYNC con 2-FF internos (§4.2), asi que no hay dual-clock.
`default_nettype none
module canny1_completo (
    input  wire       clk,
    input  wire       rst_n,
    // ---- camara OV7670 ----
    input  wire [7:0] cam_d,
    input  wire       cam_pclk,
    input  wire       cam_href,
    input  wire       cam_vsync,
    output wire       cam_xclk,
    output wire       cam_sioc,
    output wire       cam_siod_o,
    output wire       cam_siod_oe,
    // ---- display PMOD TFTLCD ----
    output wire       tft_sck,
    output wire       tft_mosi,
    output wire       tft_cs,
    output wire       tft_dc,
    // ---- estado ----
    output wire       cfg_done,
    output wire       init_done
);
    // ===== 1) FRONT-END: camara -> stream de gris (dominio clk) =====
    wire [7:0] gray; wire gray_valid, fe_frame_start, fe_line_start;
    cam_frontend_top u_fe (
        .sysclk(clk), .rst_n(rst_n),
        .cam_d(cam_d), .cam_pclk(cam_pclk), .cam_href(cam_href), .cam_vsync(cam_vsync),
        .cam_xclk(cam_xclk), .cam_sioc(cam_sioc), .cam_siod_o(cam_siod_o),
            .cam_siod_oe(cam_siod_oe),
        .gray(gray), .gray_valid(gray_valid), .frame_start(fe_frame_start),
            .line_start(fe_line_start),
        .cfg_done(cfg_done));

    // ===== 2) FILTRO: Canny 1-salto (streaming), doble umbral fijo =====
    wire can_v; wire [7:0] can_p;
    canny1_top u_can (
        .clk(clk), .reset(~rst_n),
        .in_valid(gray_valid), .in_pix(gray), .thr_hi(8'd90), .thr_lo(8'd40),
        .out_valid(can_v), .out_pix(can_p));

    // ===== 3) FRAMEBUFFER 60x80, 1 bit/pixel (bordes binarios) =====
    // Canny1 entrega 0xFF/0x00 -> basta 1 bit: 4800 flops (no 38400) y mux de lectura
    //   8x mas angosto.
    reg fb [0:4799];
    reg [12:0] wadr;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) wadr <= 13'd0;
        else if (fe_frame_start) wadr <= 13'd0;                 // alinear con el cuadro
        else if (can_v) begin
            // 0xFF->1 (borde) / 0x00->0 (plano)
            fb[wadr] <= can_p[7];
            wadr <= (wadr == 13'd4799) ? 13'd0 : wadr + 1'b1;
        end
    end

    // ===== 4) generador de direccion de lectura para el LCD (240x320 -> escala a
    //   60x80) =====
    wire lcd_next, lcd_fs;
    reg [7:0] xcol; reg [8:0] ycol;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin xcol <= 8'd0; ycol <= 9'd0; end
        else if (lcd_fs) begin xcol <= 8'd0; ycol <= 9'd0; end
        else if (lcd_next) begin
            if (xcol == 8'd239) begin xcol <= 8'd0; ycol <= (ycol==9'd319)?9'd0:ycol+1'b1; end
            else xcol <= xcol + 1'b1;
        end
    end
    wire [6:0] fx = xcol[7:2];
    wire [6:0] fy = ycol[8:2];
    wire [13:0] raddr = fy*60 + fx;
    reg fb_rd_bit;
    always @(posedge clk) fb_rd_bit <= fb[raddr[12:0]];        // lee 1 bit
    wire [7:0] fb_rd = fb_rd_bit ? 8'hFF : 8'h00;              // expande a 8 bits para el LCD

    // ===== 5) LCD DRIVER: pinta el framebuffer por SPI =====
    lcd_ili9341_top u_lcd (
        .clk(clk), .rst_n(rst_n),
        .pix_gray(fb_rd), .pix_next(lcd_next), .frame_start(lcd_fs), .init_done(init_done),
        .tft_sck(tft_sck), .tft_mosi(tft_mosi), .tft_cs(tft_cs), .tft_dc(tft_dc));

    wire _unused = &{fe_line_start, 1'b0};
endmodule
`default_nettype wire
```

## G.9 Visión Sobel (§4.3.9)

Es el circuito `vision_top` de la §5.2: 1,75 mm² en sky130. Todo el sistema está en un fichero,
portado de `cam_sobel_display.v`, el diseño que funcionaba en la FPGA; la cabecera enumera los tres
cambios que exigió el silicio.

Carpeta: `Verilog_Repo/vision_top/`.

### `vision_top.v`

```verilog
// vision_top.v — EL CHIP QUE VE Y MUESTRA, integrado para ASIC sky130 ("todo
//   en el ASIC").
// camara OV7670 -> SCCB config -> submuestreo 60x80 -> SOBEL 3x3 -> framebuffer ->
//   display ILI9341.
//   Portado del diseno FISICO verificado en FPGA (cam_sobel_display.v). 3 cambios ASIC:
// (1) RESET EXPLICITO (rst_n) en los FSM de control -> los FF arrancan aleatorios en
//   silicio.
// (2) cam_sda open-drain (inout, 1'bz) partido en cam_sda_o/cam_sda_oe -> el tri-state
//   va al pad ring.
//     (3) sin SB_RGBA_DRV (LEDs, primitiva iCE40).
// DUAL-CLOCK: SCCB+display en 'clk'; captura+Sobel+escritura del framebuffer en
//   'cam_pclk'.
// El framebuffer (60x80 x 8b = 38 400 FF) NO se resetea (se llena antes de leerse) —
//   como el transitivo.
`default_nettype none
module vision_top (
    input  wire       clk,
    input  wire       rst_n,
    // ---- camara OV7670 ----
    output wire       cam_xclk,
    output reg        cam_scl,
    output wire       cam_sda_o,     // open-drain: dato (siempre 0 cuando activo)
    output wire       cam_sda_oe,    // open-drain: enable -> el pad hace el tri-state
    input  wire       cam_pclk,
    input  wire       cam_href,
    input  wire [7:0] cam_d,
    // ---- display PMOD TFTLCD ----
    output wire       tft_sck,
    output wire       tft_mosi,
    output wire       tft_cs,
    output wire       tft_dc,
    // ---- estado ----
    output reg        cfg_done
);
    assign cam_xclk = clk;

    // ==================== SCCB config (dominio clk) ====================
    reg sda_oe;
    assign cam_sda_o  = 1'b0;
    assign cam_sda_oe = sda_oe;

    reg [5:0] tdiv;
    wire tick = (tdiv == 6'd29);
    always @(posedge clk or negedge rst_n)
        if (!rst_n) tdiv <= 6'd0; else tdiv <= tick ? 6'd0 : tdiv + 1'b1;

    reg [4:0] idx;
    reg [15:0] rom;
    always @(*) case (idx)
        5'd0:  rom = 16'h12_00;
        5'd1:  rom = 16'h13_E7;
        5'd2:  rom = 16'h09_18;
        default: rom = 16'hFF_FF;
    endcase
    wire       tbl_end  = (rom == 16'hFF_FF);
    wire [7:0] reg_addr = rom[15:8];
    wire [7:0] reg_val  = rom[7:0];

    localparam C_START=3'd0, C_WR=3'd1, C_STOP=3'd2, C_DLY=3'd3, C_NEXT=3'd4;
    reg [2:0] cpc;
    reg [1:0] cph;
    reg [3:0] cbi;
    reg [15:0] cdly;

    reg [2:0] coptype;
    always @(*) case (cpc)
        3'd0: coptype=C_START; 3'd1: coptype=C_WR; 3'd2: coptype=C_WR;
        3'd3: coptype=C_WR;    3'd4: coptype=C_STOP; 3'd5: coptype=C_DLY;
        default: coptype=C_NEXT;
    endcase
    reg [7:0] cwbyte;
    always @(*) case (cpc)
        3'd1: cwbyte=8'h42; 3'd2: cwbyte=reg_addr; 3'd3: cwbyte=reg_val;
        default: cwbyte=8'h00;
    endcase

    reg [19:0] cboot;
    wire cboot_ok = &cboot;
    always @(posedge clk or negedge rst_n)
        if (!rst_n) cboot <= 20'd0; else if (!cboot_ok) cboot <= cboot + 1'b1;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sda_oe<=1'b0; cam_scl<=1'b1; cpc<=3'd0; cph<=2'd0; cbi<=4'd0; cdly<=16'd0;
            cfg_done<=1'b0; idx<=5'd0;
        end else if (tick && cboot_ok && !cfg_done) begin
            case (coptype)
            C_START: begin
                if (tbl_end) cfg_done <= 1'b1;
                else begin
                    case (cph)
                        2'd0: begin sda_oe<=1'b0; cam_scl<=1'b1; end
                        2'd1: begin sda_oe<=1'b1; cam_scl<=1'b1; end
                        2'd2: cam_scl<=1'b0;
                        2'd3: cpc<=cpc+1'b1;
                    endcase
                    cph <= cph + 1'b1;
                end
            end
            C_WR: begin
                case (cph)
                    2'd0: begin cam_scl<=1'b0; if (cbi<4'd8) sda_oe<=~cwbyte[3'd7-cbi[2:0]];
                        else sda_oe<=1'b0; end
                    2'd1: cam_scl<=1'b1; 2'd2: cam_scl<=1'b1;
                    2'd3: begin cam_scl<=1'b0; if (cbi==4'd8) begin cbi<=4'd0; cpc<=cpc+1'b1;
                        end else cbi<=cbi+1'b1; end
                endcase
                cph <= cph + 1'b1;
            end
            C_STOP: begin
                case (cph)
                    2'd0: begin cam_scl<=1'b0; sda_oe<=1'b1; end
                    2'd1: begin cam_scl<=1'b1; sda_oe<=1'b1; end
                    2'd2: begin cam_scl<=1'b1; sda_oe<=1'b0; end
                    2'd3: begin cpc<=cpc+1'b1; cdly<=16'd999; end
                endcase
                cph <= cph + 1'b1;
            end
            C_DLY: if (cdly==16'd0) cpc<=cpc+1'b1; else cdly<=cdly-1'b1;
            default: begin idx<=idx+1'b1; cpc<=3'd0; end
            endcase
        end
    end

    // ======== submuestreo a 60x80 + SOBEL (dominio cam_pclk) ========
    reg href_d;
    reg        parity;
    reg [7:0]  curY;
    reg [3:0]  colkeep;
    reg [2:0]  rowkeep;
    reg [6:0]  fbx;
    reg [12:0] waddr_wr;
    reg        we;
    reg [12:0] wadr;
    reg [7:0]  wdat;
    reg [7:0] dline1 [0:59];
    reg [7:0] dline2 [0:59];
    reg [7:0] t00,t01,t02, t10,t11,t12, t20,t21,t22;

    wire [10:0] gxp = t00 + (t10<<1) + t20;
    wire [10:0] gxn = t02 + (t12<<1) + t22;
    wire [10:0] gyp = t22 + (t21<<1) + t20;
    wire [10:0] gyn = t02 + (t01<<1) + t00;
    wire [10:0] agx = (gxp>=gxn) ? (gxp-gxn) : (gxn-gxp);
    wire [10:0] agy = (gyp>=gyn) ? (gyp-gyn) : (gyn-gyp);
    wire [11:0] mag12 = agx + agy;
    wire [7:0]  mag = (mag12 > 12'd255) ? 8'd255 : mag12[7:0];

    integer k;
    always @(posedge cam_pclk or negedge rst_n) begin
        if (!rst_n) begin
            href_d<=1'b0; parity<=1'b0; curY<=8'd0; colkeep<=4'd0; rowkeep<=3'd0;
            fbx<=7'd0; waddr_wr<=13'd0; we<=1'b0; wadr<=13'd0; wdat<=8'd0;
            t00<=0;t01<=0;t02<=0;t10<=0;t11<=0;t12<=0;t20<=0;t21<=0;t22<=0;
        end else begin
            href_d <= cam_href;
            we     <= 1'b0;
            if (~cam_href) begin
                parity <= 1'b0; colkeep <= 4'd0; fbx <= 7'd0;
            end else begin
                if (parity == 1'b0) curY <= cam_d;
                else begin
                    if (rowkeep==3'd0 && colkeep==4'd0 && fbx<7'd60) begin
                        for (k=59; k>0; k=k-1) begin dline1[k]<=dline1[k-1];
                            dline2[k]<=dline2[k-1]; end
                        dline1[0] <= curY;
                        dline2[0] <= dline1[59];
                        t02<=t01; t01<=t00; t00<=dline2[59];
                        t12<=t11; t11<=t10; t10<=dline1[59];
                        t22<=t21; t21<=t20; t20<=curY;
                        we <= 1'b1; wadr <= waddr_wr; wdat <= (mag > 8'd40) ? 8'hFF : 8'h00;
                        waddr_wr <= (waddr_wr==13'd4799) ? 13'd0 : waddr_wr + 1'b1;
                        fbx <= fbx + 1'b1;
                    end
                    colkeep <= (colkeep==4'd9) ? 4'd0 : colkeep + 1'b1;
                end
                parity <= ~parity;
            end
            if (href_d & ~cam_href)
                rowkeep <= (rowkeep==3'd5) ? 3'd0 : rowkeep + 1'b1;
        end
    end

    // ==================== frame buffer 60x80 (sin reset, se llena antes de leerse)
    //   ====================
    reg [7:0] fb [0:4799];
    reg [7:0] fb_rd;
    always @(posedge cam_pclk) if (we) fb[wadr] <= wdat;

    // ==================== display ILI9341 (dominio clk) ====================
    reg        spi_start, spi_dcbit, spi_done;
    reg  [7:0] spi_byte;
    reg sck, mosi, cs, dc;
    assign tft_sck=sck; assign tft_mosi=mosi; assign tft_cs=cs; assign tft_dc=dc;

    localparam S_IDLE=2'd0, S_LO=2'd1, S_HI=2'd2, S_END=2'd3;
    reg [1:0] sst;
    reg [2:0] sbit;
    reg [7:0] sbuf;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sst<=S_IDLE; sbit<=3'd0; sbuf<=8'd0; spi_done<=1'b0; sck<=1'b0; mosi<=1'b0;
                cs<=1'b1; dc<=1'b1;
        end else begin
            spi_done <= 1'b0;
            case (sst)
                S_IDLE: if (spi_start) begin cs<=1'b0; dc<=spi_dcbit; sbuf<=spi_byte;
                    sbit<=3'd0; sck<=1'b0; sst<=S_LO; end
                S_LO:  begin sck<=1'b0; mosi<=sbuf[7]; sst<=S_HI; end
                S_HI:  begin sck<=1'b1; sbuf<={sbuf[6:0],1'b0}; if (sbit==3'd7) sst<=S_END;
                    else begin sbit<=sbit+1'b1; sst<=S_LO; end end
                S_END: begin sck<=1'b0; spi_done<=1'b1; sst<=S_IDLE; end
            endcase
        end
    end

    localparam T_CMD=2'd0, T_DAT=2'd1, T_DLY=2'd2, T_END=2'd3;
    localparam M_BOOT=2'd0, M_INIT=2'd1, M_FRAME=2'd2, M_FILL=2'd3;
    reg [1:0] mode;
    reg [4:0] ip;
    reg [1:0] rt; reg [7:0] rb;
    always @(*) begin
        rt=T_END; rb=8'h00;
        if (mode==M_INIT) case (ip)
            5'd0: begin rt=T_CMD; rb=8'h01; end
            5'd1: begin rt=T_DLY; rb=8'h00; end
            5'd2: begin rt=T_CMD; rb=8'h11; end
            5'd3: begin rt=T_DLY; rb=8'h00; end
            5'd4: begin rt=T_CMD; rb=8'h3A; end
            5'd5: begin rt=T_DAT; rb=8'h55; end
            5'd6: begin rt=T_CMD; rb=8'h36; end
            5'd7: begin rt=T_DAT; rb=8'h48; end
            5'd8: begin rt=T_CMD; rb=8'h29; end
            default: begin rt=T_END; rb=8'h00; end
        endcase
        else case (ip)
            5'd0:  begin rt=T_CMD; rb=8'h2A; end
            5'd1:  begin rt=T_DAT; rb=8'h00; end
            5'd2:  begin rt=T_DAT; rb=8'h00; end
            5'd3:  begin rt=T_DAT; rb=8'h00; end
            5'd4:  begin rt=T_DAT; rb=8'hEF; end
            5'd5:  begin rt=T_CMD; rb=8'h2B; end
            5'd6:  begin rt=T_DAT; rb=8'h00; end
            5'd7:  begin rt=T_DAT; rb=8'h00; end
            5'd8:  begin rt=T_DAT; rb=8'h01; end
            5'd9:  begin rt=T_DAT; rb=8'h3F; end
            5'd10: begin rt=T_CMD; rb=8'h2C; end
            default: begin rt=T_END; rb=8'h00; end
        endcase
    end

    localparam [13:0] OFFSET = 14'd1920;
    reg [7:0] xcol;
    reg [8:0] ycol;
    wire [6:0] fx = xcol[7:2];
    wire [6:0] fy = ycol[8:2];
    wire [13:0] rsum  = fy*60 + fx + OFFSET;
    wire [12:0] raddr = (rsum >= 14'd4800) ? (rsum - 14'd4800) : rsum[12:0];
    always @(posedge clk) fb_rd <= fb[raddr];
    wire [15:0] pcolor = {fb_rd[7:3], fb_rd[7:2], fb_rd[7:3]};

    reg [20:0] dcnt;
    reg [16:0] px;
    reg        pxhi;
    reg        sending;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mode<=M_BOOT; ip<=5'd0; dcnt<=21'd0; px<=17'd0; pxhi<=1'b0; sending<=1'b0;
            spi_start<=1'b0; spi_byte<=8'd0; spi_dcbit<=1'b1; xcol<=8'd0; ycol<=9'd0;
        end else begin
            spi_start <= 1'b0;
            case (mode)
            M_BOOT: begin
                dcnt <= dcnt + 1'b1;
                if (dcnt == 21'd1_800_000) begin dcnt <= 21'd0; mode <= M_INIT; ip <= 5'd0; end
            end
            M_INIT: begin
                if (!sending) begin
                    case (rt)
                        T_CMD,T_DAT: begin spi_byte<=rb; spi_dcbit<=(rt==T_DAT);
                            spi_start<=1'b1; sending<=1'b1; end
                        T_DLY: if (dcnt==21'd1_800_000) begin dcnt<=21'd0; ip<=ip+1'b1;
                            end else dcnt<=dcnt+1'b1;
                        default: begin mode<=M_FRAME; ip<=5'd0; end
                    endcase
                end else if (spi_done) begin sending<=1'b0; ip<=ip+1'b1; end
            end
            M_FRAME: begin
                if (!sending) begin
                    case (rt)
                        T_CMD,T_DAT: begin spi_byte<=rb; spi_dcbit<=(rt==T_DAT);
                            spi_start<=1'b1; sending<=1'b1; end
                        default: begin mode<=M_FILL; px<=17'd0; pxhi<=1'b0; xcol<=8'd0;
                            ycol<=9'd0; end
                    endcase
                end else if (spi_done) begin sending<=1'b0; ip<=ip+1'b1; end
            end
            M_FILL: begin
                if (!sending) begin
                    spi_byte  <= pxhi ? pcolor[7:0] : pcolor[15:8];
                    spi_dcbit <= 1'b1; spi_start <= 1'b1; sending <= 1'b1;
                end else if (spi_done) begin
                    sending <= 1'b0;
                    if (pxhi) begin
                        pxhi <= 1'b0;
                        if (px == 17'd76799) begin px<=17'd0; mode<=M_FRAME; ip<=5'd0; end
                        else begin
                            px <= px + 1'b1;
                            if (xcol == 8'd239) begin xcol<=8'd0; ycol<=ycol+1'b1; end
                            else xcol <= xcol + 1'b1;
                        end
                    end else pxhi <= 1'b1;
                end
            end
            endcase
        end
    end
endmodule
`default_nettype wire
```

## G.10 Visión Canny 1-streaming (§4.3.10)

Es el circuito `vision_canny` de la §5.2: 2,04 mm² en sky130. Todo el sistema está en un fichero,
portado de `cam_canny2_display.v`; la cabecera enumera los mismos tres cambios que el de la G.9.

Carpeta: `Verilog_Repo/vision_canny/`.

### `vision_canny_top.v`

```verilog
// vision_canny_top.v — EL CHIP QUE VE Y MUESTRA con CANNY, integrado para ASIC sky130.
// camara OV7670 -> SCCB -> submuestreo 60x80 -> Gaussian 3x3 -> Sobel 3x3 -> doble
//   umbral ->
// HISTERESIS 1-salto -> framebuffer -> display ILI9341.  Bordes mas limpios y
//   conectados que Sobel.
// Portado del fisico verificado cam_canny2_display.v. Mismos 3 cambios ASIC que
//   vision_top:
// (1) rst_n explicito en los FSM de control, (2) cam_sda open-drain ->
//   cam_sda_o/cam_sda_oe,
// (3) sin SB_RGBA_DRV. DUAL-CLOCK (clk sistema / cam_pclk camara); el framebuffer no
//   se resetea.
`default_nettype none
module vision_canny_top (
    input  wire       clk,
    input  wire       rst_n,
    output wire       cam_xclk,
    output reg        cam_scl,
    output wire       cam_sda_o,
    output wire       cam_sda_oe,
    input  wire       cam_pclk,
    input  wire       cam_href,
    input  wire [7:0] cam_d,
    output wire       tft_sck,
    output wire       tft_mosi,
    output wire       tft_cs,
    output wire       tft_dc,
    output reg        cfg_done
);
    assign cam_xclk = clk;

    // ==================== SCCB config (dominio clk) ====================
    reg sda_oe;
    assign cam_sda_o  = 1'b0;
    assign cam_sda_oe = sda_oe;

    reg [5:0] tdiv;
    wire tick = (tdiv == 6'd29);
    always @(posedge clk or negedge rst_n)
        if (!rst_n) tdiv <= 6'd0; else tdiv <= tick ? 6'd0 : tdiv + 1'b1;

    reg [4:0] idx;
    reg [15:0] rom;
    always @(*) case (idx)
        5'd0:  rom = 16'h12_00;
        5'd1:  rom = 16'h13_E7;
        5'd2:  rom = 16'h09_18;
        default: rom = 16'hFF_FF;
    endcase
    wire       tbl_end  = (rom == 16'hFF_FF);
    wire [7:0] reg_addr = rom[15:8];
    wire [7:0] reg_val  = rom[7:0];

    localparam C_START=3'd0, C_WR=3'd1, C_STOP=3'd2, C_DLY=3'd3, C_NEXT=3'd4;
    reg [2:0] cpc; reg [1:0] cph; reg [3:0] cbi; reg [15:0] cdly;
    reg [2:0] coptype;
    always @(*) case (cpc)
        3'd0: coptype=C_START; 3'd1: coptype=C_WR; 3'd2: coptype=C_WR;
        3'd3: coptype=C_WR;    3'd4: coptype=C_STOP; 3'd5: coptype=C_DLY;
        default: coptype=C_NEXT;
    endcase
    reg [7:0] cwbyte;
    always @(*) case (cpc)
        3'd1: cwbyte=8'h42; 3'd2: cwbyte=reg_addr; 3'd3: cwbyte=reg_val;
        default: cwbyte=8'h00;
    endcase
    reg [19:0] cboot;
    wire cboot_ok = &cboot;
    always @(posedge clk or negedge rst_n)
        if (!rst_n) cboot <= 20'd0; else if (!cboot_ok) cboot <= cboot + 1'b1;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sda_oe<=1'b0; cam_scl<=1'b1; cpc<=0; cph<=0; cbi<=0; cdly<=0; cfg_done<=1'b0; idx<=0;
        end else if (tick && cboot_ok && !cfg_done) begin
            case (coptype)
            C_START: begin
                if (tbl_end) cfg_done <= 1'b1;
                else begin
                    case (cph)
                        2'd0: begin sda_oe<=1'b0; cam_scl<=1'b1; end
                        2'd1: begin sda_oe<=1'b1; cam_scl<=1'b1; end
                        2'd2: cam_scl<=1'b0;
                        2'd3: cpc<=cpc+1'b1;
                    endcase
                    cph <= cph + 1'b1;
                end
            end
            C_WR: begin
                case (cph)
                    2'd0: begin cam_scl<=1'b0; if (cbi<4'd8) sda_oe<=~cwbyte[3'd7-cbi[2:0]];
                        else sda_oe<=1'b0; end
                    2'd1: cam_scl<=1'b1; 2'd2: cam_scl<=1'b1;
                    2'd3: begin cam_scl<=1'b0; if (cbi==4'd8) begin cbi<=4'd0; cpc<=cpc+1'b1;
                        end else cbi<=cbi+1'b1; end
                endcase
                cph <= cph + 1'b1;
            end
            C_STOP: begin
                case (cph)
                    2'd0: begin cam_scl<=1'b0; sda_oe<=1'b1; end
                    2'd1: begin cam_scl<=1'b1; sda_oe<=1'b1; end
                    2'd2: begin cam_scl<=1'b1; sda_oe<=1'b0; end
                    2'd3: begin cpc<=cpc+1'b1; cdly<=16'd999; end
                endcase
                cph <= cph + 1'b1;
            end
            C_DLY: if (cdly==16'd0) cpc<=cpc+1'b1; else cdly<=cdly-1'b1;
            default: begin idx<=idx+1'b1; cpc<=3'd0; end
            endcase
        end
    end

    // ==== submuestreo 60x80 + Gaussian -> Sobel -> clase -> histeresis (dominio
    //   cam_pclk) ====
    reg href_d; reg parity; reg [7:0] curY; reg [3:0] colkeep; reg [2:0] rowkeep;
    reg [6:0] fbx; reg [12:0] waddr_wr; reg we; reg [12:0] wadr; reg [7:0] wdat;

    reg [7:0] gline1 [0:59]; reg [7:0] gline2 [0:59];
    reg [7:0] g00,g01,g02, g10,g11,g12, g20,g21,g22;
    wire [11:0] gsum = g00 + (g01<<1) + g02 + (g10<<1) + (g11<<2) + (g12<<1) + g20
        + (g21<<1) + g22;
    wire [7:0]  gout = gsum[11:4];

    reg [7:0] sline1 [0:59]; reg [7:0] sline2 [0:59];
    reg [7:0] s00,s01,s02, s10,s11,s12, s20,s21,s22;
    wire [10:0] gxp = s00 + (s10<<1) + s20;
    wire [10:0] gxn = s02 + (s12<<1) + s22;
    wire [10:0] gyp = s22 + (s21<<1) + s20;
    wire [10:0] gyn = s02 + (s01<<1) + s00;
    wire [10:0] agx = (gxp>=gxn) ? (gxp-gxn) : (gxn-gxp);
    wire [10:0] agy = (gyp>=gyn) ? (gyp-gyn) : (gyn-gyp);
    wire [11:0] mag12 = agx + agy;
    wire [7:0]  mag = (mag12 > 12'd255) ? 8'd255 : mag12[7:0];

    localparam [1:0] CL_NADA=2'd0, CL_DEBIL=2'd1, CL_FUERTE=2'd2;
    wire [1:0] cls_in = (mag > 8'd70) ? CL_FUERTE : (mag > 8'd30) ? CL_DEBIL : CL_NADA;

    reg [1:0] cline1 [0:59]; reg [1:0] cline2 [0:59];
    reg [1:0] c00,c01,c02, c10,c11,c12, c20,c21,c22;
    wire any_strong = (c00==CL_FUERTE)|(c01==CL_FUERTE)|(c02==CL_FUERTE)|
                      (c10==CL_FUERTE)|                (c12==CL_FUERTE)|
                      (c20==CL_FUERTE)|(c21==CL_FUERTE)|(c22==CL_FUERTE);
    wire edge_px = (c11==CL_FUERTE) ? 1'b1 : (c11==CL_DEBIL) ? any_strong : 1'b0;

    integer k;
    always @(posedge cam_pclk or negedge rst_n) begin
        if (!rst_n) begin
            href_d<=0; parity<=0; curY<=0; colkeep<=0; rowkeep<=0; fbx<=0;
            waddr_wr<=0; we<=0; wadr<=0; wdat<=0;
            g00<=0;g01<=0;g02<=0;g10<=0;g11<=0;g12<=0;g20<=0;g21<=0;g22<=0;
            s00<=0;s01<=0;s02<=0;s10<=0;s11<=0;s12<=0;s20<=0;s21<=0;s22<=0;
            c00<=0;c01<=0;c02<=0;c10<=0;c11<=0;c12<=0;c20<=0;c21<=0;c22<=0;
        end else begin
            href_d <= cam_href;
            we     <= 1'b0;
            if (~cam_href) begin
                parity <= 1'b0; colkeep <= 4'd0; fbx <= 7'd0;
            end else begin
                if (parity == 1'b0) curY <= cam_d;
                else begin
                    if (rowkeep==3'd0 && colkeep==4'd0 && fbx<7'd60) begin
                        for (k=59; k>0; k=k-1) begin gline1[k]<=gline1[k-1];
                            gline2[k]<=gline2[k-1]; end
                        gline1[0] <= curY;  gline2[0] <= gline1[59];
                        g02<=g01; g01<=g00; g00<=gline2[59];
                        g12<=g11; g11<=g10; g10<=gline1[59];
                        g22<=g21; g21<=g20; g20<=curY;
                        for (k=59; k>0; k=k-1) begin sline1[k]<=sline1[k-1];
                            sline2[k]<=sline2[k-1]; end
                        sline1[0] <= gout;  sline2[0] <= sline1[59];
                        s02<=s01; s01<=s00; s00<=sline2[59];
                        s12<=s11; s11<=s10; s10<=sline1[59];
                        s22<=s21; s21<=s20; s20<=gout;
                        for (k=59; k>0; k=k-1) begin cline1[k]<=cline1[k-1];
                            cline2[k]<=cline2[k-1]; end
                        cline1[0] <= cls_in; cline2[0] <= cline1[59];
                        c02<=c01; c01<=c00; c00<=cline2[59];
                        c12<=c11; c11<=c10; c10<=cline1[59];
                        c22<=c21; c21<=c20; c20<=cls_in;
                        we <= 1'b1; wadr <= waddr_wr; wdat <= edge_px ? 8'hFF : 8'h00;
                        waddr_wr <= (waddr_wr==13'd4799) ? 13'd0 : waddr_wr + 1'b1;
                        fbx <= fbx + 1'b1;
                    end
                    colkeep <= (colkeep==4'd9) ? 4'd0 : colkeep + 1'b1;
                end
                parity <= ~parity;
            end
            if (href_d & ~cam_href)
                rowkeep <= (rowkeep==3'd5) ? 3'd0 : rowkeep + 1'b1;
        end
    end

    // ==================== frame buffer 60x80 (sin reset) ====================
    reg [7:0] fb [0:4799];
    reg [7:0] fb_rd;
    always @(posedge cam_pclk) if (we) fb[wadr] <= wdat;

    // ==================== display ILI9341 (dominio clk) ====================
    reg spi_start, spi_dcbit, spi_done; reg [7:0] spi_byte;
    reg sck, mosi, cs, dc;
    assign tft_sck=sck; assign tft_mosi=mosi; assign tft_cs=cs; assign tft_dc=dc;
    localparam S_IDLE=2'd0, S_LO=2'd1, S_HI=2'd2, S_END=2'd3;
    reg [1:0] sst; reg [2:0] sbit; reg [7:0] sbuf;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sst<=S_IDLE; sbit<=0; sbuf<=0; spi_done<=0; sck<=0; mosi<=0; cs<=1'b1; dc<=1'b1;
        end else begin
            spi_done <= 1'b0;
            case (sst)
                S_IDLE: if (spi_start) begin cs<=1'b0; dc<=spi_dcbit; sbuf<=spi_byte;
                    sbit<=3'd0; sck<=1'b0; sst<=S_LO; end
                S_LO:  begin sck<=1'b0; mosi<=sbuf[7]; sst<=S_HI; end
                S_HI:  begin sck<=1'b1; sbuf<={sbuf[6:0],1'b0}; if (sbit==3'd7) sst<=S_END;
                    else begin sbit<=sbit+1'b1; sst<=S_LO; end end
                S_END: begin sck<=1'b0; spi_done<=1'b1; sst<=S_IDLE; end
            endcase
        end
    end

    localparam T_CMD=2'd0, T_DAT=2'd1, T_DLY=2'd2, T_END=2'd3;
    localparam M_BOOT=2'd0, M_INIT=2'd1, M_FRAME=2'd2, M_FILL=2'd3;
    reg [1:0] mode; reg [4:0] ip; reg [1:0] rt; reg [7:0] rb;
    always @(*) begin
        rt=T_END; rb=8'h00;
        if (mode==M_INIT) case (ip)
            5'd0: begin rt=T_CMD; rb=8'h01; end 5'd1: begin rt=T_DLY; rb=8'h00; end
            5'd2: begin rt=T_CMD; rb=8'h11; end 5'd3: begin rt=T_DLY; rb=8'h00; end
            5'd4: begin rt=T_CMD; rb=8'h3A; end 5'd5: begin rt=T_DAT; rb=8'h55; end
            5'd6: begin rt=T_CMD; rb=8'h36; end 5'd7: begin rt=T_DAT; rb=8'h48; end
            5'd8: begin rt=T_CMD; rb=8'h29; end default: begin rt=T_END; rb=8'h00; end
        endcase
        else case (ip)
            5'd0:  begin rt=T_CMD; rb=8'h2A; end 5'd1:  begin rt=T_DAT; rb=8'h00; end
            5'd2:  begin rt=T_DAT; rb=8'h00; end 5'd3:  begin rt=T_DAT; rb=8'h00; end
            5'd4:  begin rt=T_DAT; rb=8'hEF; end 5'd5:  begin rt=T_CMD; rb=8'h2B; end
            5'd6:  begin rt=T_DAT; rb=8'h00; end 5'd7:  begin rt=T_DAT; rb=8'h00; end
            5'd8:  begin rt=T_DAT; rb=8'h01; end 5'd9:  begin rt=T_DAT; rb=8'h3F; end
            5'd10: begin rt=T_CMD; rb=8'h2C; end default: begin rt=T_END; rb=8'h00; end
        endcase
    end

    localparam [13:0] OFFSET = 14'd1861;
    reg [7:0] xcol; reg [8:0] ycol;
    wire [6:0] fx = xcol[7:2];
    wire [6:0] fy = ycol[8:2];
    wire [13:0] rsum  = fy*60 + fx + OFFSET;
    wire [12:0] raddr = (rsum >= 14'd4800) ? (rsum - 14'd4800) : rsum[12:0];
    always @(posedge clk) fb_rd <= fb[raddr];
    wire [15:0] pcolor = {fb_rd[7:3], fb_rd[7:2], fb_rd[7:3]};

    reg [20:0] dcnt; reg [16:0] px; reg pxhi; reg sending;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mode<=M_BOOT; ip<=0; dcnt<=0; px<=0; pxhi<=0; sending<=0;
            spi_start<=0; spi_byte<=0; spi_dcbit<=1'b1; xcol<=0; ycol<=0;
        end else begin
            spi_start <= 1'b0;
            case (mode)
            M_BOOT: begin
                dcnt <= dcnt + 1'b1;
                if (dcnt == 21'd1_800_000) begin dcnt <= 21'd0; mode <= M_INIT; ip <= 5'd0; end
            end
            M_INIT: begin
                if (!sending) begin
                    case (rt)
                        T_CMD,T_DAT: begin spi_byte<=rb; spi_dcbit<=(rt==T_DAT);
                            spi_start<=1'b1; sending<=1'b1; end
                        T_DLY: if (dcnt==21'd1_800_000) begin dcnt<=21'd0; ip<=ip+1'b1;
                            end else dcnt<=dcnt+1'b1;
                        default: begin mode<=M_FRAME; ip<=5'd0; end
                    endcase
                end else if (spi_done) begin sending<=1'b0; ip<=ip+1'b1; end
            end
            M_FRAME: begin
                if (!sending) begin
                    case (rt)
                        T_CMD,T_DAT: begin spi_byte<=rb; spi_dcbit<=(rt==T_DAT);
                            spi_start<=1'b1; sending<=1'b1; end
                        default: begin mode<=M_FILL; px<=17'd0; pxhi<=1'b0; xcol<=8'd0;
                            ycol<=9'd0; end
                    endcase
                end else if (spi_done) begin sending<=1'b0; ip<=ip+1'b1; end
            end
            M_FILL: begin
                if (!sending) begin
                    spi_byte  <= pxhi ? pcolor[7:0] : pcolor[15:8];
                    spi_dcbit <= 1'b1; spi_start <= 1'b1; sending <= 1'b1;
                end else if (spi_done) begin
                    sending <= 1'b0;
                    if (pxhi) begin
                        pxhi <= 1'b0;
                        if (px == 17'd76799) begin px<=17'd0; mode<=M_FRAME; ip<=5'd0; end
                        else begin
                            px <= px + 1'b1;
                            if (xcol == 8'd239) begin xcol<=8'd0; ycol<=ycol+1'b1; end
                            else xcol <= xcol + 1'b1;
                        end
                    end else pxhi <= 1'b1;
                end
            end
            endcase
        end
    end
endmodule
`default_nettype wire
```

## G.11 Visión Canny Framebuffer Transitivo (§4.3.11)

Es el circuito `trans_completo`, el tercero de la §5.3: 9,61 mm² en sky130. `trans_completo.v` conecta la
cadena y declara el framebuffer de clases y el de bordes; `grad_class_top.v` calcula la clase de cada
píxel con el suavizado, el gradiente y el doble umbral. El motor es el de la G.3, y los bloques de
interfaz, los de la G.7.

Carpeta: `Verilog_Repo/completos/trans_completo/`.

### `trans_completo.v`

```verilog
// trans_completo.v — LA CADENA DE VISION con histeresis TRANSITIVA (por-cuadro), sin
//   CPU, ASIC sky130.
//   camara OV7670 --> [cam_frontend_top: SCCB + captura + CDC + RGB565->gris]
// --> [grad_class_top: Gaussian -> Sobel -> doble umbral -> CLASE 2 bits]
// --> [clsfb 60x80 x2 bits] --(motor bucle: LOAD -> barre K -> READ)--> [edgefb 60x80
//   x1 bit]
//                 --> [lcd_ili9341_top: SPI + ROM ILI9341] --> PMOD TFTLCD
// Arquitectura DESACOPLADA (igual que cam_canny3_display.v en FPGA): el motor corre a
//   su propio ritmo;
// la camara sobrescribe clsfb (si llega cuadro nuevo mientras barre, la imagen "salta"
//   un poco: esperado).
// UN SOLO RELOJ (clk): el front-end sincroniza PCLK/HREF/VSYNC con 2-FF internos
//   (§4.2).
`default_nettype none
module trans_completo (
    input  wire       clk,
    input  wire       rst_n,
    // ---- camara OV7670 ----
    input  wire [7:0] cam_d,
    input  wire       cam_pclk,
    input  wire       cam_href,
    input  wire       cam_vsync,
    output wire       cam_xclk,
    output wire       cam_sioc,
    output wire       cam_siod_o,
    output wire       cam_siod_oe,
    // ---- display PMOD TFTLCD ----
    output wire       tft_sck,
    output wire       tft_mosi,
    output wire       tft_cs,
    output wire       tft_dc,
    // ---- estado ----
    output wire       cfg_done,
    output wire       init_done
);
    // ===== 1) FRONT-END: camara -> stream de gris =====
    wire [7:0] gray; wire gray_valid, fe_frame_start, fe_line_start;
    cam_frontend_top u_fe (
        .sysclk(clk), .rst_n(rst_n),
        .cam_d(cam_d), .cam_pclk(cam_pclk), .cam_href(cam_href), .cam_vsync(cam_vsync),
        .cam_xclk(cam_xclk), .cam_sioc(cam_sioc), .cam_siod_o(cam_siod_o),
            .cam_siod_oe(cam_siod_oe),
        .gray(gray), .gray_valid(gray_valid), .frame_start(fe_frame_start),
            .line_start(fe_line_start),
        .cfg_done(cfg_done));

    // ===== 2) GENERADOR DE CLASE: gray -> Gaussian -> Sobel -> doble umbral -> 2 bits
    //   =====
    wire cls_v; wire [1:0] cls_p;
    grad_class_top u_cg (
        .clk(clk), .reset(~rst_n),
        .in_valid(gray_valid), .in_pix(gray), .thr_hi(8'd110), .thr_lo(8'd70),
        .out_valid(cls_v), .class_out(cls_p));

    // ===== 3) CLSFB 60x80 x2 bits (mapa de clase; W=stream de camara, R=motor) =====
    reg [1:0] clsfb [0:4799];
    reg [12:0] wadr;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) wadr <= 13'd0;
        else if (fe_frame_start) wadr <= 13'd0;
        else if (cls_v) begin
            clsfb[wadr] <= cls_p;
            wadr <= (wadr == 13'd4799) ? 13'd0 : wadr + 1'b1;
        end
    end
    reg [12:0] cls_raddr;
    reg [1:0]  cls_rd;
    always @(posedge clk) cls_rd <= clsfb[cls_raddr];   // lectura sincrona (1 ciclo)

    // ===== 4) MOTOR transitivo + puente FSM (dominio clk) =====
    reg        eng_nreset, eng_in_valid; reg [1:0] eng_class;
    wire       eng_load_ready, eng_out_valid, eng_edge, eng_done;
    trans_engine_top ENG (
        .clk(clk), .nreset(eng_nreset),
        .in_valid(eng_in_valid), .class_in(eng_class),
        .load_ready(eng_load_ready), .out_valid(eng_out_valid), .edge_out(eng_edge),
            .done(eng_done));

    // ===== 5) EDGEFB 60x80 x1 bit (mapa de borde; W=motor READ, R=pantalla) =====
    reg        edgefb [0:4799];
    reg        edge_we; reg [12:0] edge_wa; reg edge_wd;
    always @(posedge clk) if (edge_we) edgefb[edge_wa] <= edge_wd;

    // puente FSM: reset motor -> espera LOAD -> carga clsfb -> READ escribe edgefb
    localparam [1:0] E_RST=2'd0, E_WLOAD=2'd1, E_LOAD=2'd2, E_READ=2'd3;
    reg [1:0]  estate; reg [3:0] rstcnt; reg [12:0] lptr; reg lphase; reg [12:0] eptr;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            estate<=E_RST; rstcnt<=4'd0; lptr<=13'd0; lphase<=1'b0; eptr<=13'd0;
            eng_nreset<=1'b0; eng_in_valid<=1'b0; eng_class<=2'd0; edge_we<=1'b0;
                cls_raddr<=13'd0;
        end else begin
            eng_in_valid <= 1'b0; edge_we <= 1'b0;
            case (estate)
            E_RST: begin
                eng_nreset <= 1'b0; rstcnt <= rstcnt + 1'b1;
                if (rstcnt == 4'd8) begin eng_nreset<=1'b1; estate<=E_WLOAD; lptr<=13'd0;
                    lphase<=1'b0; end
            end
            E_WLOAD: begin
                eng_nreset <= 1'b1;
                if (eng_load_ready) begin cls_raddr <= lptr; lphase <= 1'b0; estate <= E_LOAD;
                    end
            end
            E_LOAD: begin
                eng_nreset <= 1'b1;
                // direcciona pixel lptr
                if (lphase == 1'b0) begin cls_raddr <= lptr; lphase <= 1'b1; end
                else begin
                    // emite el valido
                    eng_in_valid <= 1'b1; eng_class <= cls_rd;
                    lphase <= 1'b0;
                    if (lptr == 13'd4799) begin estate<=E_READ; eptr<=13'd0; end
                    else lptr <= lptr + 1'b1;
                end
            end
            E_READ: begin
                eng_nreset <= 1'b1;
                if (eng_out_valid) begin edge_we<=1'b1; edge_wa<=eptr; edge_wd<=eng_edge;
                    eptr<=eptr+1'b1; end
                if (eng_done) begin estate<=E_RST; rstcnt<=4'd0; end
            end
            endcase
        end
    end

    // ===== 6) LECTURA para el LCD (240x320 -> escala a 60x80) desde edgefb =====
    wire lcd_next, lcd_fs;
    reg [7:0] xcol; reg [8:0] ycol;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin xcol<=8'd0; ycol<=9'd0; end
        else if (lcd_fs) begin xcol<=8'd0; ycol<=9'd0; end
        else if (lcd_next) begin
            if (xcol==8'd239) begin xcol<=8'd0; ycol<=(ycol==9'd319)?9'd0:ycol+1'b1; end
            else xcol<=xcol+1'b1;
        end
    end
    wire [6:0] fx = xcol[7:2];
    wire [6:0] fy = ycol[8:2];
    wire [13:0] raddr = fy*60 + fx;
    reg fb_rd_bit;
    always @(posedge clk) fb_rd_bit <= edgefb[raddr[12:0]];
    wire [7:0] fb_rd = fb_rd_bit ? 8'hFF : 8'h00;

    // ===== 7) LCD DRIVER =====
    lcd_ili9341_top u_lcd (
        .clk(clk), .rst_n(rst_n),
        .pix_gray(fb_rd), .pix_next(lcd_next), .frame_start(lcd_fs), .init_done(init_done),
        .tft_sck(tft_sck), .tft_mosi(tft_mosi), .tft_cs(tft_cs), .tft_dc(tft_dc));

    wire _unused = &{fe_line_start, 1'b0};
endmodule
`default_nettype wire
```

### `grad_class_top.v`

```verilog
// grad_class_top.v — genera la CLASE (2 bits) para el motor transitivo, sin CPU.
// gray stream -> Gaussian 3x3 -> Sobel 3x3 -> doble umbral -> class_out (0 nada / 1
//   debil / 2 fuerte).
// Es la MISMA cabeza del canny1_top, pero SIN la histeresis de 1 salto: aqui la
//   histeresis la hace
// el motor transitivo (por-cuadro, K barridos). Umbrales altos: la transitiva conecta
//   semillas escasas.
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
    linebuf3x3 #(.W(60),.DW(8)) LBG (
        .clk(clk),.in_valid(in_valid),.in_pix(in_pix),.valid_o(vg),
        .w00(gw00),.w01(gw01),.w02(gw02),.w10(gw10),.w11(gw11),.w12(gw12),
        .w20(gw20),.w21(gw21),.w22(gw22));
    wire [11:0] gsum = gw00+(gw01<<1)+gw02 + (gw10<<1)+(gw11<<2)+(gw12<<1) + gw20+(gw21<<1)+gw22;
    wire [7:0]  gout = gsum[11:4];   // /16
    // etapa 2: Sobel 3x3 sobre la Gaussiana
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
    wire [1:0]  cls = (mag>thr_hi)?2'd2 : (mag>thr_lo)?2'd1 : 2'd0;   // doble umbral
    always @(posedge clk) begin
        if (reset) begin out_valid<=1'b0; class_out<=2'd0; end
        else begin out_valid<=vs; class_out<=cls; end
    end
endmodule
`default_nettype wire
```

## G.12 Mini Sobel en Tiny Tapeout (§4.3.12)

Es el proyecto `tt_um_sobel_vic`, de 3×2 mosaicos. `tt_um_sobel_vic.v` adapta los pines de la
lanzadera; `sobel_top.v` es el de la G.1 con una línea más —pasa el reinicio al generador de ventana— y
`linebuf3x3.v` es el de la G.1 **con reinicio explícito** en todos sus registros, la versión que el
silicio necesita.

Carpeta: `tinytapeout/tt_sobel/src/` del repositorio de la tesis.

### `tt_um_sobel_vic.v`

```verilog
// tt_um_sobel_vic.v — Sobel 3x3 de bordes (Victor, UNAL) envuelto para Tiny Tapeout.
// Interfaz TT (8 in + 8 out + 8 bidi + clk/rst_n/ena). Umbral fijo (TT no alcanza para
//   8 pines mas).
// Pixel entra por ui_in; in_valid por uio_in[0]; out_pix por uo_out; out_valid por
//   uio_out[1].
// Es el filtro mas chico de los tres: solo 2 line-buffers y sumadores, sin Gaussiano
//   ni CPU.
`default_nettype none
module tt_um_sobel_vic (
    input  wire [7:0] ui_in,    // in_pix[7:0]
    output wire [7:0] uo_out,   // out_pix[7:0]
    input  wire [7:0] uio_in,   // uio_in[0] = in_valid
    output wire [7:0] uio_out,  // uio_out[1] = out_valid
    output wire [7:0] uio_oe,   // habilitacion bidi (1=salida)
    input  wire       ena,      // 1 cuando el diseno esta activo
    input  wire       clk,
    input  wire       rst_n     // reset activo-bajo
);
    wire out_valid;
    localparam [7:0] THR = 8'd90;   // umbral de borde (fijo; el mismo del SoC en FPGA)

    sobel_top u_sobel (
        .clk(clk), .reset(~rst_n),                  // sobel_top usa reset activo-alto
        .in_valid(uio_in[0]), .in_pix(ui_in),
        .thr(THR),
        .out_valid(out_valid), .out_pix(uo_out));

    assign uio_out = {6'b0, out_valid, 1'b0};       // out_valid en bit 1
    assign uio_oe  = 8'b0000_0010;                  // uio[1]=salida; resto entradas
    wire _unused = &{ena, uio_in[7:1], 1'b0};       // evita warnings de senales sin usar
endmodule
`default_nettype wire
```

### `sobel_top.v`

```verilog
// sobel_top.v — Sobel de bordes AUTOCONTENIDO para ASIC (sky130).
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
        .clk(clk), .reset(reset), .in_valid(in_valid), .in_pix(in_pix), .valid_o(vin),
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

### `linebuf3x3.v`, con reinicio explícito

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
//
// VERSION PARA SILICIO: lleva RESET EXPLICITO (sincrono, activo-alto).
// La version original arrancaba los contadores con valores iniciales (reg x=0, v1=0),
//   lo que
// funciona en simulacion RTL y en FPGA (el bitstream inicializa los flops) pero NO en
//   un ASIC:
// ahi los flip-flops arrancan aleatorios y el `valid` nunca se resuelve. Es la misma
//   leccion
// del port a sky130 ("el firmware no se carga solo"), aplicada a los contadores.
module linebuf3x3 #(parameter W=160, parameter DW=8) (
    input  wire            clk,
    input  wire            reset,        // sincrono, activo-alto
    input  wire            in_valid,
    input  wire [DW-1:0]   in_pix,
    output reg             valid_o,
    output reg [DW-1:0]    w00,w01,w02, w10,w11,w12, w20,w21,w22
);
    reg [DW-1:0] lb_a [0:W-1];   // fila n-2
    reg [DW-1:0] lb_b [0:W-1];   // fila n-1
    reg [DW-1:0] q_a, q_b, cur;
    reg [8:0] x, xd; reg v1;

    // etapa 1: lectura sincrona + avanzar columna
    always @(posedge clk) begin
        if (reset) begin
            x <= 9'd0; xd <= 9'd0; v1 <= 1'b0;
            q_a <= {DW{1'b0}}; q_b <= {DW{1'b0}}; cur <= {DW{1'b0}};
        end else begin
            v1 <= 1'b0;
            if (in_valid) begin
                q_a <= lb_a[x]; q_b <= lb_b[x]; cur <= in_pix;
                xd  <= x; x <= (x==W-1) ? 9'd0 : x+9'd1; v1 <= 1'b1;
            end
        end
    end
    // etapa 2: escritura de retorno (rota filas) + ventana
    always @(posedge clk) begin
        if (reset) begin
            valid_o <= 1'b0;
            w00<={DW{1'b0}}; w01<={DW{1'b0}}; w02<={DW{1'b0}};
            w10<={DW{1'b0}}; w11<={DW{1'b0}}; w12<={DW{1'b0}};
            w20<={DW{1'b0}}; w21<={DW{1'b0}}; w22<={DW{1'b0}};
        end else begin
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
    end
endmodule
```

## G.13 Mini Canny 1-streaming en Tiny Tapeout (§4.3.13)

Es el proyecto `tt_um_canny1_vic`, de 6×2 mosaicos. El generador de ventana es el de la G.12.

Carpeta: `tinytapeout/tt_canny1/src/` del repositorio de la tesis.

### `tt_um_canny1_vic.v`

```verilog
// tt_um_canny1_vic.v — Canny 1-streaming (Victor, UNAL) envuelto para Tiny Tapeout.
// Interfaz TT (8 in + 8 out + 8 bidi + clk/rst_n/ena). Umbrales fijos (TT no alcanza
//   para 16 pines mas).
// Pixel entra por ui_in; in_valid por uio_in[0]; out_pix por uo_out; out_valid por
//   uio_out[1].
`default_nettype none
module tt_um_canny1_vic (
    input  wire [7:0] ui_in,    // in_pix[7:0]
    output wire [7:0] uo_out,   // out_pix[7:0]
    input  wire [7:0] uio_in,   // uio_in[0] = in_valid
    output wire [7:0] uio_out,  // uio_out[1] = out_valid
    output wire [7:0] uio_oe,   // habilitacion bidi (1=salida)
    input  wire       ena,      // 1 cuando el diseno esta activo
    input  wire       clk,
    input  wire       rst_n     // reset activo-bajo
);
    wire out_valid;
    localparam [7:0] THR_HI = 8'd90;   // umbral alto (fijo)
    localparam [7:0] THR_LO = 8'd40;   // umbral bajo (fijo)

    canny1_top u_canny1 (
        .clk(clk), .reset(~rst_n),                 // canny1 usa reset activo-alto
        .in_valid(uio_in[0]), .in_pix(ui_in),
        .thr_hi(THR_HI), .thr_lo(THR_LO),
        .out_valid(out_valid), .out_pix(uo_out));

    assign uio_out = {6'b0, out_valid, 1'b0};       // out_valid en bit 1
    assign uio_oe  = 8'b0000_0010;                  // uio[1]=salida; resto entradas
    wire _unused = &{ena, uio_in[7:1], 1'b0};       // evita warnings de senales sin usar
endmodule
`default_nettype wire
```

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
        .clk(clk),.reset(reset),.in_valid(in_valid),.in_pix(in_pix),.valid_o(vg),
        .w00(gw00),.w01(gw01),.w02(gw02),.w10(gw10),.w11(gw11),.w12(gw12),
        .w20(gw20),.w21(gw21),.w22(gw22));
    wire [11:0] gsum = gw00+(gw01<<1)+gw02 + (gw10<<1)+(gw11<<2)+(gw12<<1) + gw20+(gw21<<1)+gw22;
    wire [7:0]  gout = gsum[11:4];   // /16

    // ===== etapa 2: Sobel 3x3 sobre la Gaussiana (line-buffer) =====
    wire vs;
    wire [7:0] sw00,sw01,sw02,sw10,sw11,sw12,sw20,sw21,sw22;
    linebuf3x3 #(.W(60),.DW(8)) LBS (
        .clk(clk),.reset(reset),.in_valid(vg),.in_pix(gout),.valid_o(vs),
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
        .clk(clk),.reset(reset),.in_valid(vs),.in_pix(cls_in),.valid_o(vc),
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

## G.14 Pan Sobel (§6.3.1)

El reconocedor con cámara, procesador y Sobel. `pan_sobel.v` une la ventana con la cadena;
`soc_mnist_top.v` reúne el SoC reducido, el extractor y el clasificador; `soc_ctrl.v` es el SoC sin el
Sobel duplicado, con el programa de siete instrucciones en ROM. `cam_win28.v`, `mnist_feat.v` y
`mnist_clf.v` son los mismos en los cuatro reconocedores de cuarenta rasgos. El periférico es el de la
G.4 y el generador de ventana el de la G.12, con reinicio explícito. Los 400 pesos del clasificador están
en `mnist_weights.vh`, un fichero de datos que no se imprime.

Carpeta: `Verilog_Repo/pan_sobel/`.

### `pan_sobel.v`

```verilog
// pan_sobel.v — con Sobel: EL CHIP QUE MIRA Y RECONOCE.
//
//   OV7670  ->  cam_win28  ->  [SoC femto: FemtoRV32 + periferico 0x0045 + Sobel]
//                                  -> mnist_feat -> mnist_clf  ->  0..9 o NADA
//
//   A diferencia de los seis chips anteriores de la tesis, este NO lleva framebuffer ni
//   driver de LCD: no dibuja, RECONOCE. La salida no es una imagen, son cuatro bits y
//   un bit de "me lo creo".
//
//   Los pines de entrada son los de la camara tal como salen del sensor: pclk, href y
//   el byte de luma ya extraido. `invertir` queda cableado a 1 porque MNIST es trazo
//   CLARO sobre fondo oscuro y la tinta sobre papel es al reves.
`default_nettype none
module pan_sobel (
    // ---- lado camara (OV7670) ----
    input  wire       pclk,          // reloj de pixel del sensor
    input  wire       reset,         // sincrono, activo-alto
    input  wire       href,          // alto durante los pixeles activos de la linea
    input  wire       sync,          // pulso de cuadro nuevo (a 0 si no se usa)
    input  wire [7:0] pix_y,         // luma
    input  wire       pix_valid,
    // ---- lado resultado ----
    output wire       done,          // pulso: hay veredicto
    output wire [3:0] digito,        // 0..9
    output wire       valido,        // 0 = NADA ("no se")
    output wire [7:0] thr_usado,     // observabilidad: que umbral uso de verdad
    output wire       cpu_escribio   // observabilidad: el CPU alcanzo a escribirlo
);
    wire w_valid, w_fin;  wire [7:0] w_pix;
    cam_win28 #(.CAM_W(640), .CAM_H(480), .WIN(448), .N(28)) WIN (
        .pclk(pclk), .reset(reset), .href(href), .sync(sync),
        .pix_y(pix_y), .pix_valid(pix_valid), .invertir(1'b1),
        .out_valid(w_valid), .out_pix(w_pix), .frame_fin(w_fin));

    // clr cuando el clasificador TERMINA, no en cada cuadro: el video es continuo y el
    // raster se encadena solo. Con clr por cuadro la latencia se reinicia y nunca
    //   cuenta.
    reg clr = 1'b0;
    always @(posedge pclk) clr <= done;

    soc_mnist_top #(.H(28), .W(28), .CW(9), .FUENTE_THR(0)) CLF (
        .clk(pclk), .reset(reset), .clr(clr),
        .in_valid(w_valid), .in_pix(w_pix),
        .done(done), .digito(digito), .valido(valido),
        .thr_usado(thr_usado), .cpu_escribio(cpu_escribio));
endmodule
`default_nettype wire
```

### `soc_mnist_top.v`

```verilog
// soc_mnist_top.v — LA CADENA CON CPU: SoC femto + Sobel + clasificador MNIST.
//
//   cam_win28 (28x28)  ->  mnist_feat  ->  mnist_clf  ->  0..9 o NADA
//                              ^
//                              |  thr
//                     soc_sobel_top  (FemtoRV32 + ROM + periferico 0x0045 + Sobel)
//
// QUE APORTA EL CPU, exactamente: el umbral del filtro deja de estar CABLEADO y pasa a
//   ser un
// registro que el firmware escribe. El datapath no cambia -la tesis midio 45 pares con
//   y sin
//   CPU identicos pixel a pixel-; lo que cambia es QUIEN elige el numero.
//
// Se midio en Python cuanto vale eso: -1.67 pp sobre MNIST limpio y
//   +27.27 pp con ruido severo. Esta es la version en hardware de ese experimento.
//
//   FUENTE_THR permite comparar las dos situaciones en el MISMO banco:
//     0 = el umbral lo fija el CPU (lo que hace el SoC real; el firmware pone 90)
//     1 = umbral cableado THR_FIJO (lo que hace el diseno sin CPU)
`default_nettype none
module soc_mnist_top #(
    parameter integer H = 28, parameter integer W = 28, parameter integer CW = 9,
    parameter integer FUENTE_THR = 0,
    parameter [7:0]   THR_FIJO   = 8'd60
)(
    input  wire       clk,
    input  wire       reset,          // sincrono, activo-alto
    input  wire       clr,
    input  wire       in_valid,
    input  wire [7:0] in_pix,
    output wire       done,
    output wire [3:0] digito,
    output wire       valido,
    output wire [7:0] thr_usado,      // observabilidad: que umbral se uso de verdad
    output wire       cpu_escribio
);
    // ---- el SoC: corre el firmware y fija el umbral por el periferico 0x0045 ----
    wire [7:0] thr_cpu;
    // soc_ctrl = FemtoRV32 + ROM + periferico, SIN el datapath Sobel duplicado.
    // Ese filtro sobra aca (mnist_feat tiene el suyo) y son ~1 300 LUT4 de mas.
    soc_ctrl SOC (.clk(clk), .resetn(~reset),
                  .thr_o(thr_cpu), .cpu_wrote(cpu_escribio));

    assign thr_usado = (FUENTE_THR == 0) ? thr_cpu : THR_FIJO;

    // ---- el clasificador, usando ESE umbral ----
    wire [32*CW-1:0] cnt;
    wire [10:0] n_bordes;
    wire fdone;
    mnist_feat #(.H(H),.W(W),.CW(CW)) FEAT (
        .clk(clk), .reset(reset), .clr(clr),
        .in_valid(in_valid), .in_pix(in_pix), .thr(thr_usado),
        .frame_done(fdone), .cnt_o(cnt), .n_bordes(n_bordes));
    mnist_clf #(.CW(CW)) CLF (
        .clk(clk), .reset(reset), .start(fdone), .cnt_i(cnt), .n_bordes(n_bordes),
        .done(done), .digito(digito), .valido(valido), .score());
endmodule
`default_nettype wire
```

### `soc_ctrl.v`

```verilog
// soc_ctrl.v — el SoC SIN su datapath: solo FemtoRV32 + ROM + periferico 0x0045.
//
// `soc_sobel_top` trae su propio Sobel, y en la cadena del clasificador ESE datapath
//   sobra:
// mnist_feat ya calcula el suyo. Lo unico que hace falta del SoC es la parte que
//   escribe el
// umbral. Sacar el filtro duplicado es la diferencia entre entrar en la iCE40UP5K y no
//   entrar.
//
// El firmware es el MISMO de la tesis, verbatim: siete instrucciones que eligen Sobel
//   y fijan
//   thr=90 escribiendo el periferico 0x0045.
`default_nettype none
module soc_ctrl #(
    // FIRMWARE: la constante que el CPU escribe en 0x0045+4 lleva los DOS umbrales
    // empaquetados -{thr_hi, thr_lo}-. El firmware original de la tesis escribe 0x5A00:
    // thr_hi=90 y thr_lo=0. Para el Sobel da igual (solo usa thr_hi); para el Canny
    //   1-salto
    // es fatal: con thr_lo=0 todo pixel es borde debil y la histeresis promueve casi
    //   todos.
    // Medido sobre las 10 000: 89.93 % con 0x5A00 contra 92.46 % con 0x5A20
    //   (thr_lo=32).
    //   0x5A00 = firmware original (Sobel)
    //   0x5A20 = firmware del Canny (thr_hi=90, thr_lo=32)
    parameter [15:0] UMBRALES = 16'h5A00
) (
    input  wire       clk,
    input  wire       resetn,        // 0 = reset, 1 = corre
    output wire [7:0] thr_o,         // thr_hi: el umbral ALTO que fijo el CPU
    output wire [7:0] thr_lo_o,      // thr_lo: el BAJO. Es un PUERTO, no una referencia
                                     // jerarquica: `SOC.flt_tlo` funciona en iverilog
                                     // pero yosys lo declara como cable implicito de 1
                                     // bit SIN DRIVER, y el chip corre con thr_lo=0.
    output wire       cpu_wrote      // ya escribio el periferico
);
    // el inmediato de 12 bits que lleva x3 de 0x6000 a UMBRALES
    localparam signed [11:0] IMM12 = $signed(UMBRALES) - 12'sh000 - 16'sh6000;

    wire [31:0] mem_addr, mem_wdata; wire [3:0] mem_wmask; wire mem_rstrb;
    reg  [31:0] mem_rdata;
    FemtoRV32 CPU (
        .clk(clk), .reset(resetn),
        .mem_addr(mem_addr), .mem_wdata(mem_wdata), .mem_wmask(mem_wmask),
        .mem_rdata(mem_rdata), .mem_rstrb(mem_rstrb), .mem_rbusy(1'b0), .mem_wbusy(1'b0));
    wire cpu_wr = |mem_wmask;
    wire cpu_rd = mem_rstrb;
    wire cs_filter = (mem_addr[31:16] == 16'h0045);

    // ROM de programa — las MISMAS 7 instrucciones de soc_sobel_top.v
    reg [31:0] rom_q;
    always @(posedge clk) begin
        case (mem_addr[4:2])
            3'd0: rom_q <= 32'h004500b7;  // lui  x1,0x450
            3'd1: rom_q <= 32'h01000113;  // addi x2,x0,16
            3'd2: rom_q <= 32'h0020a023;  // sw   x2,0(x1)    -> mode=Sobel, enable
            // lui x3,0x6 ; addi x3,x3,imm  ->  x3 = UMBRALES
            //   imm = UMBRALES - 0x6000, en complemento a dos de 12 bits
            3'd3: rom_q <= 32'h000061b7;  // lui  x3,0x6
            3'd4: rom_q <= {IMM12, 5'd3, 3'b000, 5'd3, 7'b0010011};  // addi x3,x3,IMM12
            3'd5: rom_q <= 32'h0030a223;  // sw   x3,4(x1)  -> {thr_hi, thr_lo}
            3'd6: rom_q <= 32'h0000006f;  // jal  x0,0        -> loop
            default: rom_q <= 32'h00000013;
        endcase
    end

    wire [1:0] flt_mode; wire flt_enable, flt_engrst;
    wire [7:0] flt_thi, flt_tlo; wire [31:0] filt_dout;
    peripheral_filter PER (
        .clk(clk), .reset(~resetn),
        .d_in(mem_wdata), .cs(cs_filter), .addr(mem_addr[4:0]), .rd(cpu_rd), .wr(cpu_wr),
        .d_out(filt_dout),
        .mode(flt_mode), .enable(flt_enable), .eng_reset(flt_engrst),
        .thr_hi(flt_thi), .thr_lo(flt_tlo),
        .cfg_done(1'b1), .eng_busy(1'b0), .vsync_alive(1'b1), .frame_count(16'd0));
    assign thr_o    = flt_thi;
    assign thr_lo_o = flt_tlo;

    always @(*) mem_rdata = cs_filter ? filt_dout : rom_q;

    reg wrote = 1'b0;
    always @(posedge clk) if (!resetn) wrote <= 1'b0;
        else if (cs_filter && cpu_wr) wrote <= 1'b1;
    assign cpu_wrote = wrote;
endmodule
`default_nettype wire
```

### `cam_win28.v`

```verilog
// cam_win28.v — de la camara a las 28x28 que espera el clasificador.
//
// ESTE MODULO ES LA RESPUESTA AL PROBLEMA DE MNIST. Los digitos de MNIST vienen
//   normalizados
// en tamano y centrados por centro de masa; lo que ve la OV7670 no. En vez de
//   normalizar en
//   hardware -caro y fragil- se hace lo que hace un lector de QR:
//
// se define una VENTANA CUADRADA fija en el centro del cuadro, se dibuja en la
//   pantalla,
//       y el centrado lo hace la persona metiendo el digito adentro.
//
// La ventana es de WINxWIN en el centro del cuadro de la camara, con WIN multiplo de
//   28: cada
// pixel de salida es el PROMEDIO de un bloque de (WIN/28)^2. Se promedia y NO se
//   decima: un
// trazo fino puede caer entre dos muestras de una rejilla y el digito desaparece. Con
//   WIN=448
//   el bloque es 16x16 = 256 y el divisor es un shift de 8.
//
//   INVERSION: MNIST es trazo CLARO sobre fondo OSCURO; tinta sobre papel es al reves.
//
// ENGANCHE DE CUADRO (`sync`): sin el, este modulo contaba filas LIBREMENTE y las
//   reiniciaba
// al llegar a CAM_H. Como el OV7670 clon no entrega VSYNC usable, nada le decia donde
//   empieza
// el cuadro: la ventana de 28x28 tomaba pedazos de DOS cuadros distintos y el punto de
//   corte
// derivaba. Medido sobre capturas reales, la costura aparecia en las filas
//   1,2,3,4,6,9,19,26
//   -- se movia en cada captura.
// `sync` es un pulso de comienzo de cuadro. Se genera afuera midiendo cuanto tiempo
//   `href`
// queda en bajo: entre lineas son ~144 pclk, entre cuadros son >= 14 000. Un umbral de
//   2 000
// separa los dos casos con 7x de holgura, y no hace falta VSYNC ni calibrar nada a
//   ojo.
`default_nettype none
module cam_win28 #(
    parameter integer CAM_W = 640, parameter integer CAM_H = 480,
    parameter integer WIN   = 448,
    parameter integer N     = 28
)(
    input  wire       pclk,
    input  wire       reset,
    input  wire       href,           // alto durante los pixeles activos de la linea
    input  wire       sync,           // pulso: empieza un cuadro nuevo (ver cabecera)
    input  wire [7:0] pix_y,
    input  wire       pix_valid,
    input  wire       invertir,
    output reg        out_valid,
    output reg  [7:0] out_pix,
    output reg        frame_fin       // pulso tras emitir el ultimo pixel de las 28x28
);
    localparam integer BLK = WIN / N;
    // El divisor del promedio son BLK*BLK pixeles. Estaba FIJO en /256
    //   (`fila[ex][15:8]`), que
    // solo es correcto para WIN=448 -bloques de 16x16-. Con cualquier otro WIN la
    //   imagen salia
    // casi negra, y el modulo se anunciaba parametrico igual. Ahora sale de BLK.
    localparam integer SH  = $clog2(BLK*BLK);
    localparam integer X0  = (CAM_W - WIN) / 2;
    localparam integer Y0  = (CAM_H - WIN) / 2;

    reg [9:0]  cx, cy;
    reg [15:0] acc  [0:N-1];       // acumuladores en curso
    reg [15:0] fila [0:N-1];       // COPIA de la fila terminada, para emitir en paralelo
    reg [4:0]  ox, ex;
    reg [4:0]  oy;                    // fila de salida ya emitida (0..27)
    reg [4:0]  sub_x;
    reg [4:0]  sub_y;
    reg        emitiendo;
    integer i;

    wire [15:0] prom_w = fila[ex] >> SH;
    wire [7:0]  prom   = (prom_w > 16'd255) ? 8'd255 : prom_w[7:0];

    reg  href_d;
    wire fin_linea = href_d & ~href;                 // flanco de bajada: termino la linea
    wire dentro_x = (cx >= X0) && (cx < X0 + WIN);
    wire dentro_y = (cy >= Y0) && (cy < Y0 + WIN);
    wire fin_blk  = fin_linea && dentro_y && (sub_y == BLK-1);  // se completo una fila de salida

    always @(posedge pclk) begin
        href_d <= href;
        if (reset) begin
            cx <= 0; cy <= 0; ox <= 0; ex <= 0; oy <= 0; href_d <= 1'b0;
            sub_x <= 0; sub_y <= 0; emitiendo <= 1'b0;
            out_valid <= 1'b0; out_pix <= 8'd0; frame_fin <= 1'b0;
            for (i = 0; i < N; i = i + 1) begin acc[i] <= 16'd0; fila[i] <= 16'd0; end
        end else begin
            out_valid <= 1'b0; frame_fin <= 1'b0;

            // ---- el CUADRO se engancha con `sync` ----
            // Lo mismo que `href` hace por la columna, pero para la fila. Sin esto el
            //   error
            // vertical no se acumula: directamente nunca se sabe donde estaba el
            //   origen.
            if (sync) begin
                cy <= 0; oy <= 0; sub_y <= 0; emitiendo <= 1'b0;
                for (i = 0; i < N; i = i + 1) acc[i] <= 16'd0;
            end

            // ---- la columna se re-sincroniza CON CADA LINEA ----
            // Contar 640x480 pixeles y confiar en que la cuenta salga justa NO
            //   funciona: un
            // solo pixel de desvio corre la ventana y la imagen se vuelve ruido. La
            //   OV7670
            // marca cada linea activa con `href`, asi que la columna se pone en cero
            //   ahi y el
            // error no se acumula. Es exactamente lo que hace el cam_sobel_display
            //   probado.
            if (!href) begin cx <= 0; ox <= 0; sub_x <= 0; end

            // ---- fin de linea: avanzar fila ----
            if (fin_linea) begin
                if (cy == CAM_H-1) begin cy <= 0; sub_y <= 0; end   // auto-sync: envuelve solo
                else begin
                    cy <= cy + 10'd1;
                    if (dentro_y) sub_y <= (sub_y == BLK-1) ? 5'd0 : sub_y + 5'd1;
                end
            end

            // ---- acumulacion: NUNCA se detiene ----
            // La version anterior paraba de acumular mientras emitia, y los 28 ciclos
            //   del
            // volcado se comian 28 pixeles de la camara: la imagen salia corrida y
            //   comprimida.
            // Ahora la fila terminada se COPIA a `fila` en un ciclo y se emite desde
            //   ahi,
            // mientras `acc` sigue sumando la fila siguiente. Cuesta 28 registros mas.
            if (pix_valid && href) begin
                if (dentro_x && dentro_y) begin
                    acc[ox] <= acc[ox] + {8'd0, pix_y};
                    if (sub_x == BLK-1) begin
                        sub_x <= 0;
                        if (ox != N-1) ox <= ox + 5'd1;
                    end else sub_x <= sub_x + 5'd1;
                end
                if (cx != CAM_W-1) cx <= cx + 10'd1;
            end

            if (1'b1) begin
                if (fin_blk) begin
                    emitiendo <= 1'b1; ex <= 0;
                    for (i = 0; i < N; i = i + 1) begin fila[i] <= acc[i]; acc[i] <= 16'd0; end
                end
            end

            // ---- volcado en PARALELO a la acumulacion, desde la copia ----
            // prom = suma >> SH, saturado: el shift es la division por BLK*BLK
            if (emitiendo) begin
                out_valid <= 1'b1;
                out_pix   <= invertir ? (8'd255 - prom) : prom;
                if (ex == N-1) begin
                    emitiendo <= 1'b0; ex <= 0;
                    oy <= (oy == N-1) ? 5'd0 : oy + 5'd1;
                    if (oy == N-1) frame_fin <= 1'b1;      // ultimo pixel de las 28x28
                end else ex <= ex + 5'd1;
            end
        end
    end
endmodule
`default_nettype wire
```

### `mnist_feat.v`

```verilog
// mnist_feat.v — EXTRACTOR DE CARACTERISTICAS: pixel -> bordes -> histograma por zonas.
//
// Es el front-end de la tesis (el mismo que corre en los 10 chips) con una cola nueva:
//   en vez de escribir el borde a un framebuffer, lo CUENTA por orientacion y por zona.
//
//     stream 8b -> Gauss 3x3 /16 -> Sobel 3x3 -> |Gx|+|Gy| sat 255 -> umbral
// -> octante (3 comparaciones) -> contador[zona][bin]
//
// POR QUE OCTANTE Y NO atan2: el bin es {sgn(Gy), sgn(Gx), |Gy|>|Gx|}. Tres
//   comparaciones y
// cero multiplicaciones; un atan2 pediria un CORDIC o una tabla. Son los mismos 8
//   sectores de
// 45 grados, con los bordes en 0/45/90... en vez de centrados. El golden de Python se
//   cambio
// para modelar ESTO, que es la regla de toda la tesis: el golden modela lo que el
//   silicio hace.
//
// `clr` limpia el histograma SIN tocar los line-buffers. Hace falta porque la imagen
//   se manda
// dos veces -los buffers arrancan vacios y la primera pasada trae basura, igual que en
//   los
// bancos de verificacion-: al empezar la segunda hay que poner los contadores en
//   cero
// pero conservar las dos filas ya cargadas. Un `reset` a secas borraria las dos cosas.
//
// POR QUE 32 CONTADORES Y NO 40: la piramide es nivel 0+1 = 5 zonas x 8 orientaciones
//   = 40
// caracteristicas. Pero el nivel 0 (la imagen entera) es EXACTAMENTE la suma de los
//   cuatro
// cuadrantes -son una particion-, asi que no se guarda: se deriva sumando. Ocho
//   contadores
// menos, gratis. Es la misma idea de los metatiles: no guardes lo que podes
//   reconstruir.
`default_nettype none
module mnist_feat #(
    parameter integer H   = 28,     // alto de la imagen de entrada
    parameter integer W   = 28,     // ancho
    // bits por contador (cuadrante de 12x12 = 144 -> 8 bits bastan)
    parameter integer CW  = 9
)(
    input  wire            clk,
    input  wire            reset,          // sincrono, activo-alto: limpia TODO
    // limpia solo histograma y posicion (deja los line-buffers)
    input  wire            clr,
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
    // OJO: .W(W) y NO .W(W-2). El linebuf3x3 emite UNA salida por cada entrada -no
    //   descarta
    // el borde-, asi que la segunda etapa sigue viendo filas de W. Ponerle W-2 le
    //   desalinea el
    // envolvimiento de fila y ensucia el resultado.
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
    // <- el octante, sin una sola multiplicacion
    wire [2:0]  bin = {sgy, sgx, (agy > agx)};

    // ---------------- posicion, y la latencia del pipeline ----------------
    // El linebuf3x3 emite UNA salida por cada entrada: el raster de salida tiene la
    //   misma
    // forma HxW que el de entrada, con basura en el borde. Cada etapa retrasa W+2
    //   muestras:
    // W+1 porque la ventana centrada en (r,c) recien esta cuando entro (r+1,c+1) -eso
    //   es lo
    // que midio el banco de latencia- MAS 2 por el pipeline interno del propio linebuf (etapa
    //   de
    // lectura + etapa de ventana)... y de esos 2 solo se ve 1 en el indice de muestra.
    // El valor exacto se CALIBRO contra el golden barriendo LAT: 60 para W=28, o sea
    //   2*(W+2).
    // Con LAT=2*(W+1)=58 el histograma queda corrido DOS COLUMNAS y las zonas se
    //   mezclan,
    // aunque el total de bordes sea correcto. Es la misma trampa que midio ese banco: el
    //   total
    // no cambia con un corrimiento, asi que hay que mirar la distribucion, no la suma.
    localparam integer LAT = 2*(W+2);
    reg [$clog2(LAT+1)-1:0] lat_cnt;
    wire arrancado = (lat_cnt == LAT);
    reg [$clog2(W)-1:0] cx;
    reg [$clog2(H)-1:0] cy;
    wire interior = (cy >= 2) && (cy <= H-3) && (cx >= 2) && (cx <= W-3);
    wire [1:0] zona = {(cy-2) >= HV/2, (cx-2) >= WV/2};   // cuadrante sobre el area valida
    wire ult_pix = (cy == H-3) && (cx == W-3);

    // ---------------- los 32 contadores ----------------
    // `listo` congela el histograma cuando termina el cuadro: sin el, frame_done
    //   vuelve a
    // pulsar al envolver el raster y el clasificador correria con los contadores
    //   moviendose
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
                    // arranca el clasificador y congela
                    if (ult_pix) begin frame_done <= 1'b1; listo <= 1'b1; end
                end
            end
        end
    end
    // se empaquetan en un bus: yosys no admite puertos de array en Verilog-2005, y un
    //   bus
    // plano es ademas lo que espera cualquier flujo de sintesis.
    genvar k;
    generate for (k = 0; k < 32; k = k + 1) begin : sal
        assign cnt_o[k*CW +: CW] = cnt[k];
    end endgenerate
endmodule
`default_nettype wire
```

### `mnist_clf.v`

```verilog
// mnist_clf.v — CLASIFICADOR: 40 caracteristicas -> 10 puntajes -> el digito.
//
// Un producto matriz-vector y un maximo. Nada mas: sin capas ocultas, sin activacion,
//   sin
// realimentacion. Se hace SERIE -una multiplicacion-acumulacion por ciclo, 400 ciclos-
//   porque
// el cuadro tarda ~800 ciclos en entrar: el clasificador termina antes de que llegue
//   el
// siguiente. Hacerlo paralelo costaria 400 multiplicadores para ganar un tiempo que
//   sobra.
//
//   Las 40 caracteristicas se arman al vuelo desde los 32 contadores:
//     k = 0..7   -> nivel 0: suma de los cuatro cuadrantes en esa orientacion
//     k = 8..39  -> nivel 1: el contador del cuadrante tal cual
//
// Los pesos son de 4 bits con signo y viven en una ROM sintetizada
//   (`mnist_weights.vh`,
// generado por entrenar_hw.py). Cambiar el modelo = regenerar ese archivo y re-
//   sintetizar;
// si el chip lleva CPU, el mismo mecanismo del periferico 0x0045 permitiria cargarlos.
`default_nettype none
module mnist_clf #(
    parameter integer CW = 9,       // bits por contador
    parameter integer AW = 22       // bits del acumulador con signo
)(
    input  wire            clk,
    input  wire            reset,
    input  wire            start,           // = frame_done del extractor
    input  wire [32*CW-1:0] cnt_i,
    input  wire [10:0]     n_bordes,        // total de bordes del cuadro
    output reg             done,
    output reg  [3:0]      digito,          // 0..9
    output reg             valido,          // 0 = NADA: no hay un digito reconocible
    output reg signed [AW-1:0] score        // el puntaje ganador (observabilidad)
);
`include "mnist_weights.vh"

    // el nivel 0 suma 4 cuadrantes: +2 bits
    localparam integer FW = CW + 2;
    localparam S_IDLE=2'd0, S_MAC=2'd1, S_ARGMAX=2'd2, S_DONE=2'd3;

    reg [1:0]  st;
    reg [3:0]  c;                                          // clase en curso  (0..9)
    reg [5:0]  k;                                          // caracteristica  (0..39)
    reg signed [AW-1:0] acc, mejor, segundo;
    reg [3:0]  mejor_c;

    // Umbrales del veredicto NADA, calibrados sobre 3 000 imagenes de test:
    // * densidad de bordes: un digito real deja entre 161 y 369 (p5..p95) de 576. Un
    //   cuadro
    // vacio deja 0 y una textura deja 500+. La densidad sola ya descarta los dos
    //   extremos.
    // * margen entre el mejor puntaje y el segundo: con la imagen EN BLANCO el
    //   clasificador
    // igual predice "1" con margen 112, porque el sesgo solo ya favorece esa clase.
    //   Por eso
    // el margen NO alcanza y la densidad es la que manda; el margen filtra los
    //   ambiguos.
    // Con 140/430/30: acepta el 86.7 % de los digitos, y entre los aceptados la
    //   precision sube
    // de 89.2 % a 93.9 % filtrando el 52 % de los errores. Decir "no se" mejora lo que
    //   si dice.
    localparam [10:0] B_MIN  = 11'd140;
    localparam [10:0] B_MAX  = 11'd430;
    localparam signed [AW-1:0] MARGEN = 30;

    // caracteristica k: nivel 0 (suma de cuadrantes) o nivel 1 (contador directo)
    // desempaquetado del bus a un array de wires (una funcion con part-select variable
    // sobre un puerto da X en iverilog; el generate es equivalente y portable)
    wire [CW-1:0] c_arr [0:31];
    genvar gi;
    generate for (gi = 0; gi < 32; gi = gi + 1) begin : desemp
        assign c_arr[gi] = cnt_i[gi*CW +: CW];
    end endgenerate

    wire [4:0] i0 = {2'd0, k[2:0]}, i1 = {2'd1, k[2:0]},
               i2 = {2'd2, k[2:0]}, i3 = {2'd3, k[2:0]};
    wire [4:0] i1n = k[4:0] - 5'd8;
    wire [FW-1:0] feat = (k < 6'd8)
        ? ({2'b00,c_arr[i0]} + {2'b00,c_arr[i1]} + {2'b00,c_arr[i2]} + {2'b00,c_arr[i3]})
        : {2'b00, c_arr[i1n]};

    wire signed [WB-1:0]      w    = w_rom({3'd0, c} * N_CARAC + k);
    wire signed [FW+WB-1:0]   prod = $signed({1'b0, feat}) * w;

    always @(posedge clk) begin
        if (reset) begin
            st <= S_IDLE; c <= 0; k <= 0; acc <= 0;
            mejor <= 0; segundo <= 0; mejor_c <= 0; done <= 1'b0; digito <= 4'd0;
            score <= 0; valido <= 1'b0;
        end else begin
            done <= 1'b0;
            case (st)
                S_IDLE: if (start) begin
                    c <= 0; k <= 0; acc <= b_rom(4'd0); mejor <= 0; segundo <= 0;
                    mejor_c <= 0; st <= S_MAC;
                end
                S_MAC: begin
                    acc <= acc + prod;
                    if (k == N_CARAC-1) begin
                        k <= 0; st <= S_ARGMAX;
                    end else k <= k + 1'b1;
                end
                S_ARGMAX: begin
                    // el acumulado de la clase c ya esta completo: comparar y guardar
                    //   los DOS
                    // mejores, que es lo que permite medir la confianza sin dividir
                    //   nada.
                    // Las DOS primeras clases se tratan aparte, y no es un capricho:
                    // * con `segundo` arrancando en CERO, si el segundo mejor puntaje
                    //   real era
                    // negativo nunca lo superaba y `mejor - segundo` valia `mejor`, un
                    //   numero
                    // grande: el margen siempre pasaba y la clase NADA aceptaba el 100
                    //   %.
                    // * con `segundo` arrancando en el MINIMO con signo, la resta
                    //   DESBORDA los
                    //     AW bits y el resultado sale indefinido.
                    // Sin centinela no hay ninguno de los dos problemas: en c==1 ya
                    //   hay dos
                    // puntajes reales y se ordenan directamente.
                    if (c == 4'd0) begin mejor <= acc; mejor_c <= c; end
                    else if (c == 4'd1) begin
                        if (acc > mejor) begin segundo <= mejor; mejor <= acc; mejor_c <= c; end
                        else segundo <= acc;
                    end
                    else if (acc > mejor) begin segundo <= mejor; mejor <= acc; mejor_c <= c; end
                    else if (acc > segundo) segundo <= acc;
                    if (c == N_CLASE-1) begin
                        st <= S_DONE;
                    end else begin
                        acc <= b_rom(c + 4'd1); c <= c + 4'd1; st <= S_MAC;
                    end
                end
                S_DONE: begin
                    digito <= mejor_c;
                    score  <= mejor;
                    valido <= (n_bordes >= B_MIN) && (n_bordes <= B_MAX)
                              && ((mejor - segundo) > MARGEN);
                    done   <= 1'b1; st <= S_IDLE;
                end
                // sin default se infieren latches
                default: st <= S_IDLE;
            endcase
        end
    end
endmodule
`default_nettype wire
```

## G.15 Pan Canny (§6.3.2)

`pan_canny.v` y `soc_mnist_canny_fw_top.v` cambian respecto de la G.14 en el programa —los dos
umbrales, `0x5A20`— y en el extractor, `mnist_feat_canny.v`, que añade el doble umbral y la histéresis.
El clasificador, `mnist_clf_canny_fw.v`, es el `mnist_clf.v` de la G.14 con otro nombre, otros pesos
(`mnist_weights_canny_fw.vh`) y otros límites de rechazo: 174 y 376 bordes y un margen de 70, en lugar
de 140, 430 y 30. `soc_ctrl.v` y `cam_win28.v` son los de la G.14.

Carpeta: `Verilog_Repo/pan_canny/`.

### `pan_canny.v`

```verilog
// pan_canny.v — con Canny 1-salto: EL CHIP QUE MIRA Y RECONOCE.
//
// OV7670  ->  cam_win28  ->  [SoC femto: FemtoRV32 + periferico 0x0045 + Canny
//   1-salto]
// -> mnist_feat_canny -> mnist_clf_canny  ->  0..9 o NADA
//
//   A diferencia de los seis chips anteriores de la tesis, este NO lleva framebuffer ni
//   driver de LCD: no dibuja, RECONOCE. La salida no es una imagen, son cuatro bits y
//   un bit de "me lo creo".
//
//   Los pines de entrada son los de la camara tal como salen del sensor: pclk, href y
//   el byte de luma ya extraido. `invertir` queda cableado a 1 porque MNIST es trazo
//   CLARO sobre fondo oscuro y la tinta sobre papel es al reves.
`default_nettype none
module pan_canny (
    // ---- lado camara (OV7670) ----
    input  wire       pclk,          // reloj de pixel del sensor
    input  wire       reset,         // sincrono, activo-alto
    input  wire       href,          // alto durante los pixeles activos de la linea
    input  wire       sync,          // pulso de cuadro nuevo (a 0 si no se usa)
    input  wire [7:0] pix_y,         // luma
    input  wire       pix_valid,
    // ---- lado resultado ----
    output wire       done,          // pulso: hay veredicto
    output wire [3:0] digito,        // 0..9
    output wire       valido,        // 0 = NADA ("no se")
    output wire [7:0] thr_hi_o,      // observabilidad: los DOS umbrales que uso
    output wire [7:0] thr_lo_o,
    output wire       cpu_escribio   // observabilidad: el CPU alcanzo a escribirlos
);
    wire w_valid, w_fin;  wire [7:0] w_pix;
    cam_win28 #(.CAM_W(640), .CAM_H(480), .WIN(448), .N(28)) WIN (
        .pclk(pclk), .reset(reset), .href(href), .sync(sync),
        .pix_y(pix_y), .pix_valid(pix_valid), .invertir(1'b1),
        .out_valid(w_valid), .out_pix(w_pix), .frame_fin(w_fin));

    // clr cuando el clasificador TERMINA, no en cada cuadro: el video es continuo y el
    // raster se encadena solo. Con clr por cuadro la latencia se reinicia y nunca
    //   cuenta.
    reg clr = 1'b0;
    always @(posedge pclk) clr <= done;

    // UMBRALES = 16'h5A20 -> thr_hi=90, thr_lo=32: el firmware propio del Canny
    soc_mnist_canny_fw_top #(.H(28), .W(28), .CW(9), .UMBRALES(16'h5A20)) CLF (
        .clk(pclk), .reset(reset), .clr(clr),
        .in_valid(w_valid), .in_pix(w_pix),
        .done(done), .digito(digito), .valido(valido),
        .thr_hi_o(thr_hi_o), .thr_lo_o(thr_lo_o), .cpu_escribio(cpu_escribio));
endmodule
`default_nettype wire
```

### `soc_mnist_canny_fw_top.v`

```verilog
// soc_mnist_canny_top.v — SoC femto + CANNY 1-salto + clasificador.
// Igual que soc_mnist_top.v pero con el front-end Canny, y con el firmware
//   PARAMETRIZADO:
//   la constante que el CPU escribe en 0x0045+4 lleva los DOS umbrales empaquetados.
//
//     UMBRALES = 16'h5A00  ->  thr_hi=90  thr_lo=0    (el firmware ORIGINAL, del Sobel)
//     UMBRALES = 16'h5A20  ->  thr_hi=90  thr_lo=32   (el firmware propio del Canny)
//
// Se midio que la diferencia son 2.10 puntos de exactitud sobre las
//   10 000 imagenes. Este banco la muestra sobre once escenas, en hardware simulado.
`default_nettype none
module soc_mnist_canny_fw_top #(
    parameter integer H = 28, parameter integer W = 28, parameter integer CW = 9,
    parameter [15:0]  UMBRALES = 16'h5A20
)(
    input  wire       clk,
    input  wire       reset,
    input  wire       clr,
    input  wire       in_valid,
    input  wire [7:0] in_pix,
    output wire       done,
    output wire [3:0] digito,
    output wire       valido,
    output wire [7:0] thr_hi_o,
    output wire [7:0] thr_lo_o,
    output wire       cpu_escribio
);
    wire [7:0] thr_hi, thr_lo;
    soc_ctrl #(.UMBRALES(UMBRALES)) SOC (
        .clk(clk), .resetn(~reset), .thr_o(thr_hi), .thr_lo_o(thr_lo), .cpu_wrote(cpu_escribio));
    // soc_ctrl expone thr_hi; el thr_lo sale del mismo periferico

    assign thr_hi_o = thr_hi;
    assign thr_lo_o = thr_lo;

    wire [32*CW-1:0] cnt;
    wire [10:0] n_bordes;
    wire fdone;
    mnist_feat_canny #(.H(H),.W(W),.CW(CW)) FEAT (
        .clk(clk),.reset(reset),.clr(clr),.in_valid(in_valid),.in_pix(in_pix),
        .thr_hi(thr_hi),.thr_lo(thr_lo),
        .frame_done(fdone),.cnt_o(cnt),.n_bordes(n_bordes),
        .dbg_val(),.dbg_borde(),.dbg_cx(),.dbg_cy(),.dbg_arr());
    mnist_clf_canny_fw #(.CW(CW)) CLF (
        .clk(clk),.reset(reset),.start(fdone),.cnt_i(cnt),.n_bordes(n_bordes),
        .done(done),.digito(digito),.valido(valido),.score());
endmodule
`default_nettype wire
```

### `mnist_feat_canny.v`

```verilog
// mnist_feat_canny.v — EXTRACTOR con front-end CANNY 1-SALTO en vez de umbral simple.
//
// Es `mnist_feat.v` con una tercera etapa: doble umbral (clase 2/1/0) + histeresis de
//   un salto.
// Motivado por lo que se midio en simulacion: este front-end
//   aguanta
//   +17 pp mejor la iluminacion despareja y -16 pp peor el ruido de sensor.
//
// EL TRUCO DE LA TERCERA VENTANA: hace falta el vecindario 3x3 del mapa de CLASES,
//   pero tambien
// la orientacion del pixel CENTRAL de ese vecindario -que ya quedo tres etapas atras-.
//   En vez de
//   agregar una linea de retardo aparte para la orientacion, viajan JUNTAS por el mismo
// linebuf3x3, empaquetadas en 5 bits: {octante[2:0], clase[1:0]}. El tap central da
//   las dos
//   cosas alineadas por construccion, y no hay forma de que se desincronicen.
//
// Es el front-end de la tesis (el mismo que corre en los 10 chips) con una cola nueva:
//   en vez de escribir el borde a un framebuffer, lo CUENTA por orientacion y por zona.
//
//     stream 8b -> Gauss 3x3 /16 -> Sobel 3x3 -> |Gx|+|Gy| sat 255 -> umbral
// -> octante (3 comparaciones) -> contador[zona][bin]
//
// POR QUE OCTANTE Y NO atan2: el bin es {sgn(Gy), sgn(Gx), |Gy|>|Gx|}. Tres
//   comparaciones y
// cero multiplicaciones; un atan2 pediria un CORDIC o una tabla. Son los mismos 8
//   sectores de
// 45 grados, con los bordes en 0/45/90... en vez de centrados. El golden de Python se
//   cambio
// para modelar ESTO, que es la regla de toda la tesis: el golden modela lo que el
//   silicio hace.
//
// `clr` limpia el histograma SIN tocar los line-buffers. Hace falta porque la imagen
//   se manda
// dos veces -los buffers arrancan vacios y la primera pasada trae basura, igual que en
//   los
// bancos de verificacion-: al empezar la segunda hay que poner los contadores en
//   cero
// pero conservar las dos filas ya cargadas. Un `reset` a secas borraria las dos cosas.
//
// POR QUE 32 CONTADORES Y NO 40: la piramide es nivel 0+1 = 5 zonas x 8 orientaciones
//   = 40
// caracteristicas. Pero el nivel 0 (la imagen entera) es EXACTAMENTE la suma de los
//   cuatro
// cuadrantes -son una particion-, asi que no se guarda: se deriva sumando. Ocho
//   contadores
// menos, gratis. Es la misma idea de los metatiles: no guardes lo que podes
//   reconstruir.
`default_nettype none
module mnist_feat_canny #(
    parameter integer H   = 28,     // alto de la imagen de entrada
    parameter integer W   = 28,     // ancho
    parameter integer CW  = 9,      // bits por contador
    parameter integer LATP = 0      // 0 = usar 3*(W+2); >0 = forzar (para CALIBRAR)
)(
    input  wire            clk,
    input  wire            reset,          // sincrono, activo-alto: limpia TODO
    // limpia solo histograma y posicion (deja los line-buffers)
    input  wire            clr,
    input  wire            in_valid,
    input  wire [7:0]      in_pix,
    input  wire [7:0]      thr_hi,         // umbral ALTO: borde fuerte
    // umbral BAJO: borde debil (sobrevive si toca uno fuerte)
    input  wire [7:0]      thr_lo,
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
    // OJO: .W(W) y NO .W(W-2). El linebuf3x3 emite UNA salida por cada entrada -no
    //   descarta
    // el borde-, asi que la segunda etapa sigue viendo filas de W. Ponerle W-2 le
    //   desalinea el
    // envolvimiento de fila y ensucia el resultado.
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
    // el octante, sin una sola multiplicacion
    wire [2:0]  bin_raw = {sgy, sgx, (agy > agx)};

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
    // la orientacion del MISMO pixel central
    wire [2:0]  bin = c11[4:2];

    // ---------------- posicion, y la latencia del pipeline ----------------
    // El linebuf3x3 emite UNA salida por cada entrada: el raster de salida tiene la
    //   misma
    // forma HxW que el de entrada, con basura en el borde. Cada etapa retrasa W+2
    //   muestras:
    // W+1 porque la ventana centrada en (r,c) recien esta cuando entro (r+1,c+1) -eso
    //   es lo
    // que midio el banco de latencia- MAS 2 por el pipeline interno del propio linebuf (etapa
    //   de
    // lectura + etapa de ventana)... y de esos 2 solo se ve 1 en el indice de muestra.
    // Con la tercera etapa del Canny son 3*(W+2) = 90 para W=28. Se verifica igual que
    //   antes:
    // contra el golden, contador por contador -no por la suma, que no cambia con un
    //   corrimiento-.
    // Con LAT=2*(W+1)=58 el histograma queda corrido DOS COLUMNAS y las zonas se
    //   mezclan,
    // aunque el total de bordes sea correcto. Es la misma trampa que midio ese banco: el
    //   total
    // no cambia con un corrimiento, asi que hay que mirar la distribucion, no la suma.
    localparam integer LAT = (LATP != 0) ? LATP : 3*(W+2);   // TRES etapas, no dos
    reg [$clog2(LAT+1)-1:0] lat_cnt;
    wire arrancado = (lat_cnt == LAT);
    reg [$clog2(W)-1:0] cx;
    reg [$clog2(H)-1:0] cy;
    wire interior = (cy >= 3) && (cy <= H-4) && (cx >= 3) && (cx <= W-4);
    wire [1:0] zona = {(cy-3) >= HV/2, (cx-3) >= WV/2};   // cuadrante sobre el area valida
    wire ult_pix = (cy == H-4) && (cx == W-4);

    // ---------------- los 32 contadores ----------------
    // `listo` congela el histograma cuando termina el cuadro: sin el, frame_done
    //   vuelve a
    // pulsar al envolver el raster y el clasificador correria con los contadores
    //   moviendose
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
                    // arranca el clasificador y congela
                    if (ult_pix) begin frame_done <= 1'b1; listo <= 1'b1; end
                end
            end
        end
    end
    // se empaquetan en un bus: yosys no admite puertos de array en Verilog-2005, y un
    //   bus
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
```

## G.16 Visión Sobel MNIST (§6.3.3)

`vision_sobel_mnist.v` es el circuito entero salvo el reconocedor: configuración de la cámara, ventana,
*framebuffer* de 28×28, cruce del dígito entre relojes y controlador de pantalla. `glifo.v` dibuja el
dígito en siete segmentos, y `mnist_top.v` une el extractor y el clasificador de la G.14.

Carpeta: `Verilog_Repo/vision_sobel_mnist/`.

### `vision_sobel_mnist.v`

```verilog
// vision_sobel_mnist.v — EL CHIP QUE VE UN DIGITO Y DICE CUAL ES, para ASIC sky130.
//   camara OV7670 -> ventana central 448x448 -> 28x28 -> CLASIFICADOR -> TFT ILI9341.
//
// Portado del diseno FISICO verificado en FPGA (mnist_cam_display.v, 8/10 en silicio).
//   Los MISMOS 3 cambios ASIC que se le hicieron a vision_top.v:
// (1) RESET EXPLICITO (rst_n) en todos los FSM -> en silicio los FF arrancan
//   aleatorios,
//         y en FPGA los inicializaba el bitstream.  Aqui no hay quien los inicialice.
// (2) cam_sda open-drain (inout, 1'bz) partido en cam_sda_o/cam_sda_oe -> el tri-state
//         vive en el anillo de pads, no en el nucleo.
// (3) sin SB_RGBA_DRV (el driver de LED es una primitiva de iCE40). Las tres senales
//   de
//         estado salen como pines normales.
//   Y una limpieza: `pcount` y `cam_sync` estaban declarados y no los leia nadie.
//
//   DUAL-CLOCK, igual que vision_top: SCCB + display en 'clk'; captura, ventana y
//   clasificador en 'cam_pclk'.  El cruce del digito son 2 FF (es casi-estatico).
//
//   LOS DOS FRAMEBUFFERS NO SE RESETEAN, como el de vision_top y el del transitivo: se
//   llenan antes de leerse, y resetear 784 bytes cuesta celdas que no compran nada.
`default_nettype none
module vision_sobel_mnist #(
    // INVERTIR=1: trazo claro sobre fondo oscuro, como MNIST (modo normal).
    parameter INVERTIR = 1
) (
    input  wire       clk,
    input  wire       rst_n,
    // ---- camara OV7670 ----
    output wire       cam_xclk,
    output reg        cam_scl,
    output wire       cam_sda_o,     // open-drain: dato (siempre 0 cuando activo)
    output wire       cam_sda_oe,    // open-drain: enable -> el pad hace el tri-state
    input  wire       cam_pclk,
    input  wire       cam_href,
    input  wire [7:0] cam_d,
    // ---- display PMOD TFTLCD ----
    output wire       tft_sck,
    output wire       tft_mosi,
    output wire       tft_cs,
    output wire       tft_dc,
    // ---- estado (antes iban al LED RGB de la placa) ----
    output reg        cfg_done,      // la camara quedo configurada
    output reg        hubo,          // clasifico al menos una vez
    output wire [3:0] digito         // el ultimo digito; 10 = "no se"
);
    assign cam_xclk = clk;

    // ==================== SCCB config (dominio clk) ====================
    reg sda_oe;
    assign cam_sda_o  = 1'b0;
    assign cam_sda_oe = sda_oe;

    reg [5:0] tdiv;
    wire tick = (tdiv == 6'd29);
    always @(posedge clk or negedge rst_n)
        if (!rst_n) tdiv <= 6'd0; else tdiv <= tick ? 6'd0 : tdiv + 1'b1;

    reg [4:0] idx;
    reg [15:0] rom;
    always @(*) case (idx)
        5'd0:  rom = 16'h12_00;
        5'd1:  rom = 16'h13_E7;
        5'd2:  rom = 16'h09_18;
        default: rom = 16'hFF_FF;
    endcase
    wire       tbl_end  = (rom == 16'hFF_FF);
    wire [7:0] reg_addr = rom[15:8];
    wire [7:0] reg_val  = rom[7:0];

    localparam C_START=3'd0, C_WR=3'd1, C_STOP=3'd2, C_DLY=3'd3, C_NEXT=3'd4;
    reg [2:0]  cpc;
    reg [1:0]  cph;
    reg [3:0]  cbi;
    reg [15:0] cdly;

    reg [2:0] coptype;
    always @(*) case (cpc)
        3'd0: coptype=C_START; 3'd1: coptype=C_WR; 3'd2: coptype=C_WR;
        3'd3: coptype=C_WR;    3'd4: coptype=C_STOP; 3'd5: coptype=C_DLY;
        default: coptype=C_NEXT;
    endcase
    reg [7:0] cwbyte;
    always @(*) case (cpc)
        3'd1: cwbyte=8'h42; 3'd2: cwbyte=reg_addr; 3'd3: cwbyte=reg_val;
        default: cwbyte=8'h00;
    endcase

    reg [19:0] cboot;
    wire cboot_ok = &cboot;
    always @(posedge clk or negedge rst_n)
        if (!rst_n) cboot <= 20'd0; else if (!cboot_ok) cboot <= cboot + 1'b1;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cpc <= 3'd0; cph <= 2'd0; cbi <= 4'd0; cdly <= 16'd0;
            cfg_done <= 1'b0; sda_oe <= 1'b0; cam_scl <= 1'b1; idx <= 5'd0;
        end else if (tick && cboot_ok && !cfg_done) begin
            case (coptype)
            C_START: begin
                if (tbl_end) cfg_done <= 1'b1;
                else begin
                    case (cph)
                        2'd0: begin sda_oe<=1'b0; cam_scl<=1'b1; end
                        2'd1: begin sda_oe<=1'b1; cam_scl<=1'b1; end
                        2'd2: cam_scl<=1'b0;
                        2'd3: cpc<=cpc+1'b1;
                    endcase
                    cph <= cph + 1'b1;
                end
            end
            C_WR: begin
                case (cph)
                    2'd0: begin cam_scl<=1'b0; if (cbi<4'd8) sda_oe<=~cwbyte[3'd7-cbi[2:0]];
                        else sda_oe<=1'b0; end
                    2'd1: cam_scl<=1'b1; 2'd2: cam_scl<=1'b1;
                    2'd3: begin cam_scl<=1'b0; if (cbi==4'd8) begin cbi<=4'd0; cpc<=cpc+1'b1;
                        end else cbi<=cbi+1'b1; end
                endcase
                cph <= cph + 1'b1;
            end
            C_STOP: begin
                case (cph)
                    2'd0: begin cam_scl<=1'b0; sda_oe<=1'b1; end
                    2'd1: begin cam_scl<=1'b1; sda_oe<=1'b1; end
                    2'd2: begin cam_scl<=1'b1; sda_oe<=1'b0; end
                    2'd3: begin cpc<=cpc+1'b1; cdly<=16'd999; end
                endcase
                cph <= cph + 1'b1;
            end
            C_DLY: if (cdly==16'd0) cpc<=cpc+1'b1; else cdly<=cdly-1'b1;
            default: begin idx<=idx+1'b1; cpc<=3'd0; end
            endcase
        end
    end

    // ======== ventana central 448x448 -> 28x28 promediado e invertido (dominio pclk)
    //   ========
    // La camara entrega YUV422 y la luma es el SEGUNDO byte del par (U Y V Y).
    //   Capturar en
    // parity==0 tomaba la CROMA (~0x80 constante) — lo que el diagnostico por UART
    //   mostro.
    reg parity, href_d;
    reg [7:0] curY;
    reg py_valid;
    always @(posedge cam_pclk or negedge rst_n) begin
        if (!rst_n) begin
            parity <= 1'b0; href_d <= 1'b0; curY <= 8'd0; py_valid <= 1'b0;
        end else begin
            href_d <= cam_href; py_valid <= 1'b0;
            if (~cam_href) parity <= 1'b0;
            else begin
                if (parity == 1'b1) begin curY <= cam_d; py_valid <= 1'b1; end
                parity <= ~parity;
            end
        end
    end

    wire       w_valid; wire [7:0] w_pix; wire w_fin;
    cam_win28 #(.CAM_W(640),.CAM_H(480),.WIN(448),.N(28)) WIN (
        .pclk(cam_pclk), .sync(1'b0), .reset(~cfg_done | ~rst_n), .href(cam_href),
        .pix_y(curY), .pix_valid(py_valid), .invertir(INVERTIR[0]),
        .out_valid(w_valid), .out_pix(w_pix), .frame_fin(w_fin));

    // ======== el clasificador (el MISMO verificado bit a bit contra el golden)
    //   ========
    wire       clf_done; wire [3:0] clf_dig; wire clf_val;
    // clr cuando TERMINA de clasificar, no en cada cuadro: el video es continuo y el
    //   raster se
    // encadena solo. El clasificador se autorregula: acumula, clasifica, limpia,
    //   repite.
    reg        clf_clr;
    always @(posedge cam_pclk or negedge rst_n)
        if (!rst_n) clf_clr <= 1'b0; else clf_clr <= clf_done;
    mnist_top #(.H(28),.W(28),.CW(9)) CLF (
        .clk(cam_pclk), .reset(~cfg_done | ~rst_n), .clr(clf_clr),
        .in_valid(w_valid), .in_pix(w_pix), .thr(8'd60),
        .done(clf_done), .digito(clf_dig), .valido(clf_val));

    // digito reconocido, cruzado al dominio del display (casi-estatico: 2 FF bastan).
    // Si el clasificador dice NADA se muestra el codigo 10, que el glifo dibuja como
    //   una raya.
    // Poder decir "no se" no es adorno: entre los cuadros que si contesta, la
    //   precision sube
    //   de 89.2 % a 93.9 %.
    reg [3:0] dig_pclk;
    always @(posedge cam_pclk or negedge rst_n) begin
        if (!rst_n) begin dig_pclk <= 4'd10; hubo <= 1'b0; end
        else if (clf_done) begin
            dig_pclk <= clf_val ? clf_dig : 4'd10;
            hubo <= 1'b1;
        end
    end
    reg [3:0] dig_s1, dig_clk;
    reg       hubo_s1, hubo_clk;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dig_s1 <= 4'd10; dig_clk <= 4'd10; hubo_s1 <= 1'b0; hubo_clk <= 1'b0;
        end else begin
            dig_s1 <= dig_pclk;  dig_clk  <= dig_s1;
            hubo_s1 <= hubo;     hubo_clk <= hubo_s1;
        end
    end
    assign digito = dig_clk;

    // ======== framebuffer de las 28x28 (784 bytes) — SIN reset, se llena antes de
    //   leerse ====
    // El CONTADOR se resetea; la MEMORIA no, y van en bloques SEPARADOS a proposito:
    //   una
    // memoria escrita dentro de un always con reset asincrono NO se infiere como
    //   memoria.
    // yosys avisa "mem2reg_wr ... ADDR is used but has no driver", se pierde la
    //   escritura y
    //   el framebuffer desaparece del netlist. Es el mismo patron que usa vision_top.
    reg [7:0]  fb [0:783];
    reg [9:0]  wadr;
    always @(posedge cam_pclk or negedge rst_n) begin
        if (!rst_n) wadr <= 10'd0;
        else begin
            if (w_valid) wadr <= (wadr == 10'd783) ? 10'd0 : wadr + 10'd1;
            if (w_fin)   wadr <= 10'd0;      // w_fin manda: es la ultima asignacion
        end
    end
    always @(posedge cam_pclk) if (w_valid) fb[wadr] <= w_pix;
    reg [7:0] fb_rd;

    // ==================== display ILI9341 (dominio clk) ====================
    reg        spi_start;
    reg  [7:0] spi_byte;
    reg        spi_dcbit;
    reg        spi_done;
    reg sck, mosi, cs, dc;
    assign tft_sck=sck; assign tft_mosi=mosi; assign tft_cs=cs; assign tft_dc=dc;

    localparam S_IDLE=2'd0, S_LO=2'd1, S_HI=2'd2, S_END=2'd3;
    reg [1:0] sst;
    reg [2:0] sbit;
    reg [7:0] sbuf;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            spi_done <= 1'b0; sst <= S_IDLE; sbit <= 3'd0; sbuf <= 8'd0;
            sck <= 1'b0; mosi <= 1'b0; cs <= 1'b1; dc <= 1'b1;
        end else begin
            spi_done <= 1'b0;
            case (sst)
                S_IDLE: if (spi_start) begin cs<=1'b0; dc<=spi_dcbit; sbuf<=spi_byte;
                    sbit<=3'd0; sck<=1'b0; sst<=S_LO; end
                S_LO:  begin sck<=1'b0; mosi<=sbuf[7]; sst<=S_HI; end
                S_HI:  begin sck<=1'b1; sbuf<={sbuf[6:0],1'b0}; if (sbit==3'd7) sst<=S_END;
                    else begin sbit<=sbit+1'b1; sst<=S_LO; end end
                S_END: begin sck<=1'b0; spi_done<=1'b1; sst<=S_IDLE; end
            endcase
        end
    end

    localparam T_CMD=2'd0, T_DAT=2'd1, T_DLY=2'd2, T_END=2'd3;
    localparam M_BOOT=2'd0, M_INIT=2'd1, M_FRAME=2'd2, M_FILL=2'd3;
    reg [1:0] mode;
    reg [4:0] ip;

    reg [1:0] rt; reg [7:0] rb;
    always @(*) begin
        rt=T_END; rb=8'h00;
        if (mode==M_INIT) case (ip)
            5'd0: begin rt=T_CMD; rb=8'h01; end
            5'd1: begin rt=T_DLY; rb=8'h00; end
            5'd2: begin rt=T_CMD; rb=8'h11; end
            5'd3: begin rt=T_DLY; rb=8'h00; end
            5'd4: begin rt=T_CMD; rb=8'h3A; end
            5'd5: begin rt=T_DAT; rb=8'h55; end
            5'd6: begin rt=T_CMD; rb=8'h36; end
            5'd7: begin rt=T_DAT; rb=8'h48; end
            5'd8: begin rt=T_CMD; rb=8'h29; end
            default: begin rt=T_END; rb=8'h00; end
        endcase
        else case (ip)
            5'd0:  begin rt=T_CMD; rb=8'h2A; end
            5'd1:  begin rt=T_DAT; rb=8'h00; end
            5'd2:  begin rt=T_DAT; rb=8'h00; end
            5'd3:  begin rt=T_DAT; rb=8'h00; end
            5'd4:  begin rt=T_DAT; rb=8'hEF; end
            5'd5:  begin rt=T_CMD; rb=8'h2B; end
            5'd6:  begin rt=T_DAT; rb=8'h00; end
            5'd7:  begin rt=T_DAT; rb=8'h00; end
            5'd8:  begin rt=T_DAT; rb=8'h01; end
            5'd9:  begin rt=T_DAT; rb=8'h3F; end
            5'd10: begin rt=T_CMD; rb=8'h2C; end
            default: begin rt=T_END; rb=8'h00; end
        endcase
    end

    // ======== que color va en cada pixel de la pantalla (240x320) ========
    //   filas   0..223 : las 28x28 ampliadas x8, con marco verde de 3 px
    //   filas 232..319 : el digito reconocido en siete segmentos
    reg [7:0] xcol;
    reg [8:0] ycol;

    localparam integer IMG = 224;              // 28 * 8
    localparam integer BORDE = 3;
    // en_img mira las DOS coordenadas: mirando solo ycol, las columnas 224..239 caian
    //   en el
    // marco derecho y pintaban una franja verde de 19 px en vez de 3.
    wire en_img  = (ycol < IMG) && (xcol < IMG);
    wire [4:0] ix = xcol[7:3];                 // /8
    wire [4:0] iy = ycol[7:3];
    wire [9:0] fbaddr = iy*28 + ix;
    always @(posedge clk) fb_rd <= fb[fbaddr];   // sin reset: acompana al framebuffer

    wire en_marco = en_img && ((xcol < BORDE) || (xcol >= IMG-BORDE) ||
                               (ycol < BORDE) || (ycol >= IMG-BORDE));

    localparam integer GY0 = 232, GW = 60, GH = 80;
    wire en_glifo_caja = (ycol >= GY0) && (ycol < GY0+GH) &&
                         (xcol >= (240-GW)/2) && (xcol < (240-GW)/2 + GW);
    wire glifo_on;
    // Los puertos gx/gy del glifo son de 8 bits, y `xcol - (240-GW)/2` sale de 32
    //   porque la
    // aritmetica con enteros SIN DIMENSIONAR es de 32 bits. iverilog lo avisa
    //   ("Pruning 24 high
    // bits") pero sigue; OpenLane lo rechaza con error duro ("Resizing cell port") y
    //   la sintesis
    // no arranca. Se dimensiona en dos wires: la poda ya ocurria, aqui solo se hace
    //   explicita.
    // Dentro de la caja gx va 0..59 y gy 0..79, asi que 8 bits sobran en los dos casos.
    wire [7:0] gx_off = xcol - (240-GW)/2;
    wire [8:0] gy_off = ycol - GY0;
    glifo #(.ANCHO(GW),.ALTO(GH),.GRUESO(11)) G (
        .digito(dig_clk),
        .gx(en_glifo_caja ? gx_off        : 8'd0),
        .gy(en_glifo_caja ? gy_off[7:0]   : 8'd0),
        .encendido(glifo_on));

    wire [15:0] gris  = {fb_rd[7:3], fb_rd[7:2], fb_rd[7:3]};
    wire [15:0] VERDE = 16'b00000_111111_00000;
    wire [15:0] AMBAR = 16'b11111_101101_00000;
    wire [15:0] NEGRO = 16'h0000;
    wire [15:0] pcolor = en_marco                        ? VERDE :
                         en_img                          ? gris  :
                         (en_glifo_caja && glifo_on && hubo_clk) ? AMBAR : NEGRO;

    reg [20:0] dcnt;
    reg [16:0] px;
    reg        pxhi;
    reg        sending;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            spi_start <= 1'b0; spi_byte <= 8'd0; spi_dcbit <= 1'b1;
            mode <= M_BOOT; ip <= 5'd0; dcnt <= 21'd0; px <= 17'd0;
            pxhi <= 1'b0; sending <= 1'b0; xcol <= 8'd0; ycol <= 9'd0;
        end else begin
            spi_start <= 1'b0;
            case (mode)
            M_BOOT: begin
                dcnt <= dcnt + 1'b1;
                if (dcnt == 21'd1_800_000) begin dcnt <= 21'd0; mode <= M_INIT; ip <= 5'd0; end
            end
            M_INIT: begin
                if (!sending) begin
                    case (rt)
                        T_CMD,T_DAT: begin spi_byte<=rb; spi_dcbit<=(rt==T_DAT);
                            spi_start<=1'b1; sending<=1'b1; end
                        T_DLY: if (dcnt==21'd1_800_000) begin dcnt<=21'd0; ip<=ip+1'b1;
                            end else dcnt<=dcnt+1'b1;
                        default: begin mode<=M_FRAME; ip<=5'd0; end
                    endcase
                end else if (spi_done) begin sending<=1'b0; ip<=ip+1'b1; end
            end
            M_FRAME: begin
                if (!sending) begin
                    case (rt)
                        T_CMD,T_DAT: begin spi_byte<=rb; spi_dcbit<=(rt==T_DAT);
                            spi_start<=1'b1; sending<=1'b1; end
                        default: begin mode<=M_FILL; px<=17'd0; pxhi<=1'b0; xcol<=8'd0;
                            ycol<=9'd0; end
                    endcase
                end else if (spi_done) begin sending<=1'b0; ip<=ip+1'b1; end
            end
            M_FILL: begin
                if (!sending) begin
                    spi_byte  <= pxhi ? pcolor[7:0] : pcolor[15:8];
                    spi_dcbit <= 1'b1; spi_start <= 1'b1; sending <= 1'b1;
                end else if (spi_done) begin
                    sending <= 1'b0;
                    if (pxhi) begin
                        pxhi <= 1'b0;
                        if (px == 17'd76799) begin px<=17'd0; mode<=M_FRAME; ip<=5'd0; end
                        else begin
                            px <= px + 1'b1;
                            if (xcol == 8'd239) begin xcol<=8'd0; ycol<=ycol+1'b1; end
                            else xcol <= xcol + 1'b1;
                        end
                    end else pxhi <= 1'b1;
                end
            end
            endcase
        end
    end
endmodule
`default_nettype wire
```

### `glifo.v`

```verilog
// glifo.v — el digito reconocido, grande, en la pantalla. Siete segmentos dibujados a
//   mano.
// Entra una coordenada (gx,gy) dentro de una caja de ANCHO x ALTO y el digito; sale 1
//   si ese
// punto cae sobre un segmento encendido. Es puramente combinacional: no hay memoria de
//   fuente,
// solo comparaciones. Una fuente de mapa de bits para 10 digitos costaria BRAM; esto
//   cuesta
//   unas pocas LUT, que es la diferencia entre que entre y que no.
`default_nettype none
module glifo #(
    parameter integer ANCHO = 60, parameter integer ALTO = 96, parameter integer GRUESO = 10
)(
    input  wire [3:0] digito,
    input  wire [7:0] gx, gy,
    output wire       encendido
);
    // segmentos:   a
    //            f   b
    //              g
    //            e   c
    //              d
    reg [6:0] seg;                       // {g,f,e,d,c,b,a}
    always @(*) case (digito)
        4'd0: seg = 7'b0111111;
        4'd1: seg = 7'b0000110;
        4'd2: seg = 7'b1011011;
        4'd3: seg = 7'b1001111;
        4'd4: seg = 7'b1100110;
        4'd5: seg = 7'b1101101;
        4'd6: seg = 7'b1111101;
        4'd7: seg = 7'b0000111;
        4'd8: seg = 7'b1111111;
        4'd9: seg = 7'b1101111;
        4'd10: seg = 7'b1000000;      // NADA: solo el segmento del medio -> una raya
        default: seg = 7'b0000000;
    endcase

    localparam integer MED = ALTO/2;
    wire hx = (gx >= GRUESO) && (gx < ANCHO-GRUESO);      // tramo horizontal (sin las esquinas)
    wire vy_a = (gy >= GRUESO) && (gy < MED-GRUESO/2);    // mitad de arriba
    wire vy_b = (gy >= MED+GRUESO/2) && (gy < ALTO-GRUESO);

    wire s_a = seg[0] && hx && (gy < GRUESO);
    wire s_b = seg[1] && vy_a && (gx >= ANCHO-GRUESO);
    wire s_c = seg[2] && vy_b && (gx >= ANCHO-GRUESO);
    wire s_d = seg[3] && hx && (gy >= ALTO-GRUESO);
    wire s_e = seg[4] && vy_b && (gx < GRUESO);
    wire s_f = seg[5] && vy_a && (gx < GRUESO);
    wire s_g = seg[6] && hx && (gy >= MED-GRUESO/2) && (gy < MED+GRUESO/2);

    assign encendido = s_a | s_b | s_c | s_d | s_e | s_f | s_g;
endmodule
`default_nettype wire
```

### `mnist_top.v`

```verilog
// mnist_top.v — el sistema completo: pixel -> bordes -> formas -> digito.
// Entra el stream de la imagen, sale el digito reconocido. Es la jerarquia
// -pixel, bordes, formas, digito- pero con las dos primeras capas ESCRITAS A MANO
//   (Sobel de
// 1968) en vez de aprendidas, y solo la ultima entrenada. Ese es el argumento de la
//   tesis:
// a esta escala de silicio, la columna "escrito a mano" le gana a la columna
//   "aprendido".
`default_nettype none
module mnist_top #(
    parameter integer H = 28, parameter integer W = 28, parameter integer CW = 9
)(
    input  wire       clk,
    input  wire       reset,
    input  wire       clr,
    input  wire       in_valid,
    input  wire [7:0] in_pix,
    input  wire [7:0] thr,
    output wire       done,
    output wire [3:0] digito,
    output wire       valido      // 0 = NADA
);
    wire [32*CW-1:0] cnt;
    wire [10:0] n_bordes;
    wire fdone;
    mnist_feat #(.H(H),.W(W),.CW(CW)) FEAT (
        .clk(clk),.reset(reset),.clr(clr),.in_valid(in_valid),.in_pix(in_pix),.thr(thr),
        .frame_done(fdone),.cnt_o(cnt),.n_bordes(n_bordes));
    mnist_clf #(.CW(CW)) CLF (
        .clk(clk),.reset(reset),.start(fdone),.cnt_i(cnt),.n_bordes(n_bordes),
        .done(done),.digito(digito),.valido(valido),.score());
endmodule
`default_nettype wire
```

## G.17 Visión Canny MNIST (§6.3.4)

`vision_canny_mnist.v` es el `vision_sobel_mnist.v` de la G.16 con tres líneas de código cambiadas,
además de la cabecera:

```verilog
// antes: module vision_sobel_mnist #(
module vision_canny_mnist #(
    // antes: mnist_top #(.H(28),.W(28),.CW(9)) CLF (
    mnist_top_canny #(.H(28),.W(28),.CW(9)) CLF (
        // antes: .in_valid(w_valid), .in_pix(w_pix), .thr(8'd60),
        .in_valid(w_valid), .in_pix(w_pix), .thr_hi(8'd110), .thr_lo(8'd40),
```

`mnist_top_canny.v` une el extractor de la G.15 con su clasificador, `mnist_clf_canny.v`, que es el de la
G.15 con sus propios pesos, `mnist_weights_canny.vh`, y sus propios límites de rechazo. Su cabecera conserva una nota de estado escrita antes de
la verificación de la §6.6; se imprime tal cual, como todo el anexo.

Carpeta: `Verilog_Repo/vision_canny_mnist/`.

### `mnist_top_canny.v`

```verilog
// mnist_top_canny.v — el sistema completo con front-end CANNY 1-SALTO.
// Identico a mnist_top.v salvo por las dos piezas que cambian: el extractor usa doble
//   umbral
//   con histeresis, y el clasificador lleva pesos entrenados CON ese front-end (no son
//   intercambiables: usar los pesos del Sobel aca da resultados sin sentido).
//
//   ESTADO: el extractor NO esta verificado bit a bit contra el golden de Python (mejor
// coincidencia medida: 97.3 % del mapa de bordes). Esta cadena SIRVE PARA VER CORRER
//   EL
//   SISTEMA, no para reportar precision.
`default_nettype none
module mnist_top_canny #(
    parameter integer H = 28, parameter integer W = 28, parameter integer CW = 9
)(
    input  wire       clk,
    input  wire       reset,
    input  wire       clr,
    input  wire       in_valid,
    input  wire [7:0] in_pix,
    input  wire [7:0] thr_hi,
    input  wire [7:0] thr_lo,
    output wire       done,
    output wire [3:0] digito,
    output wire       valido      // 0 = NADA
);
    wire [32*CW-1:0] cnt;
    wire [10:0] n_bordes;
    wire fdone;
    mnist_feat_canny #(.H(H),.W(W),.CW(CW)) FEAT (
        .clk(clk),.reset(reset),.clr(clr),.in_valid(in_valid),.in_pix(in_pix),
        .thr_hi(thr_hi),.thr_lo(thr_lo),
        .frame_done(fdone),.cnt_o(cnt),.n_bordes(n_bordes),
        .dbg_val(),.dbg_borde(),.dbg_cx(),.dbg_cy(),.dbg_arr());
    mnist_clf_canny #(.CW(CW)) CLF (
        .clk(clk),.reset(reset),.start(fdone),.cnt_i(cnt),.n_bordes(n_bordes),
        .done(done),.digito(digito),.valido(valido),.score());
endmodule
`default_nettype wire
```

## G.18 Canny-78 (§6.3.5)

`mnist_top78.v` une el extractor y el clasificador y hace el trasvase de los 128 contadores;
`mnist_feat16_mem.v` es el extractor de dieciséis zonas con los contadores en memoria síncrona, y
`mnist_clf78_x2.v` el clasificador de dos clases por pasada. Los 780 pesos, empaquetados de dos en dos,
están en `mnist_weights78_x2.vh`. El generador de ventana es el de la G.12. Estos tres ficheros son los
mismos, con la misma suma md5, en el diseño de la tarjeta, en el de cámara y pantalla y en el que va a
silicio.

Dos de estos ficheros conservan en su primera línea el nombre del módulo del que se derivaron
—`mnist_feat_canny.v` y `mnist_clf78_bram.v`—; se imprimen tal cual, como el resto del anexo.

Carpeta: `Verilog_Repo/canny78/asic/`.

### `mnist_top78.v`

```verilog
// mnist_top78.v — la cadena nueva completa: extractor de 16 zonas + clasificador de 78.
//
//   Existe por dos razones. La primera es que es la integracion que el diseno necesita:
//   el extractor ya no entrega un bus de 128 contadores sino un PUERTO, asi que alguien
//   tiene que recorrerlo. La segunda es que medir los modulos por separado no deja
//   emplazar: sus buses internos se convierten en patas y piden 398 de las 39 que hay.
//   Con un top de verdad las patas son veinte y pico y nextpnr puede hacer su trabajo,
//   que es lo unico que da la FRECUENCIA.
//
// El trasvase son 128 lecturas encadenadas con 128 escrituras. El desfase es UNO, no
//   dos:
// `rd_a` es un registro que va un ciclo por detras de `cnt`, y la memoria entrega el
//   dato
// un ciclo despues de eso, asi que durante el ciclo `c` el dato que hay en `rd_d` es
//   el de
// la direccion `c-1`. Con desfase dos -como estaba- el trasvase entregaba
//   fmem[k]=feat[k+1]:
// se perdia la caracteristica 0 y la 127 entraba dos veces. Lo encontro el banco de la
//   cadena completa que compara los tres sitios por separado.
// Cuesta 130 ciclos, que sumados a los 647 del clasificador dan 777: siete por debajo
//   de
//   los 784 que dura un cuadro.
//
// De paso el trasvase VACIA cada contador al leerlo (`rd_clr`) y al terminar
//   descongela el
// extractor (`reanuda`). Sin eso el diseno clasificaba UN cuadro y se quedaba quieto
//   para
//   siempre, porque `listo` solo lo baja un reset.
`default_nettype none
module mnist_top78 #(
    parameter integer CW = 9,
    parameter integer FW = 13
)(
    input  wire       clk,
    input  wire       reset,
    input  wire       in_valid,
    input  wire [7:0] in_pix,
    input  wire [7:0] thr_hi,
    input  wire [7:0] thr_lo,
    output wire       done,
    output wire [3:0] digito,
    output wire       valido
);
    wire        frame_done;
    wire [10:0] n_bordes;
    reg  [6:0]  rd_a;
    wire [CW-1:0] rd_d;
    reg         rd_clr, reanuda;

    mnist_feat16_mem #(.CW(CW)) ext (
        .clk(clk), .reset(reset), .clr(1'b0), .in_valid(in_valid), .in_pix(in_pix),
        .thr_hi(thr_hi), .thr_lo(thr_lo),
        .frame_done(frame_done), .rd_a(rd_a), .rd_d(rd_d),
        .rd_clr(rd_clr), .reanuda(reanuda), .n_bordes(n_bordes),
        .dbg_val(), .dbg_borde(), .dbg_cx(), .dbg_cy(), .dbg_arr(), .dbg_mag(), .dbg_cls()
    );

    // --- trasvase: 128 contadores del extractor a la memoria del clasificador ---
    localparam T_IDLE=2'd0, T_COPIA=2'd1, T_ARR=2'd2;
    reg [1:0]  ts;
    reg [7:0]  cnt;          // 0..128: uno de mas por el desfase de la lectura
    reg        wr_en;
    reg [7:0]  wr_addr;
    reg        arranca;
    wire [FW-1:0] wr_data = {{(FW-CW){1'b0}}, rd_d};

    always @(posedge clk) begin
        if (reset) begin
            ts <= T_IDLE; cnt <= 0; wr_en <= 1'b0; rd_a <= 0; arranca <= 1'b0;
            rd_clr <= 1'b0; reanuda <= 1'b0;
        end else begin
            wr_en <= 1'b0; arranca <= 1'b0; rd_clr <= 1'b0; reanuda <= 1'b0;
            case (ts)
                T_IDLE: if (frame_done) begin cnt <= 0; rd_a <= 0; ts <= T_COPIA; end
                T_COPIA: begin
                    if (cnt <= 8'd127) rd_a <= cnt[6:0];
                    // en el ciclo `c` la memoria ya entrega la direccion `c-1`
                    if (cnt >= 8'd1) begin wr_en <= 1'b1; wr_addr <= cnt - 8'd1; end
                    // OJO: `rd_clr` va SIN la guarda de `cnt >= 1`, y eso no es un
                    //   descuido.
                    // Es un registro, asi que sube un ciclo despues de la condicion;
                    //   con la
                    // guarda llegaba alta cuando `rd_a` ya valia 1, y vaciaba las
                    //   casillas 1
                    // a 127 SALTANDOSE LA 0. La 0 se quedaba con la cuenta del cuadro
                    // anterior y la arrastraba para siempre. Solo se ve cuando la
                    //   esquina
                    // superior izquierda tiene borde en la orientacion 0 -raro en
                    //   MNIST-, y
                    // desde ahi ya no se va: aparecio en la imagen 360 de 10 000 y
                    //   ensucio
                    // todas las siguientes con tres cuentas de mas. Lo cazo el espia de
                    // escrituras a la casilla 0, que mostro que NADIE la vaciaba nunca.
                    rd_clr <= 1'b1;
                    if (cnt == 8'd128) begin ts <= T_ARR; end
                    else cnt <= cnt + 1'b1;
                end
                T_ARR: begin arranca <= 1'b1; reanuda <= 1'b1; ts <= T_IDLE; end
            endcase
        end
    end

    mnist_clf78_x2 #(.CW(CW), .FW(FW)) clf (
        .clk(clk), .reset(reset),
        .wr_en(wr_en), .wr_addr(wr_addr), .wr_data(wr_data),
        .start(arranca), .n_bordes(n_bordes),
        .done(done), .digito(digito), .valido(valido), .score()
    );
endmodule
```

### `mnist_feat16_mem.v`

```verilog
// mnist_feat_canny.v — EXTRACTOR con front-end CANNY 1-SALTO en vez de umbral simple.
//
// Es `mnist_feat.v` con una tercera etapa: doble umbral (clase 2/1/0) + histeresis de
//   un salto.
// Motivado por lo que se midio en simulacion: este front-end
//   aguanta
//   +17 pp mejor la iluminacion despareja y -16 pp peor el ruido de sensor.
//
// EL TRUCO DE LA TERCERA VENTANA: hace falta el vecindario 3x3 del mapa de CLASES,
//   pero tambien
// la orientacion del pixel CENTRAL de ese vecindario -que ya quedo tres etapas atras-.
//   En vez de
//   agregar una linea de retardo aparte para la orientacion, viajan JUNTAS por el mismo
// linebuf3x3, empaquetadas en 5 bits: {octante[2:0], clase[1:0]}. El tap central da
//   las dos
//   cosas alineadas por construccion, y no hay forma de que se desincronicen.
//
// Es el front-end de la tesis (el mismo que corre en los 10 chips) con una cola nueva:
//   en vez de escribir el borde a un framebuffer, lo CUENTA por orientacion y por zona.
//
//     stream 8b -> Gauss 3x3 /16 -> Sobel 3x3 -> |Gx|+|Gy| sat 255 -> umbral
// -> octante (3 comparaciones) -> contador[zona][bin]
//
// POR QUE OCTANTE Y NO atan2: el bin es {sgn(Gy), sgn(Gx), |Gy|>|Gx|}. Tres
//   comparaciones y
// cero multiplicaciones; un atan2 pediria un CORDIC o una tabla. Son los mismos 8
//   sectores de
// 45 grados, con los bordes en 0/45/90... en vez de centrados. El golden de Python se
//   cambio
// para modelar ESTO, que es la regla de toda la tesis: el golden modela lo que el
//   silicio hace.
//
// `clr` limpia el histograma SIN tocar los line-buffers. Hace falta porque la imagen
//   se manda
// dos veces -los buffers arrancan vacios y la primera pasada trae basura, igual que en
//   los
// bancos de verificacion-: al empezar la segunda hay que poner los contadores en
//   cero
// pero conservar las dos filas ya cargadas. Un `reset` a secas borraria las dos cosas.
//
// POR QUE 32 CONTADORES Y NO 40: la piramide es nivel 0+1 = 5 zonas x 8 orientaciones
//   = 40
// caracteristicas. Pero el nivel 0 (la imagen entera) es EXACTAMENTE la suma de los
//   cuatro
// cuadrantes -son una particion-, asi que no se guarda: se deriva sumando. Ocho
//   contadores
// menos, gratis. Es la misma idea de los metatiles: no guardes lo que podes
//   reconstruir.
`default_nettype none
module mnist_feat16_mem #(
    parameter integer H   = 28,     // alto de la imagen de entrada
    parameter integer W   = 28,     // ancho
    parameter integer CW  = 9,      // bits por contador
    parameter integer LATP = 0      // 0 = usar 3*(W+2); >0 = forzar (para CALIBRAR)
)(
    input  wire            clk,
    input  wire            reset,          // sincrono, activo-alto: limpia TODO
    // limpia solo histograma y posicion (deja los line-buffers)
    input  wire            clr,
    input  wire            in_valid,
    input  wire [7:0]      in_pix,
    input  wire [7:0]      thr_hi,         // umbral ALTO: borde fuerte
    // umbral BAJO: borde debil (sobrevive si toca uno fuerte)
    input  wire [7:0]      thr_lo,
    output reg             frame_done,     // se conto el ultimo pixel util del cuadro
    // NO hay bus paralelo de salida. Sacar los 128 contadores a la vez obliga a
    // que sean registros: una memoria tiene UN puerto de lectura. En su lugar se
    // expone el puerto, y el clasificador lee de a uno cuando el cuadro termino.
    input  wire [6:0]      rd_a,           // que contador quiere el clasificador
    output reg  [CW-1:0]   rd_d,           // ...y su valor, un ciclo despues
    // VACIAR AL LEER. El histograma hay que ponerlo a cero entre cuadro y cuadro, y el
    //   bucle
    // de 128 ciclos de `borrando` NO CABE: desde `frame_done` hasta la primera
    //   posicion util
    // del cuadro siguiente hay 172 ciclos, y el trasvase ya se lleva 130. Pero el
    //   trasvase
    // LEE los 128 contadores uno por uno, asi que puede vaciarlos de paso, gratis y en
    //   el
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
    // OJO: .W(W) y NO .W(W-2). El linebuf3x3 emite UNA salida por cada entrada -no
    //   descarta
    // el borde-, asi que la segunda etapa sigue viendo filas de W. Ponerle W-2 le
    //   desalinea el
    // envolvimiento de fila y ensucia el resultado.
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
    // el octante, sin una sola multiplicacion
    wire [2:0]  bin_raw = {sgy, sgx, (agy > agx)};

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
    // la orientacion del MISMO pixel central
    wire [2:0]  bin = c11[4:2];

    // ---------------- posicion, y la latencia del pipeline ----------------
    // El linebuf3x3 emite UNA salida por cada entrada: el raster de salida tiene la
    //   misma
    // forma HxW que el de entrada, con basura en el borde. Cada etapa retrasa W+2
    //   muestras:
    // W+1 porque la ventana centrada en (r,c) recien esta cuando entro (r+1,c+1) -eso
    //   es lo
    // que midio el banco de latencia- MAS 2 por el pipeline interno del propio linebuf (etapa
    //   de
    // lectura + etapa de ventana)... y de esos 2 solo se ve 1 en el indice de muestra.
    // Con la tercera etapa del Canny son 3*(W+1) = 87 para W=28. NO 3*(W+2)=90: los
    //   dos
    // ciclos del cauce interno de cada linebuf NO los cuenta `lat_cnt`, porque
    //   mientras el
    // encadenado se llena `vc` esta baja y la guarda es `if (vc && !listo)`. El +2 se
    //   lo
    // traga la propia ausencia de muestras validas; contarlo otra vez lo cuenta dos
    //   veces.
    //
    // ESTO SE MIDIO, no se dedujo: se barrio LATP de 84 a 92 volcando el mapa
    //   de
    // bordes posicion por posicion y comparandolo con el golden. Encaje: 74.7 % a 84,
    //   99.6 %
    // a 87, y de vuelta a 75.1 % a 90. Con 87 y una pasada desde reset, 484/484
    //   exactas en
    // cinco imagenes.  Y LA TRAMPA, en la misma tabla: `n_bordes` -el TOTAL- coincidia
    // perfecto a 90, 91 y 92, donde el mapa estaba PEOR. Un corrimiento no cambia la
    //   suma.
    // El 3*(W+2) anterior venia justo de calibrar contra el total. Es la trampa que
    //   este
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
    // `listo` congela el histograma cuando termina el cuadro: sin el, frame_done
    //   vuelve a
    // pulsar al envolver el raster y el clasificador correria con los contadores
    //   moviendose
    //   debajo. Cuesta UN flip-flop y evita latchear los 32 contadores (288 FF).
    reg listo;
    // `frame_done` NO se anuncia en el mismo flanco que `listo`, sino una muestra
    //   valida
    // despues, cuando el histograma ya esta CERRADO. Razon: el incremento del ultimo
    //   pixel
    // util se desagua en esa muestra, y el trasvase -que arranca con `frame_done`-
    //   vacia
    // cada casilla al leerla. Con los dos en el mismo ciclo pelean por el UNICO puerto
    //   de
    // escritura de la BRAM y uno de los dos se pierde. Con tiempo muerto entre pixeles
    //   la
    // pelea es segura, porque el trasvase corre a ritmo de reloj y el desague espera la
    // proxima muestra valida: medido, una casilla de menos en una imagen de
    //   cada
    // sesenta y cuatro a partir de GAP=4. No se anuncia un cuadro que aun se esta
    //   escribiendo.
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
    // EL PUENTE. Al leer en un ciclo y escribir en el siguiente, la lectura del ciclo
    //   t no ve
    // la escritura que ocurre EN ESE MISMO flanco -la del pixel t-1-. Si los dos
    //   pixeles caen
    // en la misma casilla, la cuenta se pierde. Hay que comparar con LO QUE SE
    //   ESCRIBIO, no
    // con lo que viene:
    //
    // La version anterior hacia `(q_val && q_dir == dir) ? q_rd+1 : q_rd`, o sea
    //   comparaba
    // la casilla ya leida con la del pixel que ENTRA AHORA -mirando hacia adelante en
    //   vez
    //   de hacia atras- y le sumaba dos de golpe. Sobre una racha de tres o mas pixeles
    // seguidos en la misma casilla -que es lo normal recorriendo un contorno-
    //   descontaba.
    // Medido: 206 de 238 cuentas, con `n_bordes` perfecto. Otra vez el total
    //   tapando el error en la distribucion.
    reg [6:0]    p_dir;      // casilla escrita en el flanco anterior
    reg [CW-1:0] p_val;      // ...y el valor que se le escribio
    reg          p_en;
    wire [CW-1:0] base = (p_en && p_dir == q_dir) ? p_val : q_rd;
    wire [CW-1:0] inc  = base + 1'b1;

    // UN SOLO PUERTO DE ESCRITURA, con direccion y dato multiplexados. Son tres cosas
    //   las que
    // escriben en `cnt` -el borrado inicial, el incremento, y el vaciado al leer del
    //   trasvase-
    // y si cada una va en su propio `if`, yosys deja de inferir la BRAM y pone los 128
    // contadores en biestables. Medido, y no es un detalle: 4261 LUT4 y 7
    //   BRAM con
    // tres escrituras sueltas, contra 2001 LUT4 y 9 BRAM con una sola multiplexada.
    //   Son 2260
    // LUT4, la mitad de la FPGA, por como esta ESCRITO y no por lo que hace. La BRAM
    //   de la
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
            // `reanuda` descongela SIN tocar cx/cy/lat_cnt. Eso es a proposito: una
            //   vez que la
            // posicion quedo alineada por el reset, se envuelve sola cada 784 muestras
            //   y sigue
            // alineada para siempre. Volver a ponerla a cero -que es lo que hace
            //   `clr`- obliga
            // a tragarse la latencia otra vez y DESALINEA el cuadro siguiente: medido,
            // el raster tras `clr` encajaba 317/484 contra 484/484 del primero.
            if (reanuda) begin
                listo <= 1'b0; n_bordes <= 11'd0; q_val <= 1'b0; p_en <= 1'b0; fd_pend <= 1'b0;
            end
            if (vc) begin
                // El borrado avanza TAMBIEN mientras se traga la latencia. Antes vivia
                //   dentro
                // del `else`, o sea que arrancaba DESPUES de los 87 ciclos y se comia
                //   las 35
                // primeras posiciones interiores (toda la fila cy=3 y media de la
                //   cy=4): sus
                // incrementos quedaban suprimidos por el `if (borrando)` que tiene
                //   prioridad.
                // Aca son 88 ciclos de latencia + las 84 posiciones de cabecera (cy<3,
                //   que no
                // son interior) = 172 huecos para 128 ciclos de borrado. El borrado
                //   termina en
                // la posicion 40 -cy=1-, muy antes de la primera posicion util.
                if (borrando) begin
                    if (badr == 7'd127) borrando <= 1'b0; else badr <= badr + 1'b1;
                end
                if (!arrancado) lat_cnt <= lat_cnt + 1'b1;   // tragarse la latencia
                else begin
                    // LA POSICION AVANZA SIEMPRE, tambien mientras el clasificador
                    //   trabaja.
                    // Estaba dentro del `!listo`, asi que los 130 ciclos del trasvase
                    // congelaban el raster y el cuadro siguiente entraba 130 muestras
                    // corrido -y el siguiente 260, y asi-. El sintoma era limpio: el
                    //   primer
                    // cuadro daba `n_bordes` exacto y del segundo en adelante no. Una
                    //   vez
                    // alineada por el reset, la posicion se envuelve sola cada H*W
                    //   muestras
                    // y se queda alineada para siempre; lo unico que hay que congelar
                    //   es el
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
                    // incremento del ULTIMO pixel util se enclava en `q_val` en el
                    //   mismo
                    // flanco en que se levanta `listo`; si la escritura se congelara
                    //   con
                    // `listo`, ese incremento no se escribiria nunca. Solo se nota
                    //   cuando
                    // la esquina (H-4,W-4) resulta ser borde -una imagen de cada
                    //   treinta y
                    // pico-, y se veia como UNA casilla de 128 con una cuenta de menos,
                    // siempre en la zona 15. `q_val <= 0` de arriba la desagua en un
                    //   ciclo.
                    p_en <= 1'b0;
                    if (cw_inc) begin p_dir <= q_dir; p_val <= inc; p_en <= 1'b1; end
                end
            end
        end
    end
    // se empaquetan en un bus: yosys no admite puertos de array en Verilog-2005, y un
    //   bus
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
```

### `mnist_clf78_x2.v`

```verilog
// mnist_clf78_bram.v — el clasificador de 78, con las caracteristicas en MEMORIA.
//
//   SONDA DE AREA. Misma funcion que mnist_clf78.v, otra implementacion del acceso:
//   alli los 128 contadores eran un array de registros y leer cn[{z,bn}] con indice
//   variable costaba un multiplexor 128:1 de 9 bits -1323 LUT4 medidos, tres veces
//   la ROM entera-. Aqui viven en una memoria sincrona, que yosys infiere como
//   SB_RAM40_4K, y la lectura cuesta 17 LUT4.
//
//   La memoria guarda las 168 caracteristicas, no solo los 128 contadores:
//     0..127   nivel 2: el contador de la zona, escrito por el extractor
//     128..159 nivel 1: suma de las 4 zonas del cuadrante, derivada aqui
//     160..167 nivel 0: suma de las 16 zonas, derivada aqui
//   Asi la fase de multiplicacion-acumulacion lee SIEMPRE de un solo sitio y no hay
//   un solo multiplexor en el camino.
//
//   El precio es tiempo: la derivacion son 8*16 + 32*4 = 256 lecturas antes de poder
//   empezar. Es el intercambio de siempre, ahora en la otra direccion.
`default_nettype none
module mnist_clf78_x2 #(
    parameter integer CW = 9,
    parameter integer FW = 13,       // suma de 16 contadores de 9 bits
    parameter integer AW = 24
)(
    input  wire             clk,
    input  wire             reset,
    // puerto de escritura: el extractor deja aqui sus 128 contadores
    input  wire             wr_en,
    input  wire [7:0]       wr_addr,
    input  wire [FW-1:0]    wr_data,
    input  wire             start,
    input  wire [10:0]      n_bordes,
    output reg              done,
    output reg  [3:0]       digito,
    output reg              valido,
    output reg signed [AW-1:0] score
);
`include "mnist_weights78_x2.vh"
    // DOS clases por ciclo. La caracteristica es la MISMA para las diez clases,
    // asi que se lee UNA vez de memoria y se multiplica por dos pesos distintos:
    // un solo puerto de lectura y dos multiplicadores. 5 pasadas de 78 en vez de
    // 10, o sea 390 ciclos de multiplicacion en vez de 780.

    localparam [10:0] B_MIN = 11'd174, B_MAX = 11'd376;
    // n_bordes SE ENCLAVA AL ARRANCAR. Se leia combinacionalmente en S_DONE, 647 ciclos
    // despues, y a esa altura el extractor ya lo puso a cero y lleva medio cuadro nuevo
    // contado: `valido` salia calculado con el recuento de OTRA imagen. El banco
    //   suelto no
    // podia verlo porque mantenia `n_bordes` fijo para siempre; solo aparece en el
    //   flujo
    // continuo. Es la trampa de siempre: un banco vale por lo que puede romper.
    reg [10:0] nb_l;
    localparam signed [AW-1:0] MARGEN = 70;

    // ---- la memoria de caracteristicas: 168 de FW bits ----
    reg [FW-1:0] fmem [0:255];
    reg [7:0]    rd_a;
    reg [FW-1:0] rd_d;
    reg          we_i;
    reg [7:0]    wa_i;
    reg [FW-1:0] wd_i;
    always @(posedge clk) begin
        if (wr_en)      fmem[wr_addr] <= wr_data;      // desde el extractor
        else if (we_i)  fmem[wa_i]    <= wd_i;         // las derivadas
        rd_d <= fmem[rd_a];                            // lectura SINCRONA -> BRAM
    end

    // ---- control ----
    // La derivacion se hace en pasos de CINCO ciclos por caracteristica: cuatro
    // para pedir los cuatro sumandos y uno para escribir. La lectura es sincrona,
    // asi que el dato que llega en el ciclo t corresponde a la direccion pedida
    // en t-1: por eso se pide en 0..3 y se acumula en 1..4.
    //
    // Nivel 1 = suma de las 4 zonas del cuadrante.
    // Nivel 0 = suma de los 4 CUADRANTES ya derivados, no de las 16 zonas:
    //           los cuadrantes son una particion, asi que da lo mismo y son
    //           cuatro lecturas en vez de dieciseis.
    localparam S_IDLE=3'd0, S_DERIV=3'd1, S_MAC=3'd2, S_ARGMAX=3'd3, S_DONE=3'd4,
               S_PRE=3'd5, S_PRE2=3'd6;
    reg [2:0] st;
    reg [2:0] cp;        // pareja de clases en curso (0..4)
    reg [6:0] j;
    reg [6:0] ja;   // indice de DIRECCION: va dos por delante de j,
                    // porque el dato tarda dos ciclos en llegar (registro + lectura
                    //   sincrona)
    reg       fase;          // 0 = derivando nivel 1 (32), 1 = derivando nivel 0 (8)
    reg [4:0] fidx;          // que caracteristica derivada
    reg [2:0] t;             // paso dentro de la derivacion (0..4)
    reg [FW-1:0] acc_d;
    reg signed [AW-1:0] acc0, acc1, mejor, segundo;
    reg [3:0] mejor_c;

    // direccion de la caracteristica 0 y de la siguiente, para pedirlas con un ciclo
    // de antelacion (la lectura es sincrona)
    wire [7:0] k0 = k_rom(7'd0);
    wire [7:0] dir_j_0 = (k0 < 8'd8) ? (8'd160+k0) : (k0 < 8'd40) ? (8'd128+(k0-8'd8))
        : (k0-8'd40);
    wire [7:0] ka = k_rom(ja);
    wire [7:0] dir_ja = (ka < 8'd8) ? (8'd160+ka) : (ka < 8'd40) ? (8'd128+(ka-8'd8))
        : (ka-8'd40);


    wire [2:0] db = fase ? fidx[2:0] : fidx[2:0];      // orientacion
    wire [1:0] dq = fidx[4:3];                          // cuadrante (solo nivel 1)
    // nivel 1: zona = {qy, paso[1], qx, paso[0]}   ->   direccion = zona*8 + bin
    wire [7:0] dir_z = {1'b0, dq[1], t[1], dq[0], t[0], db};
    // nivel 0: los cuatro cuadrantes ya escritos en 128 + q*8 + bin
    wire [7:0] dir_q = 8'd128 + {3'd0, t[1:0], db};
    wire [7:0] dir_src = fase ? dir_q : dir_z;
    wire [7:0] dir_dst = fase ? (8'd160 + {5'd0, fidx[2:0]}) : (8'd128 + {3'd0, fidx});

    wire [7:0] k = k_rom(j);
    wire [7:0] dir_j = (k < 8'd8)  ? (8'd160 + k)
                     : (k < 8'd40) ? (8'd128 + (k - 8'd8))
                                   : (k - 8'd40);
    wire [3:0] c0 = {cp, 1'b0};          // clase par
    wire [3:0] c1 = {cp, 1'b1};          // clase impar
    // UNA lectura de ROM da los dos pesos. Instanciar w_rom dos veces costaba
    // 457 LUT4 de mas -toda una ROM- y era lo que dejaba el diseno en el 103 %.
    wire [7:0] w2 = w2_rom({2'd0, cp} * N_CARAC + {2'd0, j});
    wire signed [3:0] w0 = w2[3:0];
    wire signed [3:0] w1 = w2[7:4];
    wire signed [AW-1:0] prod0 = $signed({1'b0, rd_d}) * w0;
    wire signed [AW-1:0] prod1 = $signed({1'b0, rd_d}) * w1;

    always @(posedge clk) begin
        if (reset) begin
            st <= S_IDLE; done <= 1'b0; we_i <= 1'b0;
            digito <= 0; valido <= 0; score <= 0;
            j <= 0; fase <= 0; fidx <= 0; t <= 0; acc_d <= 0;
            rd_a <= 8'd0; ja <= 0; acc0 <= 0; acc1 <= 0;
            mejor <= 0; segundo <= 0; mejor_c <= 0; cp <= 0; nb_l <= 11'd0;
            // rd_a SIN inicializar dejaba la primera lectura en X, y una sola X
            // envenena el acumulador para siempre: el maximo nunca se actualiza.
        end else begin
            done <= 1'b0; we_i <= 1'b0;
            case (st)
                S_IDLE: if (start) begin
                    fase <= 1'b0; fidx <= 5'd0; t <= 3'd0; acc_d <= 0;
                    nb_l <= n_bordes;           // el recuento de ESTE cuadro, no del siguiente
                    st <= S_DERIV;
                end

                // SEIS ciclos por caracteristica, no cinco. Se piden cuatro direcciones
                // en t=0..3 y los datos llegan en t=1..4, porque la memoria es
                //   sincrona.
                // Escribir en t=4 -que es lo que hacia antes- suma solo TRES de los
                // cuatro: el ultimo dato todavia no ha llegado. El sintoma era que la
                // suma TOTAL cuadraba pero el reparto entre zonas no, que es
                //   exactamente
                // el aviso de verificar.py: un desalineamiento deja el total intacto.
                S_DERIV: begin
                    if (t <= 3'd3) rd_a <= dir_src;          // pedir
                    // La direccion pedida cuando t valia k da su dato cuando t vale
                    //   k+2:
                    // uno por el registro de direccion y otro por la lectura sincrona.
                    // Se piden en t=0..3 y llegan en t=2..5.
                    if (t >= 3'd2 && t <= 3'd4) acc_d <= acc_d + rd_d;
                    if (t == 3'd5) begin
                        we_i <= 1'b1; wa_i <= dir_dst; wd_i <= acc_d + rd_d;
                        acc_d <= 0; t <= 3'd0;
                        if (!fase && fidx == 5'd31) begin fase <= 1'b1; fidx <= 5'd0; end
                        else if (fase && fidx[2:0] == 3'd7) begin
                            cp <= 0; j <= 0; acc0 <= b_rom(4'd0); acc1 <= b_rom(4'd1);
                            mejor <= {1'b1,{(AW-1){1'b0}}}; segundo <= {1'b1,{(AW-1){1'b0}}};
                            mejor_c <= 0; ja <= 7'd0; st <= S_PRE;
                        end else fidx <= fidx + 1'b1;
                    end else t <= t + 1'b1;
                end

                // Un ciclo de espera. La memoria es SINCRONA: el dato de la
                //   caracteristica 0
                // llega un ciclo despues de pedirla. Sin esto el primer producto
                //   multiplica
                // lo que hubiera en el puerto y todo el acumulado queda corrido una
                //   posicion.
                // dos ciclos de adelanto: se piden las direcciones 0 y 1 antes de
                // empezar a multiplicar, porque el dato de la 0 no llega hasta el
                //   tercero.
                S_PRE:  begin rd_a <= dir_ja; ja <= ja + 1'b1; st <= S_PRE2; end
                S_PRE2: begin rd_a <= dir_ja; ja <= ja + 1'b1; st <= S_MAC;  end

                // una lectura por ciclo; el dato de j llega mientras se pide el j+1
                S_MAC: begin
                    acc0 <= acc0 + prod0;
                    acc1 <= acc1 + prod1;
                    if (j == N_CARAC-1) st <= S_ARGMAX;
                    else begin j <= j + 1'b1; rd_a <= dir_ja; ja <= ja + 1'b1; end
                end

                // Se comparan las DOS acumuladas, primero la de clase par. El orden
                // importa: numpy.argmax se queda con el INDICE MAS BAJO cuando hay
                // empate, y mirar primero la par reproduce ese criterio.
                S_ARGMAX: begin
                    if (acc0 > mejor) begin
                        if (acc1 > acc0) begin mejor <= acc1; segundo <= acc0; mejor_c <= c1; end
                        else             begin mejor <= acc0; mejor_c <= c0;
                                               segundo <= (acc1 > mejor) ? acc1 : mejor; end
                    end else if (acc1 > mejor) begin
                        mejor <= acc1; mejor_c <= c1;
                        segundo <= (acc0 > mejor) ? acc0 : mejor;
                    end else begin
                        if (acc0 > segundo && acc0 >= acc1) segundo <= acc0;
                        else if (acc1 > segundo)            segundo <= acc1;
                    end
                    if (cp == 3'd4) st <= S_DONE;
                    else begin
                        acc0 <= b_rom({cp+3'd1, 1'b0}); acc1 <= b_rom({cp+3'd1, 1'b1});
                        cp <= cp + 1'b1; j <= 0; ja <= 7'd0; st <= S_PRE;
                    end
                end

                S_DONE: begin
                    digito <= mejor_c; score <= mejor;
                    valido <= (nb_l >= B_MIN) && (nb_l <= B_MAX) && ((mejor-segundo) > MARGEN);
                    done <= 1'b1; st <= S_IDLE;
                end
            endcase
        end
    end
endmodule
```

## G.19 Canny-98 (§6.3.6)

`mnist_clf98.v` es el clasificador de Canny-98: la memoria de rasgos y su derivación son las de `mnist_clf78_x2.v`
(G.18), y lo nuevo son las dos capas. Los pesos se leen de `canny98_w.hex` y los sesgos de `canny98_b1.hex` y
`canny98_b2.hex`, generados por `canny98_hex.py` desde el modelo entero; las activaciones van a la primitiva
`SB_SPRAM256KA` de la iCE40. `mnist_top98.v` es el `mnist_top78.v` de la G.18 con este clasificador.

Carpeta: `clasificador_mnist/rtl/` del repositorio de la tesis.

### `mnist_clf98.v`

```verilog
// mnist_clf98.v — Canny-98: el clasificador de Canny-78 con UNA CAPA OCULTA de 120
//   neuronas.
//
// La mitad de delante es la de mnist_clf78_x2.v, sin tocar: la memoria fmem con las
//   168
// caracteristicas (0..127 nivel 2 del extractor, 128..159 nivel 1 y 160..167 nivel 0
//   derivados
//   aqui, seis ciclos por caracteristica). Lo que cambia es la cuenta:
//
//     capa 1:  acc = b1[j] + sum_k W1[j][k] * f[k]         j = 0..119, k = 0..167
// h[j] = min(255, max(0, acc >>> S))           una activacion de 8 bits: un
//   desplazamiento
//     capa 2:  s[c] = b2[c] + sum_j W2[c][j] * h[j]         c = 0..9
//     digito = argmax(s), el INDICE MAS BAJO en empate, como numpy.argmax
//
// Pesos de 4 bits con signo, UNA sola escala por capa (el argmax no la ve), asi que no
//   hay ninguna
// multiplicacion por constante. Todos en una memoria de 21 504 x 4 bits = 21 bloques
//   SB_RAM40_4K:
// W1 en las direcciones j*168+k y W2 en 20160 + c*120 + j. Las activaciones van a la
//   SPRAM, que no
// necesita inicializarse. Una multiplicacion-acumulacion por ciclo: 120*171 + 10*123
//   ciclos, unos
//   21 800, que a 12 MHz son 1,8 ms por imagen.
//
// Las lecturas son sincronas y la direccion tambien va registrada: el dato llega DOS
//   ciclos despues
// de pedirlo. Por eso cada vuelta pide sus direcciones, deja que la tuberia de dos
//   etapas se vacie
// (iss1 -> iss2) y solo entonces cierra la neurona. Es la leccion de clf78_x2: contar
//   la latencia,
//   no suponerla.
//
// Modelo de referencia: canny98_golden.py (pesos_canny98_H120.npz). Criterio: bit a
//   bit.
`default_nettype none
module mnist_clf98 #(
    parameter integer CW = 9,
    parameter integer FW = 13,
    parameter integer AW = 24,
    parameter integer H  = 120,
    parameter integer S  = 2,
    parameter [10:0]  B_MIN = 11'd174,
    parameter [10:0]  B_MAX = 11'd376,
    parameter integer MARGEN = 0
)(
    input  wire             clk,
    input  wire             reset,
    input  wire             wr_en,
    input  wire [7:0]       wr_addr,
    input  wire [FW-1:0]    wr_data,
    input  wire             start,
    input  wire [10:0]      n_bordes,
    output reg              done,
    output reg  [3:0]       digito,
    output reg              valido,
    output reg signed [AW-1:0] score
);
    localparam integer NF = 168;
    localparam integer W2_BASE = H * NF;                 // 20160

    // ---- las memorias de solo lectura: pesos y sesgos ----
    reg [3:0] wmem [0:21503];                            // 21 x SB_RAM40_4K (1024 x 4)
    (* ram_style = "logic" *) reg [8:0] b1mem [0:127];
        // sesgos de 9 bits con signo: en logica,
    (* ram_style = "logic" *) reg [8:0] b2mem [0:15];     // que no gasten bloques de BRAM
    initial begin
        $readmemh("canny98_w.hex",  wmem);
        $readmemh("canny98_b1.hex", b1mem);
        $readmemh("canny98_b2.hex", b2mem);
    end

    // ---- fmem: las 168 caracteristicas (igual que clf78_x2) ----
    reg [FW-1:0] fmem [0:255];
    reg [7:0]    rd_a;
    reg [FW-1:0] rd_d;
    reg          we_i;
    reg [7:0]    wa_i;
    reg [FW-1:0] wd_i;
    always @(posedge clk) begin
        if (wr_en)      fmem[wr_addr] <= wr_data;
        else if (we_i)  fmem[wa_i]    <= wd_i;
        rd_d <= fmem[rd_a];
    end

    // ---- pesos: una lectura por ciclo ----
    reg [14:0] w_a;
    reg [3:0]  w_d;
    always @(posedge clk) w_d <= wmem[w_a];

    // ---- activaciones en la SPRAM (16K x 16; se usan 120 palabras) ----
    reg  [13:0] sp_a;
    reg  [15:0] sp_din;
    reg         sp_we;
    wire [15:0] sp_dout;
    SB_SPRAM256KA HMEM (
        .ADDRESS(sp_a), .DATAIN(sp_din), .MASKWREN(4'b1111), .WREN(sp_we), .CHIPSELECT(1'b1),
        .CLOCK(clk), .STANDBY(1'b0), .SLEEP(1'b0), .POWEROFF(1'b1), .DATAOUT(sp_dout));

    // ---- control ----
    localparam S_IDLE=3'd0, S_DERIV=3'd1, S_L1=3'd2, S_L2=3'd3, S_DONE=3'd4;
    reg [2:0]  st;
    reg        fase;
    reg [4:0]  fidx;
    reg [2:0]  t;
    reg [FW-1:0] acc_d;
    reg [10:0] nb_l;
    reg [7:0]  ka;                 // indice que se PIDE (0..NF o 0..H)
    reg [6:0]  j;                  // neurona en curso
    reg [3:0]  c;                  // clase en curso
    reg [14:0] wbase;
    reg        iss1, iss2;         // tuberia de dos etapas: pedido -> dato
    reg signed [AW-1:0] acc, mejor, segundo;
    reg [3:0]  mejor_c;

    // derivacion (identica a clf78_x2)
    wire [2:0] db = fidx[2:0];
    wire [1:0] dq = fidx[4:3];
    wire [7:0] dir_z = {1'b0, dq[1], t[1], dq[0], t[0], db};
    wire [7:0] dir_q = 8'd128 + {3'd0, t[1:0], db};
    wire [7:0] dir_src = fase ? dir_q : dir_z;
    wire [7:0] dir_dst = fase ? (8'd160 + {5'd0, fidx[2:0]}) : (8'd128 + {3'd0, fidx});

    wire signed [4:0]  w5   = {w_d[3], w_d};
    wire signed [AW-1:0] prod1 = $signed({1'b0, rd_d}) * w5;             // capa 1: rasgo x peso
    // capa 2: activacion x peso
    wire signed [AW-1:0] prod2 = $signed({1'b0, sp_dout[7:0]}) * w5;
    wire signed [AW-1:0] acc_sh = acc >>> S;
    wire [7:0] h8 = acc_sh[AW-1] ? 8'd0 : (acc_sh > 255 ? 8'd255 : acc_sh[7:0]);
    wire signed [AW-1:0] b1v = {{(AW-9){b1mem[j][8]}}, b1mem[j]};
    wire [6:0] jn = j + 7'd1;
    wire signed [AW-1:0] b1n = {{(AW-9){b1mem[jn][8]}}, b1mem[jn]};
    wire [3:0] cn = c + 4'd1;
    // siempre con indice variable:
    wire signed [AW-1:0] b2v = {{(AW-9){b2mem[c][8]}}, b2mem[c]};
    // leer b1mem[0] o b2mem[0] con indice CONSTANTE hacia que yosys los partiera en
    //   cables sueltos y
    // avisara «used but has no driver». j y c valen 0 al llegar aqui, asi que se lee
    //   por j y c.
    wire signed [AW-1:0] b2n = {{(AW-9){b2mem[cn][8]}}, b2mem[cn]};

    always @(posedge clk) begin
        if (reset) begin
            st <= S_IDLE; done <= 1'b0; we_i <= 1'b0; sp_we <= 1'b0;
            digito <= 0; valido <= 0; score <= 0;
            fase <= 0; fidx <= 0; t <= 0; acc_d <= 0; rd_a <= 0; w_a <= 0; sp_a <= 0;
                sp_din <= 0;
            ka <= 0; j <= 0; c <= 0; wbase <= 0; iss1 <= 0; iss2 <= 0;
            acc <= 0; mejor <= 0; segundo <= 0; mejor_c <= 0; nb_l <= 0;
        end else begin
            done <= 1'b0; we_i <= 1'b0; sp_we <= 1'b0;
            case (st)
                S_IDLE: if (start) begin
                    fase <= 1'b0; fidx <= 5'd0; t <= 3'd0; acc_d <= 0;
                    nb_l <= n_bordes; j <= 0; c <= 0; st <= S_DERIV;
                end

                S_DERIV: begin
                    if (t <= 3'd3) rd_a <= dir_src;
                    if (t >= 3'd2 && t <= 3'd4) acc_d <= acc_d + rd_d;
                    if (t == 3'd5) begin
                        we_i <= 1'b1; wa_i <= dir_dst; wd_i <= acc_d + rd_d;
                        acc_d <= 0; t <= 3'd0;
                        if (!fase && fidx == 5'd31) begin fase <= 1'b1; fidx <= 5'd0; end
                        else if (fase && fidx[2:0] == 3'd7) begin
                            ka <= 0; wbase <= 0; iss1 <= 0; iss2 <= 0;
                            acc <= b1v;                          // j == 0
                            st <= S_L1;
                        end else fidx <= fidx + 1'b1;
                    end else t <= t + 1'b1;
                end

                // capa 1: se piden las NF caracteristicas y sus pesos, se acumulan dos
                //   ciclos
                // despues, y cuando la tuberia esta vacia se cierra la neurona.
                S_L1: begin
                    if (ka < NF) begin
                        rd_a <= ka; w_a <= wbase + ka; ka <= ka + 1'b1; iss1 <= 1'b1;
                    end else iss1 <= 1'b0;
                    iss2 <= iss1;
                    if (iss2) acc <= acc + prod1;
                    if (ka == NF && !iss1 && !iss2) begin
                        sp_we <= 1'b1; sp_a <= {7'd0, j}; sp_din <= {8'd0, h8};
                        ka <= 0;
                        if (j == H-1) begin
                            wbase <= W2_BASE; acc <= b2v;       // c == 0
                            mejor <= {1'b1, {(AW-1){1'b0}}};
                                segundo <= {1'b1, {(AW-1){1'b0}}}; mejor_c <= 0;
                            st <= S_L2;
                        end else begin
                            j <= jn; wbase <= wbase + NF; acc <= b1n;
                        end
                    end
                end

                // capa 2: lo mismo sobre las H activaciones de la SPRAM, una clase por
                //   vuelta
                S_L2: begin
                    if (ka < H) begin
                        sp_a <= {6'd0, ka}; w_a <= wbase + ka; ka <= ka + 1'b1; iss1 <= 1'b1;
                    end else iss1 <= 1'b0;
                    iss2 <= iss1;
                    if (iss2) acc <= acc + prod2;
                    if (ka == H && !iss1 && !iss2) begin
                        // argmax en el orden 0..9: '>' estricto conserva el indice mas
                        //   bajo
                        if (acc > mejor) begin segundo <= mejor; mejor <= acc; mejor_c <= c; end
                        else if (acc > segundo) segundo <= acc;
                        ka <= 0;
                        if (c == 4'd9) st <= S_DONE;
                        else begin c <= cn; wbase <= wbase + H; acc <= b2n; end
                    end
                end

                S_DONE: begin
                    digito <= mejor_c; score <= mejor;
                    valido <= (nb_l >= B_MIN) && (nb_l <= B_MAX) && ((mejor - segundo) > MARGEN);
                    done <= 1'b1; st <= S_IDLE;
                end
                default: st <= S_IDLE;
            endcase
        end
    end
endmodule
`default_nettype wire
```
