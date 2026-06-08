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

## Canny N×N en Verilog (nuevo)

| Archivo | Qué hace |
|---|---|
| `sobel_grad_core.sv` | Gradiente 3×3 → `|Gx|+|Gy|` (barato) y `√(Gx²+Gy²)` (exacto, usa cuadrados). |
| `canny_datapath.sv` | Ventana 3×3 **ya suavizada** → magnitud → doble umbral + `√(G_low+G_high)`. |
| `canny_top_3x3.sv` / `_5x5` / `_7x7` | **Canny N×N combinacional**: ventana `(K+2)×(K+2)` → 9× `gaussianK` (suaviza la vecindad 3×3) → `canny_datapath`. |
| `tb_canny_top.sv` | Testbench de `canny_top_3x3` vs golden Python → **ALL TESTS PASSED**. |

Síntesis (yosys): `canny_top_3x3` ≈ 8350 celdas, `canny_top_7x7` ≈ 66733 (9× gaussian7x7).
Cambiar de 3×3 a 5×5/7×7 = cambiar el `gaussianK` del front-end. **NMS + histéresis siguen siendo trabajo futuro** (no son por-pixel).

## Canny en STREAMING — NMS + histéresis (nuevo) ⭐

| Archivo | Qué hace |
|---|---|
| `canny_full_core.sv` | Canny COMPLETO por pixel, **combinacional**, sobre una ventana **7×7** de gris: gradiente (5×5) → cuadrante del ángulo (fixed-point 106/618, sin atan2) → **NMS** (3×3) → doble umbral → **histéresis 1-salto** (débil = borde si algún vecino es fuerte). Salidas `edge_o` + `class_o`. |
| `canny_control.sv` | **Streaming**: ventana deslizante 7×7 (6 line buffers) que alimenta `canny_full_core`; entrega `edge_o`/`class_o` en pixeles interiores (borde de 3 px). |
| `tb_canny_control.sv` | TB iverilog (imagen rampa+escalón 14×14) vs golden Python → **ALL TESTS PASSED** (64/64; clases none=16, weak=32, strong=16). |
| `cocotb/test_canny.py` + `Makefile.canny` | Mismo test en cocotb → edge 64/64, class 64/64 (100%). |

**¿Por qué ventana 7×7?**  `edge ← histéresis(3×3 de class) ← NMS(3×3 de mag) ← gradiente(3×3 de gris)` = 3+2+2 = 7. Así todo es combinacional con **un solo** windower, sin encadenar 3 ventanas en streaming.

### ⚠️ Honestidad: histéresis 1-salto vs completa
La histéresis aquí es **1-salto** (un débil se conserva si toca un fuerte en su 3×3). La histéresis de Canny **transitiva** (cadenas largas de débiles que llegan a un fuerte) requiere propagación iterativa / multi-pasada sobre el frame (o union-find). El 1-salto es la aproximación **streamable** estándar en hardware de tiempo real; captura la mayoría de los casos. La pasada transitiva completa queda como extensión (control iterativo + frame buffer).
