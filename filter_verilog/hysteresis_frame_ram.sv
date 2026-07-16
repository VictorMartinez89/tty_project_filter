// =============================================================================
// hysteresis_frame_ram.sv -- Histeresis TRANSITIVA de Canny, SINTETIZABLE, sobre
//   un frame en RAM on-chip. Misma semantica que canny_hysteresis_frame.sv
//   (reconstruccion morfologica 8-conexa: confirmed |= weak & dilata8(confirmed))
//   pero SIN el vector plano combinacional de todo el frame: itera barridos raster
//   sobre la RAM hasta punto fijo -> escalable a 160x120.
//
//   Interfaz por STREAM (no puertos de H*W bits): carga la clase por pixel y luego
//   emite el borde por pixel. El frame se guarda PADDED (H+2 x W+2) con borde = 0,
//   asi TODO pixel real tiene ventana 3x3 completa (vecinos fuera de rango = 0) y
//   no hay casos especiales de borde.
//
//   FSM:  CLR (poner la RAM a 0) -> LOAD (stream de clase) -> SWEEP (barridos
//         in-place hasta que un barrido no confirme nada nuevo) -> READ (stream de
//         borde) -> DONE.
//   Escritura in-place = Gauss-Seidel: converge al MISMO punto fijo (unico) que el
//   golden, en <= pocas pasadas; termina cuando 'changed' queda en 0.
//
//   NOTA de sintesis: la RAM se accede por vecinos direccionados (9 lecturas/celda)
//   -> mapea a RAM distribuida (LUTRAM). Para 1 solo puerto de BRAM verdadero se
//   sustituye el acceso por vecinos por LINE BUFFERS (ventana deslizante, 1 lectura
//   por ciclo, estilo sobel_compass_control); misma semantica, es optimizacion de
//   recursos (trabajo futuro).
// =============================================================================
`default_nettype none
module hysteresis_frame_ram #(
    parameter integer H = 12,
    parameter integer W = 12
)(
    input  wire       clk_i,
    input  wire       nreset_i,       // activo-bajo
    // fase LOAD: stream de clase por pixel (raster, H*W pixeles)
    input  wire       in_valid_i,
    input  wire [1:0] class_i,        // 0 nada / 1 debil / 2 fuerte
    output wire       load_ready_o,   // 1 = en fase LOAD (acepta clase)
    // fase READ: stream de borde por pixel (raster)
    output reg        out_valid_o,
    output reg        edge_o,
    output reg        done_o          // 1 = frame terminado (borde emitido)
);
    localparam integer PW = W + 2;
    localparam integer PH = H + 2;
    localparam integer N  = PW * PH;
    localparam integer AW = $clog2(N);
    localparam integer ROWSKIP = PW - W + 1;   // salto de fin de fila interior (=3)

    reg [1:0] mem [0:N-1];            // {weak, confirmed} por celda (padded, borde=0)

    localparam [2:0] S_CLR=0, S_LOAD=1, S_SWEEP=2, S_CHK=3, S_READ=4, S_DONE=5;
    reg [2:0]    state;
    reg [AW-1:0] addr;               // CLR: barre 0..N-1
    reg [AW-1:0] ca;                 // LOAD/SWEEP/READ: direccion de celda interior
    reg [15:0]   rr, cc;             // coords reales (0..H-1, 0..W-1)
    reg          changed;

    // celda actual y OR de sus 8 vecinos (padded -> siempre en rango por el borde=0)
    wire [1:0] c    = mem[ca];
    wire       conf_c = c[0];
    wire       weak_c = c[1];
    wire       nb8  = mem[ca-PW-1][0] | mem[ca-PW][0] | mem[ca-PW+1][0] |
                      mem[ca-1   ][0]                 | mem[ca+1   ][0] |
                      mem[ca+PW-1][0] | mem[ca+PW][0] | mem[ca+PW+1][0];
    wire       newc = conf_c | (weak_c & nb8);

    assign load_ready_o = (state == S_LOAD);

    always @(posedge clk_i or negedge nreset_i) begin
        if (!nreset_i) begin
            state<=S_CLR; addr<=0; ca<=0; rr<=0; cc<=0; changed<=0;
            out_valid_o<=1'b0; edge_o<=1'b0; done_o<=1'b0;
        end else begin
            out_valid_o <= 1'b0;
            case (state)
            // ---- poner toda la RAM a 0 (incluye el padding) ----
            S_CLR: begin
                mem[addr] <= 2'b00;
                if (addr==N-1) begin addr<=0; ca<=PW+1; rr<=0; cc<=0; state<=S_LOAD; end
                else addr<=addr+1'b1;
            end
            // ---- cargar el stream de clase en las celdas interiores ----
            S_LOAD: if (in_valid_i) begin
                mem[ca] <= {class_i==2'd1, class_i==2'd2};   // {weak, confirmed}
                if (rr==H-1 && cc==W-1) begin
                    ca<=PW+1; rr<=0; cc<=0; changed<=1'b0; state<=S_SWEEP;
                end else if (cc==W-1) begin
                    cc<=0; rr<=rr+1'b1; ca<=ca+ROWSKIP;
                end else begin
                    cc<=cc+1'b1; ca<=ca+1'b1;
                end
            end
            // ---- un barrido raster in-place ----
            S_SWEEP: begin
                mem[ca] <= {weak_c, newc};                   // in-place (preserva weak)
                if (newc != conf_c) changed <= 1'b1;
                if (rr==H-1 && cc==W-1) begin
                    state<=S_CHK;
                end else if (cc==W-1) begin
                    cc<=0; rr<=rr+1'b1; ca<=ca+ROWSKIP;
                end else begin
                    cc<=cc+1'b1; ca<=ca+1'b1;
                end
            end
            // ---- otro barrido si algo cambio, si no -> leer ----
            S_CHK: begin
                ca<=PW+1; rr<=0; cc<=0;
                if (changed) begin changed<=1'b0; state<=S_SWEEP; end
                else         begin                state<=S_READ;  end
            end
            // ---- emitir el mapa de bordes (confirmed) por pixel ----
            S_READ: begin
                out_valid_o <= 1'b1;
                edge_o      <= mem[ca][0];                   // confirmed = borde
                if (rr==H-1 && cc==W-1) begin
                    state<=S_DONE;
                end else if (cc==W-1) begin
                    cc<=0; rr<=rr+1'b1; ca<=ca+ROWSKIP;
                end else begin
                    cc<=cc+1'b1; ca<=ca+1'b1;
                end
            end
            S_DONE: done_o <= 1'b1;
            endcase
        end
    end
endmodule
`default_nettype wire
