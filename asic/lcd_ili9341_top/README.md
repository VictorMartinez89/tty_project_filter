# Driver del PMOD TFTLCD (ILI9341, SPI) → ASIC (sky130A, OpenLane 1)

El otro extremo de la cadena de visión: `lcd_ili9341_top` toma un **stream de píxeles en gris** (del
filtro) y lo pinta en el **PMOD TFTLCD (ILI9341)** por **SPI**. **Fase 8** del roadmap ASIC — el octavo
chip, gemelo del front-end de cámara (fase 7) y el más rápido de todos.

## `src/` — lo que entra al flujo
| Archivo | Qué es |
|---|---|
| `lcd_ili9341_top.v` | Shifter SPI (modo 0) + ROM de comandos ILI9341 (INIT + FRAME) + FSM `BOOT→INIT→FRAME→FILL`. |
| `config.json` | OpenLane 1: `FP_CORE_UTIL` 40, `PL_TARGET_DENSITY` 0.55, clk 20 ns. |

### Dos decisiones ASIC (para la tesis)
- **Sin framebuffer interno:** los píxeles vienen de afuera (del filtro) con handshake `pix_gray`/`pix_next`.
  El original (`cam_femto_display.v`) leía de un framebuffer propio; aquí la memoria se queda **fuera** →
  el driver es "pegamento" barato (control puro).
- **Reset explícito (`rst_n`):** el original usaba valores `initial` (válidos en FPGA por el bitstream,
  **no** en ASIC — los flip-flops arrancan aleatorios). Todo el estado se inicializa con `rst_n`. (Lección
  #2 del capítulo ASIC.)

Reusa el shifter SPI + la ROM de comandos (init: SW-reset `0x01`, sleep-out `0x11`, pixel-format `0x3A`=
RGB565, MADCTL `0x36`, display-ON `0x29`; frame: CASET `0x2A`, RASET `0x2B`, RAMWR `0x2C`) del driver
verificado en FPGA. Conversión gris→RGB565 en grises: `{g[7:3], g[7:2], g[7:3]}`.

## Resultado (run1)
- Die **0.0174 mm²** (core 0.0132) — empatado con el front-end como el más pequeño de los 8 chips
- **553 celdas** (síntesis 461) · util 42.3 %
- **Power típico 0.79 mW** · camino crítico **1.61 ns (~621 MHz, el más rápido)** · WNS/TNS = 0
- **DRC = 0, LVS = 0, XOR = 0** · flujo **1 min 30 s** · sólo aviso max-fanout (cosmético)

## Interfaz (pines)
`clk`, `rst_n`, `pix_gray[7:0]` (in) · `pix_next`, `frame_start`, `init_done`, `tft_sck`, `tft_mosi`,
`tft_cs`, `tft_dc` (out) · `VPWR`, `VGND`.

## Cómo reproducir
```bash
cd ~/Documents/UN/OpenLane
cp -r <este_repo>/asic/lcd_ili9341_top designs/lcd_ili9341
make mount
export PDK_ROOT=/home/vic/.ciel
./flow.tcl -design lcd_ili9341 -tag run1 -overwrite -ignore_mismatches
```

Documentado en el notebook `conda/TTY_Filter_Sobel/TTY_Filter_Sobel.ipynb`, Partes 118 (proyecto) y 119
(ficha). El sistema completo cámara→core→TFTLCD está en la Parte 114.
