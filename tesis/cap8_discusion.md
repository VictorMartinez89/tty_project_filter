# 8. Discusión

El capítulo anterior presentó mediciones. Éste sostiene afirmaciones. La diferencia importa: una
medición es un hecho que se comprueba repitiendo el experimento, mientras que una afirmación es una
lectura de varios hechos y puede ser equivocada aunque todos ellos sean correctos. Este trabajo tuvo
que retractar dos afirmaciones de ese tipo durante su desarrollo, y la experiencia dejó una
disciplina que se aplica aquí: **cada tesis de este capítulo señala qué medición la sostiene y qué
otra lectura descarta.**

## 8.1 Lo que decide si un algoritmo cabe no es el algoritmo

Ésta es la afirmación central del trabajo, y la más contraintuitiva para quien llega desde el
software.

Los tres filtros implementados ejecutan aritmética comparable. Ninguno multiplica; los tres recorren
la imagen aplicando una ventana de 3×3 y comparando contra un umbral. Si el costo en silicio siguiera
a la complejidad aritmética, los tres deberían costar aproximadamente lo mismo. La §5.3.3 midió lo
contrario:

| desde | hasta | cuesta |
|---|---|---:|
| Sobel | Canny de un salto | **+5 851 celdas** |
| Canny de un salto | Canny transitivo | **+94 511 celdas** |

Table: Lo que cuesta ampliar el alcance de la ventana.

Ampliar el alcance de la ventana en un salto cuesta menos de seis mil celdas. Ampliarlo al cuadro
completo cuesta **noventa y cuatro mil quinientas once**. Y la causa no está en las operaciones sino
en **cuánto estado hay que sostener a la vez**: los dos primeros filtros procesan en flujo y retienen
unas pocas líneas; el tercero necesita el cuadro entero residente y accesible en orden arbitrario,
porque su punto fijo puede propagar una decisión desde cualquier píxel hacia cualquier otro.

La comparación que resume el capítulo es ésta: **un procesador RISC-V completo, con su memoria de
programa y su periférico, cuesta alrededor de nueve mil celdas** —medido tres veces, sobre los tres
filtros, con una dispersión inferior al 5 %— **es decir, aproximadamente la décima parte de lo que
cuesta cambiar el alcance del patrón de local a global.**

> Dicho de otro modo: en el presupuesto de este chip, **meter un procesador entero es una decisión
> menor comparada con decidir cuánta imagen mira el filtro**. Es exactamente lo contrario de lo que
> sugiere la intuición formada en software, donde el procesador es el recurso caro y la memoria se
> pide al sistema operativo.

### Las tres caras del mismo precio

El costo de la memoria no se cobra sólo en área. La §5.3.1 muestra que **los dos circuitos
transitivos son también los dos únicos que no cierran temporizado**, con −19,35 ns y −18,23 ns de
holgura una vez extraídos los parásitos. El multiplexor que lee un framebuffer de miles de entradas
es un camino largo por construcción, y a partir de cierto tamaño deja de ser caro para volverse
inviable.

Y se cobra en manufacturabilidad. La §5.2 documenta que los diseños con framebuffer grande acumulan
un número de violaciones de antena muy superior al resto, porque las redes de direccionamiento son
largas y ramificadas.

**Área, frecuencia y manufacturabilidad son tres manifestaciones del mismo hecho**, y conviene
presentarlas juntas: un diseñador que optimice sólo el área concluirá que el framebuffer es
aceptable, porque sólo verá un tercio del problema.

### El mismo filtro, en los dos sustratos

El Canny de un salto cuesta, respecto del Sobel, una sola cosa más: un tercer *line-buffer*. En sky130 ese buffer se
sintetiza en biestables, uno por bit, y el filtro aislado sale **2,23 veces** mayor que el Sobel (§7.2). En la
iCE40UP5K el mismo buffer cae en un bloque de BRAM que ya está en el chip, se use o no: la cadena completa —cámara,
ventana de 28×28, filtro, clasificador y pantalla— pasa de 2 942 a 2 956 LUT con el Canny, **catorce, el 0,5 %**, y de
6 a 8 bloques de BRAM; tras el emplazamiento, de 4 453 a 4 622 celdas lógicas.

> El mismo diseño, medido con las mismas herramientas, sale «más del doble» en un sustrato y «casi gratis» en el otro.
> **Lo que decide no es el algoritmo sino la memoria, y cuánto vale la memoria depende de la tecnología**: una
> conclusión de área sin su tecnología no significa nada.

### La misma tesis, en Canny-78

El reconocedor más exacto del trabajo repite la lección dos veces, una en cada sustrato.

En la FPGA (§6.3.5), el mismo modelo —los mismos 780 pesos, la misma exactitud— se implementó en tres
circuitos. Con los 128 contadores en registros, leídos con índice variable, se estimó en el **202 %**
del dispositivo: cada lectura exigía un multiplexor de 128 entradas. Con los contadores en una memoria
síncrona y un peso por palabra, cupo en área pero no en tiempo. Con dos pesos por palabra, cupo en las
dos, al 55 % y a 17,55 MHz. **Lo que decidió no fue cuánta memoria había, sino cómo se leía**: cuántos
viajes hacían falta y si cada uno traía algo útil.

En silicio (§7.3), la memoria de rasgos estaba declarada con 256 posiciones de 13 bits y sólo se usaban
168 de 9. Recortarla, sin cambiar un solo veredicto —diez mil de diez mil otra vez—, bajó el dado de
1,122 a 0,829 mm²: **un 26 %**. En la FPGA ese sobrante no costaba nada, porque un bloque de BRAM cuesta
lo mismo lleno que vacío; en silicio se pagaba en biestables.

> Las dos caras son la misma afirmación de esta sección, ahora con el circuito que más importa: **la
> memoria no se paga por los bits que se usan sino por los que se declaran y por cómo se leen.**

## 8.2 El costo se movió; no se eliminó

Una lectura apresurada del clasificador del Capítulo 6 sugeriría que la solución al problema anterior es
sustituir memoria por lógica. El trabajo permite matizar eso con números propios.

El clasificador de dígitos alcanza 91,04 % sobre MNIST con **400 pesos de cuatro bits** —doscientos
bytes— frente al 91,9 % que obtienen los 784 píxeles crudos con 7 840 pesos. La memoria se redujo en
un factor de veinte y la exactitud no se movió. Es un resultado fuerte, y se enuncia así en el Capítulo 6.

Pero el descriptor que hace posible esa reducción —histograma de orientaciones por zona, sobre bordes—
**no es gratuito**: hay que calcularlo, y calcularlo es lógica. Las etapas cableadas que lo producen
cuestan decenas de miles de celdas.

> La conclusión honesta no es «la codificación inteligente elimina el costo» sino **«la codificación
> inteligente mueve el costo de memoria a lógica»**, y eso es valioso únicamente porque en este
> sustrato la memoria es el recurso caro. En una FPGA con bloques de memoria disponibles, la misma
> decisión sería indiferente o incluso perjudicial.

## 8.3 Quién fija el reloj cambia con lo que se mete en el chip

Los resultados del Capítulo 5 permiten seguir el camino crítico a lo largo de una familia de diseños
y observar que **el responsable cambia tres veces**:

| Diseño | Quién fija la frecuencia |
|---|---|
| Filtros solos | el camino de datos del filtro |
| Con procesador | **el FemtoRV32** |
| Con framebuffer grande | **el multiplexor de lectura del framebuffer** |

Table: Quién fija la frecuencia de reloj en cada diseño.

Es un resultado útil para quien planifique un sistema parecido, porque implica que **optimizar el
bloque que fue crítico en el diseño anterior puede no mejorar nada**. La pregunta «¿qué limita mi
frecuencia?» no tiene una respuesta estable: tiene una respuesta por configuración.

## 8.4 Integrar no es sumar, pero sólo cuando el temporizado aprieta

Dos observaciones de este trabajo parecen contradecirse, y el matiz está en la diferencia.

Al integrar el procesador con el filtro Canny en un die apretado, el resultado superó la predicción
ingenua —la suma de las partes— en unas 6 500 celdas. En otro diseño de la misma familia, con die
holgado y reloj relajado, el resultado quedó un **1,6 % por debajo** de esa predicción.

Las dos medidas son correctas. Lo que las separa es **si el flujo tuvo que trabajar para cerrar
temporizado**: cuando lo tuvo, insertó amortiguadores y redimensionó celdas, y ese trabajo se cobra
en área; cuando no, el optimizador pudo además compartir lógica entre bloques y el total salió menor
que la suma.

> La regla que se deja escrita no es «integrar cuesta más» sino: **la penalización de integración no
> es una propiedad del diseño sino del margen con que se le pide cerrar.** Un mismo sistema puede
> costar más o menos que sus partes según el reloj que se le exija.

## 8.5 La restricción mueve la frontera entre software y hardware

El episodio de la §4.9.4 es el ejemplo más claro de co-diseño de este trabajo, y conviene leerlo con
cuidado porque su lección no es la evidente.

La histéresis transitiva calculada por software funciona, pero cabe por muy poco en la iCE40UP5K: el
**99 %** del dispositivo, con el reloj del sistema en 8,7 MHz. Con el motor en hardware como periférico
del procesador, la ocupación llegó al **127 %** y el diseño no emplazó. Sin el procesador, la misma
función como camino de datos ocupa el **45 %** y cierra a 28,7 MHz.

Lo interesante no es que el hardware sea más eficiente, que es esperable. Es que **la frontera entre
lo que ejecuta el procesador y lo que ejecuta la lógica dedicada no la fijó una preferencia de diseño
sino una medición de recursos**. Y que esa frontera **se mueve con el sustrato**: en el ASIC, donde el
área no está acotada por un dispositivo fijo, el procesador vuelve a ser viable junto al transitivo y
cuesta las mismas nueve mil celdas que junto a cualquier otro filtro.

La misma pregunta de diseño tiene respuestas opuestas en los dos destinos, y ninguna de las dos es
incorrecta.

## 8.6 El front-end y el procesador son alternativas, no complementos

Éste es el aporte de ingeniería que el trabajo propone, y se apoya en tres mediciones independientes.

**Primera.** Los dos filtros no se distinguen en exactitud de clasificación: 0,38 pp entre ellos
(Capítulo 6). El Canny no reconoce mejor.

**Segunda.** Sí se distinguen en **sensibilidad al punto de operación**. Mover el umbral cambia el
resultado del Sobel en **5,79 pp** y el del Canny en **0,90 pp**. El Sobel vive en un pico angosto del
espacio de parámetros; el Canny, en una meseta.

**Tercera.** Un Sobel sensible al umbral necesita que alguien se lo ajuste en tiempo de ejecución, y
para eso está el procesador con su periférico. Un Canny insensible no lo necesita.

Poniendo precio a las dos soluciones sobre el mismo silicio:

| lo que se compra | dónde | cuesta |
|---|---|---:|
| robustez al umbral **en el front-end** | el Canny, en el reconocedor | **972 celdas** |
| robustez al umbral **por software** | el procesador y su periferia | **6 220 celdas** |

Table: Precio de la robustez al umbral en el front-end y por software.

![**Figura 8.1.** El balance completo entre los dos filtros, sobre seis parejas de circuitos con
plano firmado. El panel A los compara en celdas; el B muestra el sobrecoste del Canny cayendo del
123 % al 3 % conforme crece el sistema; el C corrige la lectura fácil —el sobrecoste **no** es una
cantidad fija, y lo que lo separa no es el tamaño del chip sino el de la imagen que el filtro
recorre—; el D reúne las otras tres balanzas; y el E pone lado a lado las dos formas de comprar
robustez al umbral.](figuras/fig_6_1_sobel_contra_canny.png)

**Comprar robustez en el front-end resulta unas seis veces más barato que comprarla con un
procesador.** Los dos caminos resuelven el mismo problema —que el punto de operación correcto depende
de la escena— y la elección entre ellos es de arquitectura, no de algoritmo.

> **Tres precisiones, porque la cifra se presta a mal uso.**
>
> *Primera: el factor depende de la escala de recuento, y por eso se da redondeado.* Sobre celdas
> emplazadas la razón es **6,4**; sobre celdas de síntesis, **8,0**. La diferencia no es un error de
> medida sino un hecho: al emplazar, el sobrecoste del Canny crece un 48 % y el del procesador sólo
> un 18 %, porque el primero es lógica en serie que exige amortiguadores y el segundo es en buena
> parte memoria ya compacta. **La conclusión cualitativa es robusta a la escala; el número exacto no
> lo es**, y se enuncia como «unas seis veces» y no como «6,40».
>
> *Segunda: el numerador y el denominador no proceden del mismo circuito.* El sobrecoste del Canny
> se mide sobre el par de reconocedores, que recorren una ventana de 28×28; el del procesador, sobre
> el par de filtros, que recorren la escena a 60×80. No existe un reconocedor sin procesador en la
> misma tecnología con el que hacer la resta directa, de modo que **la comparación es entre dos
> sistemas emparentados y no entre dos versiones del mismo**. Se deja dicho porque un lector podría
> suponer lo segundo.
>
> *Tercera: la resta de la derecha incluye* el FemtoRV32, su controlador y su periférico, no sólo el
> núcleo: es lo que cuesta *poder escribir el umbral*, que es lo que se compara. Y la de la izquierda
> es el sobrecoste del Canny **en ese sistema concreto**; la §5.3 muestra que en un circuito que
> procese la escena completa sería mucho mayor. La afirmación vale para sistemas de reconocimiento
> sobre ventana pequeña, no universalmente.

### Sobre la trayectoria de este argumento

Conviene dejar constancia de que **esta tesis sustituye a otra anterior que resultó falsa**. Durante
el desarrollo se sostuvo que el Canny superaba al Sobel bajo condiciones de cámara degradadas. Al
revisarlo se comprobó que la comparación enfrentaba dos *puntos de operación* distintos y no dos
filtros, y con el umbral efectivamente implementado el resultado se invertía. Aquella justificación
se retractó.

El argumento que la reemplaza es más fuerte precisamente porque no depende de una condición simulada
sino de una **propiedad estructural del algoritmo**: la histéresis es un mecanismo de recuperación, y
un mecanismo de recuperación es por definición menos sensible a dónde se ponga el umbral.

## 8.7 Mejor detección de bordes no implica mejor reconocimiento

El filtro transitivo produce los contornos visualmente más completos de los tres: cierra siluetas,
rellena trazos interrumpidos y elimina el ruido aislado. Por cualquier criterio visual es el mejor
detector de bordes del trabajo.

Y **no es el mejor front-end para el clasificador**. Las métricas del Capítulo 6 muestran que ordena bien
las hipótesis pero calibra mal: engordar los contornos aumenta el número de píxeles de borde, y como
el descriptor cuenta píxeles por zona, esa ganancia visual se traduce en falsos positivos.

Hay además una razón arquitectónica, y es la más importante: **el transitivo no puede operar en
flujo**. Necesita el cuadro completo y un número de barridos que depende de la imagen. No es un
filtro más caro que los otros dos —**es otra clase de objeto computacional**, y compararlo con ellos
en área o en latencia oculta esa diferencia de naturaleza.

Canny-78 muestra la otra mitad del mismo hecho. Con **el mismo detector de bordes** que el SoC + Canny
—el Canny de un salto con umbrales de 90 y 32—, la exactitud sube de 92,46 a **97,22 %**: 4,76 puntos,
3,6 veces la dispersión del procedimiento. Lo que cambió no fue el filtro sino el descriptor que lo lee:
dieciséis zonas en lugar de cuatro, y 78 rasgos elegidos entre 168. Sobre MNIST, con esos umbrales, la
máscara no es un contorno sino la silueta engrosada del trazo, y lo que el clasificador necesita saber
es **dónde hay tinta**. Un mejor detector de bordes no mejoró el reconocimiento; una mejor pregunta
sobre los mismos bordes, sí.

## 8.8 Una jerarquía construida, no esperada

El clasificador implementa explícitamente la jerarquía *bordes → orientaciones → zonas → dígito*.
Esa descomposición se propone habitualmente como una **esperanza** sobre lo que aprenden las capas
ocultas de una red neuronal, y es sabido que rara vez ocurre así.

Aquí ocurre porque **está escrita**: cada etapa existe como hardware identificable, sus salidas son
inspeccionables y su comportamiento es el que su nombre indica. El costo de esa transparencia es que
alguien tuvo que decidir la descomposición en lugar de aprenderla.

> Con la salvedad honesta de la §8.2: los 400 pesos de cuatro bits son doscientos bytes frente a los
> decenas de kilobytes de una red equivalente, pero **las etapas cableadas que producen el descriptor
> cuestan decenas de miles de celdas**. La comparación de memorias es correcta y la de sistemas
> completos sería otra.

## 8.9 Lo que el esquemático no muestra

Un resultado lateral, surgido al generar los esquemáticos RTL de los Capítulos 4 y 5, ilustra el problema
central desde un ángulo inesperado.

En la vista RTL de cualquier herramienta, **un framebuffer es un rectángulo** —con una dirección de
entrada y un dato de salida— dibujado del mismo tamaño que un sumador. El esquemático no distingue
entre una memoria y una compuerta.

En silicio, ese mismo rectángulo son **6 400 biestables** que ocupan un tercio del circuito, para
almacenar 784 bytes.

> **La abstracción que hace legible el diagrama es precisamente la que oculta el costo dominante.**
> Un diseñador que razone sobre la vista RTL llegará sistemáticamente a la conclusión equivocada
> sobre qué parte de su circuito es cara, y no porque la herramienta mienta, sino porque representa
> con la misma tinta cosas cuyo precio difiere en tres órdenes de magnitud.

## 8.10 Posición frente a los trabajos cercanos

Dos trabajos del mismo grupo sirven de referencia. El primero implementa un Sobel en escala de grises
sobre sky130 mediante Tiny Tapeout; el segundo, un SoC basado en FemtoRV32 con memorias externas.

Con el primero, la expresión del gradiente es la misma, `|Gx|+|Gy|`, de modo que en Sobel puro ambas
implementaciones son equivalentes. **La diferencia es de alcance y no de calidad**: aquí hay
procesador, tres filtros seleccionables, cadena completa con cámara y pantalla, y un clasificador que,
en su versión Canny-78, reproduce el modelo en la tarjeta sobre las diez mil imágenes de prueba.
Conviene decirlo así explícitamente, porque presentar un trabajo cercano como inferior cuando
simplemente abordaba otra pregunta es tanto una imprecisión como una descortesía.

Frente a la literatura de aceleradores de visión, la contribución de este trabajo no es un detector
mejor —los algoritmos son de 1968, 1986 y 1993— sino **una comparación sistemática de dos front-ends
sobre silicio firmado, a igualdad de todo lo demás, a lo largo de seis sistemas de complejidad
creciente**. Esa condición de igualdad es lo que permite atribuir cada diferencia a una causa.

## 8.11 Limitaciones

- **Ningún circuito ha sido fabricado.** Todas las afirmaciones sobre silicio se refieren a GDSII
  firmado con DRC, LVS y XOR en cero, no a medidas sobre un dado real.
- **Las resoluciones son pequeñas**: 60×80 y 160×120 para el procesamiento, 28×28 para el
  reconocimiento. Son exactamente lo que la memoria disponible permite, y ese límite es el objeto de
  estudio, pero conviene no extrapolar los resultados a resoluciones mayores sin volver a medir.
- **El reconocedor no normaliza el dígito.** Sobre el conjunto de prueba, Canny-78 reproduce el modelo
  imagen por imagen; frente a dígitos manuscritos reales ante la cámara acertó **seis de treinta y
  seis**. La causa medida es el encuadre: tres píxeles de corrimiento bastan para bajar la exactitud del
  97 al 63 %, porque MNIST llega recortado y centrado y la cámara no. El marco verde de la pantalla, que
  pide a la persona centrar el dígito, es un sustituto manual de ese normalizador.
- **La magnitud del gradiente satura a ocho bits**, lo que en escenas de alto contraste recorta la
  información antes del umbral.
- **Los recuentos de celdas no son homogéneos** entre las tablas de los Capítulos 5 y 7, por las tres
  definiciones documentadas en la §5.2.3. Los cocientes dentro de cada pareja son válidos; las
  comparaciones absolutas entre tablas distintas, no.
- **La verificación eléctrica de la §5.4 deja un residuo declarado**: la extracción del layout de las
  celdas recupera la mayor parte de la discrepancia entre SPICE y el analizador estático, pero no
  toda, y la parte restante se atribuye a la resistencia interna de la celda sin haberlo comprobado.
