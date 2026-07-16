// tft_pattern.v — Paso 2: patron de prueba en la PMOD TFT LCD (ILI9341).
// 8 barras verticales PAREJAS de 30 px (segun x) + lineas negras cada 32 filas (y).
// Barras/lineas nitidas -> control total de cada pixel (x,y). 🎯
//   VERDE = init OK, AZUL = heartbeat.
// Pines: clk=35, tft_sck=37, tft_mosi=36, tft_cs=25, tft_dc=23, leds=39/40/41

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
    // ---------------- SPI (envia 1 byte, modo 0) ----------------
    reg        spi_start = 1'b0;
    reg  [7:0] spi_byte  = 8'd0;
    reg        spi_dcbit = 1'b1;
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
            S_LO:  begin sck <= 1'b0; mosi <= sbuf[7]; sst <= S_HI; end
            S_HI:  begin sck <= 1'b1;
                         sbuf <= {sbuf[6:0], 1'b0};
                         if (sbit == 3'd7) sst <= S_END;
                         else begin sbit <= sbit + 1'b1; sst <= S_LO; end
                   end
            S_END: begin sck <= 1'b0; spi_done <= 1'b1; sst <= S_IDLE; end
        endcase
    end

    // ---------------- ROM init + frame ----------------
    localparam T_CMD=2'd0, T_DAT=2'd1, T_DLY=2'd2, T_END=2'd3;
    localparam M_BOOT=2'd0, M_INIT=2'd1, M_FRAME=2'd2, M_FILL=2'd3;
    reg [1:0] mode = M_BOOT;
    reg [4:0] ip   = 5'd0;

    reg [1:0] rt; reg [7:0] rb;
    always @(*) begin
        rt = T_END; rb = 8'h00;
        if (mode == M_INIT) case (ip)
            5'd0:  begin rt=T_CMD; rb=8'h01; end
            5'd1:  begin rt=T_DLY; rb=8'h00; end
            5'd2:  begin rt=T_CMD; rb=8'h11; end
            5'd3:  begin rt=T_DLY; rb=8'h00; end
            5'd4:  begin rt=T_CMD; rb=8'h3A; end
            5'd5:  begin rt=T_DAT; rb=8'h55; end
            5'd6:  begin rt=T_CMD; rb=8'h36; end
            5'd7:  begin rt=T_DAT; rb=8'h48; end
            5'd8:  begin rt=T_CMD; rb=8'h29; end
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

    // ---------------- color: 8 barras PAREJAS de 30px + lineas cada 32 filas ----------------
    reg [7:0] xcol = 8'd0;      // 0..239
    reg [8:0] ycol = 9'd0;      // 0..319

    reg [15:0] barc;
    always @(*) begin
        if      (xcol <  8'd30) barc = 16'hFFFF;  // blanco
        else if (xcol <  8'd60) barc = 16'hFFE0;  // amarillo
        else if (xcol <  8'd90) barc = 16'h07FF;  // cian
        else if (xcol < 8'd120) barc = 16'h07E0;  // verde
        else if (xcol < 8'd150) barc = 16'hF81F;  // magenta
        else if (xcol < 8'd180) barc = 16'hF800;  // rojo
        else if (xcol < 8'd210) barc = 16'h001F;  // azul
        else                    barc = 16'h0000;  // negro
    end
    wire [15:0] pcolor = (ycol[4:0] == 5'd0) ? 16'h0000 : barc;

    // ---------------- secuenciador ----------------
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
                    T_CMD, T_DAT: begin
                        spi_byte  <= rb; spi_dcbit <= (rt == T_DAT);
                        spi_start <= 1'b1; sending <= 1'b1;
                    end
                    T_DLY: if (dcnt == 21'd1_800_000) begin dcnt <= 21'd0; ip <= ip + 1'b1; end
                           else dcnt <= dcnt + 1'b1;
                    default: begin mode <= M_FRAME; ip <= 5'd0; end
                endcase
            end else if (spi_done) begin sending <= 1'b0; ip <= ip + 1'b1; end
        end
        M_FRAME: begin
            if (!sending) begin
                case (rt)
                    T_CMD, T_DAT: begin
                        spi_byte  <= rb; spi_dcbit <= (rt == T_DAT);
                        spi_start <= 1'b1; sending <= 1'b1;
                    end
                    default: begin mode <= M_FILL; px <= 17'd0; pxhi <= 1'b0;
                                   xcol <= 8'd0; ycol <= 9'd0; end
                endcase
            end else if (spi_done) begin sending <= 1'b0; ip <= ip + 1'b1; end
        end
        M_FILL: begin
            if (!sending) begin
                spi_byte  <= pxhi ? pcolor[7:0] : pcolor[15:8];
                spi_dcbit <= 1'b1;
                spi_start <= 1'b1; sending <= 1'b1;
            end else if (spi_done) begin
                sending <= 1'b0;
                if (pxhi) begin
                    pxhi <= 1'b0;
                    if (px == 17'd76799) begin
                        px <= 17'd0; mode <= M_FRAME; ip <= 5'd0;
                    end else begin
                        px <= px + 1'b1;
                        if (xcol == 8'd239) begin xcol <= 8'd0; ycol <= ycol + 1'b1; end
                        else xcol <= xcol + 1'b1;
                    end
                end else pxhi <= 1'b1;
            end
        end
        endcase
    end

    wire init_done = (mode == M_FRAME) | (mode == M_FILL);

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
