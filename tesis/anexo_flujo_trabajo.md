# Anexo F. El flujo de trabajo, paso a paso

> Si el Anexo E describe **con qué** se trabaja, éste describe **en qué orden**. Recorre el camino
> completo, desde el primer fichero Verilog hasta comprobar que el circuito enviado a fabricación se
> comporta como el simulado. Sigue el procedimiento documentado por J. Ruiz (ref. 48), que es el que
> se adoptó en este trabajo, y anota en cada paso lo que la experiencia posterior añadió.

## F.1 Compilación y simulación del RTL

El primer control de todo diseño es simularlo antes de implementarlo. Para eso hace falta, además de
los ficheros fuente, un **banco de pruebas**: un módulo que genera las señales de entrada del diseño
y observa sus salidas. Icarus Verilog compila ambos juntos y produce un ejecutable:

```
iverilog -DFUNCTIONAL <TARGET>_TB.v <OBJS>
vvp a.out
```

`TARGET` es el nombre del banco de pruebas y `OBJS` agrupa los ficheros fuente del diseño. El
ejecutable, al correr, escribe un fichero de volcado con el valor de cada señal en cada instante:
entradas, salidas y señales internas. Ese fichero se abre en GTKWave, donde se colocan en el panel
las señales de interés; la disposición puede guardarse aparte, de modo que al volver a simular tras
un cambio no haya que reconstruirla.

> La práctica que este trabajo añade al paso: **un banco de pruebas vale por lo que puede romper.**
> Si el diseño vive en un flujo de vídeo, alimentarlo con píxeles consecutivos no lo verifica, lo
> halaga: el estímulo tiene que tener líneas, bordes de línea y tiempos muertos, porque es ahí donde
> falla. Un banco que no puede fallar no está verificando nada.

## F.2 Síntesis y flujo a silicio

OpenLane automatiza el camino del RTL al plano fabricable en cinco etapas encadenadas. **Síntesis**
convierte el Verilog en una red de puertas lógicas, con Yosys. **Floorplan** decide la forma y el
tamaño del dado y reserva las regiones. **Placement** coloca cada celda en su sitio. **Routing**
tiende los metales que las conectan, respetando las reglas del proceso. Y el **análisis de tiempos**
comprueba que las señales llegan cuando deben.

La ejecución se lanza desde la carpeta local de OpenLane, no desde la del diseño, porque allí están
los guiones del flujo. La primera vez que se corre un diseño hay que darlo de alta; después, basta
con reutilizar la misma etiqueta:

```
make mount

# la primera vez, para dar de alta el diseno:
./flow.tcl -design <nombre> -init_design_config -add_to_designs

# las siguientes, sobre la misma etiqueta:
./flow.tcl -design <nombre> -tag <etiqueta> -overwrite
```

Sin `-overwrite` cada ejecución crea un directorio nuevo y la carpeta se llena de resultados
parecidos entre sí, que es exactamente la situación en que uno acaba comparando dos cosas que no
sabe si son comparables. Los resultados quedan bajo `runs/<etiqueta>/results`, con un subdirectorio
por etapa y una carpeta `final` que reúne lo que los pasos posteriores necesitan.

> Dos cosas aprendidas aquí y que no están en la guía. La primera: **OpenLane no crea el directorio
> `runs/` si no existe**; en una carpeta de diseño recién copiada el flujo arranca, imprime la ruta
> del run y muere después con un error que no nombra la causa. La segunda: conviene **no reutilizar
> la etiqueta de un run cerrado**, sino darle una nueva, para que un resultado ya archivado no quede
> nunca a merced de la siguiente prueba.

## F.3 Extracción del circuito con Magic

Entre los resultados finales está el fichero de **layout**: el dibujo real de las capas, los
polígonos y las rutas del circuito, que Magic abre y permite inspeccionar. Es una representación
física, no un modelo simulable, de modo que para llevarla a SPICE hay que extraerla. En la consola
de Magic:

```
gds noduplicates
gds readonly true
extract do local
extract all
```

Eso produce un fichero intermedio que describe el circuito en términos de transistores NMOS y PMOS y
de las conexiones entre capas, **incluyendo las capacidades y resistencias parásitas** que el dibujo
introduce y el esquema no tiene. Convertirlo después a SPICE admite parámetros que deciden cuánto de
todo eso se conserva:

```
ext2spice lvs
ext2spice cthresh infinite
ext2spice rthresh infinite
ext2spice subcircuit off
ext2spice hierarchy off
ext2spice scale off
ext2spice
```

> **Aquí hay una decisión que conviene entender antes de copiarla.** Los umbrales puestos a infinito
> descartan *todos* los parásitos, y con razón: conservarlos produce ficheros enormes y simulaciones
> que no terminan. Pero este trabajo llegó a necesitar exactamente lo contrario. Al investigar por
> qué el análisis estático de tiempos predecía más retardo del que SPICE reproducía, la respuesta
> resultó estar **dentro de las celdas**: el modelo que el kit de diseño distribuye es el esquema,
> sin un solo parásito, mientras que los datos de temporización se caracterizaron sobre la celda
> dibujada. Extraer las celdas conservando las capacidades —el umbral a cero en lugar de a infinito—
> recuperó la mayor parte de la diferencia.
>
> La lección no es que la receta esté mal, sino que **la receta que hace la simulación tratable es la
> que descarta justo aquello que a veces se quiere medir**. Conviene saber cuál de las dos cosas se
> está haciendo. Conviene saber también que Magic extrae capacidades pero no resistencias internas
> de celda, de modo que ni siquiera el umbral a cero devuelve el circuito completo.

## F.4 Simulación SPICE

El circuito extraído no se simula solo: necesita estímulos. Y los estímulos razonables son los
mismos que ya se usaron en la simulación del RTL, de modo que ambas comprueben lo mismo. GTKWave
permite exportarlos: colocadas en el visor la señal de reloj, la de reinicio y las entradas
relevantes, la opción de escritura de fichero de temporización genera un fichero con los instantes
de conmutación de cada una.

Ese fichero se traduce al formato que SPICE entiende con un guion, que convierte cada señal en una
fuente lineal por tramos y añade la definición del análisis transitorio, las bibliotecas del proceso
y la inclusión del circuito extraído:

```
python3 ../tim_to_pwl.py <fichero .tim>
```

El parámetro relevante del guion es el tiempo de subida y bajada que atribuye a los flancos. **Por
debajo de un nanosegundo el simulador falla a converger**, así que ése es el valor que se usa. Con el
fichero resultante se lanza la simulación, con uno u otro simulador:

```
mpirun -np <num. procesos> Xyce <fichero .cir>
ngspice <fichero .cir>
```

La diferencia entre ambos es de recursos: el primero reparte el trabajo entre varios procesos y
conviene para circuitos grandes; el segundo usa uno solo, tarda más y consume menos. La salida es un
fichero de datos numéricos en crudo, que se grafica con otro guion:

```
python3 plot.py
```

En las distribuciones donde el visor gráfico no está empaquetado hay que crear antes un entorno de
Python con la biblioteca que lee ese formato:

```
python3 -m venv <entorno>
source <entorno>/bin/activate
pip install ltspice
```

Con eso se cierra el círculo: la misma prueba, ejecutada sobre el RTL y sobre el circuito extraído
del dibujo, debe dar el mismo resultado. Cuando no lo da, la diferencia es información.

## F.5 Adaptación a Tiny Tapeout

Enviar un diseño a fabricación por esta vía exige adaptarlo a una interfaz fija. Se parte de la
plantilla del proyecto y se trabaja sobre una copia de ella.

Del diseño propio sólo hay que adaptar el **módulo de más alto nivel**, que debe exponer exactamente
los pines que la plantilla define: ocho de entrada, ocho de salida y ocho bidireccionales. Los que el
diseño no use deben quedar explícitamente atados, no al aire. La asignación se declara además en un
fichero de configuración, en el mismo orden que en el módulo, junto con la lista de ficheros fuente y
el número de celdas de silicio que ocupará el diseño. Un tercer fichero recoge la descripción del
proyecto.

El flujo se ejecuta solo, en la infraestructura de integración continua del repositorio, y tiene tres
partes: la que produce el plano fabricable, la que construye la documentación y la que corre las
pruebas. Cada cambio que se sube dispara una ejecución nueva, de modo que los errores aparecen uno a
uno y se corrigen antes de que se acumulen. La parte que produce el plano tarda varios minutos.

> La parte de pruebas usa un entorno de verificación en Python. En el trabajo de origen no se empleó,
> y se desactivaron sus comprobaciones para que el flujo no fallara por ellas. Conviene decirlo
> explícitamente porque tiene consecuencia: **un flujo que pasa con las comprobaciones desactivadas
> no está verificando el diseño, sólo está comprobando que compila.**

## F.6 Comprobación del circuito fabricado

Cuando el flujo remoto termina, publica sus resultados como un archivo descargable. Dentro están el
Verilog sintetizado y el plano final, y ese plano puede reabrirse en Magic igual que el generado
localmente, indicando antes dónde vive el kit de diseño:

```
export PDK_ROOT=/usr/local/share/pdk/
export PDK=sky130A
magic -T $PDK_ROOT/sky130A/libs.tech/magic/sky130A.tech <diseno>.gds
```

A partir de ahí se repiten los pasos F.3 y F.4 sobre el circuito que efectivamente se envió, y se
compara con lo que la simulación del RTL predecía. Hay un detalle que hace tropezar: **los nombres de
las señales ya no son los del diseño original**, sino los de la interfaz fija de la plataforma, de
modo que tanto el fichero de estímulos como el guion de graficado tienen que nombrarlas como las
nombra el circuito enviado, o no encontrarán nada que representar.

> Éste es el paso que cierra el argumento de todo el procedimiento, y conviene ver por qué es
> distinto de los anteriores. Simular el RTL comprueba que **lo que se describió** hace lo que debe.
> Simular el circuito extraído comprueba que **lo que se dibujó** sigue haciéndolo. Sólo el segundo
> puede detectar un defecto introducido durante la implementación física, que no está en el código y
> por tanto ninguna simulación del código va a encontrar jamás.
