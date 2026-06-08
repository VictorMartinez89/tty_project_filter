# Filtros en Verilog — tesis (Victor) sobre el diseño de Diana

Hardware (SystemVerilog) de los filtros del notebook `conda/TTY_Filter_Sobel`, en el
**estilo de Diana** (`tt06_grayscale_sobel/src`): **100 % combinacional, sin
multiplicadores ni divisores** — los coeficientes `{-2,-1,0,1,2}` se hacen con `+`, `-`
y `<<` (×2), y las divisiones por potencia de 2 con `>>`.

Todo está **simulado (iverilog) y sintetizado (yosys)**: ver `tb_filters.sv` → *ALL TESTS PASSED*.

## Módulos

| Archivo | Qué hace |
|---|---|
| `sobel_compass_core.sv` | **8 filtros Sobel direccionales** (compass): N, NE, E, SE, S, SW, W, NW. Salida: las 8 magnitudes `\|conv\|`, la dirección ganadora (`dir_o`, argmax) y su magnitud. |
| `gaussian_core.sv` | Suavizado **Gaussiano 3×3 / 5×5 / 7×7** (front-end de Canny). Kernels binomiales (Pascal) con suma potencia de 2 → la división es puro `>>` (`>>4`, `>>8`, `>>12`). |
| `canny_grad_threshold_core.sv` | Datapath de Canny por pixel: **doble umbral** (`G_low`, `G_high`), clasificación (nada/débil/fuerte) y tu combinación **`√(G_low+G_high)`**. |
| `isqrt.sv` | Raíz cuadrada **entera** combinacional (para `√`, sin multiplicador). |
| `tb_filters.sv` | Testbench: verifica compass, Gaussiano, isqrt y Canny contra valores esperados. |

## Sobel compass — las 8 direcciones (`sobel_compass_core.sv`)
Cada dirección es una rotación de 45° del kernel Sobel. Ejemplo, Norte:
```
N = [ 1  2  1 / 0 0 0 / -1 -2 -1]  ->  gN = (p0 + (p1<<1) + p2) - (p6 + (p7<<1) + p8)
```
Nota (tesis): la máscara de una dirección es el **negativo** de su opuesta
(`S = -N`, `W = -E`, …), así que `|conv|` coincide en pares; la dirección real está
en el **signo**. Por eso además del `mag_o` se entrega `dir_o` (argmax).

## Canny NxN — cómo se arma
Canny = Gaussiano **N×N** → gradiente (Sobel `sobel_core`) → doble umbral → (NMS + histéresis).
Las variantes que pediste se forman cambiando solo el front-end Gaussiano:

| Variante | Cadena de módulos |
|---|---|
| **Canny 3×3** | `gaussian3x3` → `sobel_core` → `canny_grad_threshold_core` |
| **Canny 5×5** | `gaussian5x5` → `sobel_core` → `canny_grad_threshold_core` |
| **Canny 7×7** | `gaussian7x7` → `sobel_core` → `canny_grad_threshold_core` |
| **+ `√(G_low+G_high)`** | salida `combo_o` de `canny_grad_threshold_core` (usa `isqrt`) |

## ⚠️ Límite honesto (trabajo futuro de la tesis)
La **supresión de no-máximos** y la **histéresis** de Canny **no** son por-pixel: necesitan
vecindario orientado + conectividad sobre **todo el frame** (buffers de línea / 2 pasadas).
Eso es un módulo de **control + memoria** aparte (tipo `sobel_control`), no una etapa
combinacional. Aquí queda el **datapath** completo y validado; el control de histéresis
es el siguiente paso. Por eso el chip de Diana implementa **Sobel** (combinacional, barato),
no Canny.

> "4 imágenes" / "1000 muestras" son conceptos del **dataset/testbench** (qué frames se
> inyectan), no del RTL: el hardware procesa un stream de pixeles, una ventana a la vez.

## Cómo correr
```bash
# simulación funcional
iverilog -g2012 -o sim.out tb_filters.sv sobel_compass_core.sv gaussian_core.sv \
         isqrt.sv canny_grad_threshold_core.sv
vvp sim.out                       # -> ALL TESTS PASSED

# síntesis (área / sintetizable)
yosys -p "read_verilog -sv sobel_compass_core.sv; synth; stat"
```
Resultado de síntesis (genérico, yosys): `sobel_compass_core` ≈ 2203 compuertas,
**0 multiplicadores** — coherente con el presupuesto de área de un TinyTapeout.
