# 3. Metodología

> **Estado:** borrador 1, escrito el 2026-09-21. Fuente: cuaderno 1, Partes 1-34 y 59-76;
> cuaderno 2, §3, §7, §17, §19, §24 y §25.

Este capítulo describe cómo se produjo la evidencia de los capítulos siguientes. Incluye dos
apartados —§3.5 y §3.6— que no son método estándar sino **método aprendido**: proceden de errores
cometidos durante el desarrollo, y se documentan porque su valor está precisamente en que costaron
algo.

## 3.1 El ciclo

El trabajo avanzó por un ciclo cerrado que se repitió para cada bloque:

$$\text{especificar} \rightarrow \text{simular} \rightarrow \text{sintetizar y emplazar} \rightarrow \text{grabar} \rightarrow \text{verificar} \rightarrow \text{iterar}$$

La propiedad que lo hace útil no es su forma —es el ciclo habitual— sino la regla que se le impuso:
**ninguna etapa avanza hasta que la anterior produce evidencia comprobable por alguien distinto del
autor.** Un bloque no se considera terminado porque parezca correcto, sino porque existe una
comparación numérica que lo respalda y un fichero que la contiene.

## 3.2 El modelo golden

Cada filtro se escribió **primero en Python** y sólo después en Verilog. El programa en Python es la
*verdad de referencia*: define qué debe calcular el circuito, y cualquier discrepancia es un error
del circuito hasta que se demuestre lo contrario.

La razón de ese orden es que un detector de bordes **no tiene una salida evidentemente correcta**.
Un mapa de bordes erróneo sigue pareciendo un mapa de bordes; desplaza una fila, satura un byte o
invierte un signo, y sigue mostrando contornos. La inspección visual no distingue un circuito
correcto de uno sutilmente roto, y por eso «se ve bien» no es una medida.

## 3.3 Verificación por comparación bit a bit

La verificación consiste en ejecutar el modelo y el circuito sobre la misma entrada y **comparar
píxel a píxel**. El criterio de aceptación es la coincidencia exacta, no una tolerancia.

Que la coincidencia exacta sea alcanzable no es casualidad: es consecuencia de haber elegido una
aritmética que la permite —enteros, pesos que son potencias de dos, norma L1 en lugar de euclídea,
umbral por comparación— según se describe en la §4.3. Un diseño con división o punto flotante
obligaría a una tolerancia, y una tolerancia esconde errores pequeños.

### El desfase constante no es un error

Al comparar se admite un **desplazamiento uniforme** entre ambas salidas. La implementación en
hardware está segmentada y su primer resultado válido aparece algunos ciclos después que el del
modelo; ese desfase es una propiedad de la arquitectura y no un fallo de cálculo. El procedimiento
busca el desplazamiento que minimiza las diferencias, lo descuenta, y **exige que lo que quede sea
cero**.

Admitir el desfase sin acotarlo sería un error de método —permitiría ocultar diferencias reales— por
lo que el desplazamiento aceptado se registra junto al resultado.

## 3.4 Bring-up incremental

La puesta en marcha física siguió una escalera en la que cada peldaño es verificable por sí mismo:

$$\text{parpadeo} \rightarrow \text{reloj} \rightarrow \text{SCCB} \rightarrow \text{imagen en gris} \rightarrow \text{ventana} \rightarrow \text{filtro} \rightarrow \text{umbral} \rightarrow \text{motor} \rightarrow \text{procesador}$$

La razón no es prudencia genérica sino una propiedad concreta: **cada etapa es el banco de pruebas
de la siguiente**. Cuando un filtro nuevo no produjo imagen, disponer del diseño anterior —cámara a
pantalla, sin filtro— permitió decidir **en un solo intento** si el problema estaba en el filtro o en
el montaje. Si ese diseño conocido tampoco muestra imagen, el RTL nuevo queda descartado y el
problema es del banco.

## 3.5 Disciplina de medición

Este apartado recoge tres reglas que el trabajo tuvo que aprender, y las tres corrigen errores que
ya habían producido conclusiones escritas.

### Una diferencia sin dispersión no es un resultado

Comparar dos configuraciones y observar que una obtiene medio punto porcentual más no dice nada
mientras no se sepa **cuánto varía esa medida por sí sola**. Para establecerlo se realizó una
**validación cruzada de diez pliegues** sobre el conjunto completo de sesenta mil imágenes, que
arrojó una desviación de **σ = 1,32 pp**.

Con ese valor, el criterio adoptado es que **una diferencia inferior a 2σ no se reporta como
diferencia**. La consecuencia inmediata es que la separación medida entre los dos front-ends —0,38 pp—
queda muy por debajo del umbral, y por tanto la afirmación correcta no es «el Canny es ligeramente
mejor» sino **«los dos son indistinguibles en exactitud»**.

### Una estimación de σ puede estar mal

La primera estimación de la dispersión se obtuvo repitiendo el experimento con cinco semillas
distintas sobre submuestras del conjunto. Ese procedimiento **subestimaba σ en un factor de 1,8**,
porque las submuestras se solapaban entre sí y sus errores estaban correlacionados.

La lección es de forma y conviene enunciarla: **la manera de estimar la variabilidad forma parte del
resultado**, y una σ demasiado pequeña convierte ruido en hallazgo con total naturalidad.

### Dos cosas sólo se comparan en el mismo punto de operación

Ésta es la regla que este trabajo tuvo que aprender **tres veces**, y las tres le costaron una
conclusión:

1. Comparando filtros de **área distinta**, atribuyendo al algoritmo lo que era tamaño.
2. Comparando un filtro con **umbral 110** contra otro con umbrales **110/40** — dos puntos de
   operación, no dos filtros. Esta comparación sostuvo durante un tiempo la afirmación de que el
   Canny superaba al Sobel bajo condiciones degradadas; con el umbral efectivamente implementado el
   resultado se invertía, y la afirmación se retractó.
3. Comparando **implementaciones distintas** del mismo algoritmo como si fueran algoritmos distintos.

> La §5.6 muestra por qué la regla es especialmente severa aquí: **mover el umbral dentro de un
> filtro cambia el resultado más que cambiar de filtro** —5,79 pp contra 0,38 pp—. En un espacio así,
> una comparación con puntos de operación distintos no es imprecisa: mide otra cosa.

## 3.6 El instrumento antes que el dato

El apartado anterior trata de cómo se comparan los números. Éste, de si los números son reales.

En tres ocasiones durante el desarrollo **el instrumento de medida inventó resultados**, y en las
tres el resultado inventado era plausible.

**Primero, la cadena entre el circuito y el dato.** Entre la simulación y la tabla de resultados hay
extracción, decodificación y agregación, y cada paso puede fallar en silencio. Depurar esa cadena
llevó la fracción de muestras válidas del **10,4 % al 99,7 %**. Durante todo ese intervalo los
resultados existían, tenían el aspecto correcto y estaban mal.

**Segundo, un 97,3 % que no era real.** Una configuración reportó una exactitud excelente que
bloqueó una línea de trabajo durante días, porque orientó el esfuerzo hacia reproducirla en lugar de
hacia comprobarla. Procedía de un defecto del banco de medida, no del circuito.

**Tercero, un atajo que habría inventado dos puntos.** Al preparar una comparación se consideró
desplazar una imagen con una operación circular en lugar de volver a generarla. El desplazamiento
circular reintroduce por un borde lo que sale por el otro, creando estructura donde no la hay; la
comparación habría mostrado **2,4 puntos porcentuales inexistentes**.

> **La regla operativa que se adoptó:** antes de leer un número nuevo, hacer que el instrumento
> reproduzca un número ya publicado. Si no lo reproduce, el instrumento está roto y todo lo que
> diga a continuación es ficción — por convincente que parezca.

Esta regla tiene un corolario que este trabajo aplica también a las herramientas de terceros: **un
número que una herramienta llama «camino crítico» no es el camino crítico hasta que se mira qué
recorre.** En un caso concreto, la columna correspondiente de un fichero de métricas recorría el
árbol de reloj y salía por un pin, sin atravesar una sola compuerta lógica; leerla como retardo del
filtro habría producido una conclusión invertida.

## 3.7 Herramientas y entorno

Todo el flujo es de código abierto:

| Etapa | Herramienta |
|---|---|
| Modelo de referencia | Python con NumPy |
| Simulación RTL | Icarus Verilog, cocotb |
| Inspección de formas de onda | GTKWave |
| Síntesis | yosys |
| Emplazamiento y ruteo en FPGA | nextpnr-ice40, icepack |
| Flujo a ASIC | OpenLane sobre sky130A; LibreLane sobre IHP SG13G2 |
| Verificación física | Magic, KLayout, Netgen |
| Verificación eléctrica | NGSpice |

El trabajo se reparte entre **dos máquinas**: un equipo de escritorio donde se ejecutan el modelado,
la simulación y la síntesis, y una máquina virtual Linux donde se ejecutan el emplazamiento para
FPGA y los flujos completos a silicio, que dependen de herramientas no disponibles en la primera.

> Esa separación introdujo su propia clase de error —ficheros que una máquina había actualizado y la
> otra seguía leyendo en su versión anterior— y la práctica que lo resuelve merece anotarse:
> **verificar el fichero donde la herramienta va a leerlo, no donde uno lo escribió.**

Ese entorno son once piezas de software que hay que poner de acuerdo entre sí, y montarlas no es
trivial: unas se piden al gestor de paquetes en un minuto, otras se compilan desde el código fuente
con una docena larga de dependencias, y las más complejas llegan dentro de un contenedor porque
instalarlas a mano en versiones compatibles es precisamente el problema que el contenedor resuelve.
**El Anexo E recorre la instalación de cada una**, tomando como punto de partida la documentación del
propio grupo: el manual del flujo ASIC mantenido por J. Ruiz (ref. 48) y las notas de la asignatura de
VLSI del director de este trabajo (ref. 49).

Conviene adelantar aquí una diferencia que el anexo desarrolla, porque explica el reparto entre las
dos máquinas. **Ambas guías suponen una máquina con procesador x86-64, y este trabajo se hizo sobre
ARM de 64 bits.** Lo que se compila desde el código fuente cruza sin dificultad, porque se compila
para la máquina en la que está; pero todo lo que se distribuye ya compilado —señaladamente la imagen
del contenedor del flujo a silicio— hay que buscarlo en la arquitectura correcta, y no siempre
existe. La separación en dos máquinas no es una preferencia de trabajo: es la consecuencia de que
ciertas piezas sólo funcionan donde funcionan.

> **Un manual de instalación no es un procedimiento: es el registro de un procedimiento que funcionó
> en una máquina concreta.** Reproducirlo exige identificar antes qué de lo que dice depende de esa
> máquina.

Las cifras de este documento se obtuvieron con las versiones siguientes:

| Herramienta | Versión | Dónde |
|---|---|---|
| Yosys | 0.64+351 | Ambas máquinas |
| nextpnr-ice40 | 0.10-77 | Máquina virtual |
| Magic | 8.3.656 | Máquina virtual |
| OpenLane | v1.0.2 | Contenedor, variante ARM |
| Docker | 29.5.3 | Máquina virtual |
| Kit de diseño | sky130A | Gestor de versiones de PDK |
| Sistema operativo | Ubuntu sobre ARM de 64 bits | Máquina virtual |
