# 5.3 Resultados en ASIC: los bloques

> **Estado:** borrador 1, escrito el 2026-09-16. Fuente: cuaderno 1, Partes 86-131, y el archivo de
> planos `ASIC_planos/`.
> **Recuento homogeneizado el 21 de septiembre de 2026.** Toda la columna «celdas» de esta tabla son
> **celdas lógicas tras emplazamiento y ruteado**, recontadas con un mismo criterio desde los
> netlists archivados. Véase la §5.3.3 para cruzarlas con las de la §5.4.

Esta sección presenta los circuitos que implementan **una función cada uno**: los tres filtros por
separado, los mismos con procesador, dos bloques de interfaz y dos sistemas de visión. Son el
vocabulario con el que se construyen los sistemas de la §5.4, y su valor está en que permiten atribuir
el costo de cada pieza por separado.

Todos se llevaron a GDSII con **OpenLane** sobre el PDK abierto **sky130A**, biblioteca
`sky130_fd_sc_hd`.

## 5.3.1 La tabla

| Circuito | Función | Área del die | Celdas | Signoff |
|---|---|---:|---:|:-:|
| `sobel` | filtro Sobel 3×3 | 0,167 mm² | 5 823 | DRC/LVS/XOR = 0 |
| `canny1` | Canny de un salto, en flujo | 0,360 mm² | 12 993 | DRC/LVS/XOR = 0 |
| `transitivo` | Canny con histéresis transitiva | 3,13 mm² | 65 659 | DRC/LVS/XOR = 0 |
| `soc_sobel` | FemtoRV32 + Sobel | 0,37 mm² | 12 043 | DRC/LVS/XOR = 0 |
| `soc_canny1` | FemtoRV32 + Canny de un salto | 0,67 mm² | 22 054 | DRC/LVS/XOR = 0 |
| `soc_trans` | FemtoRV32 + transitivo | 3,42 mm² | 72 337 | DRC/LVS/XOR = 0 |
| `cam_frontend` | front-end de cámara OV7670 | 0,0177 mm² | 562 | DRC/LVS/XOR = 0 |
| `lcd_ili9341` | driver de pantalla TFT por SPI | 0,0174 mm² | 553 | DRC/LVS/XOR = 0 |
| `vision_top` | cámara + Sobel + framebuffer + pantalla | 1,75 mm² | 35 653 | DRC/LVS/XOR = 0 |
| `vision_canny` | cámara + Canny + framebuffer + pantalla | 2,04 mm² | 41 925 | DRC/LVS/XOR = 0 |

**Diez circuitos, diez veces DRC, LVS y XOR en cero.**

## 5.3.2 Lo que la tabla muestra de un vistazo

**El filtro transitivo cuesta casi veinte veces más área que el Sobel** —3,13 mm² contra 0,167, y
once veces más celdas— pese a ejecutar aritmética comparable. La razón, ya anticipada, es el cuadro completo residente: en la FPGA
ese cuadro vivía en SPRAM y no consumía lógica; aquí es un banco de biestables.

**Los dos bloques de interfaz son casi gratis.** El front-end de cámara y el driver de pantalla ocupan
menos de dieciocho milésimas de milímetro cuadrado cada uno, alrededor de 560 celdas. Conviene tenerlo
medido porque desmonta una intuición común: el costo de un sistema de visión embebido no está en
hablar con los periféricos, está en lo que se hace con los datos entre medias.

![**Figura 5.2.** Acercamiento al GDSII del `canny1` en KLayout. Lo que se ve no es un esquema sino
el plano que iría a fábrica: filas de celdas estándar y, sobre ellas, las capas de metal que las
conectan. La mancha más clara del centro es una región de menor densidad de ruteo. Las 12 993 celdas
de la tabla anterior son, literalmente, estas.](figuras/fig_5_2_malla_canny1.jpg)

**Y el Sobel en silicio es mucho más rápido de lo que la FPGA permitía.** Su camino crítico quedó en
**7,69 ns** frente a un objetivo de 20 ns, es decir que soportaría unos 130 MHz, mientras que en la
iCE40 cerraba entre 9 y 28 MHz. En silicio la lógica es rápida; **lo caro es el área**, y ése es el
eje sobre el que gira todo este capítulo.

## 5.3.3 El recuento de celdas, y cómo cruzar las dos tablas

Esta advertencia no es un tecnicismo: afecta a cualquier comparación que un lector intente hacer entre
esta tabla y la de la §5.4.

Un circuito se puede contar en dos momentos del flujo, y las dos cifras son legítimas:

| Definición | Qué cuenta | Dónde se usa |
|---|---|---|
| celdas de **síntesis** | el resultado de traducir el RTL a compuertas | la tabla de la §5.4 |
| celdas **emplazadas** | lo que queda tras emplazar y rutear, con los amortiguadores que el flujo inserta para el árbol de reloj y la reparación de tiempos | **esta** tabla y la §5.6 |

Durante la redacción, la columna «celdas» de este capítulo **mezclaba las dos**, porque las fichas del
cuaderno habían registrado en cada momento el campo que la herramienta ofrecía. **Se rehízo el
recuento**: se contaron las instancias de celda estándar directamente sobre el **netlist posterior al
ruteado** de cada circuito archivado, descartando las celdas sin función lógica —relleno, contactos de
pozo, desacoplo y diodos de antena—, con un único criterio para los dieciséis.

El procedimiento se validó antes de aplicarlo: de los dieciséis circuitos, **ocho reprodujeron
exactamente la cifra que ya constaba**, hasta la unidad —los dos bloques de interfaz, los dos SoC, los
dos sistemas de visión y los dos circuitos en IHP—, que son precisamente aquellos cuya ficha ya
provenía del emplazamiento. Los ocho restantes cambiaron, y ése era el objetivo.

### El factor de conversión, medido

Como en nueve circuitos se conservan las dos cifras, el paso de una a otra no hay que estimarlo:

| | |
|---|---|
| Casos medidos | 9 |
| Factor medio | **×1,21** |
| Mediana | ×1,20 |
| Rango | ×1,16 a ×1,26 |
| Desviación típica | 0,04 |

**El emplazamiento agrega entre un 16 % y un 26 % de celdas**, con una dispersión estrecha. De modo
que una cifra de la §5.4 se lleva a la escala de ésta multiplicándola por 1,21, y el error de esa
conversión es de unos pocos puntos porcentuales — no del 20 % que separaba las tablas antes de
homogeneizarlas.

> **Por qué no se convirtió también la §5.4.** Dos de sus seis circuitos se archivaron sin netlist, de
> modo que convertir la tabla habría exigido estimar dos de las seis filas. Se prefirió dejar cada
> tabla **internamente homogénea** —la §5.4 entera en celdas de síntesis, ésta entera en celdas
> emplazadas— y publicar el factor que las relaciona, antes que producir una tabla mixta con dos
> filas estimadas. Las comparaciones dentro de cada tabla son exactas; las que cruzan de una a otra
> pasan por el factor.
