// mnist_clf78_x2_f168.v — VARIANTE de mnist_clf78_x2.v para ASIC: fmem de 168x9 en vez de 256x13 (24-sep-2026).
//   En FPGA la BRAM cuesta igual llena que vacia; en ASIC cada bit es un biestable. Resto IDENTICO.
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
module mnist_clf78_x2_f168 #(
    parameter integer CW = 9,
    parameter integer FW = 9,        // f168: las sumas de zonas no pasan de 484 (area util 22x22) -> caben en 9 bits
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
    // contado: `valido` salia calculado con el recuento de OTRA imagen. El banco suelto no
    // podia verlo porque mantenia `n_bordes` fijo para siempre; solo aparece en el flujo
    // continuo. Es la trampa de siempre: un banco vale por lo que puede romper.
    reg [10:0] nb_l;
    localparam signed [AW-1:0] MARGEN = 70;

    // ---- la memoria de caracteristicas: 168 de FW bits ----
    reg [FW-1:0] fmem [0:167];      // f168: se usan las direcciones 0..167, no 256
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
                    // porque el dato tarda dos ciclos en llegar (registro + lectura sincrona)
    reg       fase;          // 0 = derivando nivel 1 (32), 1 = derivando nivel 0 (8)
    reg [4:0] fidx;          // que caracteristica derivada
    reg [2:0] t;             // paso dentro de la derivacion (0..4)
    reg [FW-1:0] acc_d;
    reg signed [AW-1:0] acc0, acc1, mejor, segundo;
    reg [3:0] mejor_c;

    // direccion de la caracteristica 0 y de la siguiente, para pedirlas con un ciclo
    // de antelacion (la lectura es sincrona)
    wire [7:0] k0 = k_rom(7'd0);
    wire [7:0] dir_j_0 = (k0 < 8'd8) ? (8'd160+k0) : (k0 < 8'd40) ? (8'd128+(k0-8'd8)) : (k0-8'd40);
    wire [7:0] ka = k_rom(ja);
    wire [7:0] dir_ja = (ka < 8'd8) ? (8'd160+ka) : (ka < 8'd40) ? (8'd128+(ka-8'd8)) : (ka-8'd40);


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
                // en t=0..3 y los datos llegan en t=1..4, porque la memoria es sincrona.
                // Escribir en t=4 -que es lo que hacia antes- suma solo TRES de los
                // cuatro: el ultimo dato todavia no ha llegado. El sintoma era que la
                // suma TOTAL cuadraba pero el reparto entre zonas no, que es exactamente
                // el aviso de verificar.py: un desalineamiento deja el total intacto.
                S_DERIV: begin
                    if (t <= 3'd3) rd_a <= dir_src;          // pedir
                    // La direccion pedida cuando t valia k da su dato cuando t vale k+2:
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

                // Un ciclo de espera. La memoria es SINCRONA: el dato de la caracteristica 0
                // llega un ciclo despues de pedirla. Sin esto el primer producto multiplica
                // lo que hubiera en el puerto y todo el acumulado queda corrido una posicion.
                // dos ciclos de adelanto: se piden las direcciones 0 y 1 antes de
                // empezar a multiplicar, porque el dato de la 0 no llega hasta el tercero.
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
