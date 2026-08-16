# SoC Femto + Canny1 → ASIC (sky130A, OpenLane 1)

SoC de visión: **FemtoRV32 (RV32I) + ROM de programa + periférico + datapath Canny 1-salto**, en silicio sky130.
El CPU corre un firmware que elige **Canny1** y fija **los dos umbrales** (thr_hi=90, thr_lo=40); el datapath usa
esos umbrales. **Fase 4** del roadmap ASIC — el segundo diseño con un procesador adentro, ahora con el pipeline
Canny completo (Gaussian → Sobel → doble umbral → histéresis 1-salto).

## `src/` — lo que entra al flujo
| Archivo | Qué es |
|---|---|
| `soc_canny1_top.v` | Top: CPU + **ROM (7 instrucciones, sintetizada)** + periférico + datapath Canny1. Stream externo `in_pix`. |
| `femtorv32_quark.v` | El CPU FemtoRV32 (RV32I, Bruno Levy). |
| `peripheral_filter.v` | Registros del filtro (mode/thr_hi/thr_lo) que escribe el CPU. |
| `linebuf3x3.v` | Line-buffer de la ventana 3×3 (se instancia 3×: Gaussian, Sobel, clase). |
| `config.json` | Config OpenLane 1: `FP_CORE_UTIL` 30, `PL_TARGET_DENSITY` 0.40, clk 20 ns. |

> **Clave ASIC:** el firmware va en **ROM sintetizada** (permanente), no en RAM init'd — en silicio los
> flip-flops arrancan aleatorios. El firmware no usa RAM de datos → no hace falta RAM writable.

### El firmware (decodificado)
```
lui  x1, 0x450        # x1 = base periférico 0x0045_0000
addi x2, x0, 17       # x2 = 0x11  -> mode=Canny1(1) + enable
sw   x2, 0(x1)        # CTRL <- 0x11
lui  x3, 0x6          # x3 = 0x6000
addi x3, x3, -1496    # x3 = 0x5A28
sw   x3, 4(x1)        # THR  <- 0x5A28  -> thr_hi=90, thr_lo=40
jal  x0, 0            # loop
```
> Frente al SoC Sobel (un solo umbral), aquí el CPU empaqueta **dos** umbrales en `0x5A28`
> (`thr_hi` en [15:8], `thr_lo` en [7:0]) y los escribe de un `sw`. Mismo CPU, otro firmware → otro filtro.

## `results/` — solo lo pequeño (planos grandes en carpeta aparte)
`soc_canny1_top.lef` + `metrics.csv` (evidencia de signoff: `lvs_total_errors=0`, `Magic_violations=0`).

> 📁 **Planos grandes fuera de git** (por peso): `.gds` (47 MB), `.def` (20 MB), `.mag` (41 MB),
> `.nl.v` (4.8 MB) viven en la carpeta local **`~/ASIC_planos/soc_canny1/`** (y en la share).
> Se regeneran con el flujo. Fotos del layout en el notebook (Parte 106).

## Resultado (run1)
- Die **0.67 mm²** (core 0.641) · util 30.8 % · **22 054 celdas** (síntesis 17 916 + buffers de P&R)
- camino crítico **9.47 ns** (obj. 20 ns) · WNS/TNS = 0 (~106 MHz) · **DRC = 0, LVS = 0, XOR = 0**
- wire 721 mm · 139 564 vías · flujo 13 min 19 s (ruteo 9 m 32 s)
- **Hallazgo:** integrar CPU + Canny costó **~6 500 celdas más** que la predicción ingenua (10 284 + 5 255 ≈ 15 500):
  a densidad suelta (util 30), la herramienta añade buffers para cerrar timing. Integrar no es una suma.

## Interfaz (pines)
`clk`, `resetn` (0=reset), `in_valid`, `in_pix[7:0]`, `out_valid`, `out_pix[7:0]`, `cpu_wrote_filter`,
`thr_hi_o[7:0]`, `thr_lo_o[7:0]` (los dos umbrales que fijó el CPU), `VPWR`, `VGND`.

## Cómo reproducir
```bash
cd ~/Documents/UN/OpenLane
cp -r <este_repo>/asic/soc_canny1_top designs/soc_canny1
make mount
export PDK_ROOT=/home/vic/.ciel
./flow.tcl -design soc_canny1 -tag run1 -overwrite -ignore_mismatches
```

Documentado en el notebook `conda/TTY_Filter_Sobel/TTY_Filter_Sobel.ipynb`, Partes 104–106.
