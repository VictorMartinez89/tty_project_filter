# Canny 1-salto → ASIC (sky130A, OpenLane 1)

Entregable de silicio del **Canny 1-salto (streaming)**: la misma RTL validada en la FPGA iCE40UP5K,
llevada a **layout GDSII** en sky130A con OpenLane 1. Fase 2 del roadmap ASIC (Parte 87 del notebook).

## `src/` — lo que entra al flujo
| Archivo | Qué es |
|---|---|
| `canny1_top.v` | Top autocontenido: Gaussian 3×3 → Sobel 3×3 → doble umbral (clase 0/1/2) → histéresis 1-salto. |
| `linebuf3x3.v` | Line-buffers de la ventana 3×3 (se usan **3** en cascada; en ASIC → lógica). |
| `config.json` | Config OpenLane 1: `clk` 20 ns (50 MHz), `FP_CORE_UTIL` 35, `PL_TARGET_DENSITY` 0.45. |

## `results/` — los planos firmados
| Plano | Qué es |
|---|---|
| `canny1_top.gds` | **GDSII** — el layout físico (máscaras). |
| `canny1_top.def` | Posiciones de celdas + ruteo (DEF). |
| `canny1_top.lef` | *Abstract* del bloque (pines/contornos). |
| `canny1_top.mag` | Vista de Magic. |
| `canny1_top.nl.v` | Netlist gate-level (post-P&R). |
| `canny1_top.drc.rpt` | **DRC: COUNT = 0** (fabricable). |
| `canny1_top.lvs.rpt` | **LVS: Total errors = 0** (layout == netlist). |

> Los `.spef` (parásitos) y `.v` con potencia no se versionan aquí (se regeneran con el flujo).

## Resultado (run1)
- Die **583.28 × 582.08 µm** = 0.360 mm² · core 0.34 mm² · util 35.9 %
- **10 284 celdas** `sky130_fd_sc_hd` (≈2.2× el Sobel, por los 3 line-buffers)
- camino crítico **8.52 ns** (obj. 20 ns) · WNS/TNS = 0
- **DRC = 0**, **LVS = 0**, XOR Magic↔KLayout = 0 · flujo en 7 min 24 s

## Interfaz (pines)
`clk`, `reset`, `in_valid`, `in_pix[7:0]`, **`thr_hi[7:0]`**, **`thr_lo[7:0]`** (doble umbral),
`out_valid`, `out_pix[7:0]`, `VPWR`, `VGND`.

## Cómo reproducir
```bash
cd ~/Documents/UN/OpenLane
cp -r <este_repo>/asic/canny1_top designs/canny1     # config.json + src/
make mount
export PDK_ROOT=/home/vic/.ciel
./flow.tcl -design canny1 -tag run1 -overwrite -ignore_mismatches
```

Documentado en el notebook `conda/TTY_Filter_Sobel/TTY_Filter_Sobel.ipynb`, Partes 93–95.
