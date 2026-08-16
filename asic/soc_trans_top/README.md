# SoC Femto + transitivo → ASIC (sky130A, OpenLane 1) — el jefe final

SoC de visión: **FemtoRV32 (RV32I) + ROM de programa + periférico + motor de histéresis TRANSITIVA**
(reconstrucción morfológica de Canny), en silicio sky130. **Fase 6** del roadmap ASIC — el **sexto y
último** diseño, y el más grande de la tesis. Un procesador RISC-V junto a un framebuffer de ~10 600
flip-flops.

## Por qué es el más difícil
Sobel y Canny1 son puro streaming (píxel entra → píxel sale). El transitivo necesita **ver el frame
entero** y barrerlo en bucle hasta el punto fijo (un borde débil sobrevive si toca, transitivamente,
uno fuerte). Eso obliga a un **framebuffer** padded 62×82×2 bits que en la iCE40 iba en SPRAM y en el
ASIC **se vuelve ~10 600 flip-flops**, más una FSM `CLR → LOAD → SWEEP → CHK → READ → DONE`.

## `src/` — lo que entra al flujo
| Archivo | Qué es |
|---|---|
| `soc_trans_top.v` | Top: CPU + **ROM (7 instr, sintetizada)** + periférico + `trans_engine_top`. Stream de **clase** externo. |
| `trans_engine_top.v` + `hysteresis_frame_bram_sync.sv` | El motor transitivo (framebuffer → ~10 600 FF, FSM). |
| `femtorv32_quark.v`, `peripheral_filter.v` | El CPU FemtoRV32 + los registros del filtro. |
| `config.json` | **`FP_CORE_UTIL` 18, `PL_TARGET_DENSITY` 0.25, `GRT_ALLOW_CONGESTION` 1** (receta anti-congestión). |

### El firmware (decodificado)
```
lui  x1, 0x450        # base periférico 0x0045_0000
addi x2, x0, 18       # 0x12 -> mode=transitivo(2) + enable
sw   x2, 0(x1)        # CTRL <- 0x12
lui  x3, 0x7          # x3 = 0x7000
addi x3, x3, -442     # x3 = 0x6E46
sw   x3, 4(x1)        # THR  <- 0x6E46 -> thr_hi=110, thr_lo=70
jal  x0, 0            # loop
```
> El mismo CPU + un tercer firmware → el tercer filtro. El periférico ve `eng_busy = ~done` para que el
> CPU pudiera sondear el fin del barrido.

## `results/` — solo lo pequeño (planos grandes en carpeta aparte)
`soc_trans_top.lef` + `metrics.csv` (evidencia de signoff: `lvs_total_errors=0`, `Magic_violations=0`).

> 📁 **Planos grandes fuera de git** (por peso): `.gds` (195 MB), `.mag` (182 MB), `.def` (92 MB),
> `.nl.v` (22 MB) viven en **`~/ASIC_planos/soc_trans/`** (y en la share). Los `.sdf`/`.spef`
> multicorner (~678 MB, timing regenerable) NO se archivan. Se regeneran con el flujo. Fotos en el
> notebook (Parte 109).

## Resultado (run1)
- Die **3.42 mm²** (core 3.35) · util 18.4 % · **72 337 celdas** (síntesis 58 618 + ~13 700 buffers de P&R)
- camino crítico **9.46 ns** (~106 MHz al corner típico) · **DRC = 0, LVS = 0, XOR = 0**
- setup/hold sin violaciones al corner típico; avisos max-slew / max-fanout (por el fan-out del framebuffer)
- wire **6.56 m** · 538 976 vías · flujo **1 h 06 m** (ruteo 40 m 40 s)
- **Costo CPU + integración:** +19 383 celdas sobre el transitivo solo (52 954). La memoria no es gratis:
  el framebuffer crea redes de altísimo fan-out → la herramienta metió ~13 700 buffers.

## Interfaz (pines)
`clk`, `resetn` (0=reset), `in_valid`, `class_in[1:0]`, `load_ready`, `out_valid`, `edge_out`, `done`,
`cpu_wrote_filter`, `thr_hi_o[7:0]`, `thr_lo_o[7:0]`, `mode_o[1:0]`, `VPWR`, `VGND`.

## Cómo reproducir
```bash
cd ~/Documents/UN/OpenLane
cp -r <este_repo>/asic/soc_trans_top designs/soc_trans
make mount
export PDK_ROOT=/home/vic/.ciel
./flow.tcl -design soc_trans -tag run1 -overwrite -ignore_mismatches
```

Documentado en el notebook `conda/TTY_Filter_Sobel/TTY_Filter_Sobel.ipynb`, Partes 107–109.
