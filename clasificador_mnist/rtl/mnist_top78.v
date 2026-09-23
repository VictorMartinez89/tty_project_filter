// mnist_top78.v — la cadena nueva completa: extractor de 16 zonas + clasificador de 78.
//
//   Existe por dos razones. La primera es que es la integracion que el diseno necesita:
//   el extractor ya no entrega un bus de 128 contadores sino un PUERTO, asi que alguien
//   tiene que recorrerlo. La segunda es que medir los modulos por separado no deja
//   emplazar: sus buses internos se convierten en patas y piden 398 de las 39 que hay.
//   Con un top de verdad las patas son veinte y pico y nextpnr puede hacer su trabajo,
//   que es lo unico que da la FRECUENCIA.
//
//   El trasvase son 128 lecturas encadenadas con 128 escrituras, con dos ciclos de
//   desfase porque la memoria del extractor es sincrona. Cuesta 130 ciclos, que sumados
//   a los 647 del clasificador dan 777: cuatro por debajo de los 784 que dura un cuadro.
`default_nettype none
module mnist_top78 #(
    parameter integer CW = 9,
    parameter integer FW = 13
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

    mnist_feat16_mem #(.CW(CW)) ext (
        .clk(clk), .reset(reset), .clr(1'b0), .in_valid(in_valid), .in_pix(in_pix),
        .thr_hi(thr_hi), .thr_lo(thr_lo),
        .frame_done(frame_done), .rd_a(rd_a), .rd_d(rd_d), .n_bordes(n_bordes),
        .dbg_val(), .dbg_borde(), .dbg_cx(), .dbg_cy(), .dbg_arr(), .dbg_mag(), .dbg_cls()
    );

    // --- trasvase: 128 contadores del extractor a la memoria del clasificador ---
    localparam T_IDLE=2'd0, T_COPIA=2'd1, T_ARR=2'd2;
    reg [1:0]  ts;
    reg [7:0]  cnt;          // 0..129: dos de mas por el desfase de la lectura
    reg        wr_en;
    reg [7:0]  wr_addr;
    reg        arranca;
    wire [FW-1:0] wr_data = {{(FW-CW){1'b0}}, rd_d};

    always @(posedge clk) begin
        if (reset) begin
            ts <= T_IDLE; cnt <= 0; wr_en <= 1'b0; rd_a <= 0; arranca <= 1'b0;
        end else begin
            wr_en <= 1'b0; arranca <= 1'b0;
            case (ts)
                T_IDLE: if (frame_done) begin cnt <= 0; rd_a <= 0; ts <= T_COPIA; end
                T_COPIA: begin
                    if (cnt <= 8'd127) rd_a <= cnt[6:0];
                    if (cnt >= 8'd2) begin              // el dato de cnt-2 ya llego
                        wr_en <= 1'b1; wr_addr <= cnt - 8'd2;
                    end
                    if (cnt == 8'd129) begin ts <= T_ARR; end
                    else cnt <= cnt + 1'b1;
                end
                T_ARR: begin arranca <= 1'b1; ts <= T_IDLE; end
            endcase
        end
    end

    mnist_clf78_x2 #(.CW(CW), .FW(FW)) clf (
        .clk(clk), .reset(reset),
        .wr_en(wr_en), .wr_addr(wr_addr), .wr_data(wr_data),
        .start(arranca), .n_bordes(n_bordes),
        .done(done), .digito(digito), .valido(valido), .score()
    );
endmodule
