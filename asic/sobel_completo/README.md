# Cadena de visión completa (Sobel, sin CPU) → ASIC (sky130A, OpenLane 1)

`sobel_completo`: **la cadena de visión entera en un chip**, ensamblada con los módulos reusables ya
verificados — cámara OV7670 → **cam_frontend** (SCCB + captura + CDC 2-FF + RGB565→gris, fase 7) →
**sobel_top** (Sobel 3×3, umbral 90, fase 1) → **framebuffer 60×80** → **lcd_ili9341** (SPI + ROM ILI9341,
fase 8) → PMOD TFTLCD. Serie "pieza a pieza": #1 de 6 (los 3 filtros × {sin CPU, con SoC}).

## `src/`
| Archivo | Qué es |
|---|---|
| `sobel_completo.v` | Top: instancia las piezas + framebuffer + generador de dirección de lectura (escala 240×320 → 60×80). |
| `cam_frontend_top.v` + `ov7670_sccb/capture.v` + `rgb565_to_gray.v` | Front-end de cámara (fase 7). |
| `sobel_top.v` + `linebuf3x3.v` | Filtro Sobel (fase 1). |
| `lcd_ili9341_top.v` | Driver del LCD (fase 8). |
| `config.json` | `CLOCK_PORT` `clk` (**un solo reloj**); util 18, dens 0.25, `GRT_ALLOW_CONGESTION` 1. |

## Detalles ASIC
- **Un solo reloj**: el front-end sincroniza `PCLK/HREF/VSYNC` con 2-FF internos → no hay dual-clock (no
  vuelve el `STA-0408`); el SDC es el automático.
- **Framebuffer binario** (bordes 0x00/0xFF) → yosys lo colapsa a ~1 bit/píxel (~4 800 FF).
- **Nota honesta**: para geometría perfecta de imagen el front-end necesitaría un submuestreo a 60×80 (o la
  cámara en esa resolución). Esto ensambla la **cadena modular** y es un GDS válido y firmado; el ajuste de
  resolución es funcional, no del silicio.

## Cómo reproducir
```bash
cd ~/Documents/UN/OpenLane
mkdir -p designs/sobel_completo && cp -r <este_repo>/asic/sobel_completo/src/* designs/sobel_completo/
# (o copiar config.json a designs/sobel_completo/ y src/*.v a designs/sobel_completo/src/)
make mount
export PDK_ROOT=/home/vic/.ciel
./flow.tcl -design sobel_completo -tag run1 -overwrite -ignore_mismatches
```

Documentado en el notebook `conda/TTY_Filter_Sobel/TTY_Filter_Sobel.ipynb`, Parte 157.
