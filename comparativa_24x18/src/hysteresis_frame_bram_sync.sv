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
                else begin addr<=PW+1; rr<=0; cc<=0; iss<=0; issue_cnt<=0; emit_cnt<=0; state<=S_READ; end
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
