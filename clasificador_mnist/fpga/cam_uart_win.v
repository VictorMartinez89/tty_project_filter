// cam_uart_win.v — LA PLACA VUELCA LA VENTANA DE 28x28 POR EL PUERTO SERIE.
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

    // ============ ventana de 28x28, el MISMO modulo que usa el clasificador ============
    wire       w_val, w_fin;
    wire [7:0] w_pix;
    cam_win28 #(.CAM_W(CAM_W), .CAM_H(CAM_H), .WIN(WIN)) WIN28 (
        .pclk(cam_pclk), .reset(rst_p), .href(cam_href),
        .pix_y(curY), .pix_valid(pix_valid), .invertir(INVERTIR[0]),
        .out_valid(w_val), .out_pix(w_pix), .frame_fin(w_fin));

    // ============ buffer de un cuadro + handshake entre dominios ============
    // Se captura UN cuadro, se congela, se vuelca, y recien ahi se habilita el siguiente.
    // Mientras se vuelca no se escribe el buffer: sin escritura concurrente no hay carrera,
    // que es la unica forma barata de cruzar dominios de reloj sin FIFO.
    reg        ack_c = 1'b0;    // declarado ANTES de usarse (el bug #8 de la Parte 186,
                                // que ya aparecio tres veces en este proyecto)
    reg [7:0]  imgbuf [0:783];
    reg [9:0]  wcnt  = 10'd0;
    reg        lleno_p = 1'b0;              // dominio pclk: hay un cuadro listo
    reg        ack_s1 = 1'b0, ack_s2 = 1'b0;   // ack del dominio clk, sincronizado a pclk
    always @(posedge cam_pclk) begin
        ack_s1 <= ack_c; ack_s2 <= ack_s1;
        if (ack_s2) begin lleno_p <= 1'b0; wcnt <= 10'd0; end
        else if (!lleno_p) begin
            if (w_val && wcnt < 10'd784) begin
                imgbuf[wcnt] <= w_pix; wcnt <= wcnt + 1'b1;
            end
            if (w_fin && wcnt >= 10'd784) lleno_p <= 1'b1;
        end
    end

    reg lleno_s1 = 1'b0, lleno_s2 = 1'b0;      // a dominio clk
    always @(posedge clk) begin lleno_s1 <= lleno_p; lleno_s2 <= lleno_s1; end

    // ============ volcado por UART (dominio clk) ============
    // Reset de encendido. En la FPGA el bitstream inicializa los flops y esto sobraria, pero en
    // SIMULACION (y en un ASIC) los registros de uart_tx arrancan en 'x': `listo` vale x, la
    // condicion nunca se cumple y no se transmite NADA. Es el bug #9 de la Parte 186, y vuelve
    // a aparecer cada vez que se instancia uart_tx con .reset(1'b0).
    reg [7:0] por = 8'd0;
    wire      rst = (por != 8'hff);
    always @(posedge clk) if (por != 8'hff) por <= por + 1'b1;

    reg  [7:0] u_dato = 8'd0;
    reg        u_env  = 1'b0;
    wire       u_listo;
    uart_tx #(.DIVISOR(104)) TX (.clk(clk), .reset(rst), .dato(u_dato),
                                 .enviar(u_env), .tx(uart_tx_pin), .listo(u_listo));


    localparam D_ESPERA=3'd0, D_CAB=3'd1, D_HI=3'd2, D_LO=3'd3, D_SEP=3'd4,
               D_FIN=3'd5, D_ACK=3'd6;
    reg [2:0]  st  = D_ESPERA;
    reg [9:0]  rd  = 10'd0;
    reg [4:0]  col = 5'd0;   // columna 0..27. NO se puede usar rd[4:0]: eso es modulo 32,
                             // y sacaba la primera linea de 28 y las demas de 32.
    reg [2:0]  ci  = 3'd0;                      // indice dentro de "IMG\n" / "END\n"
    // Lectura REGISTRADA, incondicional y con UNA sola direccion. Antes el buffer se leia
    // dentro del case con enables (`imgbuf[rd+1]` bajo `if (u_listo && !u_env)`) y yosys NO
    // infirio BRAM: puso los 784 bytes en flip-flops -6 403 SB_DFFE- y el diseno pedia el
    // 278 % de la iCE40. Un buffer que no entra en BRAM no entra en el chip.
    reg [9:0]  raddr = 10'd0;
    reg [7:0]  rdata = 8'd0;
    always @(posedge clk) rdata <= imgbuf[raddr];
    // Los dos nibbles de `byt` en ASCII, como expresion en vez de funcion (misma razon que
    // los rotulos: yosys avisaba sobre los argumentos de la funcion).
    wire [3:0] nib_hi = rdata[7:4], nib_lo = rdata[3:0];
    wire [7:0] hex_hi = (nib_hi < 4'd10) ? (8'd48 + nib_hi) : (8'd87 + nib_hi);
    wire [7:0] hex_lo = (nib_lo < 4'd10) ? (8'd48 + nib_lo) : (8'd87 + nib_lo);

    // Los rotulos como constante y seleccion de byte, en vez de una funcion: yosys avisaba
    // "wire ... is used but has no driver" sobre los argumentos de la funcion. La simulacion
    // daba bien igual, pero un aviso de sintesis sobre algo que simula bien es exactamente el
    // caso en que el silicio puede no coincidir con el banco. Explicito es mas barato que listo.
    localparam [31:0] ROT_IMG = 32'h494d470a;   // "IMG\n"
    localparam [31:0] ROT_END = 32'h454e440a;   // "END\n"

    always @(posedge clk) begin
        u_env <= 1'b0;
        ack_c <= 1'b0;
        case (st)
        D_ESPERA: if (lleno_s2) begin st <= D_CAB; ci <= 3'd0; rd <= 10'd0; col <= 5'd0; raddr <= 10'd0; end
        D_CAB: if (u_listo && !u_env) begin
                   u_dato <= ROT_IMG[{~ci[1:0], 3'd0} +: 8]; u_env <= 1'b1;
                   if (ci == 3'd3) st <= D_HI;
                   else ci <= ci + 1'b1;
               end
        D_HI:  if (u_listo && !u_env) begin u_dato <= hex_hi; u_env <= 1'b1; st <= D_LO; end
        D_LO:  if (u_listo && !u_env) begin u_dato <= hex_lo; u_env <= 1'b1; st <= D_SEP; end
        D_SEP: if (u_listo && !u_env) begin
                   // salto de linea cada 28 bytes; espacio en el resto
                   u_dato <= (col == 5'd27) ? 8'h0a : 8'h20;
                   u_env  <= 1'b1;
                   if (rd == 10'd783) begin st <= D_FIN; ci <= 3'd0; end
                   else begin
                       col   <= (col == 5'd27) ? 5'd0 : col + 5'd1;
                       rd    <= rd + 1'b1;
                       raddr <= rd + 10'd1;     // el dato llega al ciclo siguiente; sobra tiempo
                       st    <= D_HI;
                   end
               end
        D_FIN: if (u_listo && !u_env) begin
                   u_dato <= ROT_END[{~ci[1:0], 3'd0} +: 8]; u_env <= 1'b1;
                   if (ci == 3'd3) st <= D_ACK; else ci <= ci + 1'b1;
               end
        D_ACK: begin ack_c <= 1'b1; if (!lleno_s2) st <= D_ESPERA; end
        default: st <= D_ESPERA;
        endcase
    end

    // verde = esperando cuadro · azul = volcando.  (LED de anodo comun: 0 enciende)
    assign led_r = 1'b1;
    assign led_g = ~(st == D_ESPERA);
    assign led_b = ~(st != D_ESPERA);
endmodule
`default_nettype wire
