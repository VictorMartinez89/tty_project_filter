## How it works

A **self-contained RISC-V vision SoC**, from an MSc thesis (Universidad Nacional de Colombia):

- A **FemtoRV32** (RV32I, by Bruno Levy) is the CPU.
- Its program lives in a **synthesized ROM** (7 instructions) — **no external flash needed**, because on
  an ASIC the flip-flops power up random and there is no bitstream. The firmware writes a memory-mapped
  peripheral (address 0x0045) to select **Sobel** mode and set the threshold to **90**.
- A **Sobel 3x3** datapath (`mag = |Gx|+|Gy|`) then processes a streaming image using that CPU-set
  threshold. Output: `0xFF` = edge, `0x00` = flat.

So the CPU **configures the filter by software**, all on one chip, with no external memory.

## How to test

- Hold `rst_n` low a few cycles, then high; the CPU boots and configures the filter. When it has written
  the peripheral, `cpu_wrote_filter` (`uio_out[2]`) goes high (a nice "the CPU ran" proof).
- Stream 8-bit pixels on `ui_in`, one per clock, with `in_valid` (`uio_in[0]`) high (60-pixel-wide rows).
- Read edges on `uo_out` when `out_valid` (`uio_out[1]`) is high.

## External hardware

None required (fully self-contained: CPU + ROM + filter on-chip). Optionally a microcontroller/FPGA or a
camera can feed the pixel stream and a display can show `uo_out`.
