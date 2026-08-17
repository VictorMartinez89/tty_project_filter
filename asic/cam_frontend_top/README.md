# Front-end de cámara OV7670 → ASIC (sky130A, OpenLane 1)

El **pegamento** que conecta la cámara OV7670 con los filtros: `cam_frontend_top` traduce las señales
crudas de la cámara en un **stream de gris** (`gray`/`gray_valid`) listo para cualquiera de los 6 cores.
**Fase 7** del roadmap ASIC — el séptimo chip, y el más pequeño de todos.

## `src/` — lo que entra al flujo
| Archivo | Qué es |
|---|---|
| `cam_frontend_top.v` | Top: une SCCB + captura + RGB565→gris. |
| `ov7670_sccb.v` | Maestro **SCCB** (config de la cámara al arranque). **Adaptado a ASIC**: la salida open-drain `SIOD` se parte en `siod_o` (dato) + `siod_oe` (enable) — el tri-state vive en el pad ring, no en el core. |
| `ov7670_capture.v` | Genera `XCLK`, sincroniza `PCLK`/`HREF`/`VSYNC` (2-FF = **CDC**), arma el píxel RGB565. Original verificado en FPGA. |
| `rgb565_to_gray.v` | RGB565 → gris 8 bits, `Y=(R+2G+B)>>2`. Original verificado. |
| `config.json` | OpenLane 1: `FP_CORE_UTIL` 40, `PL_TARGET_DENSITY` 0.55, clk 20 ns. |

> **Decisión ASIC (para la tesis):** el SCCB en FPGA usaba `SIOD = 1'bz` (tri-state interno). En un core
> ASIC eso no va adentro → se parte en **dato + output-enable**; el pad open-drain del anillo de I/O hace
> `pad = oe ? o : Z` (pull-up externo → 1). Ver Parte 114/116 del notebook.

## Resultado (run1)
- Die **0.0177 mm²** (116.4 × 114.2 µm) — **el más pequeño de los 7 chips**
- **562 celdas** (síntesis 448) · util 42.7 %
- **Power típico 0.77 mW** (el más bajo) · camino crítico **3.2 ns (~312 MHz)** · WNS/TNS = 0
- **DRC = 0, LVS = 0, XOR = 0** · flujo **1 min 12 s** · sólo aviso max-fanout (cosmético)

## Interfaz (pines)
`sysclk`, `rst_n`, `cam_d[7:0]`, `cam_pclk`, `cam_href`, `cam_vsync` (in) ·
`cam_xclk`, `cam_sioc`, `cam_siod_o`, `cam_siod_oe`, `gray[7:0]`, `gray_valid`, `frame_start`,
`line_start`, `cfg_done` (out) · `VPWR`, `VGND`.

## Cómo reproducir
```bash
cd ~/Documents/UN/OpenLane
cp -r <este_repo>/asic/cam_frontend_top designs/cam_frontend
make mount
export PDK_ROOT=/home/vic/.ciel
./flow.tcl -design cam_frontend -tag run1 -overwrite -ignore_mismatches
```

Documentado en el notebook `conda/TTY_Filter_Sobel/TTY_Filter_Sobel.ipynb`, Parte 116 (y el sistema
completo cámara+core+TFTLCD en la Parte 114).
