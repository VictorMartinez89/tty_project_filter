// ============================================================================
// ov7670_capture.v
//
// OV7670 camera capture front-end for the femto2 SoC (tty_project_filter thesis).
// Target board: iCESugar v1.5  (Lattice iCE40UP5K-SG48)
// Wiring:       PMOD2 = pixel data D[7:0],  PMOD3 = clocks/sync/SCCB
//
// What this module does:
//   1) Generates XCLK (~24 MHz) to drive the OV7670.
//   2) Synchronises PCLK/HREF/VSYNC into the FPGA sysclk domain.
//   3) Captures one 8-bit pixel byte on each PCLK rising edge while HREF=1.
//   4) Combines two consecutive bytes into one 16-bit RGB565 pixel.
//   5) Emits frame_start / line_start pulses for downstream pipeline sync.
//
// What this module does NOT do (separate modules needed):
//   - SCCB (I2C-like) master to configure the camera at boot
//     -> implement in   cores/camera/ov7670_sccb.v
//   - Line buffering / DMA into RAM for the femto2 to read
//     -> downstream consumer's job
//
// Verilog-2001 style, written to be readable as a teaching example.
// ============================================================================

`default_nettype none

module ov7670_capture #(
    parameter integer SYSCLK_HZ = 48_000_000,   // FPGA system clock (Hz)
    parameter integer XCLK_HZ   = 24_000_000    // target XCLK to camera (Hz)
) (
    // -------- Clock & reset --------
    input  wire        sysclk,                 // system clock (>= 2 * PCLK)
    input  wire        rst_n,                  // active-low reset

    // -------- OV7670 pins (cross the PMOD boundary) --------
    input  wire [7:0]  cam_d,                  // pixel data byte   (PMOD2)
    input  wire        cam_pclk,               // pixel clock       (PMOD3, in)
    input  wire        cam_href,               // line valid        (PMOD3, in)
    input  wire        cam_vsync,              // frame sync        (PMOD3, in)
    output wire        cam_xclk,               // FPGA-gen'd clock  (PMOD3, out, ~24 MHz)

    // -------- Pixel stream out (sysclk domain) --------
    output reg  [15:0] pixel_rgb565,           // 16-bit RGB565 pixel
    output reg         pixel_valid,            // 1 sysclk pulse when pixel_rgb565 is fresh
    output reg         frame_start,            // pulse at start of every frame
    output reg         line_start              // pulse at start of every line
);

    // ========================================================================
    // 1) XCLK generator: divide sysclk down to ~XCLK_HZ
    // ------------------------------------------------------------------------
    // For low-jitter operation prefer the iCE40UP5K PLL (SB_PLL40_PAD); this
    // counter-based divider is fine for the OV7670 (it tolerates wide XCLK).
    // ========================================================================
    localparam integer DIVIDER = (SYSCLK_HZ / (2 * XCLK_HZ));   // toggle every DIVIDER cycles
    reg [15:0] xclk_cnt;
    reg        xclk_r;
    always @(posedge sysclk or negedge rst_n) begin
        if (!rst_n) begin
            xclk_cnt <= 16'd0;
            xclk_r   <= 1'b0;
        end else if (xclk_cnt == DIVIDER[15:0] - 1) begin
            xclk_cnt <= 16'd0;
            xclk_r   <= ~xclk_r;
        end else begin
            xclk_cnt <= xclk_cnt + 16'd1;
        end
    end
    assign cam_xclk = xclk_r;

    // ========================================================================
    // 2) 2-FF synchronisers for the camera's async-looking inputs
    //    (PCLK is technically derived from cam_xclk, but it returns to us
    //     through the camera + cable: treat as async, synchronise it.)
    // ========================================================================
    reg [1:0] pclk_s, href_s, vsync_s;
    always @(posedge sysclk or negedge rst_n) begin
        if (!rst_n) begin
            pclk_s  <= 2'b00;
            href_s  <= 2'b00;
            vsync_s <= 2'b00;
        end else begin
            pclk_s  <= {pclk_s [0], cam_pclk };
            href_s  <= {href_s [0], cam_href };
            vsync_s <= {vsync_s[0], cam_vsync};
        end
    end
    wire pclk_now  = pclk_s [1];
    wire href_now  = href_s [1];
    wire vsync_now = vsync_s[1];

    // Edge detection: remember previous value, compare to current.
    reg pclk_prev, href_prev, vsync_prev;
    always @(posedge sysclk or negedge rst_n) begin
        if (!rst_n) begin
            pclk_prev  <= 1'b0;
            href_prev  <= 1'b0;
            vsync_prev <= 1'b0;
        end else begin
            pclk_prev  <= pclk_now;
            href_prev  <= href_now;
            vsync_prev <= vsync_now;
        end
    end
    wire pclk_rising  =  pclk_now  & ~pclk_prev;
    wire href_rising  =  href_now  & ~href_prev;
    wire vsync_rising =  vsync_now & ~vsync_prev;

    // ========================================================================
    // 3) Byte capture + RGB565 byte-pair combiner
    //    The OV7670 sends each 16-bit RGB565 pixel as two bytes back-to-back:
    //        byte 0 (upper) = { R[4:0] , G[5:3] }
    //        byte 1 (lower) = { G[2:0] , B[4:0] }
    //    Align at the start of every line via href_rising.
    // ========================================================================
    reg       byte_phase;     // 0 -> waiting for upper byte ; 1 -> waiting for lower byte
    reg [7:0] upper_byte;

    always @(posedge sysclk or negedge rst_n) begin
        if (!rst_n) begin
            byte_phase   <= 1'b0;
            upper_byte   <= 8'h00;
            pixel_rgb565 <= 16'h0000;
            pixel_valid  <= 1'b0;
            frame_start  <= 1'b0;
            line_start   <= 1'b0;
        end else begin
            // Single-cycle output pulses by default.
            pixel_valid <= 1'b0;
            frame_start <= vsync_rising;
            line_start  <= href_rising;

            // Re-align at the start of each line so we never get half-pixels.
            if (href_rising)
                byte_phase <= 1'b0;

            // Sample data on PCLK rising edge while the line is active.
            if (pclk_rising && href_now) begin
                if (byte_phase == 1'b0) begin
                    upper_byte <= cam_d;
                end else begin
                    pixel_rgb565 <= {upper_byte, cam_d};
                    pixel_valid  <= 1'b1;
                end
                byte_phase <= ~byte_phase;
            end
        end
    end

endmodule

`default_nettype wire
