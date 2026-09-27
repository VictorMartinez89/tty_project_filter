# 7. El reconocimiento en silicio

El capítulo anterior dejó el reconocedor verificado contra el modelo y funcionando en la tarjeta. Éste
lo lleva a silicio: el reconocedor con cada front-end, lo que cuesta el front-end según el sistema, y
Canny-78 firmado en sky130.

## 7.1 Implementación en silicio

El reconocedor se llevó a tecnología `sky130_fd_sc_hd` en dos variantes, ejecutando el flujo completo
de OpenLane hasta la firma del GDS:

| magnitud | Sobel | Canny 1-salto |
|---|---:|---:|
| área del *die* | 0.845 mm² | 0.890 mm² |
| celdas tras síntesis | 16 718 | 17 373 |
| celdas emplazadas | 19 949 | 20 921 |
| período de reloj | 30 ns (33.3 MHz) | 30 ns (33.3 MHz) |
| holgura con parásitos (`spef_wns`) | **0.00 ns** | **0.00 ns** |
| DRC · LVS · XOR | 0 · 0 · 0 | 0 · 0 · 0 |

Table: El reconocedor en silicio con front-end Sobel y con Canny de un salto.

Ambos circuitos cierran el temporizado con los parásitos del interconexionado extraídos y superan las
tres verificaciones de firma sin observaciones. Merece señalarse que **cierran más rápido que los
circuitos de visión equivalentes** —que requirieron 32 y 36 ns—, lo que resulta coherente con la
ausencia de memoria de cuadro: es el multiplexor de lectura del *framebuffer* el que constituye el
camino crítico de aquéllos.

**Son los primeros circuitos de este trabajo cuya salida no es una imagen.** Los diez presentados en
las secciones §5.2 y §5.3 procesan; éstos reconocen.

## 7.2 El costo relativo del front-end depende del sistema

La comparación de área entre ambos front-ends admite cuatro niveles de integración. Las cuatro filas
están en **celdas emplazadas**, la misma escala de la §5.2, de modo que los cocientes son
directamente comparables entre sí:

| nivel | Sobel | Canny | factor |
|---|---:|---:|---:|
| filtro aislado | 5 823 | 12 993 | **2.23×** |
| con procesador | 12 043 | 22 054 | 1.83× |
| sistema de visión completo | 35 653 | 41 925 | 1.18× |
| reconocedor con procesador | 19 949 | 20 921 | 1.05× |
| **reconocedor que además muestra** | **38 643** | **39 794** | **1.03×** |

Table: Costo relativo del front-end según el nivel del sistema.

**El sobrecosto del Canny se diluye conforme crece el sistema que lo rodea.** Considerado de forma
aislada cuesta un **123 %** más; con un procesador al lado, un 83 %; dentro de un sistema de visión,
un 18 %; integrado en un reconocedor, un 5 %; y en un reconocedor que además dibuja en pantalla,
un **3 %**. El motivo es que el clasificador
—histograma, pirámide y 400 multiplicaciones— es idéntico en ambas variantes y domina el área,
mientras que la diferencia se reduce al tercer *line-buffer*.

De ello se sigue una conclusión condicional: **el Sobel aventaja al Canny en área únicamente cuando
el filtro constituye el circuito completo.** En un sistema que reconoce, esa ventaja —la única que el
Sobel conserva, según §6.2 a §6.4— deja de ser determinante.

## 7.3 Canny-78 en silicio

El mismo RTL que dio diez mil de diez mil en la tarjeta se llevó a sky130 con OpenLane,
con la receta de los demás circuitos: reloj de 30 ns, utilización del 30 % y densidad de 0,40. Es el
**decimoséptimo circuito** de este trabajo, y firma limpio:

| | Canny-78 | Canny-78 recortado |
|---|---:|---:|
| dado | 1,122 mm² (1 043 × 1 042 µm) | **0,829 mm²** (−26 %) |
| celdas tras la síntesis | 29 449 | 21 409 |
| potencia (interna y de conmutación) | 25,3 mW | 18,6 mW |
| camino crítico, frente a un reloj de 30 ns | 12,66 ns | 11,86 ns |
| DRC · LVS · XOR · temporizado con parásitos | 0 · 0 · 0 · holgura ≥ 0 | 0 · 0 · 0 · holgura ≥ 0 |
| veredictos iguales al modelo | 10 000 / 10 000 | 10 000 / 10 000 |

Table: Canny-78 y su variante recortada, firmados en sky130.

La variante recortada cambia una sola cosa: la memoria de rasgos del clasificador estaba declarada con
256 posiciones de 13 bits y sólo se usaban 168 de 9. En la FPGA eso no costaba nada —un bloque de BRAM
cuesta lo mismo lleno que vacío—; en silicio, **un cuarto del dado era memoria declarada y no usada**.
Es la tesis del Capítulo 8 dicha con el número más limpio de todo el trabajo: la memoria se paga por
los bits que se declaran, no por los que se usan.

En Tiny Tapeout, en cambio, ninguna de las dos cabe: en el tamaño máximo de 8×2 tiles, la completa
pide un 110,7 % del área y la recortada, al 80,3 %, se queda sin sitio para los búferes que cierran el
*hold*. El reconocedor que sí cabe es el de cuarenta rasgos (94,20 %), que en la lanzadera abierta de
sky130 (SKY26d) ocupa el 42 % de 8×2 tiles, con DRC, LVS y antenas en cero y el temporizado limpio en
las tres esquinas de proceso (repositorio `tt_mnist_canny_v2_vic`, ejecución 36048035078). No se ha
enviado a fabricar.
