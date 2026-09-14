// fpga_mnist_soc_canny.v — EL SoC COMPLETO CON CANNY: RISC-V + Canny 1-salto + clasificador.
//   Igual que fpga_mnist_soc.v pero con el front-end Canny y el FIRMWARE CORREGIDO.
//
//   El firmware original escribe 0x5A00 -> thr_hi=90, thr_lo=0. Para el Sobel da igual (solo
//   usa thr_hi); para el Canny es fatal: con thr_lo=0 todo pixel es borde debil y la histeresis
//   promueve casi todos. Medido sobre las 10 000: 89.93 % contra 92.46 %.
//   Aca el CPU escribe 0x5A20 -> thr_hi=90, thr_lo=32, y los pesos estan entrenados CON esos
//   mismos umbrales. Firmware y modelo alineados.
//   Es la demo de la Parte 184 -diez digitos de MNIST embebidos, resultado por UART- pero con el
//   FemtoRV32 adentro: el umbral del filtro ya NO esta cableado, lo escribe el CPU por el
//   periferico 0x0045, igual que en el SoC de la tesis.
//
//   Es la UNICA combinacion con CPU que entra en la iCE40UP5K. Medido:
//       ROM + clasificador            2 879 LC   54 %
//       ROM + clasificador + CPU      5 107 LC   96 %   <- este
//       camara + clasificador + CPU   6 656 LC  126 %   NO ENTRA
//   Se puede tener camara, o se puede tener CPU. No los dos.
//
//   RELOJ A LA MITAD. Con el CPU adentro el camino critico alarga y nextpnr cierra en 8.89 MHz,
//   no en los 12 del oscilador. Esta demo NO necesita velocidad -no hay camara esperando ni
//   video en tiempo real: procesa diez digitos guardados y los manda por serie-, asi que se
//   corre a 6 MHz y el timing cierra con holgura. El UART se ajusta en consecuencia:
//       DIVISOR = 6e6 / 115200 = 52   (en vez de 104 a 12 MHz)
//   Bajar el reloj es la respuesta correcta cuando la tarea no es de tiempo real. Lo que NO se
//   puede es grabar un bitstream que no cierra y confiar en lo que conteste.
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
module top #(
    // ciclos de pausa entre rondas. 12e6 a 12 MHz = 1 segundo, comodo para leer en el terminal.
    // En simulacion se baja para poder ver la repeticion sin simular segundos enteros.
    parameter [23:0] PAUSA = 24'd12_000_000
) (
    input  wire clk_i,
    output wire uart_tx_pin,
    output wire led_g, led_r, led_b
);

    // ---- reloj a la mitad: 12 MHz -> 6 MHz ----
    reg clk_div = 1'b0;
    always @(posedge clk_i) clk_div <= ~clk_div;
    wire clk = clk_div;
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
    // el umbral lo pone el CPU, no el RTL
    wire [7:0] thr_cpu; wire cpu_wrote;
    // UMBRALES = 0x5A20: thr_hi=90, thr_lo=32 (la constante del Canny, §16)
    wire [7:0] thr_lo_cpu;
    soc_ctrl #(.UMBRALES(16'h5A20)) SOC (
        .clk(clk), .resetn(~reset),
        .thr_o(thr_cpu), .thr_lo_o(thr_lo_cpu), .cpu_wrote(cpu_wrote));

    mnist_top_canny_fw #(.H(28),.W(28),.CW(9)) CLF (
        .clk(clk), .reset(reset), .clr(clr),
        .in_valid(feed), .in_pix(pix), .thr_hi(thr_cpu), .thr_lo(thr_lo_cpu),
        .done(done), .digito(digito));

    // ---------------- UART ----------------
    reg  [7:0] tx_dato; reg tx_env;
    wire       tx_listo;
    uart_tx #(.DIVISOR(52)) U (
        .clk(clk), .reset(reset), .dato(tx_dato), .enviar(tx_env),
        .tx(uart_tx_pin), .listo(tx_listo));

    // ---------------- maquina principal ----------------
    localparam S_INIT=0, S_CLR=1, S_FEED=2, S_ESPERA=3, S_MSG=4, S_FIN=5, S_TOT=6;
    reg [2:0] st;
    reg [2:0] msg_i;                     // caracter dentro de la linea
    reg [3:0] guardado;                  // el digito predicho, congelado
    reg [23:0] pausa;          // declarada ANTES de usarse (la leccion de la Parte 179)
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
            aciertos <= 4'd0; hubo_error <= 1'b0; guardado <= 4'd0; pausa <= 24'd0;
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
                S_TOT: begin
                    // REPITE la ronda para siempre, con una pausa de ~1 s. Sin esto el demo
                    // corre UNA sola vez al encender: los diez digitos se clasifican en ~2 ms y
                    // el UART termina antes de que uno alcance a abrir el terminal. Es un
                    // problema de USABILIDAD, no de diseno, y cuesta un contador.
                    if (pausa == PAUSA) begin
                        pausa <= 24'd0; sel <= 4'd0; px <= 10'd0; pasada <= 2'd0;
                        aciertos <= 4'd0; hubo_error <= 1'b0; st <= S_CLR;
                    end else pausa <= pausa + 24'd1;
                end
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
    // LEDs: que cuenten lo que ESTE diseno tiene de nuevo, el CPU.
    //   verde  = el FemtoRV32 ya arranco y escribio el umbral en el periferico 0x0045.
    //            Se enciende ~11 ciclos despues del reset y queda fijo: es el RISC-V vivo.
    //   azul   = latido, para ver que el diseno corre.
    //   rojo   = hubo algun error en la ronda (el 2 y el 3, que ya sabemos).
    assign led_g = cpu_wrote;
    assign led_b = latido[23];
    assign led_r = hubo_error & latido[22];
endmodule
`default_nettype wire
