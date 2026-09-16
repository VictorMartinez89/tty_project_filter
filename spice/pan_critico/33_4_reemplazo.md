### 33.4 · Tres hipótesis que la medida desmintió

Conviene dejar constancia de las tres, porque las tres parecían razonables y las tres resultaron
falsas. La última era, además, la conclusión con que esta sección se cerró en su primera versión.

**Primera: el flanco de entrada idealizado.** El estímulo inicial era una rampa de 20 ps, mientras
que la primera etapa del chip recibe una transición mucho más lenta; cabía esperar que un frente de
onda degradado se propagase como retardo a lo largo de las 37 etapas. Sustituido por la pendiente
real que declara el reporte, la contribución es de **0.019 ns — el 0.2 %**. Descartada.

**Segunda: la capacitancia de las nets grandes.** Al examinar el perfil etapa por etapa, las
desviaciones mayores se concentran en puertas de muchas entradas (`or4b_2`, `or4_1`), lo que
sugería nets largas y cargadas. Se midió la correlación entre la desviación de cada etapa y su
capacitancia: **r = −0.15**. Y con el *fanout*: **r = −0.06**. Ninguna. **No es carga.**

**Tercera: la resistencia de la interconexión.** Por eliminación quedaba ésta, y así se dejó escrito:
el STA trabaja sobre el fichero SPEF, que da R y C de cada net, mientras que el reporte de texto
publica sólo la C, de modo que SPICE habría recibido una descripción incompleta de los cables. La
conjetura no pudo comprobarse entonces porque el SPEF de los `pan_*` no se había conservado.

Recuperado el fichero, se comprobó. **Y era falsa.**

El banco se amplió para colgar de cada nodo, en vez de una capacitancia agrupada, el árbol RC que el
extractor midió sobre la geometría: las resistencias tramo a tramo, las capacidades en su posición
real y el receptor de cada etapa en el punto del árbol donde de verdad está. Junto a esa variante se
corrió un control idéntico en todo salvo en que las resistencias se ponen a cero, que es lo que aísla
la contribución de la R de la de *repartir* la C:

| variante del mismo camino | retardo |
|---|---:|
| C agrupada, flanco real (la de §33.3) | 8.178 ns |
| topología real del SPEF, **R = 0** | 7.603 ns |
| topología real del SPEF, **con la R medida** | **7.620 ns** |

**La resistencia de la interconexión aporta 0.017 ns: el 0.1 % del camino.** No los cuatro
nanosegundos que había que explicar. La hipótesis queda descartada por medida directa.

Vale la pena señalar que el propio reporte del analizador lo decía desde el principio, y que no se
leyó. El reporte imputa cada retardo a un pin: los de pin de salida son de celda y los de pin de
entrada son de cable. Sumados por separado a lo largo del camino crítico:

    retardos imputados a CELDA   12.18 ns
    retardos imputados a CABLE    0.04 ns

El analizador nunca atribuyó el tiempo a la interconexión. La diferencia con SPICE tenía que estar,
necesariamente, dentro de las celdas. Bastaba con sumar dos columnas.

> **Sobre el método.** Las dos primeras hipótesis se descartaron midiendo; la tercera se *adoptó*
> por eliminación, que no es lo mismo. Una conclusión alcanzada descartando alternativas vale lo
> que valga la lista de alternativas, y la de entonces estaba incompleta: no incluía la
> posibilidad de que el modelo de celda —no el de cable— fuese el que discrepaba. Es el mismo
> error de forma que obligó a retractar la §6, y conviene no disimularlo: una deducción por
> eliminación es una hipótesis, y debe escribirse como tal hasta que haya una medida que la
> sostenga.

### 33.5 · Lo que sí era: la celda del esquemático no es la celda del silicio

Si la diferencia está dentro de las celdas, hay que preguntárselo a una celda sola. El banco se
redujo al mínimo: **una** celda, el mismo arco que el camino recorre, la misma pendiente de entrada
y la misma capacitancia de salida que el reporte declara, y la misma pregunta hecha dos veces —a la
tabla Liberty, interpolando como hace OpenSTA, y a NGSpice, resolviendo los transistores del
`.subckt` del PDK. Sin cadena, sin cables, sin nada que armar mal.

| # | celda | arco | pend. | carga | Liberty | SPICE | STA | L/S |
|---|---|---|---:|---:|---:|---:|---:|---:|
| 6 | `or4b_1` | B→X | 0.090 | 0.010 | 0.573 | 0.419 | 0.560 | 1.37 |
| 14 | `or4_2` | C→X | 0.070 | 0.010 | 0.658 | 0.511 | 0.710 | 1.29 |
| 17 | `or3b_2` | B→X | 0.090 | 0.030 | 0.568 | 0.466 | 0.610 | 1.22 |
| 22 | `clkbuf_8` | A→X | 0.180 | 0.110 | 0.287 | 0.228 | 0.300 | 1.26 |
| 29 | `or4b_2` | A→X | 0.110 | 0.020 | 0.777 | 0.608 | 0.800 | 1.28 |
| | **suma de las 37** | | | | **11.687** | **8.919** | **12.220** | **1.31** |

Tres cosas se leen en la tabla. La primera es que **la columna Liberty reproduce a la del STA casi
exactamente** —0.573 contra 0.560, 0.287 contra 0.300—, lo que confirma que el analizador no aplica
ningún factor de castigo: se limita a consultar la tabla. La segunda es que **SPICE queda
sistemáticamente por debajo, en cada celda y aislada de todas las demás**: en 35 de las 37 etapas,
con razón mediana 1.28 y un cociente global de 1.31. La tercera es que esa razón **no depende de la carga ni de la pendiente** —vale
tanto para el `clkbuf_8` que mueve 0.110 pF como para el `or4b_1` que mueve 0.010—, lo que descarta
que el banco esté cargando mal las celdas y apunta a la celda misma.

La causa está en el fichero que se le dio a SPICE como modelo. El `.subckt` que el PDK distribuye
es el netlist **esquemático**:

```
.subckt sky130_fd_sc_hd__or4b_1 A B C D_N VGND VNB VPB VPWR X
X0  VGND a_109_53#  a_215_297# VNB sky130_fd_pr__nfet_01v8     w=420000u l=150000u
X1  a_215_297# A    VGND       VNB sky130_fd_pr__nfet_01v8     w=420000u l=150000u
...
X11 VPWR a_215_297# X          VPB sky130_fd_pr__pfet_01v8_hvt w=1e+06u  l=150000u
.ends
```

Doce transistores y ni un solo parásito. La biblioteca Liberty, en cambio, se caracterizó sobre la
celda **dibujada**, con el metal, los contactos y la difusión que el layout añade. Al simulador se le
entregó la celda antes de dibujarla.

Y eso también se puede medir en vez de razonarlo. La Liberty declara, para cada pin de entrada, su
capacitancia. Basta comparar esa cifra con la que el netlist esquemático realmente tiene —metiéndole
al pin una rampa lenta e integrando la corriente que entra, C = Q/V, sin modelo ni supuesto:

| celda | pin | Liberty | esquemático | L/E |
|---|---|---:|---:|---:|
| `mux2_1` | A1 | 0.00188 pF | 0.00073 pF | 2.57 |
| `or4b_1` | B | 0.00181 pF | 0.00100 pF | 1.82 |
| `or2b_2` | A | 0.00171 pF | 0.00100 pF | 1.71 |
| `and3_1` | C | 0.00156 pF | 0.00100 pF | 1.56 |
| `nand2_1` | B | 0.00232 pF | 0.00184 pF | 1.26 |
| `clkbuf_8` | A | 0.00392 pF | 0.00366 pF | 1.07 |
| `xor2_1` | B | 0.00434 pF | 0.00414 pF | 1.05 |
| **media sobre los 35 pines del camino** | | **0.00238 pF** | **0.00183 pF** | **1.30** |

La biblioteca le atribuye a cada pin, de media, un 30 % más de capacitancia de la que el esquemático
tiene, y a alguno el doble largo. Esa diferencia es, literalmente, el dibujo de la celda: el
contacto, el trozo de metal que lleva la señal hasta la puerta y la difusión que la rodea.

> **Y las dos medidas concuerdan.** La razón entre el retardo que declara la Liberty y el que SPICE
> obtiene sobre el esquemático es **1.31**. La razón entre la capacitancia que la Liberty declara y
> la que el esquemático tiene es **1.30**. Son dos experimentos distintos —uno mide tiempos, el otro
> carga— hechos sobre las mismas 37 etapas, y dan la misma cifra. No es una prueba de que toda la
> diferencia de retardo sea capacitancia de pin —dentro de la celda hay más parásitos que ése, y el
> nodo de salida tiene los suyos—, pero sí es exactamente la coincidencia que cabría esperar si el
> origen es el que se afirma, y no la habría si el origen fuese otro.

### 33.6 · La cuenta, cerrada

Con las dos medidas anteriores los 12.230 ns que el analizador predice quedan repartidos sin
residuo. Cada renglón es una diferencia entre dos bancos que sólo se distinguen en una cosa:

El procedimiento se aplicó por separado a los dos chips, que tienen caminos críticos distintos, de
distinta longitud y con distintas celdas:

| | `pan_sobel` (37 etapas) | `pan_canny` (36 etapas) | |
|---|---:|---:|---|
| **lo que predice el analizador estático** | **12.230** | **9.890** | suma de tablas Liberty |
| − consulta de la tabla hecha aquí, celda a celda | −0.543 | −0.436 | el reporte redondea a dos decimales |
| = la Liberty, sumada sobre las etapas | 11.687 | 9.454 | |
| − **el modelo de celda: esquemático, no layout** | **−2.768** | **−2.181** | los parásitos que el dibujo añade |
| = SPICE, celda a celda, con las pendientes del reporte | 8.919 | 7.273 | |
| − la cadena realimenta pendientes más limpias | −1.299 | −0.230 | cada etapa entrega un flanco más vivo |
| = **SPICE sobre la cadena completa** | **7.620** | **7.043** | |
| de los cuales, resistencia de la interconexión | 0.017 | 0.020 | |

Ninguno de los dos deja residuo. Y el término que importa sale igual en los dos:

| | `pan_sobel` | `pan_canny` |
|---|---:|---:|
| **el modelo de celda, como fracción del camino** | **22.6 %** | **22.1 %** |
| razón de retardos, Liberty / SPICE en celda aislada | 1.31 | 1.30 |
| razón de capacitancias de pin, Liberty / esquemático | 1.30 | 1.27 |
| resistencia de la interconexión | 0.1 % | 0.2 % |

Dos circuitos distintos, dos caminos críticos que no comparten ni una sola instancia, y la misma
cifra: **algo más de la quinta parte del retardo de un camino crítico lo ponen los parásitos que el
dibujo añade dentro de las celdas.** Que coincida a cuatro décimas de punto porcentual es la
confirmación de que se está midiendo una propiedad de la biblioteca y no una peculiaridad de un
camino.

El término que **no** coincide es instructivo por sí mismo: la realimentación de pendientes vale
10.6 % en el Sobel y 2.3 % en el Canny. Ése sí depende del camino —de cuántas etapas encadene y de
cuánto margen de pendiente tenga cada una—, y es lo que explica que en §33.3 el Canny reprodujera el
76.7 % del retardo y el Sobel sólo el 66.9 %. No eran dos chips que se comportaran distinto: era el
mismo efecto de celda más una cola de encadenamiento distinta.

Ese segundo término, además, no es un error de ninguna de las dos herramientas. Es la consecuencia
de encadenar: al simulador se le dejó propagar sus propias pendientes, y como cada celda suya es más
rápida, el flanco que entrega es más vivo y la etapa siguiente se beneficia otra vez. Es el mismo
efecto que las tablas Liberty capturan interpolando por pendiente de entrada, visto desde el otro
lado.

> **La conclusión.** SPICE y el analizador estático no discrepan sobre la física: discrepan sobre el
> circuito. Al analizador se le describió la celda tal como quedó en el layout; al simulador, tal
> como estaba en el esquema. Los cuatro nanosegundos no son la resistencia del cable entre celdas
> —que aporta 0.017 ns, el 0.1 %— sino los parásitos dentro de cada una de las treinta y siete.
>
> La verificación eléctrica del camino crítico no midió, por tanto, que el analizador se equivocara.
> Midió **cuánto del retardo de un circuito integrado lo pone el dibujo y no el esquema**: algo más
> de la quinta parte, y la misma fracción en los dos chips. Es una cifra más útil que la que se
> buscaba, y explica por qué ninguna síntesis puede firmarse sobre el esquemático.
