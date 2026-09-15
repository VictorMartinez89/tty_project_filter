# Esqueleto de capítulos — Tesis de maestría (formato UNAL)
### *SoC RISC-V con filtros de detección de bordes: de FPGA a ASIC*
> ⚠️ **Título provisional.** Depende del Pendiente #6 (decisión de encuadre). Si se adopta el de la
> Parte 169, sería algo como *"Reconocimiento de patrones en silicio: de un detector de bordes escrito
> a mano a un clasificador entrenado — un SoC RISC-V de FPGA a ASIC"*.
*Actualizado 2026-09-14: §5.6 ampliada con el cuaderno 2 (§1-§26), §2.7 nueva (linaje del
descriptor), §3.5 nueva (disciplina de medición y las 5 retractaciones), §6.9-§6.11 nuevas.*

> ⏳ **16 días para el 30 de septiembre.** 56 secciones están marcadas ♻️ —ya escritas en los
> cuadernos, falta pasarlas a prosa— y 11 ✍️. **El cuello de botella ya no es la evidencia: es la
> escritura.** Orden acordado: **5 → 4 → 6 → 3 → 2 → 7 → 1 → Resumen**.

Mapa **cuaderno → capítulos**. Cada sección dice: qué va, de qué Partes sale, qué hay que escribir de cero,
y qué figura/tabla la sostiene. Estado: `♻️` = ya escrito en el cuaderno (pasar a prosa) · `✍️` = escribir de cero.

---

## Portada, Resumen, Abstract, Índices  ✍️
- Resumen (≤ 300 palabras) + palabras clave: *RISC-V, FemtoRV32, detección de bordes, Canny, Sobel,
  reconstrucción morfológica, FPGA, iCE40UP5K, ASIC, sky130, OpenLane, co-diseño hardware/software*.
- El resumen se escribe **al final**, cuando estén los números definitivos de los 6 chips.

---

## 1. Introducción  ✍️ (≈ 6-8 pág.)
| Sección | Contenido | Fuente |
|---|---|---|
| 1.1 Contexto y motivación | Visión embebida de bajo consumo; por qué un SoC propio y no una CPU genérica | ✍️ (apoyarse en P199 §1) |
| 1.2 Planteamiento del problema | El mismo algoritmo cabe o no según *dónde* lo pongas: el problema es de co-diseño, no de algoritmo | ♻️ P199 §4 |
| 1.3 Objetivo general | Diseñar, verificar e implementar en silicio (FPGA y ASIC) un SoC RISC-V que orqueste tres filtros de bordes sobre video en vivo | ✍️ |
| 1.4 Objetivos específicos | (a) modelo golden; (b) RTL de los 3 filtros verificados bit a bit; (c) integración SoC + cámara + TFT en iCE40UP5K; (d) port a ASIC sky130 con GDSII firmado; (e) medición de trade-offs | ✍️ |
| 1.5 Alcance y limitaciones | Resoluciones 60×80 y 160×120; ningún chip fabricado aún; validación física solo en FPGA | ✍️ |
| 1.6 Estructura del documento | Un párrafo por capítulo | ✍️ |

---

## 2. Marco teórico y estado del arte  ♻️+✍️ (≈ 12-15 pág.)
| Sección | Contenido | Fuente |
|---|---|---|
| 2.1 Detección de bordes | Gradiente, Sobel–Feldman, operador compass de Kirsch | ♻️ **P1-24** (modelo golden) |
| 2.2 Canny | Las 4 etapas; doble umbral; histéresis | ♻️ **P159** + P1-24 |
| 2.3 Histéresis transitiva | Reconstrucción morfológica (Vincent 1993), punto fijo, 8-conexidad | ♻️ **P160** (streaming vs barrido) |
| 2.4 Arquitecturas de cómputo de imagen | Streaming vs framebuffer; line-buffers; latencia vs throughput | ♻️ **P142, P154, P156** |
| 2.5 RISC-V y núcleos mínimos | RV32I, FemtoRV32 Quark | ♻️ P53-56 + refs 1-6 |
| 2.6 Del RTL al silicio | FPGA (yosys/nextpnr) vs ASIC (OpenLane/sky130); qué cambia | ♻️ **P84-87** |
| 2.7 **Descriptores de imagen: de SIFT a HOG y la pirámide espacial** ⭐ **nuevo** | La receta *rejilla espacial × histograma de orientaciones*: SIFT (Lowe 2004, 4×4×8=128), HOG (Dalal & Triggs 2005), pirámide espacial (Lazebnik 2006). **El descriptor de esta tesis es HOG + pirámide con 4 decisiones propias de hardware.** Y la clase NADA como *reject option* (Chow 1970) | ♻️ **C2 §22** |
| 2.8 **Rasgo, clase y mapa de características** ⭐ **nuevo** | El vocabulario, con la distinción que ordena el capítulo 5: *feature map* (una imagen) vs *feature vector* (una lista). Las dos escuelas de la visión artificial y dónde queda esta tesis | ♻️ **C2 §22.1, §22.6** |
| 2.7 Trabajos relacionados | `tt06_grayscale_sobel` de Diana (mismo `\|Gx\|+\|Gy\|`, sin CPU, TT06) y `tt_um_femto` de Johan; **posicionamiento: referencia, no extensión** | ♻️ **P84-85** |

> ⚠️ Es el capítulo con más trabajo de escritura nueva: el cuaderno tiene el *contenido* pero no el
> *tono académico ni las citas*. Las 27 referencias de la P200 ya están; hay que citarlas en el texto.

---

## 3. Metodología  ♻️ (≈ 8-10 pág.)
| Sección | Contenido | Fuente |
|---|---|---|
| 3.1 Método iterativo verificable | El ciclo especificar → simular → sintetizar/P&R → grabar → verificar → iterar | ♻️ **P199 §3 + su figura** |
| 3.2 Modelo golden | Python como verdad de referencia; por qué "se ve bien" no es una medida | ♻️ **P1-24, P29-34** |
| 3.3 Verificación por comparación | Bit a bit contra golden; el criterio de *best-shift* y por qué un desfase constante NO es error | ♻️ **P29-34** |
| 3.4 Bring-up incremental | blinky → reloj → SCCB → gris → line-buffers → Sobel → doble umbral → motor → CPU → SoC | ♻️ **P199 §2, P59-76** |
| 3.5 **Disciplina de medición: σ, significancia y puntos de operación** ⭐⭐ **nuevo** | Por qué una diferencia sin σ no es un resultado. La σ medida por **validación cruzada de 10 pliegues sobre las 60 000: 1.32 pp**, y por qué las 5 semillas sobre submuestras solapadas la subestimaban 1.8×. El criterio de 2σ. Y **la regla que este trabajo aprendió tres veces: dos cosas solo se comparan en el mismo punto de operación** (igual área §3, igual umbral §6, igual implementación §25) | ♻️ **C2 §3, §19, §24.3, §25.1** |
| 3.6 **El instrumento antes que el dato** ⭐ **nuevo** | Tres episodios en que el instrumento inventó resultados: los cinco bugs entre el circuito y el dato (10.4 % → 99.7 % de muestras válidas); el **97.3 % falso** que bloqueó una línea de trabajo durante días; y el atajo con `np.roll` que habría inventado 2.4 puntos inexistentes. **La regla operativa: verificar el instrumento contra números ya publicados antes de leer nada nuevo** | ♻️ **C2 §7, §17, §25.1** |
| 3.7 Herramientas y entorno | oss-cad-suite, Icarus, GTKWave, OpenLane/sky130, cocotb; las dos máquinas | ♻️ + ✍️ |

---

## 4. Diseño e implementación  ♻️ (≈ 20-25 pág.) — **el corazón**
### 4.1 Arquitectura del sistema
Cadena cámara → filtro → framebuffer → pantalla, con el CPU al costado. — ♻️ **P157, P162**
### 4.2 Front-end de cámara (OV7670)
SCCB, captura, CDC 2-FF, RGB565→gris. — ♻️ **P152, P157**
### 4.3 Los tres filtros
| Filtro | Contenido | Fuente |
|---|---|---|
| Sobel | shift-add sin multiplicadores, umbral | ♻️ P25-28 |
| Canny 1-salto | Gauss → Sobel → doble umbral → histéresis 1-salto | ♻️ **P159** |
| Canny transitivo | motor de reconstrucción morfológica, FSM, K barridos | ♻️ **P160, P161** |
### 4.4 El SoC: FemtoRV32 + periférico
Mapa de registros `0x0045`, firmware de 7 instrucciones, ROM sintetizada. — ♻️ **P53-56, P162**
### 4.5 Memoria: la batalla de los recursos
Line-buffers → BRAM, framebuffers → SPRAM, ping-pong, los bugs de ancho de puntero. — ♻️ **P45-52**
### 4.6 Del RTL a la FPGA
Trade-off LC↔BRAM, el bug del latch, pinout, bring-up físico. — ♻️ **P59-76**
### 4.7 Del RTL al ASIC
Los 4 cambios obligatorios (ROM sintetizada, sin tri-state interno, reset explícito, fuera primitivas Lattice). — ♻️ **P88-131**

---

## 5. Resultados  ♻️ (≈ 20-25 pág.)
### 5.1 Verificación funcional
- Núcleos **idénticos bit a bit** vs golden (Sobel 0/4800 px de diferencia; los tres filtros 5/5 imágenes).
- Cadena con cámara: 95-100 % (Sobel), 88-99 % (Canny1), 96-100 % (transitivo); **97.8 %** promedio en el SoC.
- ⚠️ **Precisión de escritura:** eso es *concordancia hardware↔golden*, **no "exactitud"**; y la densidad de bordes (~2 %) no es una medida de calidad. — ♻️ **P29-35**
### 5.2 Resultados en FPGA
Utilización real (LC/BRAM/SPRAM), fotos del TFT con los 3 filtros vivos, el experimento 5 imágenes × 3 filtros. — ♻️ **P25-28, P68-82**
### 5.3 Resultados en ASIC — los 10 chips base
Tabla de área/celdas/cp/potencia de los 6 filtros + 2 de pegamento + 2 sistemas. — ♻️ **P86-131**
### 5.4 Resultados en ASIC — la cadena completa (6 chips)
| Chip | Parte |
|---|---|
| #1 `sobel_completo` | ♻️ P157-158 |
| #2 `canny1_completo` | ♻️ P159 |
| #3 `trans_completo` | ♻️ P161 |
| #4 `soc_sobel_completo` | ♻️ P162 |
| #5 `soc_canny1_completo` | ♻️ **P163-164** (incluye el hallazgo del reloj) |
| #6 `soc_trans_completo` | ♻️ **P165** (+ ficha, pendiente del run) |
**✅ TABLA MAESTRA HECHA (7-sep):** `asic/tabla_maestra/tabla_6_chips.py` la genera desde los
`metrics.csv` reales (4 de 6) + las fichas del cuaderno (los 2 archivados sin reports, marcados como
tales). Salida en markdown lista para pegar + `tabla_6_chips.png` con las dos figuras.
**El hallazgo que la tabla habilita y que no estaba escrito:** el cerebro cuesta **casi constante**
—+9 289, +8 456, +9 124 celdas— o sea **~9 000 sin importar el filtro**, mientras el salto de patrón
local a global cuesta **+94 511**. Un procesador entero pesa **una décima parte** de lo que pesa
mirar el cuadro completo en vez de una ventana 3×3. — ♻️ **P157-165** + la tabla nueva
### 5.5 Rendimiento
Throughput y latencia medidos de los 6; streaming vs transitivo (miles de veces). — ♻️ **P154, P155, P156**
### 5.6 Reconocimiento de patrones: del borde al dígito  ⭐ **nuevo (sep-2026)**
La última fila de resultados, y la que conecta con el capítulo 1. Son **resultados medidos**, no
trabajo futuro: 90 simulaciones RTL, un clasificador de 11 clases **corriendo en la iCE40 a 9/10
frente a la cámara**, y el cuaderno 2 completo (§1-§26) con métricas avanzadas y validación cruzada.
| Sub | Contenido | Fuente |
|---|---|---|
| 5.6.1 Tiny Tapeout | Los 7 proyectos con `precheck` 14/14 y sus `metrics.csv` reales; el presupuesto medido (1 023-1 183 inst/tile, 45-61 % util.); los **dos bugs de silicio** que solo cazó el `gl_test` (`initial` heredado de FPGA) | ♻️ **P167** |
| 5.6.2 El experimento 5×6 a tres resoluciones | 16×12, 24×18, 36×26 → **90 simulaciones, 45 pares con/sin CPU idénticos píxel a píxel**; la serie de densidades y el piso de clipeo | ♻️ **P167-168** |
| 5.6.3 Recalibración y latencia de pipeline | 250/210; recalibrar un SoC = recompilar firmware; **cada etapa 3×3 cuesta W+1 píxeles** de latencia, medido | ♻️ **P168** |
| 5.6.4 El clasificador de dígitos | Pirámide espacial + lineal cuantizado sobre el front-end de la tesis: **94.2 % con 1 600 flip-flops**, contra 91.9 % de los 784 píxeles crudos | ♻️ **P170** |
| 5.6.5 **Cómo reconoce, de punta a punta** ⭐ | 784 px → 32 contadores → 40 rasgos → 10 puntajes → 1 dígito. Las **11 clases** atravesando el circuito con los pesos reales de la ROM (11/11). Los 40 rasgos dibujados uno por uno. **400 pesos de 4 bits = 200 bytes** | ♻️ **C2 §21, §23** |
| 5.6.6 **El sistema en silicio** ⭐ | RISC-V + Canny + clasificador en la iCE40UP5K: **9/10 frente a la cámara**, coincidiendo exactamente con la simulación. El periférico `0x0045` escribiendo los dos umbrales en un solo `word` | ♻️ **C2 §14, §18** |
| 5.6.7 **Los cinco front-ends, mismo procedimiento** ⭐ | Sobel / SoC+Sobel / Canny1 / SoC+Canny1 / Transitivo sobre 60 000 + 10 000. Exactitud, F1, matriz de confusión, FP/VN, **AUC, Brier, Brier skill** y **validación cruzada de 10 pliegues (σ = 1.32 pp)** | ♻️ **C2 §15, §18, §19** |
| 5.6.8 **El punto de operación pesa más que el filtro** ⭐⭐ | Barrido del umbral dentro de cada filtro: mueve al Sobel **5.79 pp (4.4 σ)** y al Canny **0.90 pp (0.7 σ)**; entre filtros, **0.38 pp (0.3 σ)**. **El Sobel vive en un pico, el Canny en una meseta** | ♻️ **C2 §25** |
| 5.6.9 **El CPU sobre el Canny** ⭐⭐ | El umbral adaptativo le resta al Canny en las **18 condiciones**. Con ruido severo el Canny **sin** CPU (74.12 %) queda a **1.06 pp** del Sobel **con** CPU (75.18 %) | ♻️ **C2 §26** |
⚠️ **Decisión de encuadre pendiente:** si esta sección entra, el título y el capítulo 1 tienen que
cambiar con ella (ver Pendientes #6). Sin eso, 5.6 queda colgando de un documento que promete otra cosa.

> 🔧 **OJO al escribir la §5.6 y el capítulo 6:** el arco del argumento **cambió el 14-sep**. La
> versión vieja era *«el Canny no mejora la exactitud (§3) PERO bajo condiciones de cámara sí (§6)»*.
> **La §6 quedó retractada** —comparaba dos puntos de operación, no dos filtros— así que esa
> justificación ya no existe. **El arco correcto es:**
>
> `§3 no mejora la exactitud` → `§25 pero es INSENSIBLE al umbral` → `§26 y por eso reemplaza al CPU
> bajo ruido, sin CPU` → `§9 y además entra en la FPGA`
>
> Es un argumento **más fuerte**, porque se apoya en una propiedad estructural del algoritmo (la
> histéresis es un mecanismo de recuperación) y no en una condición simulada. **No escribir el
> capítulo traduciendo sección por sección: escribirlo con el arco nuevo.**

---

## 6. Discusión  ♻️ (≈ 10-12 pág.) — **donde está el aporte**
| Tema | Tesis que se defiende | Fuente |
|---|---|---|
| 6.1 La memoria no es gratis | **Tres caras: área, potencia y reloj.** En FPGA la BRAM parece gratis; en ASIC el framebuffer son flip-flops, y su mux de lectura llegó a ser el **camino crítico** | ♻️ **P87, P158, P164** ⭐ |
| 6.2 El firmware no se carga solo | ROM sintetizada: los FF arrancan aleatorios en silicio | ♻️ P88-131 |
| 6.3 Integrar no es sumar… **cuando el timing aprieta** | +6 500 celdas en el `soc_canny1_top` apretado vs **−1.6 %** en el #5 holgado. El matiz completo | ♻️ **P87 + P164** ⭐ |
| 6.4 Quién fija el reloj | Datapath (chips 1-3) → CPU (chip 4) → **framebuffer** (chip 5). Cambia con lo que metés en el chip | ♻️ **P164** ⭐ |
| 6.5 Co-diseño HW/SW | El transitivo no cupo con CPU (127 %) → motor en hardware. Los píxeles no pasan por el bus | ♻️ P53-56, P162 |
| 6.6 Sobel "gana" a baja resolución | El hallazgo empírico: a 60×80 la magnitud graduada sobrevive y el borde binario de 1 px casi no se ve; justifica la histéresis transitiva | ♻️ P25-28 ⭐ |
| 6.7 Comparación con el trabajo de Diana | Misma RTL de Sobel, dos destinos; la diferencia es alcance, no calidad | ♻️ **P84-85** |
| 6.9 **El front-end y el registro escribible son ALTERNATIVAS, no complementos** ⭐⭐ | El Canny compra **en hardware** (+16 % de área en ASIC, +0.5 % en FPGA) buena parte de la robustez que el Sobel necesita **un CPU** (~9 000 celdas) para conseguir. Los dos resuelven el mismo problema por dos caminos. **Es el aporte de ingeniería del cuaderno 2** | ♻️ **C2 §25.4, §26** ⭐ |
| 6.10 **Mejor detección de bordes ≠ mejor reconocimiento** | El transitivo **ordena bien** (AUC 4.º, por encima del SoC+Sobel) y **calibra mal** (Brier 5.º por amplio margen): sus 139 falsos positivos son la consecuencia mecánica de engordar los contornos. Y **no puede transmitir**: memoria de cuadro + barridos hasta punto fijo. No es un filtro más caro — **es otra clase de objeto computacional** | ♻️ **C2 §11, §19, §20.5** ⭐ |
| 6.11 **La jerarquía de 3Blue1Brown, construida en vez de esperada** | Sanderson propone *bordes → trazos → dígito* como una esperanza sobre las capas ocultas de un MLP, y muestra que no ocurre. Acá **sí ocurre, porque está escrita**. 13 002 parámetros (52 KB) contra **400 pesos de 4 bits (220 bytes)**, con la salvedad honesta: las capas cableadas cuestan 36 730 celdas — el costo se **movió** de memoria a lógica, no se eliminó | ♻️ **C2 §21** |
| 6.8 Limitaciones | Ningún chip fabricado; 60×80/160×120; magnitud de 8 bits satura (monarch); XCLK = clk/4 al relajar el reloj; hold del #3 | ♻️ **P164** + ✍️ |

---

## 7. Conclusiones y trabajo futuro  ♻️ (≈ 4-5 pág.)

> ⭐ **Incluir una subsección de retractaciones.** El cuaderno 2 corrigió **cinco** afirmaciones
> propias, con fecha y evidencia: el VSYNC que era un off-by-one (§7.4); el `thr=110` que no
> transfiere de 20 000 a 60 000 (§3); el **97.3 % falso** (§17); la **σ subestimada 1.8×** (§19); y la
> **§6 entera**, que comparaba dos puntos de operación y no dos filtros (§26). *Un documento que lista
> cinco errores propios con evidencia es mucho más difícil de atacar que uno que no lista ninguno —
> y un jurado que encuentra un error por su cuenta es mucho peor que uno que lo ve ya corregido.*
- Conclusiones por objetivo específico (cerrar el círculo con §1.4). — ♻️ **P199**
- Contribuciones: el SoC con 3 filtros vivo en FPGA; el motor transitivo en hardware con su hallazgo de
  co-diseño; los chips con GDSII firmado; el cuaderno reproducible.
- Trabajo futuro: **Tiny Tapeout** (fabricar de verdad), macro de SRAM en vez de flip-flops
  (la respuesta directa al hallazgo del reloj), resoluciones mayores. — ♻️ **P132-134**

## Referencias  ♻️ — P200 (**36 fuentes**, formato IEEE) — se agregaron 33-36 (Lazebnik 2006, Csurka 2004, LeCun 1998, scikit-learn)
## Anexos  ♻️ — mapa de registros, pinout, recetas de OpenLane, el cuaderno completo como material reproducible

---

## 📋 Pendientes concretos
1. ~~**Ficha del chip #6**~~ — ✅ **hecha**, P165 (GDS firmado 23-ago, con nota honesta de timing).
2. ~~**Limpiar la "Parte 100 — Referencias" huérfana**~~ — ✅ **ya no está**. Queda solo un comentario mal
   numerado (`# === Parte 100: diagrama...`) en una celda de código que vive dentro de la Parte 101. Cosmético.
3. ~~**Tabla maestra de los 6 chips**~~ — ✅ **hecha** (7-sep), `asic/tabla_maestra/tabla_6_chips.py`.
4. **Citas en el texto**: la P200 tiene las 36 fuentes pero el cuerpo no las cita todavía.
5. **Escribir de cero**: Resumen/Abstract, Introducción completa, y el tono académico del Cap. 2.
6. ⭐ **DECISIÓN DE ENCUADRE — bloquea el Cap. 1 y el título.** La Parte 169 propone que la tesis no es
   "un filtro Sobel llevado a ASIC" sino *reconocimiento de patrones en silicio bajo restricciones duras:
   el mismo datapath sirve para un patrón escrito a mano, uno buscado y uno aprendido, y lo que decide
   cuál cabe no es el algoritmo sino la memoria*. Está respaldado por la propuesta de 2017 (esta tesis es
   su "Trabajo Futuro" literal) y por la §5.6. **Si se adopta, cambian el título, el Cap. 1 y el Cap. 2**;
   si no, la §5.6 sobra. Hay que decidirlo ANTES de escribir el Cap. 1 — no antes del Cap. 5.
7. ⭐ **AVISARLE A CARLOS — lo más urgente (14-sep).** No vio nada del cuaderno 2 §19-§26, y sobre
   todo **no sabe que la §6 está retractada**. Esa sección justificaba toda la línea del Canny.
   Republicar la página del tutor con: las métricas avanzadas, el pico-vs-meseta, el CPU sobre el
   Canny, y **la retractación de la §6 con el arco nuevo del argumento**.
8. **Experimento barato que queda abierto:** medir en la placa `110/40` contra `170/61`. En Python el
   segundo gana **18 pp** con ruido severo y empata en limpio (C2 §26.5). Cuesta cambiar la constante
   `UMBRALES` del `soc_ctrl` — **es exactamente el experimento para el que se construyó el
   periférico `0x0045`**. No está medido en silicio; la §3 ya enseñó que los óptimos no transfieren.
9. **Auditoría pendiente sobre el cuaderno 1:** las tres comparaciones inválidas halladas (igual área,
   igual umbral, igual implementación) son **el mismo modo de fallo**. El cuaderno 1 nunca se revisó
   con esa pregunta. Es barato y puede evitar que el jurado encuentre la cuarta.
10. **Dos datos que faltan** para cerrar la tabla maestra: el `spef_wns` de los chips #1 y #2 (se
   archivaron sin `reports/`; su ficha solo tiene el WNS nominal). Se resuelve re-corriendo esos dos
   diseños, o se documenta el hueco tal como está ahora.

## 🗺️ Orden sugerido de escritura
**Cap. 5 → Cap. 4 → Cap. 6 → Cap. 3 → Cap. 2 → Cap. 7 → Cap. 1 → Resumen.**
Empezar por resultados (ya están, es casi copiar y pegar en prosa) da impulso y deja claro qué tiene que
justificar el marco teórico. La introducción y el resumen, últimos: se escriben mejor cuando ya sabés qué
dice el documento.
