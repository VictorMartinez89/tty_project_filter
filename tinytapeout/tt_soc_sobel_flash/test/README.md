# Test — tt_um_soc_sobel_flash_vic

El boot desde flash requiere el modelo de flash + un firmware .hex. Para simular:
```bash
iverilog -g2012 -o tb.out test/tb_flash.v src/*.v \
   /Users/vic/UN/Tesis/Repository/tty_project_filter/cores/sim_spi_flash/spiflash.v
vvp tb.out
```
(El .hex del firmware Sobel-config debe cargarse en el modelo de flash — paso iterativo por verificar.)
