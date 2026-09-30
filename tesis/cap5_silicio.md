# 5. Los filtros en silicio: OpenLane, Magic y NGSpice

El capítulo anterior llevó los filtros y el SoC hasta la tarjeta. Éste los lleva a silicio: primero los
cambios que el mismo RTL necesita para pasar de la FPGA a un ASIC, después los bloques y la cadena
completa firmados en sky130 con OpenLane, y por último la verificación eléctrica del camino crítico
con Magic y NGSpice.

## 5.1 Del RTL al ASIC: los cuatro cambios obligatorios

El mismo Verilog no sirve para los dos destinos. Cuatro cosas hay que cambiar, y ninguna de ellas
produce un error de simulación —por eso son peligrosas.

**1. La memoria de programa debe sintetizarse.** Ya explicado en la §4.5: en silicio no existe el
*bitstream* que la inicializa.

**2. Reset explícito en todos los registros de control.** En una FPGA los biestables arrancan en el
valor que el *bitstream* les da; en silicio arrancan en un estado indefinido. Toda máquina de estados
necesita una señal de reinicio explícita, y omitirla produce un circuito que en simulación arranca
correctamente y en la mesa no arranca nunca.

**3. Fuera el tri-estado interno.** El bus de datos de la cámara es bidireccional y en FPGA se
describe con alta impedancia dentro del diseño. Un ASIC de celda estándar no dispone de eso: la señal
debe partirse en un dato y un habilitador —`cam_sda_o` y `cam_sda_oe`— y el tri-estado real ocurre en
el anillo de pads.

**4. Fuera las primitivas del fabricante.** Los bloques específicos de Lattice —el controlador del
LED RGB, entre otros— no existen en sky130. Se sustituyen por pines ordinarios o se eliminan.

> Los cuatro cambios comparten una propiedad que conviene subrayar: **ninguno produce un fallo
> visible en simulación RTL**. Un diseño con `initial` heredado de FPGA simula perfectamente y sale
> de fábrica mudo. Los dos únicos que se detectaron a tiempo durante este trabajo aparecieron en
> **simulación de compuertas**, después de la síntesis, y no antes.

> **Lo que no se aplicó a tiempo.** El generador de ventana `linebuf3x3` (Anexo G.1) no reinicia su
> contador de columna: lo arranca con un valor inicial (`reg x=0`), que la FPGA respeta y el silicio no.
> Con esa versión se firmaron los bloques `sobel`, `canny1`, `soc_sobel` y `soc_canny1` de la §5.2 y las
> seis cadenas completas de la §5.3. En silicio el contador arrancaría en un valor cualquiera. Como todas
> las filas comparten el mismo contador, un desfase no desalinea la ventana; sólo si arranca por encima
> del ancho de línea lee fuera de ella hasta dar la vuelta, que con nueve bits ocurre en a lo sumo 512
> píxeles. El efecto sería, como mucho, **las primeras líneas del primer cuadro erróneas**, no un chip
> mudo. En la simulación de compuertas, que representa ese arranque como un valor indefinido, la salida no
> se resuelve nunca, y así apareció, en Tiny Tapeout (§4.3.12). Los diseños posteriores —los reconocedores
> del Capítulo 7 y los proyectos de Tiny Tapeout— llevan el reinicio explícito; los GDS de las §5.2 y §5.3
> no se regeneraron. Que el DRC y el LVS den cero no dice nada de esto: ninguna de las dos comprobaciones
> mira el arranque.

## 5.2 Resultados en ASIC: los bloques

> **Sobre el recuento.** Toda la columna «celdas» de la tabla de esta sección son **celdas lógicas
> tras emplazamiento y ruteado**, recontadas con un mismo criterio desde los netlists archivados.
> Véase la §5.2.3 para cruzarlas con las de la §5.3.

Esta sección presenta los circuitos que implementan **una función cada uno**: los tres filtros por
separado, los mismos con procesador, dos bloques de interfaz y dos sistemas de visión. Son el
vocabulario con el que se construyen los sistemas de la §5.3, y su valor está en que permiten atribuir
el costo de cada pieza por separado.

Todos se llevaron a GDSII con **OpenLane** sobre el PDK abierto **sky130A**, biblioteca
`sky130_fd_sc_hd`.

### 5.2.1 La tabla

| Circuito | Función | Área del dado | Celdas | DRC · LVS · XOR |
|---|---|---:|---:|:-:|
| `sobel` | filtro Sobel 3×3 | 0,167 mm² | 5 823 | 0 · 0 · 0 |
| `canny1` | Canny de un salto, en flujo | 0,360 mm² | 12 993 | 0 · 0 · 0 |
| `transitivo` | Canny con histéresis transitiva | 3,13 mm² | 65 659 | 0 · 0 · 0 |
| `soc_sobel` | FemtoRV32 + Sobel | 0,37 mm² | 12 043 | 0 · 0 · 0 |
| `soc_canny1` | FemtoRV32 + Canny de un salto | 0,67 mm² | 22 054 | 0 · 0 · 0 |
| `soc_trans` | FemtoRV32 + transitivo | 3,42 mm² | 72 337 | 0 · 0 · 0 |
| `cam_frontend` | front-end de cámara OV7670 | 0,0177 mm² | 562 | 0 · 0 · 0 |
| `lcd_ili9341` | driver de pantalla TFT por SPI | 0,0174 mm² | 553 | 0 · 0 · 0 |
| `vision_top` | cámara + Sobel + framebuffer + pantalla | 1,75 mm² | 35 653 | 0 · 0 · 0 |
| `vision_canny` | cámara + Canny + framebuffer + pantalla | 2,04 mm² | 41 925 | 0 · 0 · 0 |

Table: Los bloques llevados a silicio en sky130: área, celdas y firma.

**Diez circuitos, diez veces DRC, LVS y XOR en cero.**

### 5.2.2 Lo que la tabla muestra de un vistazo

**El filtro transitivo cuesta casi veinte veces más área que el Sobel** —3,13 mm² contra 0,167, y
once veces más celdas— pese a ejecutar aritmética comparable. La razón, ya anticipada, es el cuadro completo residente: en la FPGA
ese cuadro vivía en SPRAM y no consumía lógica; aquí es un banco de biestables.

![**Figura 5.1.** El Canny transitivo en silicio: `trans_engine_top.gds` abierto en KLayout. Con
3,13 mm² es el bloque más grande de la tabla, porque el cuadro completo se guarda en
biestables.](figuras/fig_5_trans_asic.png)

**Los dos bloques de interfaz son casi gratis.** El front-end de cámara y el driver de pantalla ocupan
menos de dieciocho milésimas de milímetro cuadrado cada uno, alrededor de 560 celdas. Conviene tenerlo
medido porque desmonta una intuición común: el costo de un sistema de visión embebido no está en
hablar con los periféricos, está en lo que se hace con los datos entre medias.

![**Figura 5.2.** Los dos bloques de interfaz en silicio, en KLayout: el front-end de cámara
(`cam_frontend_top.gds`, 0,0177 mm²) y el controlador de pantalla (`lcd_ili9341_top.gds`, 0,0174 mm²).
Son los chips más pequeños del trabajo.](figuras/fig_5_interfaz_asic.png)

![**Figura 5.3.** El sistema de visión con el Sobel, `vision_top.gds`, en KLayout: a la izquierda el
dado de 1,75 mm²; a la derecha, un acercamiento a sus celdas.](figuras/fig_5_vision_asic.jpg)

![**Figura 5.4.** El sistema de visión con el Canny, `vision_canny_top.gds`, en KLayout: el dado de
2,04 mm² y un acercamiento a sus celdas, con las tres etapas del Canny y el
framebuffer.](figuras/fig_5_visioncanny_asic.jpg)

![**Figura 5.5.** Los dos sistemas de visión frente a frente: el Canny añade 0,29 mm² de dado, pasa de
35 653 a 41 925 celdas y de 66,9 a 90,9 mW de potencia típica estimada.](figuras/fig_5_vision_comparacion.png)

![**Figura 5.6.** Acercamiento al GDSII del `canny1` en KLayout. Lo que se ve no es un esquema sino
el plano que iría a fábrica: filas de celdas estándar y, sobre ellas, las capas de metal que las
conectan. La mancha más clara del centro es una región de menor densidad de ruteo. Las 12 993 celdas
de la tabla anterior son, literalmente, estas.](figuras/fig_5_2_malla_canny1.jpg)

**Los dos primeros filtros caben también en Tiny Tapeout.** Envueltos para la lanzadera, el Sobel ocupa
3×2 mosaicos y el Canny de un salto 6×2, los dos con la comprobación previa entera y el LVS en cero
(§4.3.12 y §4.3.13); el transitivo, con su cuadro entero, no cabe en ninguna.

![**Figura 5.7.** El Sobel en Tiny Tapeout, `tt_um_sobel_vic`: 3×2 mosaicos, 0,115 mm², tal como lo
dibuja el visor de la lanzadera.](figuras/fig_5_tt_sobel.png)

![**Figura 5.8.** El Canny de un salto en Tiny Tapeout, `tt_um_canny1_vic`: 6×2 mosaicos,
0,233 mm².](figuras/fig_5_tt_canny1.png)

**Y el Sobel en silicio es mucho más rápido de lo que la FPGA permitía.** Su camino crítico quedó en
**7,69 ns** frente a un objetivo de 20 ns, es decir que soportaría unos 130 MHz, mientras que en la
iCE40 cerraba entre 9 y 28 MHz. En silicio la lógica es rápida; **lo caro es el área**, y ése es el
eje sobre el que gira todo este capítulo.

![**Figura 5.9.** El filtro Sobel en silicio: `sobel_top.gds` abierto en KLayout. Con 0,167 mm² es el
filtro más pequeño de la tabla; en el perímetro, los pines del píxel de entrada y de
salida.](figuras/fig_4_sobel_asic.png)

![**Figura 5.10.** El SoC con el Sobel en silicio: `soc_sobel_top.gds` en KLayout. Con 0,37 mm², el
procesador, su ROM y su periférico añaden 6 220 celdas al filtro solo de la figura
anterior.](figuras/fig_5_socsobel_asic.png)

![**Figura 5.11.** El SoC con el Canny de un salto en silicio: `soc_canny1_top.gds` en KLayout,
0,67 mm².](figuras/fig_5_soccanny_asic.png)

![**Figura 5.12.** El SoC con el Canny transitivo en silicio: `soc_trans_top.gds` en KLayout, 3,42 mm².
El procesador ocupa una parte pequeña; el resto es el motor y su cuadro de unos 10 600
biestables.](figuras/fig_5_soctrans_asic.png)

### 5.2.3 El recuento de celdas, y cómo cruzar las dos tablas

Esta advertencia no es un tecnicismo: afecta a cualquier comparación que un lector intente hacer entre
esta tabla y la de la §5.3.

Un circuito se puede contar en dos momentos del flujo, y las dos cifras son legítimas:

| Definición | Qué cuenta | Dónde se usa |
|------------------|------------------------------------------------------------|--------------------------|
| celdas de **síntesis** | el resultado de traducir el RTL a compuertas | la tabla de la §5.3 |
| celdas **emplazadas** | lo que queda tras emplazar y rutear, con los amortiguadores que el flujo inserta para el árbol de reloj y la reparación de tiempos | **esta** tabla y el Capítulo 7 |

Table: Las dos definiciones de «celda» y dónde se usa cada una.

Durante la redacción, la columna «celdas» de este capítulo **mezclaba las dos**, porque en cada momento
se había registrado el campo que la herramienta ofrecía. **Se rehízo el
recuento**: se contaron las instancias de celda estándar directamente sobre el **netlist posterior al
ruteado** de cada circuito archivado, descartando las celdas sin función lógica —relleno, contactos de
pozo, desacoplo y diodos de antena—, con un único criterio para los dieciséis.

El procedimiento se validó antes de aplicarlo: de los dieciséis circuitos, **ocho reprodujeron
exactamente la cifra que ya constaba**, hasta la unidad —los dos bloques de interfaz, los dos SoC, los
dos sistemas de visión y los dos circuitos en IHP—, que son precisamente aquellos cuya ficha ya
provenía del emplazamiento. Los ocho restantes cambiaron, y ése era el objetivo.

#### El factor de conversión, medido

Como en nueve circuitos se conservan las dos cifras, el paso de una a otra no hay que estimarlo:

| | |
|---|---|
| Casos medidos | 9 |
| Factor medio | **×1,21** |
| Mediana | ×1,20 |
| Rango | ×1,16 a ×1,26 |
| Desviación típica | 0,04 |

Table: Factor de conversión de celdas de síntesis a celdas tras el emplazamiento, medido sobre nueve circuitos.

**El emplazamiento agrega entre un 16 % y un 26 % de celdas**, con una dispersión estrecha. De modo
que una cifra de la §5.3 se lleva a la escala de ésta multiplicándola por 1,21, y el error de esa
conversión es de unos pocos puntos porcentuales — no del 20 % que separaba las tablas antes de
homogeneizarlas.

> **Por qué no se convirtió también la §5.3.** Dos de sus seis circuitos se archivaron sin netlist, de
> modo que convertir la tabla habría exigido estimar dos de las seis filas. Se prefirió dejar cada
> tabla **internamente homogénea** —la §5.3 entera en celdas de síntesis, ésta entera en celdas
> emplazadas— y publicar el factor que las relaciona, antes que producir una tabla mixta con dos
> filas estimadas. Las comparaciones dentro de cada tabla son exactas; las que cruzan de una a otra
> pasan por el factor.

## 5.3 Resultados en ASIC: la cadena de visión completa

La §5.2 presentó bloques: filtros solos, un front-end de cámara, un driver de pantalla. Ésta presenta
**sistemas**: seis circuitos que llevan la cadena entera —captura, filtrado, almacenamiento y
visualización— en un solo dado. Los seis están organizados como una matriz de dos variables, el
**filtro** y la **presencia de procesador**, de modo que cada comparación entre dos de ellos aísla una
sola causa.

\needspace{14\baselineskip}

### 5.3.1 La tabla maestra

| # | Diseño | Área (mm²) | Celdas | Reloj de firma | Setup con parásitos | DRC · LVS · XOR |
|---|--------------------|--------:|--------:|------------------:|-------------:|:------------:|
| #1 | Sobel ᵃ | 2,45 | 36 730 | 20 ns · 50,0 MHz | sin dato ᵇ | 0 · 0 · 0 |
| #2 | Canny1 ᵃ | 2,90 | 42 581 | 20 ns · 50,0 MHz | sin dato ᵇ | 0 · 0 · 0 |
| #3 | Transitivo | 9,61 | 137 092 | 20 ns · 50,0 MHz | **−19,35 ns** | 0 · 0 · 0 |
| #4 | SoC + Sobel | 3,03 | 46 019 | 32 ns · 31,2 MHz | **+0,00 ns** | 0 · 0 · 0 |
| #5 | SoC + Canny1 | 3,44 | 51 037 | 36 ns · 27,8 MHz | **+0,00 ns** | 0 · 0 · 0 |
| #6 | SoC + Transitivo | 10,19 | 146 216 | 36 ns · 27,8 MHz | **−18,23 ns** | 0 · 0 · 0 |

Table: Tabla maestra de la cadena de visión completa en silicio.

Los seis son la cadena completa —cámara, filtro, memoria y pantalla—; los tres de abajo llevan además el
procesador FemtoRV32. Sus directorios se llaman `sobel_completo`, `canny1_completo` y `trans_completo`,
y `soc_sobel_completo`, `soc_canny1_completo` y `soc_trans_completo` los que llevan procesador.

ᵃ Estos dos se archivaron sin el directorio de reportes; sus cifras provienen de lo registrado en su
momento y no de un `metrics.csv` del flujo. Se marcan porque en una tabla de resultados debe poder decirse de
dónde sale cada número.

ᵇ Su ficha registra el **WNS nominal** —0,00 ns, sin violaciones— pero no quedó registrado el setup ya
con parásitos extraídos, que es justamente la columna que hunde a los dos transitivos. Se deja en
blanco antes que suponer que cierran.

**Los seis llegaron a GDSII con DRC, LVS y XOR en cero.** Cuatro cierran temporizado o carecen del dato
para afirmar lo contrario; los dos transitivos no cierran, y conviene decirlo con el número: el #3
pediría 39,4 ns —25,4 MHz— y el #6, 54,2 ns, es decir 18,4 MHz en lugar de los 27,8 solicitados.

![**Figura 5.13.** El Sobel completo, #1 de la tabla, en silicio: `sobel_completo.gds` en KLayout,
2,45 mm². Los pines de la cámara y de la pantalla recorren el perímetro.](figuras/fig_5_sobelcomp_asic.png)

![**Figura 5.14.** El transitivo completo, #3 de la tabla, en KLayout: a la izquierda el dado entero,
de unos 3,1 × 3,1 mm, con los pines de la cámara, la pantalla y la alimentación en el borde; a la
derecha, un acercamiento a sus filas de celdas.](figuras/fig_5_visiontrans_asic.jpg)

![**Figura 5.15.** Lo que costó llegar a ese plano. A la izquierda, las violaciones de DRC con un
framebuffer de ocho bits y una utilización del 35 %, frente a ninguna con uno de un bit y una del 15 %.
A la derecha, el área del Sobel solo frente a la de la cadena completa.](figuras/fig_5_sobelcomp_congestion.png)

![**Figura 5.16.** El Canny 1-streaming completo, #2 de la tabla, en KLayout: a la izquierda el dado
entero, `canny1_completo.gds`, de 2,90 mm²; a la derecha, un acercamiento al ruteo, con las celdas de
sky130 y las capas de metal que llevan el píxel de la cámara a la pantalla.](figuras/fig_5_cannycomp_asic.jpg)

> **Sobre el recuento de celdas, y es importante al leer junto a la §5.2.** Las cifras de esta tabla
> son **celdas de síntesis**; las de la §5.2 y las del Capítulo 7 son **celdas emplazadas**. Cada tabla es
> internamente homogénea, y el paso de una escala a otra **está medido sobre nueve circuitos que
> conservan las dos cifras**: el emplazamiento agrega entre un 16 % y un 26 %, con un factor medio de
> **×1,21** y una desviación típica de 0,04. Para comparar una cifra de aquí con una de allá,
> multiplíquese por 1,21; el detalle del procedimiento está en la §5.2.3.
>
> Dos de los seis circuitos de esta tabla se archivaron sin *netlist*, razón por la cual no se
> convirtió la tabla entera: se prefirió una tabla homogénea en su propia escala antes que una tabla
> mixta con dos filas estimadas.

![**Figura 5.17.** El mismo tipo de acercamiento, ahora sobre el sistema de visión completo. La
diferencia con la figura anterior no está en la textura sino en la escala: aquí caben cámara, filtro,
memoria de cuadro y controlador de pantalla en el mismo dado. Es la forma que toma en silicio la
frase «el filtro es una pieza y no el circuito».](figuras/fig_5_3_mar_de_celdas_vision.jpg)

### 5.3.2 El procesador cuesta lo mismo, sea cual sea el filtro

Restando cada chip de su gemelo con procesador se obtiene el costo del FemtoRV32, su memoria de
programa y su periférico:

| Filtro | sin CPU | con CPU | Δ celdas | Δ relativo |
|---|---:|---:|---:|---:|
| Sobel | 36 730 | 46 019 | **+9 289** | +25,3 % |
| Canny de un salto | 42 581 | 51 037 | **+8 456** | +19,9 % |
| Canny transitivo | 137 092 | 146 216 | **+9 124** | +6,7 % |

Table: Costo del procesador según el filtro que acompaña.

El incremento absoluto es **prácticamente constante**: alrededor de nueve mil celdas, con una
dispersión de ±5 % en torno a la media, entre el caso más barato y el más caro. Es un resultado esperable —el
procesador no sabe qué filtro tiene al lado— pero conviene tenerlo medido, porque convierte al
procesador en un **costo fijo y presupuestable** frente a un datapath cuyo costo varía en un factor de
cuatro.

La columna relativa dice lo contrario que la absoluta, y las dos son ciertas: el mismo procesador
representa una cuarta parte del chip más pequeño y apenas una quinceava parte del más grande. Cuál de
las dos lecturas importa depende de la pregunta. Para decidir si añadir un procesador a un diseño
dado, manda la absoluta.

### 5.3.3 Lo que de verdad cuesta caro no es el cerebro: es la memoria

El mismo ejercicio, hecho ahora sobre el eje del filtro en lugar del procesador, produce el resultado
central de este capítulo:

| Alcance del patrón | Filtro | Celdas (sin CPU) | Δ respecto al anterior |
|-----------------------|-----------------|----------------:|----------------------:|
| local, ventana 3×3 | Sobel | 36 730 | — |
| local más un salto | Canny de un salto | 42 581 | +5 851 |
| **global, cuadro completo** | Canny transitivo | **137 092** | **+94 511** |

Table: Costo de ampliar el alcance del patrón, de un filtro al siguiente.

Pasar de mirar una ventana de 3×3 a mirar un salto más cuesta menos de seis mil celdas. Pasar de ahí a
**mirar el cuadro entero** cuesta noventa y cuatro mil quinientas once.

La comparación directa es la que conviene enunciar: **un procesador RISC-V completo, con su memoria y
su periférico, pesa aproximadamente la décima parte de lo que pesa cambiar el alcance del patrón de
local a global.** Nueve mil celdas contra noventa y cuatro mil quinientas.

Y la razón no está en la aritmética. Los tres filtros ejecutan esencialmente las mismas operaciones
sobre cada píxel; lo que cambia es **cuánto estado hay que sostener simultáneamente**. El Sobel y el
Canny de un salto procesan en flujo y necesitan unas pocas líneas de la imagen —los *line-buffers* de
la §4.6—, mientras que la histéresis transitiva necesita el cuadro completo residente y accesible en
cualquier orden, porque su punto fijo puede propagar una decisión desde cualquier píxel hacia
cualquier otro. En una FPGA ese cuadro es un bloque de memoria que ya está en el sustrato; en un ASIC
sin macro de memoria es un banco de biestables, y se paga en área, en potencia y en frecuencia.

> Éste es, en una sola cifra, el argumento que el Capítulo 8 desarrolla: **lo que decide si un
> algoritmo cabe en silicio no es su complejidad aritmética sino su huella de memoria.** Los dos
> transitivos son además los dos únicos chips de la tabla que no cierran temporizado, lo que muestra
> que el precio de esa memoria no se cobra sólo en milímetros cuadrados.

### 5.3.4 Balance

Seis circuitos, 459 675 celdas en total, **seis de seis con DRC = LVS = XOR = 0**. Dos cierran
temporizado con parásitos extraídos, dos carecen de ese dato por haberse archivado sin reportes, y dos
no cierran y se documentan con la frecuencia que sí soportarían.

Ninguno ha sido fabricado. La §9.4 describe la vía por la que podrían serlo.

## 5.4 Verificación eléctrica del camino crítico

Todas las cifras de esta sección proceden de corridas de NGSpice sobre `sky130_fd_sc_hd` en la
esquina típica, a 1,8 V y 25 °C, y de los ficheros de parásitos extraídos de los dos reconocedores.

Las secciones anteriores aceptaron sin discusión lo que el analizador de tiempos informa. Ésta
pregunta si ese número es correcto, y lo hace por el único camino que no depende de la misma
herramienta: **resolver los transistores**.

La pregunta no es ociosa. Un analizador estático no simula: consulta tablas caracterizadas de
antemano e interpola. Es rapidísimo y es lo que permite firmar un circuito de doscientas mil
instancias, pero entre su respuesta y la física median un modelo de celda, un modelo de cable y un
procedimiento de interpolación. Comprobar cuánto de lo que informa sobrevive a una simulación
eléctrica es, por tanto, una verificación del instrumento y no del circuito.

### 5.4.1 Por qué el camino crítico y no el chip

Simular los dos reconocedores enteros no es inviable por tamaño —`pan_sobel` tiene 116 314
transistores y en este trabajo ya se simuló un procesador de 121 310— sino **por tiempo**: para que
el clasificador vea sus 784 píxeles hay que hacerle entrar un cuadro completo, y eso son 633 800
ciclos, unos treinta y dos veces más actividad que la simulación de procesador ya realizada.

El camino crítico, en cambio, son **treinta y siete celdas** en un chip y treinta y seis en el otro.
Se extrajeron del reporte del analizador, se reconstruyeron como cadena aislada con la carga y la
pendiente que el propio reporte declara en cada etapa, y se resolvieron en NGSpice.

### 5.4.2 El resultado

Se aplicaron cinco variantes del mismo banco, cada una añadiendo un ingrediente al anterior, de modo
que la diferencia entre dos renglones consecutivos aísla la contribución de ese ingrediente:

| | `pan_sobel` (37 etapas) | `pan_canny` (36 etapas) |
|---------------------------------------------------------|---------------------:|---------------------:|
| **Analizador estático, con parásitos** | **12,230 ns** | **9,890 ns** |
| A · las puertas solas | 4,646 ns | 4,424 ns |
| B · más la capacitancia extraída, agrupada | 8,159 ns | 7,552 ns |
| C · más la pendiente de entrada real | 8,178 ns | 7,588 ns |
| D0 · más la topología del fichero de parásitos, **con R = 0** | 7,603 ns | 7,022 ns |
| D · más la **resistencia medida** de cada tramo | 7,620 ns | 7,043 ns |
| E · más la **celda extraída del *layout*** | **9,694 ns** | **8,962 ns** |
| *fracción del retardo que la simulación reproduce* | *79,3 %* | *90,6 %* |

Table: Descomposición del retardo del camino crítico: cinco variantes del banco de simulación frente al analizador estático.

La variante **D0 es un control**, idéntica a la D salvo en que sus resistencias valen cero. Sin ella,
el efecto de la resistencia y el de *repartir* la capacitancia a lo largo del árbol en vez de
agruparla en un nodo quedarían sumados en una sola cifra y no podrían separarse.

![**Figura 5.18.** El desglose completo de la verificación. El panel A explica por qué se simula el
camino y no el chip; el B reparte los 12,23 ns del `pan_sobel` y los 9,89 del `pan_canny` en sumandos
que no dejan residuo; el C recoge las tres hipótesis que la medida desmintió; el D contrapone la
celda del esquemático con la extraída del dibujo en los dos experimentos independientes; y el E
separa lo que quedó cerrado de lo que se deja escrito como abierto.](figuras/fig_5_8_spice_desglose.png)

### 5.4.3 Tres explicaciones que la medida desmintió

Las tres parecían razonables, y conviene dejar constancia de las tres.

**El flanco de entrada idealizado.** El estímulo inicial era una rampa de 20 ps, mucho más limpia que
la transición que la primera etapa recibe en el circuito; cabía esperar que un frente degradado se
propagase como retardo a lo largo de las treinta y siete etapas. Sustituido por la pendiente real que
el reporte declara, la contribución resultó de **0,019 ns: el 0,2 %**.

**La capacitancia de las redes grandes.** Las desviaciones mayores se concentraban en puertas de
muchas entradas, lo que sugería redes largas y cargadas. Se midió la correlación entre la desviación
de cada etapa y su capacitancia: **r = −0,15**; y con el número de destinos: **r = −0,06**. Ninguna
de las dos sostiene la explicación.

**La resistencia de la interconexión.** Descartadas las anteriores quedaba ésta, y **así se dio por
concluida la primera versión de esta sección**: el analizador trabaja sobre el fichero de parásitos,
que informa resistencia y capacitancia de cada red, mientras que el reporte de texto publica sólo la
capacitancia, de modo que la simulación habría recibido una descripción incompleta de los cables. La
conjetura no pudo comprobarse entonces porque ese fichero no se había conservado.

Recuperado, se midió. **La resistencia de la interconexión aporta 0,017 ns: el 0,1 % del camino.** No
los cuatro nanosegundos que había que explicar.

> **El propio reporte lo decía, y no se leyó.** El analizador imputa cada retardo a un pin, y los de
> pin de salida son de celda mientras que los de pin de entrada son de cable. Sumados por separado a
> lo largo del camino: **12,18 ns imputados a celda y 0,04 ns a cable**. La herramienta nunca
> atribuyó el tiempo a la interconexión. Bastaba con sumar dos columnas.

### 5.4.4 La causa: la celda del esquemático no es la celda del silicio

Si la diferencia está dentro de las celdas, hay que preguntárselo a una celda sola. El banco se
redujo al mínimo —una celda, el arco que el camino recorre, la pendiente y la carga que el reporte
declara— y se hizo la misma pregunta dos veces: a la tabla caracterizada, interpolando como hace el
analizador, y al simulador, resolviendo los transistores que el kit de diseño distribuye.

La tabla reproduce al analizador casi exactamente, lo que confirma que éste se limita a consultarla.
La simulación, en cambio, queda **sistemáticamente por debajo en treinta y cinco de las treinta y
siete etapas**, con una razón de **1,31** que no depende ni de la carga ni de la pendiente. Esa
independencia es la que descarta un defecto del banco y señala a la celda misma.

La causa está en el fichero que se le entregó como modelo. El kit distribuye el netlist
**esquemático**: doce transistores y ni un solo parásito. La biblioteca caracterizada, en cambio, se
obtuvo sobre la celda **dibujada**, con el metal, los contactos y la difusión que el *layout* añade.
Al simulador se le describió la celda antes de dibujarla.

Eso admite medición directa. Inyectando una rampa lenta en cada pin de entrada e integrando la
corriente —capacitancia como carga dividida por tensión, sin modelo ni supuesto— la biblioteca
atribuye a cada pin, en promedio sobre los treinta y cinco del camino, **un 30 % más de capacitancia
de la que el esquemático tiene**.

> **Dos experimentos distintos, la misma cifra.** La razón entre el retardo que la biblioteca declara
> y el que la simulación obtiene sobre el esquemático es **1,31**. La razón entre la capacitancia que
> la biblioteca declara y la que el esquemático tiene es **1,30**. Uno mide tiempos y el otro mide
> carga, sobre las mismas treinta y siete etapas.

**La comprobación.** Lo anterior establece que al esquemático le faltan parásitos, no que sean *ésos*
los que faltan. El kit no distribuye el netlist de la celda dibujada, pero sí el dibujo: se
extrajeron con Magic las **cuarenta y seis celdas** que aparecen en los dos caminos y se repitieron
los dos experimentos sin cambiar nada más.

| razón biblioteca / simulación | celda del **esquemático** | celda **extraída** |
|------------------------------------|---------------------:|--------------:|
| capacitancia de pin · `pan_sobel` | 1,30 | **0,98** |
| capacitancia de pin · `pan_canny` | 1,27 | **0,99** |
| retardo de celda aislada · `pan_sobel` | 1,31 | **1,05** |
| retardo de celda aislada · `pan_canny` | 1,30 | **1,06** |

Table: Razón entre biblioteca y simulación, con la celda del esquemático y con la celda extraída del layout.

**La discrepancia de capacitancia desaparece.** La hipótesis queda medida y no deducida, que era
justamente lo que faltaba.

### 5.4.5 La cuenta, y lo que queda abierto

Repartidos los 12,230 ns sin residuo, el término que importa sale igual en los dos circuitos:

| | `pan_sobel` | `pan_canny` |
|--------------------------------------------|---------:|---------:|
| **el modelo de celda, como fracción del camino** | **22,6 %** | **22,1 %** |
| resistencia de la interconexión | 0,1 % | 0,2 % |

Table: Contribución del modelo de celda y de la resistencia de la interconexión al camino crítico.

Dos circuitos distintos, dos caminos críticos que no comparten una sola instancia, y la misma cifra a
cinco décimas de punto: **algo más de la quinta parte del retardo de un camino crítico la ponen los
parásitos que el dibujo añade dentro de las celdas.**

![**Figura 5.19.** La salida del simulador, tal como éste la dibuja. Cada traza es un nodo del camino
crítico, desplazada dos voltios respecto de la anterior para que las diez quepan en el mismo eje; la
cascada de transiciones de arriba abajo es la señal propagándose etapa por etapa. El último nodo del
`pan_sobel` conmuta a unos 8,2 ns y el del `pan_canny` a unos 7,6, que son las variantes C de la
Tabla 5.7.](figuras/fig_5_9_spice_ondas.png)

**Lo que no cerró, y se deja escrito.** Queda un 5 % por celda —0,528 ns en un chip y 0,530 en el
otro, prácticamente el mismo valor absoluto en dos caminos distintos— que la extracción no recupera.
La explicación más probable es que el procedimiento empleado conserva las **capacidades** internas de
la celda pero no sus **resistencias**, de modo que su metal interno sigue comportándose como un
cortocircuito ideal. Se anota como **probable y no comprobada**. Y la realimentación de pendientes a
lo largo de la cadena resulta asimétrica entre los dos chips (+1,47 ns en uno y −0,04 en el otro)
sin explicación disponible.

> **La conclusión.** El simulador y el analizador no discrepan sobre la física: discrepan sobre el
> circuito. Al analizador se le describió la celda tal como quedó en el *layout*; al simulador, tal
> como estaba en el esquema.
>
> La verificación eléctrica no midió, por tanto, que el analizador se equivocara. Midió **cuánto del
> retardo de un circuito integrado lo pone el dibujo y no el esquema**: algo más de la quinta parte,
> y la misma fracción en dos chips independientes. Es una cifra más útil que la que se buscaba, y
> explica por qué ninguna implementación puede firmarse sobre el esquemático.
