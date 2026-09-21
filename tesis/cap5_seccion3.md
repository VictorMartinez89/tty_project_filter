# 5.3 Resultados en ASIC: los bloques

> **Estado:** borrador 1, escrito el 2026-09-16. Fuente: cuaderno 1, Partes 86-131, y el archivo de
> planos `ASIC_planos/`.
> ⚠️ Léase la advertencia sobre el recuento de celdas al final: **las cifras de esta tabla no son
> comparables una a una con las de la §5.4.**

Esta sección presenta los circuitos que implementan **una función cada uno**: los tres filtros por
separado, los mismos con procesador, dos bloques de interfaz y dos sistemas de visión. Son el
vocabulario con el que se construyen los sistemas de la §5.4, y su valor está en que permiten atribuir
el costo de cada pieza por separado.

Todos se llevaron a GDSII con **OpenLane** sobre el PDK abierto **sky130A**, biblioteca
`sky130_fd_sc_hd`.

## 5.3.1 La tabla

| Circuito | Función | Área del die | Celdas | Signoff |
|---|---|---:|---:|:-:|
| `sobel` | filtro Sobel 3×3 | 0,167 mm² | 4 651 | DRC/LVS/XOR = 0 |
| `canny1` | Canny de un salto, en flujo | 0,360 mm² | 10 284 | DRC/LVS/XOR = 0 |
| `transitivo` | Canny con histéresis transitiva | 3,13 mm² | 52 954 | DRC/LVS/XOR = 0 |
| `soc_sobel` | FemtoRV32 + Sobel | 0,37 mm² | 9 906 | DRC/LVS/XOR = 0 |
| `soc_canny1` | FemtoRV32 + Canny de un salto | 0,67 mm² | 22 054 | DRC/LVS/XOR = 0 |
| `soc_trans` | FemtoRV32 + transitivo | 3,42 mm² | 72 337 | DRC/LVS/XOR = 0 |
| `cam_frontend` | front-end de cámara OV7670 | 0,0177 mm² | 562 | DRC/LVS/XOR = 0 |
| `lcd_ili9341` | driver de pantalla TFT por SPI | 0,0174 mm² | 553 | DRC/LVS/XOR = 0 |
| `vision_top` | cámara + Sobel + framebuffer + pantalla | 1,75 mm² | 35 653 | DRC/LVS/XOR = 0 |
| `vision_canny` | cámara + Canny + framebuffer + pantalla | 2,04 mm² | 41 925 | DRC/LVS/XOR = 0 |

**Diez circuitos, diez veces DRC, LVS y XOR en cero.**

## 5.3.2 Lo que la tabla muestra de un vistazo

**El filtro transitivo cuesta casi veinte veces más que el Sobel** —3,13 mm² contra 0,167— pese a
ejecutar aritmética comparable. La razón, ya anticipada, es el cuadro completo residente: en la FPGA
ese cuadro vivía en SPRAM y no consumía lógica; aquí es un banco de biestables.

**Los dos bloques de interfaz son casi gratis.** El front-end de cámara y el driver de pantalla ocupan
menos de dieciocho milésimas de milímetro cuadrado cada uno, alrededor de 560 celdas. Conviene tenerlo
medido porque desmonta una intuición común: el costo de un sistema de visión embebido no está en
hablar con los periféricos, está en lo que se hace con los datos entre medias.

**Y el Sobel en silicio es mucho más rápido de lo que la FPGA permitía.** Su camino crítico quedó en
**7,69 ns** frente a un objetivo de 20 ns, es decir que soportaría unos 130 MHz, mientras que en la
iCE40 cerraba entre 9 y 28 MHz. En silicio la lógica es rápida; **lo caro es el área**, y ése es el
eje sobre el que gira todo este capítulo.

## 5.3.3 Advertencia sobre el recuento de celdas

Esta advertencia no es un tecnicismo: afecta a cualquier comparación que un lector intente hacer entre
esta tabla y la de la §5.4.

Las cifras de la columna «celdas» de este capítulo **no proceden todas del mismo campo de medida**. Al
contrastarlas contra los ficheros `metrics.csv` de cada *run* se comprobó que conviven tres
definiciones distintas:

| Definición | Qué cuenta | Circuitos que la usan |
|---|---|---|
| `synth_cell_count` | celdas tras síntesis, antes de emplazar | `sobel`, y los reconocedores de la §5.6 |
| `NonPhysCells` | celdas lógicas tras emplazamiento y ruteo | `soc_canny1`, `soc_trans` |
| conteo del flujo de LibreLane | celdas estándar tras emplazamiento | los circuitos en IHP SG13G2 |

La diferencia entre la primera y la segunda es de **entre el 19 % y el 23 %**, medida sobre tres
diseños, y corresponde a los amortiguadores que el emplazamiento inserta para el árbol de reloj y la
reparación de tiempos. En `soc_canny1`, por ejemplo, son 17 916 celdas de síntesis frente a 22 054
tras emplazar.

**En consecuencia: los cocientes dentro de una misma fila son válidos, y las diferencias absolutas
entre filas de tablas distintas no lo son.** Una comparación que cruce las dos tablas produce una
discrepancia cercana al 20 % que no corresponde a ninguna decisión de diseño.

> La causa de la heterogeneidad es documental y no experimental: de los dieciséis directorios de
> resultados, sólo una parte conservó su `metrics.csv`, y las fichas del cuaderno registraron en cada
> momento el campo que la herramienta ofrecía. **Homogeneizar la tabla exige regenerar los `metrics.csv`
> ausentes** —`sobel`, `canny1`, `soc_sobel`, `transitivo`, `vision_top` y `vision_canny`— y se deja
> anotado como trabajo pendiente antes de la versión final del documento.
