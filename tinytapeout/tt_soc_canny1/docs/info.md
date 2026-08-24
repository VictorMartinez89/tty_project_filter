## How it works

A **complete little system-on-chip**: a RISC-V processor that configures an image filter, both on the same
die, taken from an MSc thesis on a vision SoC (Universidad Nacional de Colombia).

- The **CPU** is a [FemtoRV32 Quark](https://github.com/BrunoLevy/learn-fpga) (RV32I). It boots from a
  **synthesized ROM** — seven instructions baked into the logic, not a RAM — because on real silicon
  flip-flops power up with random contents and there is nothing to load a program from.
- The firmware writes a **memory-mapped peripheral** at `0x0045_0000`: it selects Canny mode and sets
  **both hysteresis thresholds** in one 32-bit word (`0x5A28` → `thr_hi = 90`, `thr_lo = 40`).
- The **image path never touches the CPU bus.** Pixels stream through the hardware pipeline —
  Gaussian 3x3 → Sobel 3x3 → double threshold → 1-hop hysteresis — one pixel per clock. The processor only
  configures and supervises. That split (hardware for the data flow, CPU for control) is the point of the
  design.

Compared with the companion project `tt_um_sobel_vic`, where the threshold is hard-wired because the pins
are all taken, here the thresholds are set **from inside the chip** — which is exactly what having a CPU
buys you.

## How to test

Hold `rst_n` low for a few clocks and release it. Within ~2 µs the CPU has executed its firmware and
`cpu_wrote_filter` (`uio_out[2]`) goes high: the filter is configured.

Then feed a raster stream of 8-bit grayscale pixels on `ui_in`, one per clock, with `in_valid`
(`uio_in[0]`) high. Rows are **60 pixels wide**. Each cycle with `out_valid` (`uio_out[1]`) high presents
one output pixel on `uo_out`: `0xFF` = edge, `0x00` = flat.

## External hardware

None. The firmware lives in on-chip ROM, so the chip needs only a clock, a reset and something to drive
the pixel bus.
