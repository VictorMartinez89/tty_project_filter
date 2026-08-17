## How it works

This is a **streaming Canny edge detector** (stage-1, one-hop hysteresis), taken from an MSc thesis on a
RISC-V vision SoC (Universidad Nacional de Colombia). The pixel pipeline is:

1. **Gaussian 3x3** smoothing (kernel [1 2 1; 2 4 2; 1 2 1] / 16) to reduce noise.
2. **Sobel 3x3** gradient: `mag = |Gx| + |Gy|` (no multipliers, only adds/shifts).
3. **Double threshold** -> class per pixel: `strong` if `mag > 90`, `weak` if `mag > 40`, else `none`.
4. **1-hop hysteresis**: a pixel is an edge if it is `strong`, or `weak` **and** touching a `strong`
   neighbour (8-connectivity). Isolated weak pixels are dropped -> cleaner, connected edges.

The image is processed as a **raster stream of 60-pixel-wide rows** using three sets of BRAM-style
line-buffers (`linebuf3x3`), which on sky130 become flip-flops + logic. Thresholds are fixed (90/40) to
save I/O pins.

## How to test

Feed a raster stream of 8-bit grayscale pixels on `ui_in`, one per clock, with `in_valid` (`uio_in[0]`)
high. After the pipeline fills (a few rows), each valid output cycle (`out_valid` = `uio_out[1]`) presents
one edge pixel on `uo_out`: `0xFF` = edge, `0x00` = flat. Rows are 60 pixels wide; use a 60xH test image.

- Hold `rst_n` low for a few cycles, then high.
- Drive `in_valid` high and stream pixels on `ui_in`.
- Read `uo_out` when `out_valid` is high.

A cocotb/iverilog testbench can stream a small 60xN image and compare against a golden Sobel/Canny model.

## External hardware

None required (self-contained). Optionally, a microcontroller/FPGA or a camera front-end can feed the
pixel stream, and a display can show `uo_out`. In the source thesis the stream came from an OV7670 camera
and the edges went to an ILI9341 TFT.
