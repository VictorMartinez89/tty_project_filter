# Esqueleto de capítulos — Tesis de maestría (formato UNAL)
### *SoC RISC-V con filtros de detección de bordes: de FPGA a ASIC*
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
| 3.5 Herramientas y entorno | oss-cad-suite, Icarus, GTKWave, OpenLane/sky130, cocotb; las dos máquinas | ♻️ + ✍️ |

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
Tabla resumen de los 6 + la figura de áreas y del costo del cerebro. — ♻️ **P165 (figura)**
### 5.5 Rendimiento
Throughput y latencia medidos de los 6; streaming vs transitivo (miles de veces). — ♻️ **P154, P155, P156**

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
| 6.8 Limitaciones | Ningún chip fabricado; 60×80/160×120; magnitud de 8 bits satura (monarch); XCLK = clk/4 al relajar el reloj; hold del #3 | ♻️ **P164** + ✍️ |

---

## 7. Conclusiones y trabajo futuro  ♻️ (≈ 4-5 pág.)
- Conclusiones por objetivo específico (cerrar el círculo con §1.4). — ♻️ **P199**
- Contribuciones: el SoC con 3 filtros vivo en FPGA; el motor transitivo en hardware con su hallazgo de
  co-diseño; los chips con GDSII firmado; el cuaderno reproducible.
- Trabajo futuro: **Tiny Tapeout** (fabricar de verdad), macro de SRAM en vez de flip-flops
  (la respuesta directa al hallazgo del reloj), resoluciones mayores. — ♻️ **P132-134**

## Referencias  ♻️ — P200 (27 fuentes, formato IEEE)
## Anexos  ♻️ — mapa de registros, pinout, recetas de OpenLane, el cuaderno completo como material reproducible

---

## 📋 Pendientes concretos
1. **Ficha del chip #6** — en cuanto termine el run (`ficha_run.sh`) + fotos de KLayout.
2. **Limpiar la "Parte 100 — Referencias" huérfana** del cuaderno (idx≈153, id `p100-md`), duplicada de una reorganización. La buena es la P200.
3. **Tabla maestra de los 6 chips** de la cadena completa (área, celdas, reloj de signoff, DRC/LVS/XOR, potencia estimada, estado) — hoy los datos están repartidos entre P157-165.
4. **Citas en el texto**: la P200 tiene las fuentes pero el cuerpo no las cita todavía.
5. **Escribir de cero**: Resumen/Abstract, Introducción completa, y el tono académico del Cap. 2.

## 🗺️ Orden sugerido de escritura
**Cap. 5 → Cap. 4 → Cap. 6 → Cap. 3 → Cap. 2 → Cap. 7 → Cap. 1 → Resumen.**
Empezar por resultados (ya están, es casi copiar y pegar en prosa) da impulso y deja claro qué tiene que
justificar el marco teórico. La introducción y el resumen, últimos: se escriben mejor cuando ya sabés qué
dice el documento.
