# Sobel → ASIC (sky130A, OpenLane 1)

Entregable de silicio del filtro Sobel de bordes: la **misma RTL** validada en la FPGA iCE40UP5K,
llevada a **layout GDSII** en el proceso **sky130A** con OpenLane 1 (*"misma RTL, dos destinos"*).

## `src/` — lo que entra al flujo
| Archivo | Qué es |
|---|---|
| `sobel_top.v` | Top autocontenido: ventana 3×3 → `Gx`/`Gy` → `\|Gx\|+\|Gy\|` (sat 255) → umbral → `out_pix`. |
| `linebuf3x3.v` | Line-buffers de la ventana 3×3 (en ASIC → lógica; *"la memoria ya no es gratis"*). |
| `config.json` | Config OpenLane 1: `clk` 20 ns (50 MHz), `FP_CORE_UTIL` 35, `PL_TARGET_DENSITY` 0.45. |

## `results/` — los planos firmados
| Plano | Qué es |
|---|---|
| `sobel_top.gds` | **GDSII** — el layout físico (máscaras). Se ve en KLayout/Magic. |
| `sobel_top.def` | Posiciones de celdas + ruteo (DEF). |
| `sobel_top.lef` | *Abstract* del bloque (pines/contornos) para reuso como macro. |
| `sobel_top.mag` | Vista de Magic. |
| `sobel_top.nl.v` | Netlist gate-level (post-P&R). |
| `sobel_top.drc.rpt` | **DRC: COUNT = 0** (cero violaciones → fabricable). |
| `sobel_top.lvs.rpt` | **LVS: Total errors = 0** (layout == netlist). |

> Los `.spef` (parásitos, ~15 MB) y `.v` con potencia **no** se versionan aquí (se regeneran con el flujo).

## Resultado (run1)
- Die **392.84 × 391.68 µm** = 0.167 mm² · core 0.154 mm² · util 36 %
- **4 651 celdas** `sky130_fd_sc_hd` · camino crítico **7.69 ns** (obj. 20 ns) · WNS/TNS = 0
- **DRC = 0**, **LVS = 0**, XOR Magic↔KLayout = 0 · flujo en 3 min 36 s

## Cómo reproducir
```bash
cd ~/Documents/UN/OpenLane
cp -r <este_repo>/asic/sobel_top designs/sobel   # config.json + src/
make mount
export PDK_ROOT=/home/vic/.ciel                  # PDK con libs.tech/openlane
./flow.tcl -design sobel -tag run1 -overwrite -ignore_mismatches
```

Documentado en el notebook `conda/TTY_Filter_Sobel/TTY_Filter_Sobel.ipynb`, Partes 87–92.
