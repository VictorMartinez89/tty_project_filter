# 5.7 Verificación eléctrica del camino crítico

> **Estado:** borrador 1, 2026-09-21. Fuente: cuaderno 2, §33.
> Todas las cifras de esta sección proceden de corridas de NGSpice sobre `sky130_fd_sc_hd` en la
> esquina típica, 1,8 V y 25 °C, y de los ficheros de parásitos extraídos de los dos reconocedores.

Las secciones anteriores aceptaron sin discusión lo que el analizador de tiempos informa. Ésta
pregunta si ese número es correcto, y lo hace por el único camino que no depende de la misma
herramienta: **resolver los transistores**.

La pregunta no es ociosa. Un analizador estático no simula: consulta tablas caracterizadas de
antemano e interpola. Es rapidísimo y es lo que permite firmar un circuito de doscientas mil
instancias, pero entre su respuesta y la física median un modelo de celda, un modelo de cable y un
procedimiento de interpolación. Comprobar cuánto de lo que informa sobrevive a una simulación
eléctrica es, por tanto, una verificación del instrumento y no del circuito.

## 5.7.1 Por qué el camino crítico y no el chip

Simular los dos reconocedores enteros no es inviable por tamaño —`pan_sobel` tiene 116 314
transistores y en este trabajo ya se simuló un procesador de 121 310— sino **por tiempo**: para que
el clasificador vea sus 784 píxeles hay que hacerle entrar un cuadro completo, y eso son 633 800
ciclos, unos treinta y dos veces más actividad que la simulación de procesador ya realizada.

El camino crítico, en cambio, son **treinta y siete celdas** en un chip y treinta y seis en el otro.
Se extrajeron del reporte del analizador, se reconstruyeron como cadena aislada con la carga y la
pendiente que el propio reporte declara en cada etapa, y se resolvieron en NGSpice.

## 5.7.2 El resultado

Se aplicaron cinco variantes del mismo banco, cada una añadiendo un ingrediente al anterior, de modo
que la diferencia entre dos renglones consecutivos aísla la contribución de ese ingrediente:

| | `pan_sobel` (37 etapas) | `pan_canny` (36 etapas) |
|---|---:|---:|
| **Analizador estático, con parásitos** | **12,230 ns** | **9,890 ns** |
| A · las puertas solas | 4,646 ns | 4,424 ns |
| B · más la capacitancia extraída, agrupada | 8,159 ns | 7,552 ns |
| C · más la pendiente de entrada real | 8,178 ns | 7,588 ns |
| D0 · más la topología del fichero de parásitos, **con R = 0** | 7,603 ns | 7,022 ns |
| D · más la **resistencia medida** de cada tramo | 7,620 ns | 7,043 ns |
| E · más la **celda extraída del *layout*** | **9,694 ns** | **8,962 ns** |
| *fracción del retardo que la simulación reproduce* | *79,3 %* | *90,6 %* |

La variante **D0 es un control**, idéntica a la D salvo en que sus resistencias valen cero. Sin ella,
el efecto de la resistencia y el de *repartir* la capacitancia a lo largo del árbol en vez de
agruparla en un nodo quedarían sumados en una sola cifra y no podrían separarse.

![**Figura 5.8.** El desglose completo de la verificación. El panel A explica por qué se simula el
camino y no el chip; el B reparte los 12,23 ns del `pan_sobel` y los 9,89 del `pan_canny` en sumandos
que no dejan residuo; el C recoge las tres hipótesis que la medida desmintió; el D contrapone la
celda del esquemático con la extraída del dibujo en los dos experimentos independientes; y el E
separa lo que quedó cerrado de lo que se deja escrito como abierto.](figuras/fig_5_8_spice_desglose.png)

## 5.7.3 Tres explicaciones que la medida desmintió

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

## 5.7.4 La causa: la celda del esquemático no es la celda del silicio

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
|---|---:|---:|
| capacitancia de pin · `pan_sobel` | 1,30 | **0,98** |
| capacitancia de pin · `pan_canny` | 1,27 | **0,99** |
| retardo de celda aislada · `pan_sobel` | 1,31 | **1,05** |
| retardo de celda aislada · `pan_canny` | 1,30 | **1,06** |

**La discrepancia de capacitancia desaparece.** La hipótesis queda medida y no deducida, que era
justamente lo que faltaba.

## 5.7.5 La cuenta, y lo que queda abierto

Repartidos los 12,230 ns sin residuo, el término que importa sale igual en los dos circuitos:

| | `pan_sobel` | `pan_canny` |
|---|---:|---:|
| **el modelo de celda, como fracción del camino** | **22,6 %** | **22,1 %** |
| resistencia de la interconexión | 0,1 % | 0,2 % |

Dos circuitos distintos, dos caminos críticos que no comparten una sola instancia, y la misma cifra a
cuatro décimas de punto: **algo más de la quinta parte del retardo de un camino crítico la ponen los
parásitos que el dibujo añade dentro de las celdas.**

![**Figura 5.9.** La salida del simulador, tal como éste la dibuja. Cada traza es un nodo del camino
crítico, desplazada dos voltios respecto de la anterior para que las diez quepan en el mismo eje; la
cascada de transiciones de arriba abajo es la señal propagándose etapa por etapa. El último nodo del
`pan_sobel` conmuta a unos 8,2 ns y el del `pan_canny` a unos 7,6, que son las variantes D de la
tabla anterior.](figuras/fig_5_9_spice_ondas.png)

**Lo que no cerró, y se deja escrito.** Queda un 5 % por celda —0,528 ns en un chip y 0,530 en el
otro, prácticamente el mismo valor absoluto en dos caminos distintos— que la extracción no recupera.
La explicación más probable es que el procedimiento empleado conserva las **capacidades** internas de
la celda pero no sus **resistencias**, de modo que su metal interno sigue comportándose como un
cortocircuito ideal. Se anota como **probable y no comprobada**. Y la realimentación de pendientes a
lo largo de la cadena resulta asimétrica entre los dos chips —+1,47 ns en uno y −0,04 en el otro—
sin explicación disponible.

> **La conclusión.** El simulador y el analizador no discrepan sobre la física: discrepan sobre el
> circuito. Al analizador se le describió la celda tal como quedó en el *layout*; al simulador, tal
> como estaba en el esquema.
>
> La verificación eléctrica no midió, por tanto, que el analizador se equivocara. Midió **cuánto del
> retardo de un circuito integrado lo pone el dibujo y no el esquema**: algo más de la quinta parte,
> y la misma fracción en dos chips independientes. Es una cifra más útil que la que se buscaba, y
> explica por qué ninguna implementación puede firmarse sobre el esquemático.
