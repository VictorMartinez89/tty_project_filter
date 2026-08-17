# Test — tt_um_soc_sobel_flash_vic (boot desde flash SPI)

**VERIFICADO** ✅: el CPU arranca de la flash externa y configura el Sobel (cpu_wrote_filter=1) en ~203 ciclos.
```bash
iverilog -g2012 -o tb.out test/tb_flash.v src/soc_sobel_flash_top.v src/MappedSPIFlash.v \
    src/femtorv32_quark.v src/peripheral_filter.v src/linebuf3x3.v \
    /path/to/cores/sim_spi_flash/spiflash.v
vvp tb.out +firmware=fw_sobel_flash.hex     # imprime "BOOT OK ..."
```
`fw_sobel_flash.hex` = las 7 instrucciones del firmware (mismo que la ROM interna), en bytes little-endian.
