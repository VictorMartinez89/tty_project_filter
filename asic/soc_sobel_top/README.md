# SoC Femto + Sobel → ASIC (sky130A, OpenLane 1)

SoC de visión: **FemtoRV32 (RV32I) + ROM de programa + periférico + datapath Sobel**, en silicio sky130.
El CPU corre un firmware que elige Sobel y fija el umbral (thr=90); el datapath usa ese umbral. Fase 3
del roadmap ASIC. **El primer diseño con un procesador adentro.**

## `src/` — lo que entra al flujo
| Archivo | Qué es |
|---|---|
| `soc_sobel_top.v` | Top: CPU + **ROM (7 instrucciones, sintetizada)** + periférico + Sobel. Stream externo `in_pix`. |
| `femtorv32_quark.v` | El CPU FemtoRV32 (RV32I, Bruno Levy). |
| `peripheral_filter.v` | Registros del filtro (mode/thr) que escribe el CPU. |
| `linebuf3x3.v` | Line-buffer de la ventana 3×3. |
| `config.json` | Config OpenLane 1: `FP_CORE_UTIL` 30, `PL_TARGET_DENSITY` 0.40. |

> **Clave ASIC:** el firmware va en **ROM sintetizada** (permanente), no en RAM init'd — en silicio los
> flip-flops arrancan aleatorios. El firmware no usa RAM de datos → no hace falta RAM writable.

## `results/` — solo lo pequeño (planos grandes en carpeta aparte)
`soc_sobel_top.lef`, `.mag`, `.drc.rpt` (**COUNT=0**), `.lvs.rpt` (**0 errores**).

> 📁 **Planos grandes fuera de git** (por peso): `.gds` (27 MB), `.def` (12 MB), `.nl.v` (2.6 MB) viven en
> la carpeta local **`~/ASIC_planos/soc_sobel/`** (y en la share). Se regeneran con el flujo. Fotos del
> layout en el notebook (Parte 103).

## Resultado (run1)
- Die **0.37 mm²** (core 0.353) · util 30.8 % · **9 906 celdas**
- camino crítico **8.41 ns** (obj. 20 ns) · WNS/TNS = 0 (~119 MHz) · **DRC = 0, LVS = 0, XOR = 0**
- wire 384 mm · 76 376 vías · flujo 7 min 39 s
- **Costo del CPU:** ~5 255 celdas (~0.2 mm²) sobre el Sobel solo (4 651)

## Interfaz (pines)
`clk`, `resetn` (0=reset), `in_valid`, `in_pix[7:0]`, `out_valid`, `out_pix[7:0]`, `cpu_wrote_filter`,
`thr_o[7:0]` (el umbral que fijó el CPU), `VPWR`, `VGND`.

## Cómo reproducir
```bash
cd ~/Documents/UN/OpenLane
cp -r <este_repo>/asic/soc_sobel_top designs/soc_sobel
make mount
export PDK_ROOT=/home/vic/.ciel
./flow.tcl -design soc_sobel -tag run1 -overwrite -ignore_mismatches
```

Documentado en el notebook `conda/TTY_Filter_Sobel/TTY_Filter_Sobel.ipynb`, Partes 101–103.
