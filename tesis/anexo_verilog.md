# Anexo G. Código Verilog

Este anexo reúne el código de los diseños de la §4.3. Los fuentes completos están ordenados por
diseño en el repositorio `Verilog_Repo`, una carpeta por circuito; cada carpeta lleva un `LEEME.md` con
el origen y la suma md5 de cada fichero, de modo que puede comprobarse que el texto impreso es el mismo
que se entregó al sintetizador o al flujo a silicio.

Se incluyen los módulos escritos para este trabajo. El núcleo del procesador, `femtorv32_quark.v`, es
de B. Levy [ref. 1] y se cita en lugar de reproducirse. En los listados, sólo las líneas de comentario
que no cabían en la página se han partido en dos; el código no se ha tocado, salvo alguna línea con
varias sentencias, que se parte entre dos de ellas y se indica en su sección.

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
