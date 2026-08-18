// lcd_ili9341_top.v — DRIVER del PMOD TFTLCD (ILI9341, SPI) AUTOCONTENIDO para ASIC sky130 (fase 8).
//   El otro extremo de la cadena: toma un STREAM de pixeles en gris (pix_gray, con handshake pix_next)
//   y lo pinta en la pantalla por SPI. Hace: (1) delay de arranque, (2) secuencia de INIT del ILI9341,
//   (3) por cada cuadro CASET/RASET/RAMWR, (4) FILL: 240x320 pixeles RGB565 (2 bytes c/u).
//   Logica de SPI + ROM de comandos reusada del driver verificado en FPGA (cam_femto_display.v).
//
//   DECISIONES ASIC (para la tesis):
//   - SIN framebuffer interno: los pixeles vienen de AFUERA (del filtro). La memoria se queda fuera
//     -> el driver es "pegamento" barato. Handshake: pix_next pulsa cuando consume un pixel.
//   - RESET EXPLICITO: el original usaba valores `initial` (valen en FPGA por el bitstream, NO en ASIC
//     donde los FF arrancan aleatorios). Aqui todo el estado se inicializa con rst_n.
//   - gris -> RGB565 en grises: {g[7:3], g[7:2], g[7:3]}.
`default_nettype none
module lcd_ili9341_top #(
    parameter integer BOOT_DELAY = 1_800_000,   // ~36 ms @50MHz (reset del ILI9341)
    parameter integer NPIX       = 76800        // 240 x 320
)(
    input  wire       clk,
    input  wire       rst_n,          // reset asincrono activo-bajo (ASIC: obligatorio)
    // ---- stream de pixeles desde el filtro (upstream) ----
    input  wire [7:0] pix_gray,       // pixel actual (gris); debe mantenerse hasta pix_next
    output reg        pix_next,       // pulso 1 ciclo: consumi un pixel, dame el siguiente
    output reg        frame_start,    // pulso: empieza un cuadro (upstream resetea su direccion)
    output wire       init_done,      // 1 = ILI9341 ya inicializado
    // ---- pines del PMOD TFTLCD (SPI) ----
    output reg        tft_sck,
    output reg        tft_mosi,
    output reg        tft_cs,
    output reg        tft_dc
);
    // ============ shifter SPI (modo 0, MSB primero) ============
    reg        spi_start, spi_dcbit, spi_done;
    reg  [7:0] spi_byte;
    localparam S_IDLE=2'd0, S_LO=2'd1, S_HI=2'd2, S_END=2'd3;
    reg [1:0] sst;
    reg [2:0] sbit;
    reg [7:0] sbuf;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sst<=S_IDLE; sbit<=3'd0; sbuf<=8'd0; spi_done<=1'b0;
            tft_sck<=1'b0; tft_mosi<=1'b0; tft_cs<=1'b1; tft_dc<=1'b1;
        end else begin
            spi_done <= 1'b0;
            case (sst)
                S_IDLE: if (spi_start) begin tft_cs<=1'b0; tft_dc<=spi_dcbit; sbuf<=spi_byte; sbit<=3'd0; tft_sck<=1'b0; sst<=S_LO; end
                S_LO:  begin tft_sck<=1'b0; tft_mosi<=sbuf[7]; sst<=S_HI; end
                S_HI:  begin tft_sck<=1'b1; sbuf<={sbuf[6:0],1'b0};
                             if (sbit==3'd7) sst<=S_END; else begin sbit<=sbit+1'b1; sst<=S_LO; end end
                S_END: begin tft_sck<=1'b0; spi_done<=1'b1; sst<=S_IDLE; end
            endcase
        end
    end

    // ============ ROM de comandos (INIT + FRAME) ============
    localparam T_CMD=2'd0, T_DAT=2'd1, T_DLY=2'd2, T_END=2'd3;
    localparam M_BOOT=2'd0, M_INIT=2'd1, M_FRAME=2'd2, M_FILL=2'd3;
    reg [1:0] dmode;
    reg [4:0] ip;
    reg [1:0] rt; reg [7:0] rb;
    always @(*) begin
        rt=T_END; rb=8'h00;
        if (dmode==M_INIT) case (ip)
            5'd0: begin rt=T_CMD; rb=8'h01; end   // SW reset
            5'd1: begin rt=T_DLY; rb=8'h00; end
            5'd2: begin rt=T_CMD; rb=8'h11; end   // sleep out
            5'd3: begin rt=T_DLY; rb=8'h00; end
            5'd4: begin rt=T_CMD; rb=8'h3A; end   // pixel format
            5'd5: begin rt=T_DAT; rb=8'h55; end   //   RGB565
            5'd6: begin rt=T_CMD; rb=8'h36; end   // MADCTL
            5'd7: begin rt=T_DAT; rb=8'h48; end
            5'd8: begin rt=T_CMD; rb=8'h29; end   // display ON
            default: begin rt=T_END; rb=8'h00; end
        endcase
        else case (ip)                            // M_FRAME: ventana + RAMWR
            5'd0:  begin rt=T_CMD; rb=8'h2A; end   // CASET
            5'd1:  begin rt=T_DAT; rb=8'h00; end
            5'd2:  begin rt=T_DAT; rb=8'h00; end
            5'd3:  begin rt=T_DAT; rb=8'h00; end
            5'd4:  begin rt=T_DAT; rb=8'hEF; end   //   239
            5'd5:  begin rt=T_CMD; rb=8'h2B; end   // RASET
            5'd6:  begin rt=T_DAT; rb=8'h00; end
            5'd7:  begin rt=T_DAT; rb=8'h00; end
            5'd8:  begin rt=T_DAT; rb=8'h01; end
            5'd9:  begin rt=T_DAT; rb=8'h3F; end   //   319
            5'd10: begin rt=T_CMD; rb=8'h2C; end   // RAMWR
            default: begin rt=T_END; rb=8'h00; end
        endcase
    end

    // ============ FSM de display ============
    reg [20:0] dcnt;
    reg [16:0] px;
    reg        pxhi;
    reg        sending;
    reg [15:0] pcolor_l;
    wire [15:0] pcolor_w = {pix_gray[7:3], pix_gray[7:2], pix_gray[7:3]}; // gris -> RGB565

    assign init_done = (dmode==M_FRAME) || (dmode==M_FILL);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dmode<=M_BOOT; ip<=5'd0; dcnt<=21'd0; px<=17'd0; pxhi<=1'b0; sending<=1'b0;
            spi_start<=1'b0; spi_byte<=8'd0; spi_dcbit<=1'b1; pix_next<=1'b0; frame_start<=1'b0; pcolor_l<=16'd0;
        end else begin
            spi_start   <= 1'b0;
            pix_next    <= 1'b0;
            frame_start <= 1'b0;
            case (dmode)
            M_BOOT: begin
                dcnt <= dcnt + 1'b1;
                if (dcnt == BOOT_DELAY[20:0]) begin dcnt<=21'd0; dmode<=M_INIT; ip<=5'd0; end
            end
            M_INIT: begin
                if (!sending) begin
                    case (rt)
                        T_CMD,T_DAT: begin spi_byte<=rb; spi_dcbit<=(rt==T_DAT); spi_start<=1'b1; sending<=1'b1; end
                        T_DLY: if (dcnt==BOOT_DELAY[20:0]) begin dcnt<=21'd0; ip<=ip+1'b1; end else dcnt<=dcnt+1'b1;
                        default: begin dmode<=M_FRAME; ip<=5'd0; end
                    endcase
                end else if (spi_done) begin sending<=1'b0; ip<=ip+1'b1; end
            end
            M_FRAME: begin
                if (!sending) begin
                    case (rt)
                        T_CMD,T_DAT: begin spi_byte<=rb; spi_dcbit<=(rt==T_DAT); spi_start<=1'b1; sending<=1'b1; end
                        default: begin dmode<=M_FILL; px<=17'd0; pxhi<=1'b0; frame_start<=1'b1; end
                    endcase
                end else if (spi_done) begin sending<=1'b0; ip<=ip+1'b1; end
            end
            M_FILL: begin
                if (!sending) begin
                    if (!pxhi) begin pcolor_l<=pcolor_w; spi_byte<=pcolor_w[15:8]; end
                    else                                  spi_byte<=pcolor_l[7:0];
                    spi_dcbit<=1'b1; spi_start<=1'b1; sending<=1'b1;
                end else if (spi_done) begin
                    sending<=1'b0;
                    if (pxhi) begin
                        pxhi<=1'b0; pix_next<=1'b1;                 // pixel completo -> pide el siguiente
                        if (px==NPIX[16:0]-17'd1) begin px<=17'd0; dmode<=M_FRAME; ip<=5'd0; end
                        else px<=px+1'b1;
                    end else pxhi<=1'b1;
                end
            end
            endcase
        end
    end
endmodule
`default_nettype wire
