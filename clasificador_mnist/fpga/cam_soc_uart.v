// cam_soc_uart.v — CAMARA + CPU + CLASIFICADOR, y el digito sale por el puerto serie.
//   Sin TFT: la cadena con FemtoRV32 adentro NO entra en la iCE40UP5K si ademas hay display
//   (medido: ~6 855 LC de 5 280). Sacando el TFT entra, y el resultado se lee por serie igual
//   que en la demo ROM de la Parte 184 -que es la que se pudo fotografiar-.
//
//   Es el instrumento del experimento de la §6 del cuaderno 2: alli se midio EN SIMULACION que
//   el Canny 1-salto le gana al Sobel por +17 pp con iluminacion despareja y le PIERDE por 16 pp
//   con ruido de sensor. Para comprobarlo con la camara de verdad hacen falta imagenes de verdad:
//   este diseno captura la misma ventana de 28x28 que consume el clasificador y la manda en
//   hexadecimal, para analizarla en Python con los dos front-ends sobre LOS MISMOS pixeles.
//
//   Por que volcar y no clasificar en la placa: porque asi se comparan los dos filtros sobre
//   exactamente la misma captura. Clasificando a bordo habria que grabar dos bitstreams y las
//   escenas no serian identicas -cambia la luz, cambia la mano-. Es la misma razon por la que el
//   `cam_uart_bits` saco la interpretacion visual del medio en la depuracion de la camara.
//
//   FORMATO de salida, una captura por vez:
//       IMG
//       3a 3b 40 ... (28 bytes en hexadecimal)      <- 28 lineas
//       ...
//       END
//   A 115200 baudios son ~2.4 kB por captura: unas 5 por segundo. La camara sigue corriendo;
//   simplemente se ignoran los cuadros que llegan mientras se esta volcando.
//
//   Reusa la puesta en marcha SCCB de `cam_fase.v` VERBATIM -incluida la fase del byte YUV, que
//   costo cuatro dias de biseccion (el OV7670 emite UYVY: la luma es el SEGUNDO byte)-.
`default_nettype none
module top #(
    // BAUDIOS: el CDC del USB de la iCESugar NO sostiene 115200 con 2.4 kB seguidos. En rafagas
    // cortas (la demo ROM) anda; con un volcado largo se desincroniza y despues de ~1.5 kB solo
    // llegan 0x00 y bytes altos. A 38400 el caudal baja a 4.8 kB/s y aguanta.
    //   DIVISOR = f_clk / baudios = 12e6 / 38400 = 312
    // ENGANCHE=0 desactiva el enganche de cuadro. Existe para poder correr la
    // CONTRAPRUEBA: si el banco no muestra diferencia entre 0 y 1, el banco no esta
    // midiendo lo que dice medir.
    parameter integer ENGANCHE = 1,
    parameter integer DIV = 312,
    // Pausa entre capturas, para que el CDC drene. 12e6 = 1 segundo.
    parameter [23:0] PAUSA = 24'd6_000_000,
    // CAM_W/CAM_H se exponen para poder SIMULAR con un cuadro chico: un cuadro real de
    // 640x480 son 614 400 ciclos de pclk y el banco tardaria minutos por captura.
    parameter integer CAM_W = 640,
    parameter integer CAM_H = 480,
    parameter integer WIN = 448,        // ventana cuadrada centrada, multiplo de 28
    parameter integer INVERTIR = 1      // MNIST es trazo claro sobre fondo oscuro; la tinta al reves
) (
    input  wire       clk,
    output wire       cam_xclk,
    output wire       cam_scl,
    inout  wire       cam_sda,
    input  wire       cam_pclk,
    input  wire       cam_href,
    input  wire [7:0] cam_d,
    output wire       uart_tx_pin,
    output wire       led_r,
    output wire       led_g,
    output wire       led_b
);
    assign cam_xclk = clk;
    // ==================== SCCB config (dominio clk) ====================
    reg sda_oe = 1'b0;
    assign cam_sda = sda_oe ? 1'b0 : 1'bz;
    reg scl = 1'b1;
    assign cam_scl = scl;

    reg [5:0] tdiv = 6'd0;
    wire tick = (tdiv == 6'd29);
    always @(posedge clk) tdiv <= tick ? 6'd0 : tdiv + 1'b1;

    reg [15:0] rom;
    reg [4:0]  idx = 5'd0;
    always @(*) case (idx)
        5'd0:  rom = 16'h12_00;
        5'd1:  rom = 16'h13_E7;
        5'd2:  rom = 16'h09_18;
        default: rom = 16'hFF_FF;
    endcase
    wire       tbl_end  = (rom == 16'hFF_FF);
    wire [7:0] reg_addr = rom[15:8];
    wire [7:0] reg_val  = rom[7:0];

    localparam C_START=3'd0, C_WR=3'd1, C_STOP=3'd2, C_DLY=3'd3, C_NEXT=3'd4;
    reg [2:0] cpc = 3'd0;
    reg [1:0] cph = 2'd0;
    reg [3:0] cbi = 4'd0;
    reg [15:0] cdly = 16'd0;
    reg        cfg_done = 1'b0;

    reg [2:0] coptype;
    always @(*) case (cpc)
        3'd0: coptype=C_START; 3'd1: coptype=C_WR; 3'd2: coptype=C_WR;
        3'd3: coptype=C_WR;    3'd4: coptype=C_STOP; 3'd5: coptype=C_DLY;
        default: coptype=C_NEXT;
    endcase
    reg [7:0] cwbyte;
    always @(*) case (cpc)
        3'd1: cwbyte=8'h42; 3'd2: cwbyte=reg_addr; 3'd3: cwbyte=reg_val;
        default: cwbyte=8'h00;
    endcase

    reg [19:0] cboot = 20'd0;
    wire cboot_ok = &cboot;
    always @(posedge clk) if (!cboot_ok) cboot <= cboot + 1'b1;

    always @(posedge clk) if (tick && cboot_ok && !cfg_done) begin
        case (coptype)
        C_START: begin
            if (tbl_end) cfg_done <= 1'b1;
            else begin
                case (cph)
                    2'd0: begin sda_oe<=1'b0; scl<=1'b1; end
                    2'd1: begin sda_oe<=1'b1; scl<=1'b1; end
                    2'd2: scl<=1'b0;
                    2'd3: cpc<=cpc+1'b1;
                endcase
                cph <= cph + 1'b1;
            end
        end
        C_WR: begin
            case (cph)
                2'd0: begin scl<=1'b0; if (cbi<4'd8) sda_oe<=~cwbyte[3'd7-cbi[2:0]]; else sda_oe<=1'b0; end
                2'd1: scl<=1'b1; 2'd2: scl<=1'b1;
                2'd3: begin scl<=1'b0; if (cbi==4'd8) begin cbi<=4'd0; cpc<=cpc+1'b1; end else cbi<=cbi+1'b1; end
            endcase
            cph <= cph + 1'b1;
        end
        C_STOP: begin
            case (cph)
                2'd0: begin scl<=1'b0; sda_oe<=1'b1; end
                2'd1: begin scl<=1'b1; sda_oe<=1'b1; end
                2'd2: begin scl<=1'b1; sda_oe<=1'b0; end
                2'd3: begin cpc<=cpc+1'b1; cdly<=16'd999; end
            endcase
            cph <= cph + 1'b1;
        end
        C_DLY: if (cdly==16'd0) cpc<=cpc+1'b1; else cdly<=cdly-1'b1;
        default: begin idx<=idx+1'b1; cpc<=3'd0; end
        endcase
    end
    // Reset de encendido del dominio pclk. cam_win28 tampoco inicializa sus registros
    // (cx, cy, acc[]...), asi que con .reset(1'b0) arrancan en 'x' y no emite nunca.
    // Mismo bug #9, segundo modulo: no alcanza con arreglarlo una vez.
    reg [7:0] por_p = 8'd0;
    wire      rst_p = (por_p != 8'hff);
    always @(posedge cam_pclk) if (por_p != 8'hff) por_p <= por_p + 1'b1;

    // ============ captura de luma (dominio pclk) ============
    // La fase es la de cam_fase.v: la luma es el SEGUNDO byte del par (UYVY).
    reg       parity = 1'b0;
    reg [7:0] curY   = 8'd0;
    always @(posedge cam_pclk) begin
        if (~cam_href) parity <= 1'b0;
        else begin
            if (parity == 1'b1) curY <= cam_d;
            parity <= ~parity;
        end
    end
    // curY vale durante el ciclo de parity==0, que es cuando se entrega
    wire pix_valid = cam_href & (parity == 1'b0);

    // ============ enganche de cuadro SIN VSYNC ============
    //   El OV7670 clon no entrega VSYNC usable, pero el hueco entre CUADROS es mucho mas largo
    //   que el hueco entre LINEAS: ~144 pclk contra >= 14 000. Contando cuanto tiempo `href`
    //   queda en bajo, el comienzo de cuadro se detecta solo, sin calibrar nada.
    localparam integer UMBRAL_V = 2000;        // 7x mas chico que el hueco vertical real
    reg [15:0] sin_href = 16'd0;
    reg        sync     = 1'b0;
    always @(posedge cam_pclk) begin
        sync <= 1'b0;
        if (cam_href) sin_href <= 16'd0;
        else if (sin_href != 16'hffff) begin
            sin_href <= sin_href + 1'b1;
            if (sin_href == UMBRAL_V-1) sync <= 1'b1;   // UN pulso por cuadro
        end
    end

    // ============ ventana de 28x28, el MISMO modulo que usa el clasificador ============
    wire       w_val, w_fin;
    wire [7:0] w_pix;
    cam_win28 #(.CAM_W(CAM_W), .CAM_H(CAM_H), .WIN(WIN)) WIN28 (
        .pclk(cam_pclk), .reset(rst_p), .href(cam_href), .sync(sync),
        .pix_y(curY), .pix_valid(pix_valid), .invertir(INVERTIR[0]),
        .out_valid(w_val), .out_pix(w_pix), .frame_fin(w_fin));


    // ============ clasificador con el umbral que pone el CPU ============
    wire        clf_done, clf_val;
    wire [3:0]  clf_dig;
    wire [7:0]  thr_cpu;
    wire        cpu_wrote;
    reg         clf_clr = 1'b0;
    always @(posedge cam_pclk) clf_clr <= clf_done;
    soc_mnist_top #(.H(28),.W(28),.CW(9),.FUENTE_THR(0)) CLF (
        .clk(cam_pclk), .reset(rst_p), .clr(clf_clr),
        .in_valid(w_val), .in_pix(w_pix),
        .done(clf_done), .digito(clf_dig), .valido(clf_val),
        .thr_usado(thr_cpu), .cpu_escribio(cpu_wrote));

    // cruce al dominio clk (casi-estatico: 2 FF alcanzan)
    reg [3:0] dig_s1=0, dig_s2=0; reg val_s1=0, val_s2=0, don_s1=0, don_s2=0;
    always @(posedge clk) begin
        dig_s1<=clf_dig; dig_s2<=dig_s1; val_s1<=clf_val; val_s2<=val_s1;
        don_s1<=clf_done; don_s2<=don_s1;
    end

    // ============ UART: manda "d\n" o "-\n" cada vez que el clasificador termina ============
    reg [7:0] por = 8'd0;
    wire      rst = (por != 8'hff);
    always @(posedge clk) if (por != 8'hff) por <= por + 1'b1;

    reg  [7:0] u_dato = 8'd0;
    reg        u_env  = 1'b0;
    wire       u_listo;
    uart_tx #(.DIVISOR(104)) TX (.clk(clk), .reset(rst), .dato(u_dato),
                                 .enviar(u_env), .tx(uart_tx_pin), .listo(u_listo));
    reg don_d = 1'b0;
    reg [1:0] est = 2'd0;
    always @(posedge clk) begin
        u_env <= 1'b0;
        don_d <= don_s2;
        case (est)
        2'd0: if (don_s2 & ~don_d) est <= 2'd1;                    // flanco: hay resultado
        2'd1: if (u_listo && !u_env) begin
                  u_dato <= val_s2 ? (8'd48 + dig_s2) : 8'h2d;     // '0'..'9' o '-'
                  u_env <= 1'b1; est <= 2'd2;
              end
        2'd2: if (u_listo && !u_env) begin u_dato <= 8'h0a; u_env <= 1'b1; est <= 2'd0; end
        endcase
    end

    assign led_r = 1'b1;
    assign led_g = ~cpu_wrote;          // verde cuando el CPU ya fijo el umbral
    assign led_b = ~clf_val;            // azul cuando reconocio algo
endmodule
`default_nettype wire
