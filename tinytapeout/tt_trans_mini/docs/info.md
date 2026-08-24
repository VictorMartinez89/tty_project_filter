## How it works

This is the **transitive hysteresis engine** of a Canny edge detector — the part that decides whether a
*weak* edge pixel is real — implemented as **morphological reconstruction to a fixed point**, from an MSc
thesis on a RISC-V vision SoC (Universidad Nacional de Colombia).

Ordinary streaming implementations do **one hop**: a weak pixel survives only if it is touching a strong
one *right now*. This engine does better. It stores the whole **32x24 frame of pixel classes**
(0 = none, 1 = weak, 2 = strong) and **sweeps it repeatedly** until nothing changes any more:

```
newc = confirmed | (weak & any_of_8_neighbours_confirmed)
```

Each sweep wakes up one more link, so after K sweeps a **whole chain** of weak pixels hanging off a single
strong seed is confirmed — not just the neighbour that touches it. That is what *transitive* means here,
and it produces noticeably better-connected edges than the one-hop version.

**Why 32x24 and not the 80x60 of the thesis?** Because the frame is the design. On an FPGA it lives in one
block of BRAM and costs almost nothing; on an ASIC without SRAM macros it becomes **flip-flops**, and the
area scales with the pixel count. At 80x60 this engine needs about 53 tiles — impossible. At 32x24 it fits
in six. *The resolution is chosen by the memory, not by the application.*

## How to test

1. Release `rst_n`. The engine first **clears** its padded frame ((H+2)x(W+2) = 884 cells), so wait for
   `load_ready` (`uio_out[3]`) to go high — about 900 clocks. Do not start pushing pixels before that.
2. Load the frame: drive the 2-bit class on `ui_in[1:0]` with `in_valid` (`uio_in[0]`) high, one pixel per
   clock, in raster order — 32 rows of 24.
3. The engine sweeps on its own, then streams the result: every cycle with `out_valid` (`uio_out[1]`) high
   presents one pixel on `uo_out[0]` (1 = edge). `done` (`uio_out[2]`) marks the end of the frame.

A good test is the one that shows what makes this engine different: put **one strong pixel** and a **chain
of weak pixels** running away from it, all in one row. A one-hop hysteresis would light up two pixels; this
one lights up the entire chain.

## External hardware

None. Something has to produce the 2-bit class stream — in the original system a Gaussian + Sobel + double
threshold front-end does it, and the companion projects `tt_um_sobel_vic` and `tt_um_canny1_vic` contain
that front-end.
