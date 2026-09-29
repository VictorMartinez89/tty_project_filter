// mnist_clf98.v — Canny-98: el clasificador de Canny-78 con UNA CAPA OCULTA de 120 neuronas.
//
//   La mitad de delante es la de mnist_clf78_x2.v, sin tocar: la memoria fmem con las 168
//   caracteristicas (0..127 nivel 2 del extractor, 128..159 nivel 1 y 160..167 nivel 0 derivados
//   aqui, seis ciclos por caracteristica). Lo que cambia es la cuenta:
//
//     capa 1:  acc = b1[j] + sum_k W1[j][k] * f[k]         j = 0..119, k = 0..167
//              h[j] = min(255, max(0, acc >>> S))           una activacion de 8 bits: un desplazamiento
//     capa 2:  s[c] = b2[c] + sum_j W2[c][j] * h[j]         c = 0..9
//     digito = argmax(s), el INDICE MAS BAJO en empate, como numpy.argmax
//
//   Pesos de 4 bits con signo, UNA sola escala por capa (el argmax no la ve), asi que no hay ninguna
//   multiplicacion por constante. Todos en una memoria de 21 504 x 4 bits = 21 bloques SB_RAM40_4K:
//   W1 en las direcciones j*168+k y W2 en 20160 + c*120 + j. Las activaciones van a la SPRAM, que no
//   necesita inicializarse. Una multiplicacion-acumulacion por ciclo: 120*171 + 10*123 ciclos, unos
//   21 800, que a 12 MHz son 1,8 ms por imagen.
//
//   Las lecturas son sincronas y la direccion tambien va registrada: el dato llega DOS ciclos despues
//   de pedirlo. Por eso cada vuelta pide sus direcciones, deja que la tuberia de dos etapas se vacie
//   (iss1 -> iss2) y solo entonces cierra la neurona. Es la leccion de clf78_x2: contar la latencia,
//   no suponerla.
//
//   Modelo de referencia: canny98_golden.py (pesos_canny98_H120.npz). Criterio: bit a bit.
`default_nettype none
module mnist_clf98_asic #(
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

    // ---- pesos y sesgos: funciones case (canny98_rom.vh); en silicio no hay BRAM que inicializar ----
`include "canny98_rom.vh"

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
    always @(posedge clk) w_d <= w_rom(w_a);

    // ---- activaciones en la SPRAM (16K x 16; se usan 120 palabras) ----
    reg  [13:0] sp_a;
    reg  [15:0] sp_din;
    reg         sp_we;
    wire [15:0] sp_dout;
    // en sky130 no hay SPRAM: 128 x 8 bits en registros, con la misma temporizacion que DATAOUT
    reg [7:0] hmem [0:127];
    reg [7:0] hq;
    always @(posedge clk) if (sp_we) hmem[sp_a[6:0]] <= sp_din[7:0]; else hq <= hmem[sp_a[6:0]];
    assign sp_dout = {8'd0, hq};

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
    wire signed [AW-1:0] prod2 = $signed({1'b0, sp_dout[7:0]}) * w5;     // capa 2: activacion x peso
    wire signed [AW-1:0] acc_sh = acc >>> S;
    wire [7:0] h8 = acc_sh[AW-1] ? 8'd0 : (acc_sh > 255 ? 8'd255 : acc_sh[7:0]);
    wire signed [AW-1:0] b1v = $signed(b1_rom(j));
    wire [6:0] jn = j + 7'd1;
    wire signed [AW-1:0] b1n = $signed(b1_rom(jn));
    wire [3:0] cn = c + 4'd1;
    wire signed [AW-1:0] b2v = $signed(b2_rom(c));     // siempre con indice variable:
    // leer b1mem[0] o b2mem[0] con indice CONSTANTE hacia que yosys los partiera en cables sueltos y
    // avisara «used but has no driver». j y c valen 0 al llegar aqui, asi que se lee por j y c.
    wire signed [AW-1:0] b2n = $signed(b2_rom(cn));

    always @(posedge clk) begin
        if (reset) begin
            st <= S_IDLE; done <= 1'b0; we_i <= 1'b0; sp_we <= 1'b0;
            digito <= 0; valido <= 0; score <= 0;
            fase <= 0; fidx <= 0; t <= 0; acc_d <= 0; rd_a <= 0; w_a <= 0; sp_a <= 0; sp_din <= 0;
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

                // capa 1: se piden las NF caracteristicas y sus pesos, se acumulan dos ciclos
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
                            mejor <= {1'b1, {(AW-1){1'b0}}}; segundo <= {1'b1, {(AW-1){1'b0}}}; mejor_c <= 0;
                            st <= S_L2;
                        end else begin
                            j <= jn; wbase <= wbase + NF; acc <= b1n;
                        end
                    end
                end

                // capa 2: lo mismo sobre las H activaciones de la SPRAM, una clase por vuelta
                S_L2: begin
                    if (ka < H) begin
                        sp_a <= {6'd0, ka}; w_a <= wbase + ka; ka <= ka + 1'b1; iss1 <= 1'b1;
                    end else iss1 <= 1'b0;
                    iss2 <= iss1;
                    if (iss2) acc <= acc + prod2;
                    if (ka == H && !iss1 && !iss2) begin
                        // argmax en el orden 0..9: '>' estricto conserva el indice mas bajo
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
