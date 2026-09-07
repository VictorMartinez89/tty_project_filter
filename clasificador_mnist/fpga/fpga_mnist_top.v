// fpga_mnist_top.v — el clasificador de digitos CORRIENDO EN LA iCE40UP5K.
//
//   Los diez digitos de prueba viven en una ROM dentro del bitstream (la FPGA no tiene de donde
//   leer imagenes). El diseno los pasa uno por uno por el MISMO mnist_top que se verifico contra
//   el golden, y manda por UART una linea legible con lo esperado y lo predicho:
//
//       0->0 ok
//       1->1 ok
//       2->0 XX
//       ...
//       8/10
//
//   Terminal: 115200 8N1 en el puerto serie de la iCESugar.  El LED verde queda encendido
//   cuando termina la ronda; el rojo parpadea si hubo algun error.
//
//   Pines (iCESugar v1.5, sg48): clk=35, uart_tx=6, leds 39=VERDE 40=ROJO 41=AZUL.
//   OJO con los LEDs: en esta placa RGB0/pin39 es VERDE y RGB1/pin40 es ROJO (verificado).
`default_nettype none
module top (
    input  wire clk,
    output wire uart_tx_pin,
    output wire led_g, led_r, led_b
);
    localparam integer N_DIG = 10, PX = 28*28;
    localparam integer PASADAS = 3;      // ceba line-buffers, cuenta, drena (como el banco)

    reg        reset = 1'b1;
    reg [7:0]  rst_cnt = 8'd0;
    always @(posedge clk) begin
        if (rst_cnt != 8'hFF) begin rst_cnt <= rst_cnt + 8'd1; reset <= 1'b1; end
        else reset <= 1'b0;
    end

    // ---------------- ROM de digitos ----------------
    reg  [3:0]  sel;                     // que digito se esta clasificando
    reg  [9:0]  px;                      // pixel dentro del digito
    reg  [1:0]  pasada;
    wire [12:0] addr = sel*PX + px;   // 10*784-1 = 7839 entra en 13 bits
    wire [7:0]  pix;
    wire [3:0]  etiqueta;
    rom_digitos ROM (.addr(addr), .pix(pix), .sel(sel), .etiqueta(etiqueta));

    // ---------------- el clasificador (el mismo verificado) ----------------
    reg        clr, feed;
    wire       done;
    wire [3:0] digito;
    mnist_top #(.H(28),.W(28),.CW(9)) CLF (
        .clk(clk), .reset(reset), .clr(clr),
        .in_valid(feed), .in_pix(pix), .thr(8'd60),
        .done(done), .digito(digito));

    // ---------------- UART ----------------
    reg  [7:0] tx_dato; reg tx_env;
    wire       tx_listo;
    uart_tx #(.DIVISOR(104)) U (
        .clk(clk), .reset(reset), .dato(tx_dato), .enviar(tx_env),
        .tx(uart_tx_pin), .listo(tx_listo));

    // ---------------- maquina principal ----------------
    localparam S_INIT=0, S_CLR=1, S_FEED=2, S_ESPERA=3, S_MSG=4, S_FIN=5, S_TOT=6;
    reg [2:0] st;
    reg [2:0] msg_i;                     // caracter dentro de la linea
    reg [3:0] guardado;                  // el digito predicho, congelado
    reg [3:0] aciertos;
    reg       hubo_error;

    // la linea es: <esperado> - > <predicho> espacio o k \n   -> 7 caracteres
    reg [7:0] linea [0:6];
    always @(*) begin
        linea[0] = 8'h30 + etiqueta;
        linea[1] = "-";
        linea[2] = ">";
        linea[3] = 8'h30 + guardado;
        linea[4] = " ";
        linea[5] = (guardado == etiqueta) ? "o" : "X";
        linea[6] = 8'h0A;
    end

    always @(posedge clk) begin
        if (reset) begin
            st <= S_INIT; sel <= 4'd0; px <= 10'd0; pasada <= 2'd0;
            clr <= 1'b0; feed <= 1'b0; tx_env <= 1'b0; msg_i <= 3'd0;
            aciertos <= 4'd0; hubo_error <= 1'b0; guardado <= 4'd0;
        end else begin
            tx_env <= 1'b0; clr <= 1'b0; feed <= 1'b0;
            case (st)
                S_INIT: begin px <= 10'd0; pasada <= 2'd0; st <= S_FEED; end
                S_CLR:  begin clr <= 1'b1; st <= S_FEED; end
                S_FEED: begin
                    feed <= 1'b1;
                    if (px == PX-1) begin
                        px <= 10'd0;
                        if (pasada == PASADAS-1) st <= S_ESPERA;
                        else begin
                            pasada <= pasada + 2'd1;
                            st <= (pasada == 2'd0) ? S_CLR : S_FEED;   // clr antes de la 2a
                        end
                    end else px <= px + 10'd1;
                    if (done) begin guardado <= digito; st <= S_MSG; msg_i <= 3'd0; end
                end
                S_ESPERA: if (done) begin guardado <= digito; st <= S_MSG; msg_i <= 3'd0; end
                S_MSG: if (tx_listo && !tx_env) begin
                    tx_dato <= linea[msg_i]; tx_env <= 1'b1;
                    if (msg_i == 3'd6) begin
                        if (guardado == etiqueta) aciertos <= aciertos + 4'd1;
                        else hubo_error <= 1'b1;
                        st <= S_FIN;
                    end else msg_i <= msg_i + 3'd1;
                end
                S_FIN: begin
                    if (sel == N_DIG-1) st <= S_TOT;
                    else begin sel <= sel + 4'd1; px <= 10'd0; pasada <= 2'd0; st <= S_CLR; end
                end
                S_TOT: st <= S_TOT;      // terminado: los LEDs cuentan la historia
                default: st <= S_INIT;   // sin default se infieren latches (la leccion de la quark)
            endcase
        end
    end

    // LEDs: verde = termino la ronda · rojo = hubo al menos un error · azul = latido
    //   El latido se RESETEA a proposito: sin eso arranca en X y el LED rojo queda indefinido
    //   en simulacion. En FPGA el bitstream lo inicializa y no se nota, pero es justo el tipo
    //   de descuido que en silicio se vuelve un bug (la leccion de los `initial` heredados).
    reg [23:0] latido;
    always @(posedge clk) latido <= reset ? 24'd0 : latido + 24'd1;
    assign led_g = (st == S_TOT);
    assign led_r = hubo_error & latido[22];
    assign led_b = latido[23];
endmodule
`default_nettype wire
