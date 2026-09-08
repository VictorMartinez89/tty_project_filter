// cam_uart_pix.v — LA PLACA IMPRIME PIXELES VECINOS. La prueba de si el muestreo esta bien.
//
//   En una IMAGEN REAL los pixeles vecinos se parecen: el brillo cambia de a poco, salvo en los
//   bordes. Si el instante de muestreo respecto de PCLK es incorrecto, cada byte capturado es
//   basura independiente del anterior y los vecinos saltan al azar.
//
//   Ocho numeros alcanzan para distinguirlo, y no hay que interpretar ninguna foto:
//
//       PIX 3A 3B 3D 3C 40 42 41 44   <- suave: los vecinos se parecen -> ES UNA IMAGEN
//       PIX 07 C3 51 9E 22 FA 68 11   <- saltos: no hay correlacion    -> ES BASURA
//
//   Se imprimen los 8 primeros bytes de LUMA de una linea del medio del cuadro, una vez por
//   cuadro. Junto con AND/OR, que ya dijeron que el bus esta sano.
// cam_uart_bits.v — EL DIAGNOSTICO DEFINITIVO: la placa DICE los numeros, no hay que mirarlos.
//
//   Mirar franjas en una foto llego a su limite: el angulo del celular cambia entre tomas y
//   corre todas las referencias. Este diseno saca la interpretacion visual del medio.
//
//   Sobre cada cuadro de la camara acumula dos cosas y las manda por el puerto serie:
//
//       AND de todos los bytes de cam_d  -> los bits que valen 1 en TODOS los pixeles.
//                                           Un bit ahi es un PEGADO EN 1. Si no hay ninguno,
//                                           AND=00.
//       OR  de todos los bytes de cam_d  -> los bits que valen 1 en ALGUN pixel.
//                                           Un bit que falta ahi es un PEGADO EN 0.
//
//   Sale una linea por cuadro, por ejemplo:   AND=80 OR=FF
//   que se lee directo: "el bit 7 esta pegado en 1, los demas se mueven".
//
//   Terminal serie a 115200 8N1. El TFT sigue funcionando igual, por si sirve de referencia.
// cam_display.v — CAMARA -> frame buffer -> PANTALLA. Sincronismo de cuadro por
// CONTEO DE FILAS (480 filas activas = 1 cuadro), determinístico (sin VSYNC ni
// umbrales de blanking). Llena el buffer completo -> imagen a pantalla llena.
//   VERDE = camara configurada, AZUL = heartbeat.
// Pines: clk=35, cam_xclk=2, cam_scl=26, cam_sda=27, cam_pclk=28, cam_href=32,
//        cam_d[0..7]=48,46,44,43,38,34,31,42,
//        tft_sck=37, tft_mosi=36, tft_cs=25, tft_dc=23, leds=39/40/41

module top (
    output wire       uart_tx_pin,
    input  wire       clk,
    output wire       cam_xclk,
    output wire       cam_scl,
    inout  wire       cam_sda,
    input  wire       cam_pclk,
    input  wire       cam_href,
    input  wire [7:0] cam_d,
    output wire       tft_sck,
    output wire       tft_mosi,
    output wire       tft_cs,
    output wire       tft_dc,
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

    // ============ captura camara -> frame buffer (dominio pclk) ============
    // AUTO-SINCRONIZADO: el puntero envuelve en 4800 (=1 cuadro) y se alinea
    // solo. No usa VSYNC (el clon no lo entrega bien).
    reg href_d = 1'b0;
    reg        parity  = 1'b0;
    reg [7:0]  curY    = 8'd0;
    reg [3:0]  colkeep = 4'd0;
    reg [2:0]  rowkeep = 3'd0;
    reg [6:0]  fbx     = 7'd0;
    reg [12:0] waddr_wr= 13'd0;
    reg        we      = 1'b0;
    reg [12:0] wadr    = 13'd0;
    reg [7:0]  wdat    = 8'd0;

    always @(posedge cam_pclk) begin
        href_d <= cam_href;
        we     <= 1'b0;
        if (~cam_href) begin
            parity <= 1'b0; colkeep <= 4'd0; fbx <= 7'd0;
        end else begin
            if (parity == 1'b0) curY <= cam_d;
            else begin
                if (rowkeep==3'd0 && colkeep==4'd0 && fbx<7'd60) begin
                    we <= 1'b1; wadr <= waddr_wr; wdat <= curY;
                    waddr_wr <= (waddr_wr==13'd4799) ? 13'd0 : waddr_wr + 1'b1;
                    fbx <= fbx + 1'b1;
                end
                colkeep <= (colkeep==4'd9) ? 4'd0 : colkeep + 1'b1;
            end
            parity <= ~parity;
        end
        if (href_d & ~cam_href)
            rowkeep <= (rowkeep==3'd5) ? 3'd0 : rowkeep + 1'b1;
    end

    // ==================== frame buffer 60x80 (doble puerto) ====================
    reg [7:0] fb [0:4799];
    reg [7:0] fb_rd = 8'd0;
    always @(posedge cam_pclk) if (we) fb[wadr] <= wdat;

    // ==================== display ILI9341 (dominio clk) ====================
    reg        spi_start = 1'b0;
    reg  [7:0] spi_byte  = 8'd0;
    reg        spi_dcbit = 1'b1;
    reg        spi_done  = 1'b0;
    reg sck=1'b0, mosi=1'b0, cs=1'b1, dc=1'b1;
    assign tft_sck=sck; assign tft_mosi=mosi; assign tft_cs=cs; assign tft_dc=dc;

    localparam S_IDLE=2'd0, S_LO=2'd1, S_HI=2'd2, S_END=2'd3;
    reg [1:0] sst = S_IDLE;
    reg [2:0] sbit = 3'd0;
    reg [7:0] sbuf = 8'd0;
    always @(posedge clk) begin
        spi_done <= 1'b0;
        case (sst)
            S_IDLE: if (spi_start) begin cs<=1'b0; dc<=spi_dcbit; sbuf<=spi_byte; sbit<=3'd0; sck<=1'b0; sst<=S_LO; end
            S_LO:  begin sck<=1'b0; mosi<=sbuf[7]; sst<=S_HI; end
            S_HI:  begin sck<=1'b1; sbuf<={sbuf[6:0],1'b0}; if (sbit==3'd7) sst<=S_END; else begin sbit<=sbit+1'b1; sst<=S_LO; end end
            S_END: begin sck<=1'b0; spi_done<=1'b1; sst<=S_IDLE; end
        endcase
    end

    localparam T_CMD=2'd0, T_DAT=2'd1, T_DLY=2'd2, T_END=2'd3;
    localparam M_BOOT=2'd0, M_INIT=2'd1, M_FRAME=2'd2, M_FILL=2'd3;
    reg [1:0] mode = M_BOOT;
    reg [4:0] ip   = 5'd0;

    reg [1:0] rt; reg [7:0] rb;
    always @(*) begin
        rt=T_END; rb=8'h00;
        if (mode==M_INIT) case (ip)
            5'd0: begin rt=T_CMD; rb=8'h01; end
            5'd1: begin rt=T_DLY; rb=8'h00; end
            5'd2: begin rt=T_CMD; rb=8'h11; end
            5'd3: begin rt=T_DLY; rb=8'h00; end
            5'd4: begin rt=T_CMD; rb=8'h3A; end
            5'd5: begin rt=T_DAT; rb=8'h55; end
            5'd6: begin rt=T_CMD; rb=8'h36; end
            5'd7: begin rt=T_DAT; rb=8'h48; end
            5'd8: begin rt=T_CMD; rb=8'h29; end
            default: begin rt=T_END; rb=8'h00; end
        endcase
        else case (ip)
            5'd0:  begin rt=T_CMD; rb=8'h2A; end
            5'd1:  begin rt=T_DAT; rb=8'h00; end
            5'd2:  begin rt=T_DAT; rb=8'h00; end
            5'd3:  begin rt=T_DAT; rb=8'h00; end
            5'd4:  begin rt=T_DAT; rb=8'hEF; end
            5'd5:  begin rt=T_CMD; rb=8'h2B; end
            5'd6:  begin rt=T_DAT; rb=8'h00; end
            5'd7:  begin rt=T_DAT; rb=8'h00; end
            5'd8:  begin rt=T_DAT; rb=8'h01; end
            5'd9:  begin rt=T_DAT; rb=8'h3F; end
            5'd10: begin rt=T_CMD; rb=8'h2C; end
            default: begin rt=T_END; rb=8'h00; end
        endcase
    end

    // OFFSET de encuadre: ajustar de a ~600 para centrar la imagen partida.
    localparam [13:0] OFFSET = 14'd2400;

    reg [7:0] xcol = 8'd0;
    reg [8:0] ycol = 9'd0;
    wire [6:0] fx = xcol[7:2];
    wire [6:0] fy = ycol[8:2];
    wire [13:0] rsum  = fy*60 + fx + OFFSET;                 // desplaza la lectura
    wire [12:0] raddr = (rsum >= 14'd4800) ? (rsum - 14'd4800) : rsum[12:0];
    always @(posedge clk) fb_rd <= fb[raddr];
    wire [15:0] pcolor = {fb_rd[7:3], fb_rd[7:2], fb_rd[7:3]};

    reg [20:0] dcnt = 21'd0;
    reg [16:0] px   = 17'd0;
    reg        pxhi = 1'b0;
    reg        sending = 1'b0;

    always @(posedge clk) begin
        spi_start <= 1'b0;
        case (mode)
        M_BOOT: begin
            dcnt <= dcnt + 1'b1;
            if (dcnt == 21'd1_800_000) begin dcnt <= 21'd0; mode <= M_INIT; ip <= 5'd0; end
        end
        M_INIT: begin
            if (!sending) begin
                case (rt)
                    T_CMD,T_DAT: begin spi_byte<=rb; spi_dcbit<=(rt==T_DAT); spi_start<=1'b1; sending<=1'b1; end
                    T_DLY: if (dcnt==21'd1_800_000) begin dcnt<=21'd0; ip<=ip+1'b1; end else dcnt<=dcnt+1'b1;
                    default: begin mode<=M_FRAME; ip<=5'd0; end
                endcase
            end else if (spi_done) begin sending<=1'b0; ip<=ip+1'b1; end
        end
        M_FRAME: begin
            if (!sending) begin
                case (rt)
                    T_CMD,T_DAT: begin spi_byte<=rb; spi_dcbit<=(rt==T_DAT); spi_start<=1'b1; sending<=1'b1; end
                    default: begin mode<=M_FILL; px<=17'd0; pxhi<=1'b0; xcol<=8'd0; ycol<=9'd0; end
                endcase
            end else if (spi_done) begin sending<=1'b0; ip<=ip+1'b1; end
        end
        M_FILL: begin
            if (!sending) begin
                spi_byte  <= pxhi ? pcolor[7:0] : pcolor[15:8];
                spi_dcbit <= 1'b1; spi_start <= 1'b1; sending <= 1'b1;
            end else if (spi_done) begin
                sending <= 1'b0;
                if (pxhi) begin
                    pxhi <= 1'b0;
                    if (px == 17'd76799) begin px<=17'd0; mode<=M_FRAME; ip<=5'd0; end
                    else begin
                        px <= px + 1'b1;
                        if (xcol == 8'd239) begin xcol<=8'd0; ycol<=ycol+1'b1; end
                        else xcol <= xcol + 1'b1;
                    end
                end else pxhi <= 1'b1;
            end
        end
        endcase
    end

    reg [23:0] hb = 24'd0;
    always @(posedge clk) hb <= hb + 1'b1;
    SB_RGBA_DRV #(
        .CURRENT_MODE("0b1"),
        .RGB0_CURRENT("0b000001"), .RGB1_CURRENT("0b000001"), .RGB2_CURRENT("0b000001")
    ) rgba (
        .CURREN(1'b1), .RGBLEDEN(1'b1),
        .RGB0PWM(cfg_done), .RGB1PWM(1'b0), .RGB2PWM(hb[23]),
        .RGB0(led_r), .RGB1(led_g), .RGB2(led_b)
    );

    // ==================== DIAGNOSTICO POR UART ====================
    //   Acumula AND y OR de cam_d sobre el cuadro, y los reporta al terminar.
    reg [7:0] acc_and = 8'hFF, acc_or = 8'h00;      // neutros de cada operacion
    reg [7:0] rep_and = 8'h00, rep_or = 8'h00;
    reg       hay_reporte = 1'b0;
    reg [16:0] npix = 17'd0;

    always @(posedge cam_pclk) begin
        if (~cfg_done) begin
            acc_and <= 8'hFF; acc_or <= 8'h00; npix <= 17'd0; hay_reporte <= 1'b0;
        end else if (cam_href && parity == 1'b0) begin   // solo los bytes de LUMA
            acc_and <= acc_and & cam_d;
            acc_or  <= acc_or  | cam_d;
            if (npix == 17'd60000) begin                  // ~un cuadro
                rep_and <= acc_and & cam_d;
                rep_or  <= acc_or  | cam_d;
                hay_reporte <= 1'b1;
                acc_and <= 8'hFF; acc_or <= 8'h00; npix <= 17'd0;
            end else npix <= npix + 17'd1;
        end
        if (u_tomado) hay_reporte <= 1'b0;
    end

    // cruce al dominio clk (los reportes son casi-estaticos: 2 FF alcanzan)
    reg [7:0] a1, a2, o1, o2; reg h1, h2, h3;
    always @(posedge clk) begin
        a1<=rep_and; a2<=a1; o1<=rep_or; o2<=o1;
        h1<=hay_reporte; h2<=h1; h3<=h2;
    end
    wire nuevo = h2 & ~h3;
    reg u_tomado = 1'b0;
    always @(posedge clk) u_tomado <= nuevo;


    // ---- captura de 8 pixeles vecinos de una linea del medio ----
    reg [7:0] muestra [0:7];
    reg [2:0] mi_idx = 3'd0;
    reg [8:0] linea_n = 9'd0;
    reg       tomando = 1'b0;
    always @(posedge cam_pclk) begin
        if (href_d & ~cam_href) linea_n <= linea_n + 9'd1;      // fin de linea
        if (~cam_href) begin
            tomando <= (linea_n == 9'd240);                      // una linea del medio
            mi_idx  <= 3'd0;
        end else if (tomando && parity == 1'b0 && mi_idx != 3'd7) begin
            muestra[mi_idx] <= cam_d;
            mi_idx <= mi_idx + 3'd1;
        end
        if (linea_n >= 9'd480) linea_n <= 9'd0;
    end

    // ---- transmisor: manda "AND=xx OR=xx\n" ----
    reg [7:0] u_dato; reg u_env; wire u_listo;
    uart_tx #(.DIVISOR(104)) UART (
        .clk(clk), .reset(1'b0), .dato(u_dato), .enviar(u_env), .tx(uart_tx_pin), .listo(u_listo));

    function [7:0] hex; input [3:0] n; begin hex = (n<10) ? (8'h30+n) : (8'h41+n-10); end endfunction

    reg [5:0] mi = 6'd0; reg mandando = 1'b0;
    reg [7:0] linea [0:37];
    always @(*) begin
        linea[0]="A"; linea[1]="N"; linea[2]="D"; linea[3]="=";
        linea[4]=hex(a2[7:4]); linea[5]=hex(a2[3:0]);
        linea[6]=" "; linea[7]="O"; linea[8]="R"; linea[9]="=";
        linea[10]=hex(o2[7:4]); linea[11]=hex(o2[3:0]);
        linea[12]=" "; linea[13]="P"; linea[14]="I"; linea[15]="X"; linea[16]="=";
        linea[17]=hex(muestra[0][7:4]); linea[18]=hex(muestra[0][3:0]); linea[19]=" ";
        linea[20]=hex(muestra[1][7:4]); linea[21]=hex(muestra[1][3:0]); linea[22]=" ";
        linea[23]=hex(muestra[2][7:4]); linea[24]=hex(muestra[2][3:0]); linea[25]=" ";
        linea[26]=hex(muestra[3][7:4]); linea[27]=hex(muestra[3][3:0]); linea[28]=" ";
        linea[29]=hex(muestra[4][7:4]); linea[30]=hex(muestra[4][3:0]); linea[31]=" ";
        linea[32]=hex(muestra[5][7:4]); linea[33]=hex(muestra[5][3:0]); linea[34]=" ";
        linea[35]=hex(muestra[6][7:4]); linea[36]=hex(muestra[6][3:0]);
        linea[37]=8'h0A;
    end
    always @(posedge clk) begin
        u_env <= 1'b0;
        if (nuevo && !mandando) begin mandando <= 1'b1; mi <= 6'd0; end
        else if (mandando && u_listo && !u_env) begin
            u_dato <= linea[mi]; u_env <= 1'b1;
            if (mi == 6'd37) mandando <= 1'b0; else mi <= mi + 6'd1;
        end
    end

endmodule
