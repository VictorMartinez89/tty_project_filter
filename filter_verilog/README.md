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

## Integración al SoC RISC-V — peripheral en 0x0045 ⭐

| Archivo | Qué hace |
|---|---|
| `peripheral_sobel.v` | Wrapper memory-mapped (contrato femto: cs/addr/rd/wr/d_in/d_out). Envuelve `sobel_compass_control` **y** `canny_control` con **bit de modo**; **IMG_W/low/high escribibles**; modelo **pixel-a-pixel (polling)** con latch de resultado + `result_ready`. |
| `cocotb/test_peripheral.py` (`Makefile.peri`) | Maneja el bus como el CPU (escribe CTRL/IMGW/LOW/HIGH, feed pixel-a-pixel, poll STATUS, lee RESULT) y valida **ambos modos** → COMPASS 36/36 y CANNY 64/64 (100%). |
| `../firmware/sobel.h` | Driver C: `sobel_init(mode,w,low,high)` + `sobel_run_frame()` + macros de decodificación. |

**Mapa de registros (0x0045):** `0x00` CTRL (mode/frame_reset) · `0x04` IMGW · `0x08` LOW · `0x0C` HIGH · `0x10` PIXEL (W) · `0x14` STATUS (R, bit0=ready) · `0x18` RESULT (R).

**Ediciones en el SoC** (`SOC_flash.v` y el top de síntesis `OpenLane/src/femto.v`): se ensanchó `cs` a 8 bits, se añadió el decode `16'h0045`, la instancia `peripheral_sobel sobel1 (.cs(cs[7])...)` y la línea del read-MUX. El SoC integrado **elabora** (los únicos errores de elaboración son del core `femtorv32_quark.v`, ajenos al filtro y propios del flujo de build del CPU).

**Los controladores `sobel_compass_control` / `canny_control`** ahora toman `img_w_i` en **runtime** (line buffers dimensionados a `MAX_IMG_W`); sus testbenches (iverilog y cocotb) siguen pasando.

## (c) Histéresis TRANSITIVA completa + (b) DEMO en Verilog ⭐

| Archivo | Qué hace |
|---|---|
| `canny_hysteresis_frame.sv` | Histéresis **transitiva** real (no 1-salto): reconstrucción morfológica de `strong` bajo `weak`, por **propagación iterativa** sobre un frame (`confirmed |= weak & dilata8(confirmed)` hasta estabilizar). Necesita frame buffer (BRAM en HW real). |
| `cocotb/test_hysteresis.py` (`Makefile.hyst`) | Valida vs golden Python (scipy.label 8-conexo): **5/5 OK**; converge en ~7–10 pasadas para 16×16. |
| `tb_demo.sv` | **DEMO en Verilog**: emula al CPU manejando `peripheral_sobel` por el bus (CTRL/IMGW/LOW/HIGH, feed pixel-a-pixel, poll STATUS, lee RESULT) y dibuja los bordes en ASCII. Modo Canny sobre un cuadrado → detecta el contorno. Corre con iverilog/vvp. |

Salida de la demo (Canny sobre un cuadrado 16×16, interior 10×10):
```
#.######.#
.########.
##......##
##......##
##......##
##......##
##......##
##......##
.########.
#.######.#
```

### Histéresis: 1-salto (canny_control) vs transitiva (canny_hysteresis_frame)
- **1-salto** (`canny_control.sv`): por-ventana, **streamable**, ~99.7% del resultado completo. Para tiempo real.
- **Transitiva** (`canny_hysteresis_frame.sv`): exacta, pero **frame-buffered + iterativa** (varias pasadas). Para cuando se necesita el resultado de Canny 100% fiel.
