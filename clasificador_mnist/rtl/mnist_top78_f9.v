// mnist_top78_f9.v — VARIANTE de mnist_top78.v con FW = 9 y el clasificador f168 (24-sep-2026). Resto IDENTICO.
// mnist_top78.v — la cadena nueva completa: extractor de 16 zonas + clasificador de 78.
//
//   Existe por dos razones. La primera es que es la integracion que el diseno necesita:
//   el extractor ya no entrega un bus de 128 contadores sino un PUERTO, asi que alguien
//   tiene que recorrerlo. La segunda es que medir los modulos por separado no deja
//   emplazar: sus buses internos se convierten en patas y piden 398 de las 39 que hay.
//   Con un top de verdad las patas son veinte y pico y nextpnr puede hacer su trabajo,
//   que es lo unico que da la FRECUENCIA.
//
//   El trasvase son 128 lecturas encadenadas con 128 escrituras. El desfase es UNO, no dos:
//   `rd_a` es un registro que va un ciclo por detras de `cnt`, y la memoria entrega el dato
//   un ciclo despues de eso, asi que durante el ciclo `c` el dato que hay en `rd_d` es el de
//   la direccion `c-1`. Con desfase dos -como estaba- el trasvase entregaba fmem[k]=feat[k+1]:
//   se perdia la caracteristica 0 y la 127 entraba dos veces. Lo encontro el banco de la
//   cadena completa el 23-sep, que compara los tres sitios por separado.
//   Cuesta 130 ciclos, que sumados a los 647 del clasificador dan 777: siete por debajo de
//   los 784 que dura un cuadro.
//
//   De paso el trasvase VACIA cada contador al leerlo (`rd_clr`) y al terminar descongela el
//   extractor (`reanuda`). Sin eso el diseno clasificaba UN cuadro y se quedaba quieto para
//   siempre, porque `listo` solo lo baja un reset.
`default_nettype none
module mnist_top78_f9 #(
    parameter integer CW = 9,
    parameter integer FW = 9
)(
    input  wire       clk,
    input  wire       reset,
    input  wire       in_valid,
    input  wire [7:0] in_pix,
    input  wire [7:0] thr_hi,
    input  wire [7:0] thr_lo,
    output wire       done,
    output wire [3:0] digito,
    output wire       valido
);
    wire        frame_done;
    wire [10:0] n_bordes;
    reg  [6:0]  rd_a;
    wire [CW-1:0] rd_d;
    reg         rd_clr, reanuda;

    mnist_feat16_mem #(.CW(CW)) ext (
        .clk(clk), .reset(reset), .clr(1'b0), .in_valid(in_valid), .in_pix(in_pix),
        .thr_hi(thr_hi), .thr_lo(thr_lo),
        .frame_done(frame_done), .rd_a(rd_a), .rd_d(rd_d),
        .rd_clr(rd_clr), .reanuda(reanuda), .n_bordes(n_bordes),
        .dbg_val(), .dbg_borde(), .dbg_cx(), .dbg_cy(), .dbg_arr(), .dbg_mag(), .dbg_cls()
    );

    // --- trasvase: 128 contadores del extractor a la memoria del clasificador ---
    localparam T_IDLE=2'd0, T_COPIA=2'd1, T_ARR=2'd2;
    reg [1:0]  ts;
    reg [7:0]  cnt;          // 0..128: uno de mas por el desfase de la lectura
    reg        wr_en;
    reg [7:0]  wr_addr;
    reg        arranca;
    wire [FW-1:0] wr_data = rd_d;   // f9: FW = CW, sin relleno (una replicacion de ancho 0 no es Verilog-2005 valido)

    always @(posedge clk) begin
        if (reset) begin
            ts <= T_IDLE; cnt <= 0; wr_en <= 1'b0; rd_a <= 0; arranca <= 1'b0;
            rd_clr <= 1'b0; reanuda <= 1'b0;
        end else begin
            wr_en <= 1'b0; arranca <= 1'b0; rd_clr <= 1'b0; reanuda <= 1'b0;
            case (ts)
                T_IDLE: if (frame_done) begin cnt <= 0; rd_a <= 0; ts <= T_COPIA; end
                T_COPIA: begin
                    if (cnt <= 8'd127) rd_a <= cnt[6:0];
                    // en el ciclo `c` la memoria ya entrega la direccion `c-1`
                    if (cnt >= 8'd1) begin wr_en <= 1'b1; wr_addr <= cnt - 8'd1; end
                    // OJO: `rd_clr` va SIN la guarda de `cnt >= 1`, y eso no es un descuido.
                    // Es un registro, asi que sube un ciclo despues de la condicion; con la
                    // guarda llegaba alta cuando `rd_a` ya valia 1, y vaciaba las casillas 1
                    // a 127 SALTANDOSE LA 0. La 0 se quedaba con la cuenta del cuadro
                    // anterior y la arrastraba para siempre. Solo se ve cuando la esquina
                    // superior izquierda tiene borde en la orientacion 0 -raro en MNIST-, y
                    // desde ahi ya no se va: aparecio en la imagen 360 de 10 000 y ensucio
                    // todas las siguientes con tres cuentas de mas. Lo cazo el espia de
                    // escrituras a la casilla 0, que mostro que NADIE la vaciaba nunca.
                    rd_clr <= 1'b1;
                    if (cnt == 8'd128) begin ts <= T_ARR; end
                    else cnt <= cnt + 1'b1;
                end
                T_ARR: begin arranca <= 1'b1; reanuda <= 1'b1; ts <= T_IDLE; end
            endcase
        end
    end

    mnist_clf78_x2_f168 #(.CW(CW), .FW(FW)) clf (
        .clk(clk), .reset(reset),
        .wr_en(wr_en), .wr_addr(wr_addr), .wr_data(wr_data),
        .start(arranca), .n_bordes(n_bordes),
        .done(done), .digito(digito), .valido(valido), .score()
    );
endmodule
