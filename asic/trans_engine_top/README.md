# Motor Canny transitivo → ASIC (sky130A, OpenLane 1)

Entregable de silicio del **motor de histéresis transitiva** (reconstrucción morfológica de Canny): el
núcleo que hace crecer los bordes débiles conectados —transitivamente— a un borde fuerte, barriendo el
cuadro hasta el punto fijo. Fase 5 del roadmap ASIC. **El diseño más grande de la tesis.**

## `src/` — lo que entra al flujo
| Archivo | Qué es |
|---|---|
| `trans_engine_top.v` | Top autocontenido: envuelve el motor a 60×80. |
| `hysteresis_frame_bram_sync.sv` | El motor: FSM CLR→LOAD→SWEEP→CHK→READ→DONE + framebuffer (padded 62×82 × 2 bits). |
| `config.json` | Config OpenLane 1 **que cerró**: `FP_CORE_UTIL` **18**, `PL_TARGET_DENSITY` **0.25**, `GRT_ALLOW_CONGESTION` 1. |

## `results/` — solo lo pequeño (los planos grandes NO caben en git)
| Archivo | Qué es |
|---|---|
| `trans_engine_top.lef` | *Abstract* del bloque. |
| `trans_engine_top.mag` | Vista de Magic. |
| `trans_engine_top.drc.rpt` | **DRC: COUNT = 0** (fabricable). |
| `trans_engine_top.lvs.rpt` | **LVS: Total errors = 0** (layout == netlist). |

> ⚠️ **Planos grandes fuera de git:** el `.gds` (**190 MB**, supera el límite de 100 MB de GitHub), el
> `.def` (88 MB) y el `.nl.v` (20 MB) **no se versionan** aquí. Viven en la share
> (`utm-share/asic_trans/results/`) y se **regeneran** corriendo el flujo. Las fotos del layout están en
> el notebook (Parte 99).

## Resultado (run1, tras resolver la congestión — Parte 97)
- Die **3.13 mm²** (core 3.07) · util 18.4 % · ~**19×** el Sobel, ~**8.7×** el Canny1
- **52 954 celdas** (~10 600 flip-flops del framebuffer + ~42 000 de lógica de acceso)
- camino crítico **12.3 ns** (obj. 20 ns) · WNS/TNS = 0 · **DRC = 0**, **LVS = 0**, XOR = 0
- wire length **6.98 m** · **523 268 vías** · flujo **1 h 7 min 33 s**

## Interfaz (pines) — es un **motor**, no un filtro-stream
`clk`, `nreset` (reset asíncrono activo-bajo), `in_valid`, `class_in[1:0]` (0=nada/1=débil/2=fuerte),
`load_ready`, `out_valid`, `edge_out`, `done`, `VPWR`, `VGND`.

## Cómo reproducir
```bash
cd ~/Documents/UN/OpenLane
cp -r <este_repo>/asic/trans_engine_top designs/trans     # config.json + src/
make mount
export PDK_ROOT=/home/vic/.ciel
./flow.tcl -design trans -tag run1 -overwrite -ignore_mismatches
```

Documentado en el notebook `conda/TTY_Filter_Sobel/TTY_Filter_Sobel.ipynb`, Partes 96–99.
