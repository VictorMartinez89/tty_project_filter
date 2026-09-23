// mnist_clf78.v — CLASIFICADOR de 78 caracteristicas ELEGIDAS de las 168.
//
//   El de 40 (mnist_clf_canny_fw.v) toma 32 contadores -4 cuadrantes- y arma sus 40
//   caracteristicas con una regla fija. Este toma 128 contadores -16 zonas- y arma las
//   suyas leyendo una TABLA: k_rom(j) dice que caracteristica original (0..167) es la
//   j-esima elegida. Asi el mismo circuito sirve para cualquier seleccion: cambiar de
//   modelo es regenerar el .vh, no rehacer el datapath.
//
//   Por que 78: 78 x 10 clases = 780 multiplicacion-acumulacion, y entre cuadro y cuadro
//   hay 28x28 = 784 ciclos. Cabe con 4 de margen. Con 100 caracteristicas no cabria.
//
//   Las tres familias de caracteristica, todas derivadas de los MISMOS 128 contadores:
//     nivel 0 (k<8)    suma de las 16 zonas en esa orientacion
//     nivel 1 (k<40)   suma de las 4 zonas del cuadrante
//     nivel 2 (k>=40)  el contador tal cual
//   El nivel 0 y el 1 NO se guardan aparte: se derivan sumando, que es lo que ya hacia
//   el de 40 con sus cuadrantes.
`default_nettype none
module mnist_clf78 #(
    parameter integer CW = 9,        // bits por contador
    parameter integer AW = 24        // acumulador con signo
)(
    input  wire             clk,
    input  wire             reset,
    input  wire             start,
    input  wire [128*CW-1:0] cnt_i,  // 16 zonas x 8 orientaciones
    input  wire [10:0]      n_bordes,
    output reg              done,
    output reg  [3:0]       digito,
    output reg              valido,
    output reg signed [AW-1:0] score
);
`include "mnist_weights78.vh"

    localparam integer FW = CW + 4;      // sumar 16 contadores de CW bits: +4
    localparam S_IDLE=2'd0, S_MAC=2'd1, S_ARGMAX=2'd2, S_DONE=2'd3;

    // mismos umbrales de NADA que el de 40: no se tocan aqui
    localparam [10:0] B_MIN  = 11'd174;
    localparam [10:0] B_MAX  = 11'd376;
    localparam signed [AW-1:0] MARGEN = 70;

    reg [1:0]  st;
    reg [3:0]  c;
    reg [6:0]  j;                        // caracteristica elegida (0..77)
    reg signed [AW-1:0] acc, mejor, segundo;
    reg [3:0]  mejor_c;

    // desempaquetado del bus (yosys no admite arrays en puertos)
    wire [CW-1:0] cn [0:127];
    genvar gi;
    generate for (gi = 0; gi < 128; gi = gi + 1) begin : desemp
        assign cn[gi] = cnt_i[gi*CW +: CW];
    end endgenerate

    // --- que caracteristica original toca ahora ---
    wire [7:0] k  = k_rom(j);
    wire [2:0] bn = (k < 8'd8)  ? k[2:0]
                  : (k < 8'd40) ? (k - 8'd8)  & 3'b111
                                : (k - 8'd40) & 3'b111;
    wire [1:0] q  = (k - 8'd8)  >> 3;          // cuadrante, si es nivel 1
    wire [3:0] z  = (k - 8'd40) >> 3;          // zona,      si es nivel 2

    // nivel 0: suma de las 16 zonas en la orientacion bn
    wire [FW-1:0] s0 =
        {4'd0,cn[{4'd0 ,bn}]} + {4'd0,cn[{4'd1 ,bn}]} + {4'd0,cn[{4'd2 ,bn}]} + {4'd0,cn[{4'd3 ,bn}]} +
        {4'd0,cn[{4'd4 ,bn}]} + {4'd0,cn[{4'd5 ,bn}]} + {4'd0,cn[{4'd6 ,bn}]} + {4'd0,cn[{4'd7 ,bn}]} +
        {4'd0,cn[{4'd8 ,bn}]} + {4'd0,cn[{4'd9 ,bn}]} + {4'd0,cn[{4'd10,bn}]} + {4'd0,cn[{4'd11,bn}]} +
        {4'd0,cn[{4'd12,bn}]} + {4'd0,cn[{4'd13,bn}]} + {4'd0,cn[{4'd14,bn}]} + {4'd0,cn[{4'd15,bn}]};

    // nivel 1: suma de las 4 zonas del cuadrante q. zona = zy*4+zx, con
    // zy en {2*qy, 2*qy+1} y zx en {2*qx, 2*qx+1}.
    wire [3:0] za = {q[1],1'b0,q[0],1'b0};     // (2qy  , 2qx  )
    wire [3:0] zb = {q[1],1'b0,q[0],1'b1};     // (2qy  , 2qx+1)
    wire [3:0] zc = {q[1],1'b1,q[0],1'b0};     // (2qy+1, 2qx  )
    wire [3:0] zd = {q[1],1'b1,q[0],1'b1};     // (2qy+1, 2qx+1)
    wire [FW-1:0] s1 = {4'd0,cn[{za,bn}]} + {4'd0,cn[{zb,bn}]}
                     + {4'd0,cn[{zc,bn}]} + {4'd0,cn[{zd,bn}]};

    wire [FW-1:0] feat = (k < 8'd8) ? s0 : (k < 8'd40) ? s1 : {4'd0, cn[{z,bn}]};
    wire signed [3:0]    w    = w_rom({3'd0, c} * N_CARAC + {3'd0, j});
    wire signed [AW-1:0] prod = $signed({1'b0, feat}) * w;

    always @(posedge clk) begin
        if (reset) begin
            st <= S_IDLE; done <= 1'b0; digito <= 4'd0; valido <= 1'b0; score <= 0;
            c <= 0; j <= 0; acc <= 0; mejor <= 0; segundo <= 0; mejor_c <= 0;
        end else begin
            done <= 1'b0;
            case (st)
                S_IDLE: if (start) begin
                    c <= 0; j <= 0; acc <= b_rom(4'd0);
                    mejor <= {1'b1,{(AW-1){1'b0}}}; segundo <= {1'b1,{(AW-1){1'b0}}};
                    mejor_c <= 0; st <= S_MAC;
                end
                S_MAC: begin
                    acc <= acc + prod;
                    if (j == N_CARAC-1) st <= S_ARGMAX; else j <= j + 1'b1;
                end
                S_ARGMAX: begin
                    if (acc > mejor) begin
                        mejor <= acc; segundo <= mejor; mejor_c <= c;
                    end else if (acc > segundo) segundo <= acc;
                    if (c == N_CLASE-1) st <= S_DONE;
                    else begin acc <= b_rom(c + 4'd1); c <= c + 4'd1; j <= 0; st <= S_MAC; end
                end
                S_DONE: begin
                    digito <= mejor_c; score <= mejor;
                    valido <= (n_bordes >= B_MIN) && (n_bordes <= B_MAX)
                              && ((mejor - segundo) > MARGEN);
                    done <= 1'b1; st <= S_IDLE;
                end
            endcase
        end
    end
endmodule
