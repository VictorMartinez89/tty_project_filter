# Anexo G. Código Verilog

Este anexo reúne el código de los diseños de la §4.3. Los fuentes completos están ordenados por
diseño en el repositorio `Verilog_Repo`, una carpeta por circuito; cada carpeta lleva un `LEEME.md` con
el origen y la suma md5 de cada fichero, de modo que puede comprobarse que el texto impreso es el mismo
que se entregó al sintetizador o al flujo a silicio.

Se incluyen los módulos escritos para este trabajo. El núcleo del procesador, `femtorv32_quark.v`, es
de B. Levy [ref. 1] y se cita en lugar de reproducirse. En los listados, sólo las líneas de comentario
que no cabían en la página se han partido en dos; el código no se ha tocado, salvo en un sentido: las
líneas de código demasiado largas se parten entre dos sentencias, dos argumentos o dos sumandos, y los
comentarios al final de ellas suben a la línea anterior. En Verilog un salto de línea equivale a un
espacio, de modo que el circuito descrito es el mismo; se comprobó fichero por fichero, comparando el
código sin espacios ni comentarios.

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
// Fase 4 del roadmap ASIC: el SoC con el datapath Canny (Gaussian->Sobel->doble
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
// El jefe final: un CPU RISC-V junto al motor de histeresis TRANSITIVA (reconstruccion
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

Es el circuito `sobel_completo`, el #1 de la §5.3: 2,45 mm² en sky130. `sobel_completo.v` conecta el
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
// Ensamblado con los MODULOS reusables ya verificados (fases 7, 1, 8). UN SOLO RELOJ
//   (clk): el
// front-end sincroniza PCLK/HREF/VSYNC con 2-FF internos (Parte 152), asi que no hay
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
// cam_frontend_top.v — FRONT-END de la OV7670 AUTOCONTENIDO para ASIC sky130 (fase 7).
// Une las 3 piezas verificadas en FPGA: SCCB (config) + captura (PCLK/HREF/VSYNC/D7:0
//   -> RGB565,
// con sincronizadores 2-FF = CDC) + RGB565->gris. Entrega un STREAM DE GRIS
//   (gray/gray_valid)
// listo para cualquiera de los 6 filtros. La salida SCCB open-drain se parte en
//   dato+enable
//   (siod_o/siod_oe): el tri-state vive en el anillo de I/O (Parte 114).
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
// tri-state vive en el ANILLO DE I/O (el pad hace: pad = siod_oe ? siod_o : Z). Ver
//   Parte 114.
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
// OV7670 camera capture front-end for the femto2 SoC (tty_project_filter thesis).
// Target board: iCESugar v1.5  (Lattice iCE40UP5K-SG48)
// Wiring:       PMOD2 = pixel data D[7:0],  PMOD3 = clocks/sync/SCCB
//
// What this module does:
//   1) Generates XCLK (~24 MHz) to drive the OV7670.
//   2) Synchronises PCLK/HREF/VSYNC into the FPGA sysclk domain.
//   3) Captures one 8-bit pixel byte on each PCLK rising edge while HREF=1.
//   4) Combines two consecutive bytes into one 16-bit RGB565 pixel.
//   5) Emits frame_start / line_start pulses for downstream pipeline sync.
//
// What this module does NOT do (separate modules needed):
//   - SCCB (I2C-like) master to configure the camera at boot
//     -> implement in   cores/camera/ov7670_sccb.v
//   - Line buffering / DMA into RAM for the femto2 to read
//     -> downstream consumer's job
//
// Verilog-2001 style, written to be readable as a teaching example.
// ============================================================================

`default_nettype none

module ov7670_capture #(
    parameter integer SYSCLK_HZ = 48_000_000,   // FPGA system clock (Hz)
    parameter integer XCLK_HZ   = 24_000_000    // target XCLK to camera (Hz)
) (
    // -------- Clock & reset --------
    input  wire        sysclk,                 // system clock (>= 2 * PCLK)
    input  wire        rst_n,                  // active-low reset

    // -------- OV7670 pins (cross the PMOD boundary) --------
    input  wire [7:0]  cam_d,                  // pixel data byte   (PMOD2)
    input  wire        cam_pclk,               // pixel clock       (PMOD3, in)
    input  wire        cam_href,               // line valid        (PMOD3, in)
    input  wire        cam_vsync,              // frame sync        (PMOD3, in)
    output wire        cam_xclk,               // FPGA-gen'd clock  (PMOD3, out, ~24 MHz)

    // -------- Pixel stream out (sysclk domain) --------
    output reg  [15:0] pixel_rgb565,           // 16-bit RGB565 pixel
    output reg         pixel_valid,            // 1 sysclk pulse when pixel_rgb565 is fresh
    output reg         frame_start,            // pulse at start of every frame
    output reg         line_start              // pulse at start of every line
);

    // ========================================================================
    // 1) XCLK generator: divide sysclk down to ~XCLK_HZ
    // ------------------------------------------------------------------------
    // For low-jitter operation prefer the iCE40UP5K PLL (SB_PLL40_PAD); this
    // counter-based divider is fine for the OV7670 (it tolerates wide XCLK).
    // ========================================================================
    localparam integer DIVIDER = (SYSCLK_HZ / (2 * XCLK_HZ));   // toggle every DIVIDER cycles
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
    // 2) 2-FF synchronisers for the camera's async-looking inputs
    //    (PCLK is technically derived from cam_xclk, but it returns to us
    //     through the camera + cable: treat as async, synchronise it.)
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

    // Edge detection: remember previous value, compare to current.
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
    // 3) Byte capture + RGB565 byte-pair combiner
    //    The OV7670 sends each 16-bit RGB565 pixel as two bytes back-to-back:
    //        byte 0 (upper) = { R[4:0] , G[5:3] }
    //        byte 1 (lower) = { G[2:0] , B[4:0] }
    //    Align at the start of every line via href_rising.
    // ========================================================================
    reg       byte_phase;     // 0 -> waiting for upper byte ; 1 -> waiting for lower byte
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
            // Single-cycle output pulses by default.
            pixel_valid <= 1'b0;
            frame_start <= vsync_rising;
            line_start  <= href_rising;

            // Re-align at the start of each line so we never get half-pixels.
            if (href_rising)
                byte_phase <= 1'b0;

            // Sample data on PCLK rising edge while the line is active.
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
```

### `lcd_ili9341_top.v`

```verilog
// lcd_ili9341_top.v — DRIVER del PMOD TFTLCD (ILI9341, SPI) AUTOCONTENIDO para ASIC
//   sky130 (fase 8).
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
