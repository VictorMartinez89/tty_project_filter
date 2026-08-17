## How it works

Same RISC-V vision SoC as `tt_um_soc_sobel_vic`, but the CPU **boots from an EXTERNAL SPI flash** instead
of an internal synthesized ROM — the philosophy used by Johan Ruiz's `tt_um_femto` and by real
microcontrollers. The **FemtoRV32** fetches instructions over SPI (`MappedSPIFlash`: `flash_clk`,
`flash_cs_n`, `flash_mosi`, `flash_miso`), stalling on `mem_rbusy` while each word arrives. The firmware
(in the external flash) writes peripheral 0x0045 to select **Sobel** and set the threshold; then the Sobel
datapath processes the streaming image.

**Two firmware philosophies (thesis comparison):**
- `tt_um_soc_sobel_vic` — firmware in a **synthesized ROM** (self-contained, no external chip).
- `tt_um_soc_sobel_flash_vic` (this one) — firmware in an **external SPI flash** (flexible, needs a flash chip).

## How to test

Connect an SPI flash (or a flash model in simulation) with the Sobel-config firmware. Hold `rst_n` low,
then high: the CPU boots from flash and configures the filter (`cpu_wrote_filter` = `uio_out[2]` goes high
when it has). Then stream pixels on `ui_in` with `in_valid` (`uio_in[0]`); read edges on `uo_out` when
`out_valid` (`uio_out[1]`) is high.

> **Nota (honestidad):** el diseño **elabora limpio** (estructura), pero el **boot real desde flash** debe
> verificarse en simulación con un modelo de flash (`cores/sim_spi_flash/spiflash.v`) + un `.hex` con el
> firmware de config del Sobel, ANTES de enviarlo a un shuttle. Es un paso iterativo (protocolo SPI +
> vector de reset + endianness). La versión de ROM interna (`tt_soc_sobel`) ya es autónoma y más segura.

## External hardware

An **SPI flash chip** holding the firmware (e.g., W25Q-series). Optionally a camera/uC to feed pixels and
a display to show `uo_out`.
