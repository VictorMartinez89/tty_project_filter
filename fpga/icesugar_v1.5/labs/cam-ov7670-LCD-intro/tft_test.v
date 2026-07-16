// tft_test.v — "Blinky" de la pantalla PMOD TFT LCD v1.1 (ILI9341, 320x240, SPI).
// Inicializa el ILI9341 y rellena TODA la pantalla con un color que cambia lento.
// Si la pantalla muestra color y va cambiando -> SPI + init OK. 🎉
//
//   VERDE = init terminado (pantalla configurada)
//   AZUL  = heartbeat (FPGA viva)
// Pines: clk=35, tft_sck=37, tft_mosi=36, tft_cs=25, tft_dc=24, leds=39/40/41
// SPI modo 0, SCK ~6 MHz. RST por software (cmd 0x01). Backlight siempre ON (VCC).

module top (
    input  wire clk,
    output wire tft_sck,
    output wire tft_mosi,
    output wire tft_cs,
    output wire tft_dc,
    output wire led_r,
    output wire led_g,
    output wire led_b
);
    // ---------------- SPI: envia 1 byte (MSB primero, modo 0) ----------------
    reg        spi_start = 1'b0;
    reg  [7:0] spi_byte  = 8'd0;
    reg        spi_dcbit = 1'b1;    // 0=comando, 1=dato
    reg        spi_done  = 1'b0;

    reg sck = 1'b0, mosi = 1'b0, cs = 1'b1, dc = 1'b1;
    assign tft_sck  = sck;
    assign tft_mosi = mosi;
    assign tft_cs   = cs;
    assign tft_dc   = dc;

    localparam S_IDLE=2'd0, S_LO=2'd1, S_HI=2'd2, S_END=2'd3;
    reg [1:0] sst = S_IDLE;
    reg [2:0] sbit = 3'd0;
    reg [7:0] sbuf = 8'd0;
    always @(posedge clk) begin
        spi_done <= 1'b0;
        case (sst)
            S_IDLE: if (spi_start) begin
                        cs <= 1'b0; dc <= spi_dcbit; sbuf <= spi_byte;
                        sbit <= 3'd0; sck <= 1'b0; sst <= S_LO;
                    end
            S_LO:  begin sck <= 1'b0; mosi <= sbuf[7]; sst <= S_HI; end   // dato con SCK bajo
            S_HI:  begin sck <= 1'b1;                                     // slave muestrea en subida
                         sbuf <= {sbuf[6:0], 1'b0};
                         if (sbit == 3'd7) sst <= S_END;
                         else begin sbit <= sbit + 1'b1; sst <= S_LO; end
                   end
            S_END: begin sck <= 1'b0; spi_done <= 1'b1; sst <= S_IDLE; end
        endcase
    end

    // ---------------- ROM de inicializacion + de frame ----------------
    // tipo: 0=CMD, 1=DATA, 2=DELAY, 3=END
    localparam T_CMD=2'd0, T_DAT=2'd1, T_DLY=2'd2, T_END=2'd3;
    localparam M_BOOT=2'd0, M_INIT=2'd1, M_FRAME=2'd2, M_FILL=2'd3;
    reg [1:0] mode = M_BOOT;
    reg [4:0] ip   = 5'd0;

    reg [1:0] rt; reg [7:0] rb;
    always @(*) begin
        rt = T_END; rb = 8'h00;
        if (mode == M_INIT) case (ip)
            5'd0:  begin rt=T_CMD; rb=8'h01; end   // SWRESET
            5'd1:  begin rt=T_DLY; rb=8'h00; end   // ~150ms
            5'd2:  begin rt=T_CMD; rb=8'h11; end   // SLPOUT (salir de sleep)
            5'd3:  begin rt=T_DLY; rb=8'h00; end   // ~150ms
            5'd4:  begin rt=T_CMD; rb=8'h3A; end   // COLMOD
            5'd5:  begin rt=T_DAT; rb=8'h55; end   //   16-bit RGB565
            5'd6:  begin rt=T_CMD; rb=8'h36; end   // MADCTL
            5'd7:  begin rt=T_DAT; rb=8'h48; end   //   MX + BGR
            5'd8:  begin rt=T_CMD; rb=8'h29; end   // DISPON
            default: begin rt=T_END; rb=8'h00; end
        endcase
        else case (ip)  // frame setup: ventana completa + escribir RAM
            5'd0:  begin rt=T_CMD; rb=8'h2A; end   // CASET (columnas)
            5'd1:  begin rt=T_DAT; rb=8'h00; end
            5'd2:  begin rt=T_DAT; rb=8'h00; end
            5'd3:  begin rt=T_DAT; rb=8'h00; end
            5'd4:  begin rt=T_DAT; rb=8'hEF; end   //   0..239
            5'd5:  begin rt=T_CMD; rb=8'h2B; end   // PASET (paginas)
            5'd6:  begin rt=T_DAT; rb=8'h00; end
            5'd7:  begin rt=T_DAT; rb=8'h00; end
            5'd8:  begin rt=T_DAT; rb=8'h01; end
            5'd9:  begin rt=T_DAT; rb=8'h3F; end   //   0..319
            5'd10: begin rt=T_CMD; rb=8'h2C; end   // RAMWR (a partir de aca, pixeles)
            default: begin rt=T_END; rb=8'h00; end
        endcase
    end

    // ---------------- secuenciador ----------------
    reg [20:0] dcnt = 21'd0;
    reg [16:0] px   = 17'd0;     // 0..76799 (320*240)
    reg        pxhi = 1'b0;
    reg [15:0] color = 16'hF800; // arranca rojo
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
                    T_CMD, T_DAT: begin
                        spi_byte  <= rb;
                        spi_dcbit <= (rt == T_DAT);
                        spi_start <= 1'b1; sending <= 1'b1;
                    end
                    T_DLY: if (dcnt == 21'd1_800_000) begin dcnt <= 21'd0; ip <= ip + 1'b1; end
                           else dcnt <= dcnt + 1'b1;
                    default: begin mode <= M_FRAME; ip <= 5'd0; end   // T_END
                endcase
            end else if (spi_done) begin sending <= 1'b0; ip <= ip + 1'b1; end
        end
        M_FRAME: begin
            if (!sending) begin
                case (rt)
                    T_CMD, T_DAT: begin
                        spi_byte  <= rb;
                        spi_dcbit <= (rt == T_DAT);
                        spi_start <= 1'b1; sending <= 1'b1;
                    end
                    default: begin mode <= M_FILL; px <= 17'd0; pxhi <= 1'b0; end
                endcase
            end else if (spi_done) begin sending <= 1'b0; ip <= ip + 1'b1; end
        end
        M_FILL: begin
            if (!sending) begin
                spi_byte  <= pxhi ? color[7:0] : color[15:8];
                spi_dcbit <= 1'b1;          // pixeles = datos
                spi_start <= 1'b1; sending <= 1'b1;
            end else if (spi_done) begin
                sending <= 1'b0;
                if (pxhi) begin
                    pxhi <= 1'b0;
                    if (px == 17'd76799) begin
                        px    <= 17'd0;
                        color <= color + 16'h0841;   // cambia el color lento
                        mode  <= M_FRAME; ip <= 5'd0;
                    end else px <= px + 1'b1;
                end else pxhi <= 1'b1;
            end
        end
        endcase
    end

    wire init_done = (mode == M_FRAME) | (mode == M_FILL);

    // ---------------- LEDs ----------------
    reg [23:0] hb = 24'd0;
    always @(posedge clk) hb <= hb + 1'b1;
    SB_RGBA_DRV #(
        .CURRENT_MODE("0b1"),
        .RGB0_CURRENT("0b000001"), .RGB1_CURRENT("0b000001"), .RGB2_CURRENT("0b000001")
    ) rgba (
        .CURREN(1'b1), .RGBLEDEN(1'b1),
        .RGB0PWM(init_done), .RGB1PWM(1'b0), .RGB2PWM(hb[23]),
        .RGB0(led_r), .RGB1(led_g), .RGB2(led_b)
    );
endmodule
