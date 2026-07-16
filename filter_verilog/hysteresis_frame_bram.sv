// =============================================================================
// hysteresis_frame_bram.sv -- Histeresis TRANSITIVA de Canny, SINTETIZABLE A BRAM.
//   Misma semantica que canny_hysteresis_frame.sv (reconstruccion morfologica
//   8-conexa: confirmed |= weak & dilata8(confirmed)) pero escalable a 160x120:
//   guarda el frame en RAM y lo barre con LINE BUFFERS (ventana deslizante 3x3),
//   1 LECTURA + 1 ESCRITURA por ciclo -> mapea a BRAM de doble puerto simple.
//
//   Frame PADDED (H+2 x W+2) con borde=0 -> todo pixel real tiene ventana 3x3
//   completa (vecinos fuera de rango = 0), sin casos especiales de borde.
//
//   FSM:  CLR (RAM a 0) -> LOAD (stream de clase) -> SWEEP (barridos raster
//         in-place hasta que un barrido no confirme nada) -> READ (stream de
//         borde) -> DONE.
//   El barrido reusa el patron EXACTO de sobel_compass_control (2 line buffers +
//   ventana w0..w8); el centro de la ventana es w4 = celda (raddr_d - PW - 1),
//   con raddr_d = direccion de lectura retrasada 1 ciclo (la ventana se completa
//   un ciclo despues de leer el pixel entrante). Escritura in-place = converge al
//   MISMO punto fijo (unico) que el golden; termina cuando 'changed' queda en 0.
//
//   ESTADO DE SINTESIS (honesto): la RTL es CORRECTA y esta VERIFICADA vs golden
//   (test_hyst_ram, 6/6). PERO usa LECTURA ASINCRONA (bot = mem[raddr]) y escritura
//   dentro de un bloque con reset asincrono -> yosys mapea 'mem' a REGISTROS, no a
//   BRAM (a 160x120 = ~40k FF, no cabe). Para BRAM VERDADERA hace falta el patron
//   sincrono: (1) lectura registrada 'rdata <= mem[ra]' (1 ciclo de latencia),
//   (2) el mem en un always @(posedge clk) SIN reset (la BRAM no se resetea; para
//   eso esta la fase CLR). Eso agrega una etapa de pipeline al barrido = el
//   refactor pendiente (misma semantica, ya verificada aqui como referencia).
// =============================================================================
`default_nettype none
module hysteresis_frame_bram #(
    parameter integer H = 12,
    parameter integer W = 12
)(
    input  wire       clk_i,
    input  wire       nreset_i,       // activo-bajo
    input  wire       in_valid_i,     // LOAD: clase valida
    input  wire [1:0] class_i,        // 0 nada / 1 debil / 2 fuerte
    output wire       load_ready_o,   // 1 = en fase LOAD
    output reg        out_valid_o,    // READ: borde valido
    output reg        edge_o,
    output reg        done_o
);
    localparam integer PW = W + 2;
    localparam integer PH = H + 2;
    localparam integer N  = PW * PH;
    localparam integer AW = $clog2(N);
    localparam integer ROWSKIP = PW - W + 1;   // salto de fin de fila interior (=3)

    reg [1:0] mem [0:N-1];            // {weak, confirmed} por celda (padded, borde=0)
    reg [1:0] line1 [0:PW-1];         // fila (prow-1)
    reg [1:0] line2 [0:PW-1];         // fila (prow-2)
    reg [1:0] w0,w1,w2,w3,w4,w5,w6,w7,w8;

    localparam [2:0] S_CLR=0, S_LOAD=1, S_SWEEP=2, S_CHK=3, S_READ=4, S_DONE=5;
    reg [2:0]    state;
    reg [AW-1:0] addr;               // CLR: barre 0..N-1  ;  LOAD/READ: celda interior
    reg [15:0]   rr, cc;             // LOAD/READ: coords reales (0..H-1,0..W-1)
    // barrido:
    reg [AW-1:0] raddr, raddr_d;     // puntero de lectura raster (padded) y su retraso 1 ciclo
    reg [15:0]   prow, pcol, prow_d, pcol_d;
    reg          changed;

    // lecturas async (como los line buffers de Diana)
    wire [1:0] bot = mem[raddr];     // pixel entrante (padded) en el barrido
    wire [1:0] top = line2[pcol];
    wire [1:0] mid = line1[pcol];
    // centro de la ventana actual = w4 (corresponde a la celda raddr_d - PW - 1)
    wire conf_c = w4[0];
    wire weak_c = w4[1];
    wire nb8 = w0[0]|w1[0]|w2[0]|w3[0]|w5[0]|w6[0]|w7[0]|w8[0];
    wire newc = conf_c | (weak_c & nb8);
    wire center_valid = (prow_d >= 2) && (pcol_d >= 2);

    assign load_ready_o = (state == S_LOAD);

    always @(posedge clk_i or negedge nreset_i) begin
        if (!nreset_i) begin
            state<=S_CLR; addr<=0; rr<=0; cc<=0; changed<=0;
            raddr<=0; raddr_d<=0; prow<=0; pcol<=0; prow_d<=0; pcol_d<=0;
            w0<=0;w1<=0;w2<=0;w3<=0;w4<=0;w5<=0;w6<=0;w7<=0;w8<=0;
            out_valid_o<=1'b0; edge_o<=1'b0; done_o<=1'b0;
        end else begin
            out_valid_o <= 1'b0;
            case (state)
            // ---- poner toda la RAM a 0 (incluye padding) ----
            S_CLR: begin
                mem[addr] <= 2'b00;
                if (addr==N-1) begin addr<=PW+1; rr<=0; cc<=0; state<=S_LOAD; end
                else addr<=addr+1'b1;
            end
            // ---- cargar el stream de clase en las celdas interiores ----
            S_LOAD: if (in_valid_i) begin
                mem[addr] <= {class_i==2'd1, class_i==2'd2};   // {weak, confirmed}
                if (rr==H-1 && cc==W-1) begin
                    raddr<=0; raddr_d<=0; prow<=0; pcol<=0; prow_d<=0; pcol_d<=0;
                    w0<=0;w1<=0;w2<=0;w3<=0;w4<=0;w5<=0;w6<=0;w7<=0;w8<=0;
                    changed<=1'b0; state<=S_SWEEP;
                end else if (cc==W-1) begin
                    cc<=0; rr<=rr+1'b1; addr<=addr+ROWSKIP;
                end else begin
                    cc<=cc+1'b1; addr<=addr+1'b1;
                end
            end
            // ---- un barrido raster con ventana deslizante (in-place) ----
            S_SWEEP: begin
                // 1) procesar el centro de la ventana ACTUAL (w4 = celda raddr_d-PW-1)
                if (center_valid) begin
                    mem[raddr_d - PW - 1] <= {weak_c, newc};   // in-place (preserva weak)
                    if (newc != conf_c) changed <= 1'b1;
                end
                // 2) ensamblar la ventana con el pixel entrante (identico a sobel_compass_control)
                w0<=w1; w1<=w2; w2<=top;
                w3<=w4; w4<=w5; w5<=mid;
                w6<=w7; w7<=w8; w8<=bot;
                line2[pcol] <= line1[pcol];
                line1[pcol] <= bot;
                // 3) registrar el retraso (coords de la ventana recien formada)
                raddr_d<=raddr; prow_d<=prow; pcol_d<=pcol;
                // 4) avanzar / drenar el ultimo centro
                if (raddr_d == N-1) begin
                    state <= S_CHK;
                end else if (raddr != N-1) begin
                    if (pcol==PW-1) begin pcol<=0; prow<=prow+1'b1; end
                    else pcol<=pcol+1'b1;
                    raddr <= raddr + 1'b1;
                end
            end
            // ---- otro barrido si algo cambio; si no -> leer ----
            S_CHK: begin
                raddr<=0; raddr_d<=0; prow<=0; pcol<=0; prow_d<=0; pcol_d<=0;
                w0<=0;w1<=0;w2<=0;w3<=0;w4<=0;w5<=0;w6<=0;w7<=0;w8<=0;
                if (changed) begin changed<=1'b0; state<=S_SWEEP; end
                else         begin addr<=PW+1; rr<=0; cc<=0; state<=S_READ; end
            end
            // ---- emitir el mapa de bordes (confirmed) por pixel ----
            S_READ: begin
                out_valid_o <= 1'b1;
                edge_o      <= mem[addr][0];
                if (rr==H-1 && cc==W-1) begin
                    state<=S_DONE;
                end else if (cc==W-1) begin
                    cc<=0; rr<=rr+1'b1; addr<=addr+ROWSKIP;
                end else begin
                    cc<=cc+1'b1; addr<=addr+1'b1;
                end
            end
            S_DONE: done_o <= 1'b1;
            endcase
        end
    end
endmodule
`default_nettype wire
