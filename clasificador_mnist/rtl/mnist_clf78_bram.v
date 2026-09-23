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
module mnist_clf78_bram #(
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
`include "mnist_weights78.vh"

    localparam [10:0] B_MIN = 11'd174, B_MAX = 11'd376;
    localparam signed [AW-1:0] MARGEN = 70;
    localparam S_IDLE=3'd0, S_DERIV=3'd1, S_ESCR=3'd2, S_MAC=3'd3, S_ARGMAX=3'd4, S_DONE=3'd5;

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

    reg [2:0] st;
    reg [3:0] c;
    reg [6:0] j;
    reg [4:0] dz;                 // zona en curso al derivar (0..15) o cuadrante (0..3)
    reg [2:0] db;                 // orientacion en curso (0..7)
    reg       dnivel;             // 0 = derivando nivel 1, 1 = derivando nivel 0
    reg [FW-1:0] dacc;
    reg signed [AW-1:0] acc, mejor, segundo;
    reg [3:0] mejor_c;

    wire [7:0] k = k_rom(j);
    // direccion de la caracteristica j: nivel 2 directo, nivel 1 y 0 ya derivadas
    wire [7:0] dir_j = (k < 8'd8)  ? (8'd160 + k)
                     : (k < 8'd40) ? (8'd128 + (k - 8'd8))
                                   : (k - 8'd40);
    wire signed [3:0]    w    = w_rom({3'd0,c} * N_CARAC + {3'd0,j});
    wire signed [AW-1:0] prod = $signed({1'b0, rd_d}) * w;

    always @(posedge clk) begin
        if (reset) begin
            st <= S_IDLE; done <= 1'b0; we_i <= 1'b0; digito <= 0; valido <= 0; score <= 0;
            c <= 0; j <= 0; dz <= 0; db <= 0; dnivel <= 0; dacc <= 0;
        end else begin
            done <= 1'b0; we_i <= 1'b0;
            case (st)
                // --- derivar nivel 1 (4 zonas por cuadrante) y luego nivel 0 (16) ---
                S_IDLE: if (start) begin
                    dz <= 0; db <= 0; dnivel <= 1'b0; dacc <= 0;
                    rd_a <= {4'd0, 1'b0, 3'd0};        // primera zona del cuadrante 0
                    st <= S_DERIV;
                end
                S_DERIV: begin
                    dacc <= dacc + rd_d;
                    if (dz[1:0] == 2'd3) st <= S_ESCR;
                    else begin
                        dz <= dz + 1'b1;
                        rd_a <= dnivel ? {1'b0, dz[3:0]+4'd1, db} : {3'd0, dz[1:0]+2'd1, db};
                    end
                end
                S_ESCR: begin
                    we_i <= 1'b1; wd_i <= dacc + rd_d;
                    wa_i <= dnivel ? (8'd160 + {5'd0,db}) : (8'd128 + {dz[4:2],db});
                    dacc <= 0;
                    if (db == 3'd7) begin
                        db <= 0;
                        if (!dnivel && dz[4:2] == 3'd3) begin dnivel <= 1'b1; dz <= 0; end
                        else if (dnivel) begin c <= 0; j <= 0; acc <= b_rom(4'd0); st <= S_MAC; end
                        else dz <= dz + 4'd4;
                    end else db <= db + 1'b1;
                    rd_a <= dnivel ? {4'd0, db+3'd1} : {3'd0, dz[4:2], db+3'd1};
                    if (st == S_ESCR) st <= S_DERIV;
                end
                // --- multiplicacion-acumulacion: SIEMPRE una lectura de memoria ---
                S_MAC: begin
                    acc <= acc + prod;
                    if (j == N_CARAC-1) st <= S_ARGMAX;
                    else begin j <= j + 1'b1; rd_a <= dir_j; end
                end
                S_ARGMAX: begin
                    if (acc > mejor) begin mejor <= acc; segundo <= mejor; mejor_c <= c; end
                    else if (acc > segundo) segundo <= acc;
                    if (c == N_CLASE-1) st <= S_DONE;
                    else begin acc <= b_rom(c+4'd1); c <= c+4'd1; j <= 0; st <= S_MAC; end
                end
                S_DONE: begin
                    digito <= mejor_c; score <= mejor;
                    valido <= (n_bordes >= B_MIN) && (n_bordes <= B_MAX) && ((mejor-segundo) > MARGEN);
                    done <= 1'b1; st <= S_IDLE;
                end
            endcase
        end
    end
endmodule
