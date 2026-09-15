// mnist_clf.v — CLASIFICADOR: 40 caracteristicas -> 10 puntajes -> el digito.
//
//   Un producto matriz-vector y un maximo. Nada mas: sin capas ocultas, sin activacion, sin
//   realimentacion. Se hace SERIE -una multiplicacion-acumulacion por ciclo, 400 ciclos- porque
//   el cuadro tarda ~800 ciclos en entrar: el clasificador termina antes de que llegue el
//   siguiente. Hacerlo paralelo costaria 400 multiplicadores para ganar un tiempo que sobra.
//
//   Las 40 caracteristicas se arman al vuelo desde los 32 contadores:
//     k = 0..7   -> nivel 0: suma de los cuatro cuadrantes en esa orientacion
//     k = 8..39  -> nivel 1: el contador del cuadrante tal cual
//
//   Los pesos son de 4 bits con signo y viven en una ROM sintetizada (`mnist_weights.vh`,
//   generado por entrenar_hw.py). Cambiar el modelo = regenerar ese archivo y re-sintetizar;
//   si el chip lleva CPU, el mismo mecanismo del periferico 0x0045 permitiria cargarlos.
`default_nettype none
module mnist_clf_canny_fw #(
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
`include "mnist_weights_canny_fw.vh"

    localparam integer FW = CW + 2;                       // el nivel 0 suma 4 cuadrantes: +2 bits
    localparam S_IDLE=2'd0, S_MAC=2'd1, S_ARGMAX=2'd2, S_DONE=2'd3;

    reg [1:0]  st;
    reg [3:0]  c;                                          // clase en curso  (0..9)
    reg [5:0]  k;                                          // caracteristica  (0..39)
    reg signed [AW-1:0] acc, mejor, segundo;
    reg [3:0]  mejor_c;

    // Umbrales del veredicto NADA, calibrados sobre 3 000 imagenes de test:
    //   * densidad de bordes: un digito real deja entre 161 y 369 (p5..p95) de 576. Un cuadro
    //     vacio deja 0 y una textura deja 500+. La densidad sola ya descarta los dos extremos.
    //   * margen entre el mejor puntaje y el segundo: con la imagen EN BLANCO el clasificador
    //     igual predice "1" con margen 112, porque el sesgo solo ya favorece esa clase. Por eso
    //     el margen NO alcanza y la densidad es la que manda; el margen filtra los ambiguos.
    //   Con 140/430/30: acepta el 86.7 % de los digitos, y entre los aceptados la precision sube
    //   de 89.2 % a 93.9 % filtrando el 52 % de los errores. Decir "no se" mejora lo que si dice.
    localparam [10:0] B_MIN  = 11'd174;   // calibrado para hi=90 lo=32
    localparam [10:0] B_MAX  = 11'd376;
    localparam signed [AW-1:0] MARGEN = 70;

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
                    // el acumulado de la clase c ya esta completo: comparar y guardar los DOS
                    // mejores, que es lo que permite medir la confianza sin dividir nada.
                    // Las DOS primeras clases se tratan aparte, y no es un capricho:
                    //   * con `segundo` arrancando en CERO, si el segundo mejor puntaje real era
                    //     negativo nunca lo superaba y `mejor - segundo` valia `mejor`, un numero
                    //     grande: el margen siempre pasaba y la clase NADA aceptaba el 100 %.
                    //   * con `segundo` arrancando en el MINIMO con signo, la resta DESBORDA los
                    //     AW bits y el resultado sale indefinido.
                    // Sin centinela no hay ninguno de los dos problemas: en c==1 ya hay dos
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
                default: st <= S_IDLE;      // sin default se infieren latches (la leccion de la quark)
            endcase
        end
    end
endmodule
`default_nettype wire
