# 4. Diseño e implementación

> **Estado:** borrador 1, escrito el 2026-09-21. Fuente: cuaderno 1, Partes 25-28, 45-76, 88-131,
> 152, 157-165; y los fuentes en `asic/*/src/`.
> Las cifras y las expresiones de este capítulo se leyeron del RTL, no de las notas.

Este capítulo describe **cómo está construido** el sistema. Sigue el orden en que los datos lo
atraviesan —de la cámara a la pantalla— y reserva para el final las dos traducciones que el mismo
RTL tuvo que sufrir para existir en dos sustratos distintos.

## 4.1 Arquitectura

La cadena consta de cuatro etapas en serie y un procesador **al costado**, no en medio:

$$\text{cámara} \rightarrow \text{filtro} \rightarrow \text{almacenamiento} \rightarrow \text{pantalla}$$

Que el procesador quede al costado es la decisión de arquitectura más importante del trabajo. **Los
píxeles no pasan por el bus.** El FemtoRV32 no lee la imagen, no la escribe y no participa del camino
de datos: escribe un registro de configuración —el umbral— y lee un resultado. Si se detuviera, el
filtrado continuaría.

La consecuencia es que el caudal del sistema no depende de la frecuencia del procesador ni del número
de ciclos que consuma una instrucción, y por eso el §5.5 puede afirmar que la presencia del procesador
no altera la latencia del cauce: cuatro ciclos siguen siendo cuatro ciclos.

### Dos dominios de reloj

El sistema tiene **dos relojes asíncronos entre sí**:

| Dominio | Frecuencia | Qué vive ahí |
|---|---|---|
| `clk` | 50 MHz (20 ns) | configuración SCCB, generación del raster, driver de pantalla |
| `cam_pclk` | 25 MHz (40 ns) | captura, submuestreo, filtro, escritura del almacenamiento |

La frontera entre ambos atraviesa el circuito **por el almacenamiento**: la cámara escribe en su
reloj y la pantalla lee en el suyo. El único otro punto de cruce, en los diseños que reconocen, son
los dos biestables que llevan el dígito al dominio de la pantalla. Todo lo demás vive enteramente a
un lado o al otro, lo que reduce el problema de cruce de dominios a dos casos tratables por separado.

## 4.2 Front-end de cámara

### Configuración por SCCB

La OV7670 arranca en un modo que no sirve, de modo que hay que programarla. El circuito incluye una
máquina de estados que implementa **SCCB** —el protocolo de dos hilos de OmniVision— y escribe tres
registros:

| Registro | Valor | Efecto |
|---|---|---|
| `0x12` | `0x00` | reinicio de la configuración |
| `0x13` | `0xE7` | habilita AGC, AWB y AEC automáticos |
| `0x09` | `0x18` | configura los pines de control |

La máquina espera un arranque largo —un contador de veinte bits— antes de emitir el primer bit,
porque el sensor necesita tiempo tras la alimentación. Al terminar activa `cfg_done`, que además
actúa de reset para las etapas aguas abajo: nada procesa píxeles hasta que la cámara está configurada.

### La captura, y el byte que importa

El sensor emite **YUV422**, es decir la secuencia `U Y V Y`, de modo que la luminancia es **uno de
cada dos bytes**. La distinción no es un detalle de formato: capturar el byte equivocado devuelve la
crominancia, que en una escena normal es aproximadamente constante alrededor de `0x80`.

Este error se produjo durante el desarrollo y **no se detectó mirando la pantalla**, porque una
imagen de crominancia plana se parece a una imagen mal expuesta. Se detectó haciendo que la placa
imprimiera por el puerto serie los valores de píxeles vecinos: la secuencia `80 80 80 80 81 80 83` no
es una imagen, es una constante con ruido. La corrección es una línea —capturar en la paridad
opuesta— y el diagnóstico que la hizo posible fue **cambiar de instrumento**, no mirar más fuerte.

### El cruce de dominios

El dígito reconocido cruza de `cam_pclk` a `clk` mediante **dos biestables en cadena**. Es el
sincronizador clásico de dos etapas, y aquí es suficiente porque la señal es *casi estática*: cambia
como mucho una vez por cuadro, es decir cada varios millones de ciclos. Un sincronizador de dos
biestables es inadecuado para un bus, pero correcto para un valor que permanece estable durante
órdenes de magnitud más tiempo que el período de reloj.

El almacenamiento, en cambio, **no se sincroniza**: se escribe en un reloj y se lee en el otro sin
protección, porque la escritura completa un cuadro antes de que la lectura lo alcance. Es una
decisión deliberada y conviene declararla como tal.

## 4.3 Los tres filtros

### Sobel: aritmética sin multiplicadores

El operador de Sobel–Feldman aplica dos núcleos de 3×3 cuyos pesos son `1`, `2` y `4`. Siendo
potencias de dos, **la multiplicación se implementa como desplazamiento**, y el cálculo entero del
gradiente se reduce a sumas y restas:

```verilog
wire [10:0] gxp = w02 + (w12<<1) + w22;
wire [10:0] gxn = w00 + (w10<<1) + w20;
wire [10:0] gyp = w20 + (w21<<1) + w22;
wire [10:0] gyn = w00 + (w01<<1) + w02;
```

La magnitud usa la norma **L1**, `|Gx|+|Gy|`, en lugar de la euclídea, evitando la raíz cuadrada. El
resultado se compara contra un umbral, que es otra comparación.

**El camino de datos de imagen no contiene un solo multiplicador**, y esa propiedad es la que hace
posible la igualdad bit a bit con el modelo de referencia que documenta la §5.1: no hay ninguna
operación cuyo redondeo pueda diferir entre una biblioteca de punto flotante y un circuito.

### La ventana deslizante

Los tres filtros necesitan una ventana de 3×3, es decir tres filas simultáneas de la imagen. El
módulo `linebuf3x3` las proporciona con **dos memorias de línea** —las filas *n−2* y *n−1*— mientras
la fila *n* llega directamente del flujo. Almacenar dos filas y no tres es la diferencia entre un
buffer y una copia de la imagen, y es el fundamento de toda la arquitectura de flujo.

### Canny de un salto

El Canny completo consta de suavizado gaussiano, cálculo del gradiente, supresión de no-máximos,
doble umbral e histéresis. La histéresis es el problema: exige seguir cadenas de píxeles débiles
conectados a fuertes, lo que en general requiere recorrer el cuadro varias veces.

La implementación en flujo aproxima ese paso con un **salto único**: un píxel débil se promueve a
borde si *alguno de sus ocho vecinos inmediatos* es fuerte. Es una histéresis de radio uno, y captura
la mayor parte del efecto porque en una imagen real los débiles forman un halo fino alrededor de los
fuertes —afirmación que la §5.5.3 confirma midiendo que el proceso completo converge en dos pasadas.

El precio arquitectónico es que esta cadena encadena **tres** etapas de ventana 3×3 en lugar de una,
y por eso necesita tres `linebuf3x3` y presenta ocho ciclos de latencia de cauce frente a los cuatro del
Sobel. El esquemático generado de la §35 muestra las tres cajas.

### Canny transitivo: la histéresis como punto fijo

El tercer filtro no aproxima: resuelve la histéresis completa. Formalmente es una **reconstrucción
morfológica** —la reconstrucción de la máscara de píxeles débiles a partir de los fuertes como
marcadores, bajo conectividad de ocho vecinos— y su resultado es el **punto fijo** de la operación
«promover todo débil adyacente a un borde confirmado».

La implementación es un motor con máquina de estados que **barre el cuadro repetidamente** y termina
cuando un barrido completo no produce ningún cambio. El número de barridos, *K*, no es una constante
del diseño sino una propiedad de la imagen, y la §5.5.3 lo mide: dos para bordes reales, cincuenta y
uno en el peor caso construido.

Esta es la única de las tres arquitecturas que **exige el cuadro completo residente**, y de esa
exigencia se derivan casi todos los resultados del Capítulo 6.

## 4.4 El SoC: procesador, periférico y firmware

El procesador es un **FemtoRV32 Quark**, una implementación mínima de RV32I. Se le añaden una memoria
de programa y un **periférico mapeado en memoria en la base `0x0045_0000`** a través del cual escribe
el umbral del filtro y lee el estado.

Esa dirección no es arbitraria, y conviene explicarla porque sitúa el trabajo. La arquitectura de
bus, el decodificador que compara `mem_addr[31:16]` contra una lista de bases y el conjunto de
periféricos —comunicación serie en `0x0040`, puertos de propósito general en `0x0041`, multiplicador
en `0x0042`, divisor en `0x0043` y conversión a decimal codificado en `0x0044`— proceden del **SoC de
referencia descrito por Camargo (2025, §1.2.1)**, que es el material sobre el que se enseña diseño
digital en el programa. **Este trabajo añade un periférico más, en la base siguiente.**

![**Figura 4.1.** El sistema en silicio, en el lenguaje de bloques del SoC de referencia. Los siete
periféricos en gris son los heredados; el que aparece destacado, en la base `0x0045`, es la
aportación de este trabajo. Obsérvese que **el camino de datos de imagen no pasa por el bus**: los
píxeles entran de la cámara al filtro y salen de éste a la pantalla a un píxel por ciclo, y lo único
que el procesador pone en el bus es el umbral.](figuras/fig_4_1_soc.png)

La figura muestra por qué este periférico no se parece a los demás. Un multiplicador o un divisor
reciben sus operandos por el bus y devuelven el resultado por el bus: el procesador los usa. El
filtro, en cambio, **tiene su propio camino de datos** —de la cámara a la pantalla, a un píxel por
ciclo— y del bus recibe únicamente un parámetro de configuración. El procesador no lo usa: lo
**ajusta**.

> Esa distinción es la que el Capítulo 6 convierte en argumento. Un periférico que procesa a través
> del bus está limitado por el ancho de banda del bus; uno que procesa al margen de él, no. Es la
> razón de que un sistema de visión en tiempo real pueda construirse sobre un procesador de siete
> instrucciones.

El firmware ocupa **siete instrucciones**: inicializa, escribe el umbral y queda en un lazo. No es un
programa modesto por limitación sino por diseño — el procesador existe para poder cambiar un
parámetro en tiempo de ejecución, no para procesar.

### La ROM sintetizada

En una FPGA el contenido de la memoria de programa se carga con el *bitstream*. **En un ASIC no hay
nada que lo cargue**: los biestables arrancan en un estado indefinido. La memoria de programa debe
por tanto sintetizarse como lógica combinacional —una tabla de constantes— y no como un arreglo
inicializado.

Es el primero de los cuatro cambios obligatorios de la §4.7, y el que más sorprende a quien llega
desde FPGA, porque el código funciona idénticamente en simulación en ambos casos.

## 4.5 Memoria: la batalla de los recursos

La iCE40UP5K ofrece tres clases de almacenamiento, y el diseño usa las tres con criterios distintos:

| Recurso | Cantidad | Uso en este trabajo |
|---|---|---|
| Celdas lógicas | 5 280 | lógica y registros pequeños |
| Bloques de memoria (4 kbit) | 30 | **memorias de línea** de las ventanas 3×3 |
| SPRAM (256 kbit) | 4 | **framebuffers** del filtro transitivo |

La asignación no es libre: una memoria de línea cabe en un bloque de memoria si el sintetizador la
reconoce como tal, y no la reconoce si el código la escribe de una forma que no encaja con el patrón
esperado. Varios de los problemas de recursos del desarrollo fueron de esa naturaleza —memorias que
se convertían en biestables por un detalle de escritura del RTL— y no de tamaño real del diseño.

El caso más costoso fue un **ancho de puntero insuficiente**: un contador de direcciones con un bit
de menos del necesario direcciona la mitad de la memoria y sobrescribe la otra, produciendo una
imagen que se ve plausible pero está mal. Como en el caso del byte de luminancia, el error sobrevive
a la inspección visual.

> Este apartado es el origen del título del Capítulo 6. En la FPGA los dos primeros recursos parecen
> gratuitos porque ya están en el sustrato; en el ASIC ninguno lo es, y el mismo RTL que allí cabía
> holgadamente aquí define el tamaño del dado.

## 4.6 Del RTL a la FPGA

El camino a la FPGA impuso sus propias decisiones.

**El intercambio entre celdas lógicas y bloques de memoria.** Forzar más memorias de línea a bloques
libera celdas pero consume bloques, que son treinta. En varios puntos del desarrollo el diseño estuvo
limitado alternativamente por uno y por otro, y la solución consistió en mover recursos entre ambos
hasta encontrar una combinación que cerrara.

**El bug del cerrojo.** Una asignación condicional incompleta dentro de un bloque combinacional
infiere un cerrojo en lugar de lógica. El diseño sintetiza, ocupa recursos parecidos y funciona en
simulación; en la placa produce un comportamiento dependiente de la temporización. La herramienta lo
advierte, y la advertencia es fácil de ignorar entre otras muchas.

**El bring-up incremental.** El sistema se puso en marcha por etapas, cada una verificable por sí
misma: parpadeo, reloj, configuración SCCB, imagen en gris, memorias de línea, filtro, umbral, motor,
procesador. La razón es que **cada etapa es el banco de pruebas de la siguiente**: cuando el filtro no
produjo imagen, disponer de la etapa anterior funcionando permitió decidir en un solo intento si el
problema estaba en el filtro o en la captura.

## 4.7 Del RTL al ASIC: los cuatro cambios obligatorios

El mismo Verilog no sirve para los dos destinos. Cuatro cosas hay que cambiar, y ninguna de ellas
produce un error de simulación —por eso son peligrosas.

**1. La memoria de programa debe sintetizarse.** Ya explicado en la §4.4: en silicio no existe el
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
