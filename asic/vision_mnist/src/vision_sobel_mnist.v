// vision_sobel_mnist.v — EL CHIP QUE VE UN DIGITO Y DICE CUAL ES, para ASIC sky130.
//   camara OV7670 -> ventana central 448x448 -> 28x28 -> CLASIFICADOR -> TFT ILI9341.
//
//   Portado del diseno FISICO verificado en FPGA (mnist_cam_display.v, 8/10 en silicio).
//   Los MISMOS 3 cambios ASIC que se le hicieron a vision_top.v en la fase 9:
//     (1) RESET EXPLICITO (rst_n) en todos los FSM -> en silicio los FF arrancan aleatorios,
//         y en FPGA los inicializaba el bitstream.  Aqui no hay quien los inicialice.
//     (2) cam_sda open-drain (inout, 1'bz) partido en cam_sda_o/cam_sda_oe -> el tri-state
//         vive en el anillo de pads, no en el nucleo.
//     (3) sin SB_RGBA_DRV (el driver de LED es una primitiva de iCE40). Las tres senales de
//         estado salen como pines normales.
//   Y una limpieza: `pcount` y `cam_sync` estaban declarados y no los leia nadie.
//
//   DUAL-CLOCK, igual que vision_top: SCCB + display en 'clk'; captura, ventana y
//   clasificador en 'cam_pclk'.  El cruce del digito son 2 FF (es casi-estatico).
//
//   LOS DOS FRAMEBUFFERS NO SE RESETEAN, como el de vision_top y el del transitivo: se
//   llenan antes de leerse, y resetear 784 bytes cuesta celdas que no compran nada.
`default_nettype none
module vision_sobel_mnist #(
    // INVERTIR=1: trazo claro sobre fondo oscuro, como MNIST (modo normal).
    parameter INVERTIR = 1
) (
    input  wire       clk,
    input  wire       rst_n,
    // ---- camara OV7670 ----
    output wire       cam_xclk,
    output reg        cam_scl,
    output wire       cam_sda_o,     // open-drain: dato (siempre 0 cuando activo)
    output wire       cam_sda_oe,    // open-drain: enable -> el pad hace el tri-state
    input  wire       cam_pclk,
    input  wire       cam_href,
    input  wire [7:0] cam_d,
    // ---- display PMOD TFTLCD ----
    output wire       tft_sck,
    output wire       tft_mosi,
    output wire       tft_cs,
    output wire       tft_dc,
    // ---- estado (antes iban al LED RGB de la placa) ----
    output reg        cfg_done,      // la camara quedo configurada
    output reg        hubo,          // clasifico al menos una vez
    output wire [3:0] digito         // el ultimo digito; 10 = "no se"
);
    assign cam_xclk = clk;

    // ==================== SCCB config (dominio clk) ====================
    reg sda_oe;
    assign cam_sda_o  = 1'b0;
    assign cam_sda_oe = sda_oe;

    reg [5:0] tdiv;
    wire tick = (tdiv == 6'd29);
    always @(posedge clk or negedge rst_n)
        if (!rst_n) tdiv <= 6'd0; else tdiv <= tick ? 6'd0 : tdiv + 1'b1;

    reg [4:0] idx;
    reg [15:0] rom;
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
    reg [2:0]  cpc;
    reg [1:0]  cph;
    reg [3:0]  cbi;
    reg [15:0] cdly;

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

    reg [19:0] cboot;
    wire cboot_ok = &cboot;
    always @(posedge clk or negedge rst_n)
        if (!rst_n) cboot <= 20'd0; else if (!cboot_ok) cboot <= cboot + 1'b1;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cpc <= 3'd0; cph <= 2'd0; cbi <= 4'd0; cdly <= 16'd0;
            cfg_done <= 1'b0; sda_oe <= 1'b0; cam_scl <= 1'b1; idx <= 5'd0;
        end else if (tick && cboot_ok && !cfg_done) begin
            case (coptype)
            C_START: begin
                if (tbl_end) cfg_done <= 1'b1;
                else begin
                    case (cph)
                        2'd0: begin sda_oe<=1'b0; cam_scl<=1'b1; end
                        2'd1: begin sda_oe<=1'b1; cam_scl<=1'b1; end
                        2'd2: cam_scl<=1'b0;
                        2'd3: cpc<=cpc+1'b1;
                    endcase
                    cph <= cph + 1'b1;
                end
            end
            C_WR: begin
                case (cph)
                    2'd0: begin cam_scl<=1'b0; if (cbi<4'd8) sda_oe<=~cwbyte[3'd7-cbi[2:0]]; else sda_oe<=1'b0; end
                    2'd1: cam_scl<=1'b1; 2'd2: cam_scl<=1'b1;
                    2'd3: begin cam_scl<=1'b0; if (cbi==4'd8) begin cbi<=4'd0; cpc<=cpc+1'b1; end else cbi<=cbi+1'b1; end
                endcase
                cph <= cph + 1'b1;
            end
            C_STOP: begin
                case (cph)
                    2'd0: begin cam_scl<=1'b0; sda_oe<=1'b1; end
                    2'd1: begin cam_scl<=1'b1; sda_oe<=1'b1; end
                    2'd2: begin cam_scl<=1'b1; sda_oe<=1'b0; end
                    2'd3: begin cpc<=cpc+1'b1; cdly<=16'd999; end
                endcase
                cph <= cph + 1'b1;
            end
            C_DLY: if (cdly==16'd0) cpc<=cpc+1'b1; else cdly<=cdly-1'b1;
            default: begin idx<=idx+1'b1; cpc<=3'd0; end
            endcase
        end
    end

    // ======== ventana central 448x448 -> 28x28 promediado e invertido (dominio pclk) ========
    //   La camara entrega YUV422 y la luma es el SEGUNDO byte del par (U Y V Y). Capturar en
    //   parity==0 tomaba la CROMA (~0x80 constante) — lo que el diagnostico por UART mostro.
    reg parity, href_d;
    reg [7:0] curY;
    reg py_valid;
    always @(posedge cam_pclk or negedge rst_n) begin
        if (!rst_n) begin
            parity <= 1'b0; href_d <= 1'b0; curY <= 8'd0; py_valid <= 1'b0;
        end else begin
            href_d <= cam_href; py_valid <= 1'b0;
            if (~cam_href) parity <= 1'b0;
            else begin
                if (parity == 1'b1) begin curY <= cam_d; py_valid <= 1'b1; end
                parity <= ~parity;
            end
        end
    end

    wire       w_valid; wire [7:0] w_pix; wire w_fin;
    cam_win28 #(.CAM_W(640),.CAM_H(480),.WIN(448),.N(28)) WIN (
        .pclk(cam_pclk), .sync(1'b0), .reset(~cfg_done | ~rst_n), .href(cam_href),
        .pix_y(curY), .pix_valid(py_valid), .invertir(INVERTIR[0]),
        .out_valid(w_valid), .out_pix(w_pix), .frame_fin(w_fin));

    // ======== el clasificador (el MISMO verificado bit a bit contra el golden) ========
    wire       clf_done; wire [3:0] clf_dig; wire clf_val;
    // clr cuando TERMINA de clasificar, no en cada cuadro: el video es continuo y el raster se
    // encadena solo. El clasificador se autorregula: acumula, clasifica, limpia, repite.
    reg        clf_clr;
    always @(posedge cam_pclk or negedge rst_n)
        if (!rst_n) clf_clr <= 1'b0; else clf_clr <= clf_done;
    mnist_top #(.H(28),.W(28),.CW(9)) CLF (
        .clk(cam_pclk), .reset(~cfg_done | ~rst_n), .clr(clf_clr),
        .in_valid(w_valid), .in_pix(w_pix), .thr(8'd60),
        .done(clf_done), .digito(clf_dig), .valido(clf_val));

    // digito reconocido, cruzado al dominio del display (casi-estatico: 2 FF bastan).
    //   Si el clasificador dice NADA se muestra el codigo 10, que el glifo dibuja como una raya.
    //   Poder decir "no se" no es adorno: entre los cuadros que si contesta, la precision sube
    //   de 89.2 % a 93.9 %.
    reg [3:0] dig_pclk;
    always @(posedge cam_pclk or negedge rst_n) begin
        if (!rst_n) begin dig_pclk <= 4'd10; hubo <= 1'b0; end
        else if (clf_done) begin
            dig_pclk <= clf_val ? clf_dig : 4'd10;
            hubo <= 1'b1;
        end
    end
    reg [3:0] dig_s1, dig_clk;
    reg       hubo_s1, hubo_clk;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dig_s1 <= 4'd10; dig_clk <= 4'd10; hubo_s1 <= 1'b0; hubo_clk <= 1'b0;
        end else begin
            dig_s1 <= dig_pclk;  dig_clk  <= dig_s1;
            hubo_s1 <= hubo;     hubo_clk <= hubo_s1;
        end
    end
    assign digito = dig_clk;

    // ======== framebuffer de las 28x28 (784 bytes) — SIN reset, se llena antes de leerse ====
    //   El CONTADOR se resetea; la MEMORIA no, y van en bloques SEPARADOS a proposito: una
    //   memoria escrita dentro de un always con reset asincrono NO se infiere como memoria.
    //   yosys avisa "mem2reg_wr ... ADDR is used but has no driver", se pierde la escritura y
    //   el framebuffer desaparece del netlist. Es el mismo patron que usa vision_top.
    reg [7:0]  fb [0:783];
    reg [9:0]  wadr;
    always @(posedge cam_pclk or negedge rst_n) begin
        if (!rst_n) wadr <= 10'd0;
        else begin
            if (w_valid) wadr <= (wadr == 10'd783) ? 10'd0 : wadr + 10'd1;
            if (w_fin)   wadr <= 10'd0;      // w_fin manda: es la ultima asignacion
        end
    end
    always @(posedge cam_pclk) if (w_valid) fb[wadr] <= w_pix;
    reg [7:0] fb_rd;

    // ==================== display ILI9341 (dominio clk) ====================
    reg        spi_start;
    reg  [7:0] spi_byte;
    reg        spi_dcbit;
    reg        spi_done;
    reg sck, mosi, cs, dc;
    assign tft_sck=sck; assign tft_mosi=mosi; assign tft_cs=cs; assign tft_dc=dc;

    localparam S_IDLE=2'd0, S_LO=2'd1, S_HI=2'd2, S_END=2'd3;
    reg [1:0] sst;
    reg [2:0] sbit;
    reg [7:0] sbuf;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            spi_done <= 1'b0; sst <= S_IDLE; sbit <= 3'd0; sbuf <= 8'd0;
            sck <= 1'b0; mosi <= 1'b0; cs <= 1'b1; dc <= 1'b1;
        end else begin
            spi_done <= 1'b0;
            case (sst)
                S_IDLE: if (spi_start) begin cs<=1'b0; dc<=spi_dcbit; sbuf<=spi_byte; sbit<=3'd0; sck<=1'b0; sst<=S_LO; end
                S_LO:  begin sck<=1'b0; mosi<=sbuf[7]; sst<=S_HI; end
                S_HI:  begin sck<=1'b1; sbuf<={sbuf[6:0],1'b0}; if (sbit==3'd7) sst<=S_END; else begin sbit<=sbit+1'b1; sst<=S_LO; end end
                S_END: begin sck<=1'b0; spi_done<=1'b1; sst<=S_IDLE; end
            endcase
        end
    end

    localparam T_CMD=2'd0, T_DAT=2'd1, T_DLY=2'd2, T_END=2'd3;
    localparam M_BOOT=2'd0, M_INIT=2'd1, M_FRAME=2'd2, M_FILL=2'd3;
    reg [1:0] mode;
    reg [4:0] ip;

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

    // ======== que color va en cada pixel de la pantalla (240x320) ========
    //   filas   0..223 : las 28x28 ampliadas x8, con marco verde de 3 px
    //   filas 232..319 : el digito reconocido en siete segmentos
    reg [7:0] xcol;
    reg [8:0] ycol;

    localparam integer IMG = 224;              // 28 * 8
    localparam integer BORDE = 3;
    // en_img mira las DOS coordenadas: mirando solo ycol, las columnas 224..239 caian en el
    // marco derecho y pintaban una franja verde de 19 px en vez de 3.
    wire en_img  = (ycol < IMG) && (xcol < IMG);
    wire [4:0] ix = xcol[7:3];                 // /8
    wire [4:0] iy = ycol[7:3];
    wire [9:0] fbaddr = iy*28 + ix;
    always @(posedge clk) fb_rd <= fb[fbaddr];   // sin reset: acompana al framebuffer

    wire en_marco = en_img && ((xcol < BORDE) || (xcol >= IMG-BORDE) ||
                               (ycol < BORDE) || (ycol >= IMG-BORDE));

    localparam integer GY0 = 232, GW = 60, GH = 80;
    wire en_glifo_caja = (ycol >= GY0) && (ycol < GY0+GH) &&
                         (xcol >= (240-GW)/2) && (xcol < (240-GW)/2 + GW);
    wire glifo_on;
    // Los puertos gx/gy del glifo son de 8 bits, y `xcol - (240-GW)/2` sale de 32 porque la
    // aritmetica con enteros SIN DIMENSIONAR es de 32 bits. iverilog lo avisa ("Pruning 24 high
    // bits") pero sigue; OpenLane lo rechaza con error duro ("Resizing cell port") y la sintesis
    // no arranca. Se dimensiona en dos wires: la poda ya ocurria, aqui solo se hace explicita.
    // Dentro de la caja gx va 0..59 y gy 0..79, asi que 8 bits sobran en los dos casos.
    wire [7:0] gx_off = xcol - (240-GW)/2;
    wire [8:0] gy_off = ycol - GY0;
    glifo #(.ANCHO(GW),.ALTO(GH),.GRUESO(11)) G (
        .digito(dig_clk),
        .gx(en_glifo_caja ? gx_off        : 8'd0),
        .gy(en_glifo_caja ? gy_off[7:0]   : 8'd0),
        .encendido(glifo_on));

    wire [15:0] gris  = {fb_rd[7:3], fb_rd[7:2], fb_rd[7:3]};
    wire [15:0] VERDE = 16'b00000_111111_00000;
    wire [15:0] AMBAR = 16'b11111_101101_00000;
    wire [15:0] NEGRO = 16'h0000;
    wire [15:0] pcolor = en_marco                        ? VERDE :
                         en_img                          ? gris  :
                         (en_glifo_caja && glifo_on && hubo_clk) ? AMBAR : NEGRO;

    reg [20:0] dcnt;
    reg [16:0] px;
    reg        pxhi;
    reg        sending;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            spi_start <= 1'b0; spi_byte <= 8'd0; spi_dcbit <= 1'b1;
            mode <= M_BOOT; ip <= 5'd0; dcnt <= 21'd0; px <= 17'd0;
            pxhi <= 1'b0; sending <= 1'b0; xcol <= 8'd0; ycol <= 9'd0;
        end else begin
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
    end
endmodule
`default_nettype wire
