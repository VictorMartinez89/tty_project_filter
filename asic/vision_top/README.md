# Top integrado "el chip que ve y muestra" → ASIC (sky130A, OpenLane 1)

`vision_top`: el **sistema de visión completo en un solo die** — cámara OV7670 → SCCB config →
submuestreo 60×80 → **Sobel 3×3** → framebuffer → display **ILI9341** (SPI). **Fase 9** del roadmap ASIC,
el camino **(A) todo-ASIC**. Portado del diseño físico verificado en FPGA (`cam_sobel_display.v`).

## Dual-clock
| Dominio | Qué corre |
|---|---|
| `clk` (sistema) | maestro SCCB + display ILI9341 (SPI + FSM). |
| `cam_pclk` (cámara) | captura + submuestreo 60×80 + Sobel 3×3 → escribe el framebuffer. |

El **framebuffer** (60×80 × 8 bits = **4 800 bytes → ~38 400 flip-flops**) puentea los dos relojes:
escritura en `cam_pclk`, lectura en `clk`. Es la memoria grande del chip (domina el tamaño, como el
transitivo).

## 3 cambios para el ASIC
1. **`rst_n` explícito** en los FSM de control (los FF arrancan aleatorios en silicio; lección #2).
2. **`cam_sda` inout `1'bz` → `cam_sda_o` / `cam_sda_oe`** (tri-state open-drain al pad ring).
3. **quitado `SB_RGBA_DRV`** (primitiva de LEDs iCE40, no existe en sky130).
> El framebuffer **no** se resetea (se llena antes de leerse) — misma decisión que el motor transitivo.

## `src/`
| Archivo | Qué es |
|---|---|
| `vision_top.v` | Top integrado (SCCB + captura/Sobel + framebuffer + display), dual-clock. |
| `config.json` | `CLOCK_PORT` = `clk cam_pclk`; `FP_CORE_UTIL` 18, `PL_TARGET_DENSITY` 0.25, `GRT_ALLOW_CONGESTION` 1. |

## Interfaz (pines)
`clk`, `rst_n`, `cam_pclk`, `cam_href`, `cam_d[7:0]` (in) · `cam_xclk`, `cam_scl`, `cam_sda_o`,
`cam_sda_oe`, `tft_sck`, `tft_mosi`, `tft_cs`, `tft_dc`, `cfg_done` (out) · `VPWR`, `VGND`.

## El pad ring (capa física final)
Lo que sale del flujo es el **core** (macro de celdas estándar, 1.8 V). El chip físico final necesita
además el **anillo de I/O** (pads 3.3 V + level shifters + ESD) que usa la librería `sky130_fd_io` y un
flujo de integración de chip aparte — ver Parte 114 del notebook.

## Cómo reproducir
```bash
cd ~/Documents/UN/OpenLane
cp -r <este_repo>/asic/vision_top designs/vision_top
make mount
export PDK_ROOT=/home/vic/.ciel
./flow.tcl -design vision_top -tag run1 -overwrite -ignore_mismatches
```

Documentado en el notebook `conda/TTY_Filter_Sobel/TTY_Filter_Sobel.ipynb`, Partes 121 (proyecto), 122
(código de cámara+LCD) y 123 (ficha, tras la corrida). Sistema completo también en la Parte 114.

> **Nota:** resultados (die/celdas/signoff) se añaden aquí tras completar la corrida de OpenLane.
