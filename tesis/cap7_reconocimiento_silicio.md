# 7. El reconocimiento en silicio

El capítulo anterior dejó el reconocedor verificado contra el modelo y funcionando en la tarjeta. Éste
lo lleva a silicio: el reconocedor con cada front-end, lo que cuesta el front-end según el sistema, y
Canny-78 firmado en sky130.

## 7.1 Implementación en silicio

El reconocedor se llevó a tecnología `sky130_fd_sc_hd` en dos variantes, ejecutando el flujo completo
de OpenLane hasta la firma del GDS:

| magnitud | Sobel | Canny 1-salto |
|---|---:|---:|
| área del *die* | 0,845 mm² | 0,890 mm² |
| celdas tras síntesis | 16 718 | 17 373 |
| celdas emplazadas | 19 949 | 20 921 |
| período de reloj | 30 ns (33,3 MHz) | 30 ns (33,3 MHz) |
| holgura con parásitos (`spef_wns`) | **0,00 ns** | **0,00 ns** |
| DRC · LVS · XOR | 0 · 0 · 0 | 0 · 0 · 0 |

Table: El reconocedor en silicio con front-end Sobel y con Canny de un salto.

Ambos circuitos cierran el temporizado con los parásitos del interconexionado extraídos y superan las
tres verificaciones de firma sin observaciones. Merece señalarse que **cierran más rápido que los
circuitos de visión equivalentes** —que requirieron 32 y 36 ns—, lo que resulta coherente con la
ausencia de memoria de cuadro: es el multiplexor de lectura del *framebuffer* el que constituye el
camino crítico de aquéllos.

**Son los primeros circuitos de este trabajo cuya salida no es una imagen.** Los diez presentados en
las secciones §5.2 y §5.3 procesan; éstos reconocen.

![**Figura 7.1.** Pan Sobel en KLayout: 914×925 µm y 92 857 instancias, contando las celdas de relleno
y de alimentación. A la izquierda el dado completo; a la derecha, una ampliación con las filas de
celdas estándar. No hay un bloque que destaque: sin *framebuffer*, el área es lógica repartida —el
procesador, el extractor y el clasificador—.](figuras/fig_7_pansobel_asic.png)

![**Figura 7.2.** Pan Canny en KLayout: 938×949 µm y 97 533 instancias. Es el plano anterior con el
tercer *line-buffer* del Canny; la diferencia de área entre ambos, un 5 %, es la de la
§7.2.](figuras/fig_7_pancanny_asic.png)

## 7.2 El costo relativo del front-end depende del sistema

La comparación de área entre ambos front-ends admite cuatro niveles de integración. Las cuatro filas
están en **celdas emplazadas**, la misma escala de la §5.2, de modo que los cocientes son
directamente comparables entre sí:

| nivel | Sobel | Canny | factor |
|------------------------------|------:|------:|------:|
| filtro aislado | 5 823 | 12 993 | **2,23×** |
| con procesador | 12 043 | 22 054 | 1,83× |
| sistema de visión completo | 35 653 | 41 925 | 1,18× |
| reconocedor con procesador | 19 949 | 20 921 | 1,05× |
| **reconocedor que además muestra** | **38 643** | **39 794** | **1,03×** |

Table: Costo relativo del front-end según el nivel del sistema.

**El sobrecosto del Canny se diluye conforme crece el sistema que lo rodea.** Considerado de forma
aislada cuesta un **123 %** más; con un procesador al lado, un 83 %; dentro de un sistema de visión,
un 18 %; integrado en un reconocedor, un 5 %; y en un reconocedor que además dibuja en pantalla,
un **3 %**. El motivo es que el clasificador
—histograma, pirámide y 400 multiplicaciones— es idéntico en ambas variantes y domina el área,
mientras que la diferencia se reduce al tercer *line-buffer*.

De ello se sigue una conclusión condicional: **el Sobel aventaja al Canny en área únicamente cuando
el filtro constituye el circuito completo.** En un sistema que reconoce, esa ventaja —la única que el
Sobel conserva, según las §6.2, §6.4 y §6.5— deja de ser determinante.

Las dos últimas filas de la tabla son los circuitos que además muestran el resultado, los de las
§6.3.3 y §6.3.4. Son los mayores de los reconocedores, y sus planos lo hacen visible.

![**Figura 7.3.** Visión Sobel MNIST en KLayout: 1 420×1 431 µm, 2,032 mm². Ve, reconoce y muestra:
la cámara, la ventana de 28×28, el clasificador, el *framebuffer* de la ventana y el controlador de la
pantalla.](figuras/fig_7_visionsobel_asic.png)

![**Figura 7.4.** Visión Canny MNIST en KLayout: 1 441×1 452 µm, 2,092 mm², con un 2,8 % más de celdas
que el del Sobel. Entre los dos planos apenas se distingue la diferencia: es la de la última fila de la
tabla.](figuras/fig_7_visioncanny_asic.png)

## 7.3 Canny-78 en silicio

El mismo RTL que dio diez mil de diez mil en la tarjeta se llevó a sky130 con OpenLane,
con la receta de los demás circuitos: reloj de 30 ns, utilización del 30 % y densidad de 0,40. Es el
**decimoséptimo circuito** de este trabajo, y firma limpio:

| | Canny-78 | Canny-78 recortado |
|-------------------------------------------|----------------------------:|-----------------------:|
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

![**Figura 7.5.** Canny-78 recortado en KLayout, el dado completo: 905×916 µm, 0,829 mm² y 93 867
instancias. Alrededor del borde están los pines del circuito —`in_pix`, `in_valid`, `thr_hi`, `thr_lo`,
`digito`—, y las franjas horizontales son las tiras de alimentación. No hay un bloque de memoria a la
vista: la memoria de rasgos, ya recortada a 168 posiciones de 9 bits, son biestables repartidos entre
las demás celdas.](figuras/fig_7_canny78f9_chip.png)

![**Figura 7.6.** Una ampliación del mismo plano: las filas de celdas estándar de sky130, con sus
nombres legibles —los biestables `dfxtp` y los condensadores de desacoplo `decap`—, y encima el ruteo
en los niveles de metal que las conecta.](figuras/fig_7_canny78f9_zoom.png)

En Tiny Tapeout, en cambio, ninguna de las dos cabe: en el tamaño máximo de 8×2 tiles, la completa
pide un 110,7 % del área y la recortada, al 80,3 %, se queda sin sitio para los búferes que cierran el
*hold*. El reconocedor que sí cabe es el de cuarenta rasgos (94,20 %), que en la lanzadera abierta de
sky130 (SKY26d) ocupa el 42 % de 8×2 tiles, con DRC, LVS y antenas en cero y el temporizado limpio en
las tres esquinas de proceso (repositorio `tt_mnist_canny_v2_vic`, ejecución 36048035078). No se ha
enviado a fabricar.

Antes de esa versión se armaron para Tiny Tapeout dos reconocedores de 8×2 mosaicos, uno con cada
front-end, sin cámara ni procesador: el píxel entra por los pines y el dígito sale por ellos. El del
Sobel lleva el umbral fijo en 60 y **13 319 celdas**; el del Canny, los umbrales 90 y 32 y **14 970
celdas**. Los dos firman con DRC y LVS en cero.

![**Figura 7.7.** El reconocedor con el Sobel en los 8×2 mosaicos de Tiny Tapeout, en el render que
genera el flujo de la lanzadera. Las columnas verticales son las tiras de
alimentación.](figuras/fig_7_tt_mnist_sobel.png)

![**Figura 7.8.** El reconocedor con el Canny en los mismos 8×2 mosaicos. Es el antecesor directo del
`tt_mnist_canny_v2_vic` que cabe con el 42 % de utilización.](figuras/fig_7_tt_mnist_canny.png)
