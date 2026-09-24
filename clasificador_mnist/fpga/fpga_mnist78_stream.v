// fpga_mnist78_stream.v — la cadena del 97,22 % en la iCE40UP5K, alimentada POR EL PUERTO SERIE.
//
//   El ensayo A metia diez digitos en una ROM del bitstream: diez es todo lo que cabe. Aqui la
//   placa no guarda ninguna imagen; el Mac le manda las 10 000 del test por el UART del iCELink
//   (el mismo cable USB) y la placa contesta UN byte por imagen. Asi la comparacion con el
//   golden deja de ser 10 de 10 y pasa a ser 10 000 de 10 000, en silicio.
//
//   Protocolo (lo implementa placa78.py):
//     Mac -> placa : los 784 pixeles de cada imagen, fila por fila, un byte cada uno, SIN
//                    separadores, imagenes encadenadas. Al final de cada lote, 8 bytes de cola
//                    para que el cauce desague la ultima (lo mismo que hace tb_top78.v).
//     placa -> Mac : por cada imagen, 0x40 | valido<<4 | digito
//                    -> '@'..'I' = digito 0..9 con NADA, 'P'..'Y' = digito 0..9 hablando.
//                    Imprimible a proposito: se puede leer con `cat` sin herramientas.
//                  + '!' tras la pausa de un lote al que le falto o sobro un byte.
//
//   El realineo: si se pierde un byte, TODAS las imagenes siguientes quedan corridas y el
//   resultado seria basura silenciosa. Por eso, si pasan IDLE ciclos sin recibir nada, la
//   cadena se resetea y el raster vuelve a (0,0). El Mac hace una pausa entre lotes, y un
//   byte perdido cuesta a lo sumo un lote, no el resto de la corrida.
//
//   Pines (iCESugar v1.5, sg48): clk 35 · uart_tx 6 (PROBADO) · uart_rx 4 (el de la hoja de
//   datos de la placa, NUNCA probado en esta tesis) · leds 39/40/41.
`default_nettype none
module top #(
    parameter integer DIVISOR = 104,          // 12 MHz / 115200
    parameter [23:0]  IDLE    = 24'd600_000   // 50 ms sin bytes -> realinear
) (
    input  wire clk,
    input  wire uart_rx_pin,
    output wire uart_tx_pin,
    output wire led_r, led_g, led_b
);
    // ---------------- reset de encendido ----------------
    reg       reset = 1'b1;
    reg [7:0] rst_cnt = 8'd0;
    always @(posedge clk) begin
        if (rst_cnt != 8'hFF) begin rst_cnt <= rst_cnt + 8'd1; reset <= 1'b1; end
        else reset <= 1'b0;
    end

    // ---------------- UART ----------------
    wire [7:0] rx_dato; wire rx_valido;
    uart_rx #(.DIVISOR(DIVISOR)) RX (
        .clk(clk), .reset(reset), .rx(uart_rx_pin), .dato(rx_dato), .valido(rx_valido));

    reg  [7:0] tx_dato; reg tx_env;
    wire       tx_listo;
    uart_tx #(.DIVISOR(DIVISOR)) TX (
        .clk(clk), .reset(reset), .dato(tx_dato), .enviar(tx_env),
        .tx(uart_tx_pin), .listo(tx_listo));

    // ---------------- realineo por silencio ----------------
    reg [23:0] quieto;
    reg [2:0]  rst_cad_n;                     // pulso de reset de la cadena, 4 ciclos
    reg        perdido;                       // un realineo encontro un lote roto
    reg        avisa_roto;                    // pulso: mandar '!' al Mac
    reg [9:0]  resto;                         // bytes recibidos modulo 784
    always @(posedge clk) begin
        if (reset) begin
            quieto <= 24'd0; rst_cad_n <= 3'd0; perdido <= 1'b0; resto <= 10'd0; avisa_roto <= 1'b0;
        end else begin
            avisa_roto <= 1'b0;
            if (rst_cad_n != 3'd0) rst_cad_n <= rst_cad_n - 3'd1;
            if (rx_valido) begin
                quieto <= 24'd0;
                resto  <= (resto == 10'd783) ? 10'd0 : resto + 10'd1;
            end else if (quieto != IDLE) begin
                quieto <= quieto + 24'd1;
                if (quieto == IDLE - 24'd1) begin
                    rst_cad_n <= 3'd4; resto <= 10'd0;
                    // un lote sano termina con resto 8 (la cola) o 0 (sin cola). Cualquier otro
                    // numero es un byte perdido o de mas: ese lote ya no vale y el LED lo dice.
                    if (resto != 10'd0 && resto != 10'd8) begin perdido <= 1'b1; avisa_roto <= 1'b1; end
                end
            end
        end
    end
    wire reset_cad = reset | (rst_cad_n != 3'd0);

    // ---------------- la cadena verificada, sin tocar ----------------
    wire       done, valido;
    wire [3:0] digito;
    mnist_top78 CAD (
        .clk(clk), .reset(reset_cad),
        .in_valid(rx_valido & ~reset_cad), .in_pix(rx_dato),
        .thr_hi(8'd90), .thr_lo(8'd32),
        .done(done), .digito(digito), .valido(valido));

    // ---------------- respuesta: un byte por imagen ----------------
    //   `done` llega como mucho una vez cada 784 bytes recibidos (~68 ms) y el byte de vuelta
    //   tarda 0,09 ms en salir, asi que el transmisor siempre esta libre. Aun asi se guarda en
    //   un registro de espera: si algun dia no lo estuviera, se nota en la cuenta, no se pierde.
    reg       pend;
    reg [7:0] resp;
    reg       parpadeo;
    always @(posedge clk) begin
        if (reset) begin pend <= 1'b0; tx_env <= 1'b0; resp <= 8'd0; parpadeo <= 1'b0; end
        else begin
            tx_env <= 1'b0;
            if (done) begin resp <= {3'b010, valido, digito}; pend <= 1'b1; end
            // '!' = el lote que acaba de terminar perdio (o gano) un byte: el Mac lo repite.
            // Llega ~50 ms despues del ultimo veredicto, asi que nunca pisa uno pendiente.
            else if (avisa_roto) begin resp <= 8'h21; pend <= 1'b1; end
            else if (pend && tx_listo && !tx_env) begin
                tx_dato <= resp; tx_env <= 1'b1; pend <= 1'b0; parpadeo <= ~parpadeo;
            end
        end
    end

    // LEDs: verde cambia con cada veredicto · rojo = se perdio (o sobro) un byte · azul = latido
    //   (led_r 39 / led_g 40: el orden PROBADO en la Parte 179, el de cam_uart_win.pcf)
    reg [23:0] latido;
    always @(posedge clk) latido <= reset ? 24'd0 : latido + 24'd1;
    assign led_g = parpadeo;
    assign led_r = perdido & latido[21];
    assign led_b = latido[23];
endmodule
`default_nettype wire
