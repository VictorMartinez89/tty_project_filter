# Top integrado "chip que ve y muestra" con CANNY → ASIC (sky130A, OpenLane 1)

`vision_canny_top`: el sistema de visión completo en un die, con el **Canny 1-streaming** — cámara OV7670
→ SCCB → submuestreo 60×80 → **Gaussian → Sobel → doble umbral → histéresis 1-salto** → framebuffer →
display **ILI9341**. **Fase 10** del roadmap ASIC — la hermana de `vision_top` (fase 9, Sobel), con bordes
más limpios y conectados. Portado del físico verificado `cam_canny2_display.v`.

## Dual-clock
`clk` (sistema: SCCB + display) y `cam_pclk` (cámara: captura + Gaussian/Sobel/clase/histéresis + fb-write).
El **framebuffer** (60×80 × 8b) puentea los dos relojes; guarda bordes binarios (0x00/0xFF) → yosys lo
colapsa a ~1 bit/píxel, como en `vision_top`.

## 3 cambios para el ASIC (idénticos a `vision_top`)
1. **`rst_n` explícito** en los FSM de control (los FF arrancan aleatorios).
2. **`cam_sda` inout `1'bz` → `cam_sda_o` / `cam_sda_oe`** (tri-state al pad ring).
3. **quitado `SB_RGBA_DRV`**. El framebuffer no se resetea.

## `src/`
| Archivo | Qué es |
|---|---|
| `vision_canny_top.v` | Top integrado con el pipeline **Canny** (3 juegos de line-buffers: Gaussian, Sobel, clase). |
| `vision_canny.sdc` | Dos relojes asíncronos (`clk` 20 ns, `cam_pclk` 40 ns) — evita el `STA-0408`. |
| `config.json` | `CLOCK_PORT` `clk` + `BASE_SDC_FILE`/`SDC_FILE`; util 18, dens 0.25, `GRT_ALLOW_CONGESTION` 1. |

## Resultado (run1)
- Die **2.04 mm²** (floorplan 1411.74 × 1411.68 µm) · util 18.4 % · **41 925 celdas** (síntesis 32 799)
- camino crítico **10.89 ns** (~92 MHz, `clk`) · **DRC = 0, LVS = 0, XOR = 0** · sin setup/hold; aviso max-cap
- power típico **90.9 mW** · flujo **27 min 32 s**
- **vs `vision_top` (Sobel):** +0.29 mm², +6 272 celdas, +24 mW — el costo del datapath Canny (3 line-buffers
  vs 1) por **bordes más limpios y conectados**.

## Interfaz (pines)
`clk`, `rst_n`, `cam_pclk`, `cam_href`, `cam_d[7:0]` (in) · `cam_xclk`, `cam_scl`, `cam_sda_o`,
`cam_sda_oe`, `tft_sck`, `tft_mosi`, `tft_cs`, `tft_dc`, `cfg_done` (out) · `VPWR`, `VGND`.

## Cómo reproducir
```bash
cd ~/Documents/UN/OpenLane
cp -r <este_repo>/asic/vision_canny_top designs/vision_canny
make mount
export PDK_ROOT=/home/vic/.ciel
./flow.tcl -design vision_canny -tag run1 -overwrite -ignore_mismatches
```

Documentado en el notebook `conda/TTY_Filter_Sobel/TTY_Filter_Sobel.ipynb`, Partes 128 (proyecto+código),
129 (matriz de configuraciones) y 130 (comparación Sobel vs Canny como sistema completo).
