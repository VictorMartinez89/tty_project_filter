## How it works

This is the **most complete design of the set**: a RISC-V processor and a transitive-hysteresis engine on
the same die, from an MSc thesis on a vision SoC (Universidad Nacional de Colombia). It completes the
matrix the thesis explores — three edge filters, each with and without a CPU — inside Tiny Tapeout.

**The brain.** A [FemtoRV32 Quark](https://github.com/BrunoLevy/learn-fpga) (RV32I) boots from a
**synthesized ROM** — seven instructions baked into the logic, because on real silicon flip-flops power up
with random contents and there is no bitstream to load a program. The firmware writes a memory-mapped
peripheral at `0x0045_0000`, selecting **transitive mode** and setting both hysteresis thresholds
(110 / 70).

**The engine.** It stores a **36x26 frame of pixel classes** (0 = none, 1 = weak, 2 = strong) and sweeps it
repeatedly until nothing changes:

```
newc = confirmed | (weak & any_of_8_neighbours_confirmed)
```

Each sweep wakes one more link, so a whole **chain** of weak pixels hanging off a single strong seed gets
confirmed — not just the neighbour touching it. That is morphological reconstruction to a fixed point, and
it is what *transitive* means: better-connected edges than a one-hop hysteresis can produce.

**Why such a small frame?** Because the CPU does not shrink. The FemtoRV32 costs about 5 300 standard
cells no matter what, while the engine's cost scales with the pixel count (its frame becomes flip-flops —
there is no SRAM macro here). The companion project `tt_um_trans_mini_vic`, without a CPU, fits a 36x26
frame in the same budget at **875 cells per tile**; add the brain to that very same 36x26 frame and the
design measures **~22 855 instances = 1 428 cells per tile**, while the shuttle already failed to converge
at 1 378 and at 1 163. That is roughly 25 tiles against a 16-tile ceiling. The submittable frame is 24x18
(~16 870 instances, 1 054 cells per tile); this 36x26 build is the measurement, kept for the thesis.

So this chip is a **demonstrator of the architecture**, not a useful image processor: it proves the CPU can
configure the engine at run time and that the engine propagates a full chain — on a toy-sized image.

## How to test

1. Release `rst_n`. Within ~2 us `cpu_wrote_filter` (`uio_out[4]`) goes high: the processor has executed
   its firmware and configured the filter.
2. The engine first **clears** its padded frame, so wait for `load_ready` (`uio_out[3]`).
3. Load the frame: drive the 2-bit class on `ui_in[1:0]` with `in_valid` (`uio_in[0]`) high, one pixel per
   clock, raster order — 36 rows of 26.
4. The engine sweeps, then streams the result: each cycle with `out_valid` (`uio_out[1]`) high presents one
   pixel on `uo_out[0]` (1 = edge). `done` (`uio_out[2]`) marks the end of the frame.

The revealing test: put **one strong pixel** and a **chain of weak pixels** running away from it in a single
row. A one-hop hysteresis lights two pixels; this design lights the whole chain.

## External hardware

None. The firmware lives in on-chip ROM, so the chip needs only a clock, a reset, and something to feed the
class stream.
