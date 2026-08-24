## How it works

This is a **streaming Sobel 3x3 edge detector**, taken from an MSc thesis on a RISC-V vision SoC
(Universidad Nacional de Colombia). It is the smallest of the three filters in that work, and the
baseline the others are compared against.

1. A **3x3 sliding window** is built from the incoming raster stream with two line-buffers
   (`linebuf3x3`, 60-pixel rows).
2. **Sobel gradients** are computed with shifts and adds only, **no multipliers**:
   `Gx = [-1 0 1; -2 0 2; -1 0 1]`, `Gy = [-1 -2 -1; 0 0 0; 1 2 1]`.
3. The magnitude is the **Manhattan approximation** `mag = |Gx| + |Gy|`, saturated to 255 — the same
   expression used in other Tiny Tapeout Sobel designs, which makes the results directly comparable.
4. A **fixed threshold** (90) turns the magnitude into a binary edge map: `0xFF` = edge, `0x00` = flat.

The threshold is hard-wired rather than exposed on pins, because Tiny Tapeout only offers 8+8+8 I/O and
the pixel bus already takes eight of them. In the FPGA version of this design a RISC-V core writes the
threshold at run time through a memory-mapped peripheral; see the companion project
`tt_um_soc_sobel_vic` for the version that keeps the CPU on-chip.

## How to test

Feed a raster stream of 8-bit grayscale pixels on `ui_in`, one per clock, holding `in_valid`
(`uio_in[0]`) high. Rows are **60 pixels wide**; use a 60xH test image. After the pipeline fills (two
rows plus a few cycles), every cycle with `out_valid` high (`uio_out[1]`) presents one output pixel on
`uo_out`: `0xFF` where an edge was detected, `0x00` elsewhere.

A quick sanity check: send an image whose left half is dark (e.g. 20) and right half is bright (e.g.
200). The boundary column should come out as `0xFF` and the flat areas as `0x00`.

## External hardware

None. Pixels go in and out on the standard Tiny Tapeout pins; a microcontroller or FPGA driving the
`ui_in` bus at one pixel per clock is enough.
