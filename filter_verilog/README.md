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

## Versión FRAMEBUFFER / DMA — velocidad (rama dev01_install_conda_FrameBuffer) 🚀

| Archivo | Qué hace |
|---|---|
| `peripheral_sobel_fb.v` | Peripheral 0x0045 con **buffers internos** (in/out, BRAM en HW) y un **secuenciador (DMA-lite)**: el CPU carga la imagen (WRPIX) y dispara START; el frame se procesa **autónomo a ~1 pixel/ciclo** sin polling por pixel. Ambos filtros con bit de modo, IMG_W/low/high y NPX escribibles. |
| `cocotb/test_fb.py` (`Makefile.fb`) | Carga imagen → START → lee resultados. **FB COMPASS 36/36, FB CANNY 64/64 (100%)**. Sintetiza (buffers → memoria inferida por yosys). |

**Mapa de registros:** `0x00` CTRL(mode/clear) · `0x04` IMGW · `0x08` NPX · `0x0C` LOW · `0x10` HIGH · `0x14` WRPIX(W, carga) · `0x18` START(W)/STATUS(R: {rescount,done}) · `0x1C` RDRES(R, auto-incremento).

**Pixel-a-pixel vs Framebuffer:** el polling por pixel hace ~10+ transacciones de bus POR pixel (write+poll+read); el framebuffer procesa el frame entero **pipelined a 1px/ciclo** y el CPU sólo carga + lee en lote. Siguiente paso para máxima velocidad: **DMA real** que lea la imagen directo de la RAM principal (sin que el CPU cargue el buffer).

## DMA REAL desde RAM — máxima velocidad (rama FrameBuffer) 🚀🚀

| Archivo | Qué hace |
|---|---|
| `filter_dma.sv` | **DMA maestro**: el CPU solo programa `src_addr/dst_addr/npx/mode/low/high` + START. El DMA **lee la imagen directo de la RAM** (canal de lectura), la pasa por el filtro a ~1 px/ciclo y **escribe los resultados de vuelta a la RAM** (canal de escritura). El CPU NO toca ningún pixel. |
| `dpram.sv` | RAM dual-port (BRAM en HW): src (CPU escribe / DMA lee) y dst (DMA escribe / CPU lee). |
| `tb_dma_top.sv` + `cocotb/test_dma.py` (`Makefile.dma`) | Precarga imagen en RAM → START → lee resultados de RAM. **DMA COMPASS 36/36 en 77 ciclos (64px); DMA CANNY 64/64 en 209 ciclos (196px)** → throughput ~1 px/ciclo. |

### Los 3 modelos de I/O (mismos filtros, distinta alimentación)
| Modelo | CPU por pixel | Procesamiento | Archivo |
|---|---|---|---|
| Pixel-a-pixel (polling) | write+poll+read (~10+ bus/px) | CPU-paced | `peripheral_sobel.v` (rama base) |
| Framebuffer (DMA-lite) | solo CARGA el buffer (1 write/px) | pipelined 1px/ciclo | `peripheral_sobel_fb.v` |
| **DMA real desde RAM** | **NADA** (solo src/dst/start) | pipelined 1px/ciclo, autónomo | `filter_dma.sv` |

Integración al SoC: el DMA necesita **arbitraje de bus** (maestro que comparte el bus con el CPU o BRAM dual-port). Eso es el paso de integración pendiente (no mergeado: revision del profesor Carlos Camargo).

## Arbitraje de bus — DMA integrado al SoC 🔗 (rama FrameBuffer)

| Archivo | Qué hace |
|---|---|
| `bus_arbiter.sv` | Árbitro de un puerto de memoria entre CPU y DMA. **Prioridad al DMA**: mientras el DMA pide el bus, controla la RAM y el **CPU queda en stall** (`cpu_stall`). El CPU se pausa y reanuda al terminar. |
| `filter_dma_bus.sv` | DMA de **puerto único** (dos fases: READ src→filtro→buffer, WRITE buffer→dst) para no chocar lectura/escritura en el puerto compartido. |
| `spram.sv` | RAM single-port (BRAM). |
| `soc_dma_top.sv` + `cocotb/test_soc_dma.py` (`Makefile.soc`) | CPU precarga RAM → programa DMA → START → DMA procesa (CPU stalled) → CPU lee resultados de RAM. **SOC DMA COMPASS 36/36 (114 cyc), CANNY 64/64 (274 cyc), cpu_stall observado**. |

Así el DMA queda integrado al bus del SoC: el CPU programa src/dst/npx/START y el árbitro arbitra el acceso a la RAM compartida. (Modelo simple: el DMA monopoliza el bus mientras corre; una mejora futura sería ceder el bus periódicamente para que el CPU avance en paralelo.)
