# 2. Marco teórico y estado del arte

> **Estado:** borrador 1, escrito el 2026-09-21.
> ⚠️ **Las citas de este capítulo deben verificarse contra la lista de 36 referencias ya recopilada
> (cuaderno 1, Parte 200) antes de la versión final.** Se escribieron desde el conocimiento del área
> y no se contrastaron con la bibliografía; autor, año y publicación exacta están sin comprobar.
> Ver la nota al final del capítulo.

Este capítulo establece el andamiaje conceptual del trabajo. Su estructura obedece a una afirmación
que conviene enunciar de entrada, porque de ella depende que los capítulos siguientes se lean como
un todo y no como una colección de implementaciones: **los tres detectores y el clasificador de este
trabajo no son cuatro cosas distintas, sino cuatro casos de la misma operación, y lo que los
distingue en silicio no es su aritmética sino su huella de memoria.**

## 2.1 Reconocer bajo restricciones duras

El problema que este trabajo aborda no es detectar bordes —eso está resuelto desde hace medio
siglo— sino **qué se puede reconocer dentro de un presupuesto de recursos fijo y pequeño**.

La pregunta tiene un origen concreto y anterior a este documento. Una propuesta de investigación del
mismo autor, fechada en 2017, planteaba: *«¿será posible abordar la detección y clasificación de
objetos sobre imágenes sin la necesidad de estos procesadores?»*. Su primer experimento —reconocer un
objeto mediante un vector de histograma de intensidades y los momentos invariantes de Hu [Hu 1962],
clasificado con una máquina de vectores de soporte— **fracasó**: el modelo separaba las muestras de
entrenamiento y no predecía ninguna clase positiva sobre muestras nuevas. Y su sección de trabajo
futuro proponía la corrección: *«binarizar las imágenes, ya sea con un filtro de Canny o de Sobel, a
fin de mejorar la silueta del objeto de interés»*.

Este trabajo es ese trabajo futuro. El preprocesamiento que le faltaba a aquel clasificador,
construido y medido de la FPGA al silicio.

Situarlo así tiene una consecuencia sobre cómo se lee el resto: **un detector de bordes no es aquí el
objetivo sino la primera etapa de un reconocedor**, y el borde es el patrón más simple que existe —el
caso base del problema general.

## 2.2 El primitivo común: correlar, acumular, decidir

Esta sección sostiene la afirmación central del capítulo, y es la que hace legítimo tratar juntos
objetos que la literatura presenta por separado.

Las cuatro operaciones que este trabajo implementa —el operador de Sobel, el de Canny, la
reconstrucción morfológica y el clasificador lineal— comparten una misma estructura de cómputo:

1. **Correlar** una vecindad de la imagen contra una plantilla.
2. **Acumular** el resultado.
3. **Decidir** comparando contra un umbral.

Es la estructura del filtro adaptado clásico, y es también la de la primera capa de una red
convolucional [LeCun *et al.* 1998]: una convolución seguida de una no linealidad. Que el aprendizaje
profundo haya popularizado esa operación no la inventó; la heredó del procesamiento de señales.

Si el cómputo es el mismo, **lo que distingue a las cuatro es de dónde sale la plantilla**. Y ese
criterio produce una agrupación en tres familias que organiza el resto del capítulo:

| Familia | De dónde sale la plantilla | Ejemplo en este trabajo |
|---|---|---|
| **escrita a mano** | una persona la deriva de un modelo de qué es un borde | Sobel, Prewitt, Kirsch |
| **buscada** | se obtiene optimizando un criterio, o la operación misma busca | Canny; histéresis transitiva |
| **aprendida** | se ajusta a partir de datos | los pesos del clasificador |

> **Sobre esta clasificación.** La agrupación en «escrita a mano / buscada / aprendida» **es propia de
> este trabajo** y no corresponde a una taxonomía establecida en la literatura. Se propone como
> dispositivo organizador —agrupa según cómo se obtiene la plantilla— y cada una de sus tres ramas se
> apoya en referencias reconocidas, que son las que las secciones siguientes desarrollan. Se enuncia
> explícitamente como aportación de organización para no presentarla como consenso ajeno.

## 2.3 El patrón escrito a mano

El operador de Sobel–Feldman [Sobel y Feldman 1968] estima el gradiente de una imagen mediante dos
núcleos de 3×3 cuyos coeficientes combinan una diferencia central con un promedio ponderado en la
dirección perpendicular. Es una plantilla **escrita por una persona** a partir de un modelo explícito
de qué constituye un borde: una variación brusca de intensidad, suavizada para tolerar ruido.

De la misma familia son el operador de Prewitt [Prewitt 1970], que omite la ponderación central, y el
operador de brújula de Kirsch [Kirsch 1971], que aplica ocho plantillas rotadas y retiene el máximo,
obteniendo así orientación además de magnitud.

La decisión final —qué magnitud constituye un borde— requiere un umbral, y su elección automática
tiene tratamiento clásico en el método de Otsu [Otsu 1979], que lo sitúa donde se minimiza la
varianza intraclase del histograma.

**Ninguno de estos operadores se entrena.** Sus coeficientes son constantes derivadas de un
argumento, y esa propiedad —que hoy resulta llamativa— es justamente lo que los hace baratos de
implementar: los pesos son potencias de dos, de modo que la multiplicación se reduce a
desplazamiento.

## 2.4 El patrón buscado

El operador de Canny [Canny 1986] pertenece a otra familia, y por dos razones distintas que conviene
separar porque a menudo se confunden.

**Primera: el operador se halló optimizando.** Canny no propuso una plantilla y la justificó
después; formuló tres criterios —buena detección, buena localización y respuesta única por borde— y
**derivó** el operador que los optimiza conjuntamente. La plantilla es el resultado de una búsqueda
en un espacio de diseño, no una elección.

**Segunda: la operación misma busca.** La etapa final del método —la histéresis— no evalúa cada píxel
de forma independiente: promueve un píxel de magnitud intermedia a la condición de borde *si está
conectado* a uno de magnitud alta. Es una consulta de alcanzabilidad sobre un grafo, y su resultado
depende de la estructura global de la imagen y no de una vecindad fija.

Formalmente, esa operación es una **reconstrucción morfológica** [Vincent 1993]: la reconstrucción de
una máscara —los píxeles débiles— a partir de unos marcadores —los fuertes— bajo una relación de
conectividad, cuyo resultado es el **punto fijo** de una dilatación geodésica iterada.

> Esta caracterización no es un tecnicismo: es lo que explica el resultado central del Capítulo 6. Un
> punto fijo sobre el cuadro completo **no admite implementación en flujo**, porque no puede emitirse
> ningún resultado definitivo hasta comprobar que ningún píxel cambia. La estructura matemática de la
> operación determina su arquitectura, y su arquitectura determina su costo.

## 2.5 El patrón aprendido

La tercera familia obtiene la plantilla de los datos. El trabajo emplea un descriptor de orientaciones
por zona y un clasificador lineal cuantizado, y ambos tienen una genealogía precisa.

La idea de describir una región mediante un **histograma de orientaciones del gradiente** aparece en
el descriptor SIFT [Lowe 2004] y se establece como método general en el descriptor HOG [Dalal y
Triggs 2005]. Su virtud para este trabajo es doble: se calcula a partir de lo que el front-end ya
produce —magnitud y orientación del gradiente— y es robusto frente a variaciones de iluminación,
porque cuenta direcciones y no intensidades.

La organización de esos histogramas en una **rejilla espacial de varios niveles** procede de la
pirámide espacial [Lazebnik *et al.* 2006], que reintroduce información de posición en un descriptor
que por construcción la descarta. Esa reintroducción es la que distingue, en el experimento del
Capítulo 5, un clasificador que confunde sistemáticamente dos dígitos de uno que no lo hace.

Como referencia de la tarea se emplea el conjunto MNIST [LeCun *et al.* 1998], por ser el punto de
comparación estándar en reconocimiento de dígitos manuscritos y permitir situar los resultados
propios frente a una literatura extensa.

## 2.6 Lo que los separa en silicio

Las tres familias anteriores se distinguen por el origen de la plantilla. En una implementación
física se distinguen por otra cosa, y ésta es la sección que conecta el marco teórico con el objeto
del trabajo.

### Flujo contra cuadro

Una operación cuya salida depende de una vecindad acotada puede implementarse **en flujo**: basta
retener las pocas líneas de la imagen que la vecindad abarca. Una operación cuya salida depende de la
imagen completa exige **almacenar el cuadro**.

La diferencia entre ambos regímenes no es de grado. Retener dos líneas de una imagen de sesenta
píxeles de ancho son ciento veinte bytes; retener el cuadro son cuatro mil ochocientos. Y en un
circuito integrado que no dispone de un generador de memoria, esos bytes se implementan con
biestables.

### El costo lo domina el movimiento de datos, no el cómputo

Este trabajo mide, en un sistema pequeño, una relación que la literatura de aceleradores establece
para sistemas grandes: **el costo de un sistema de procesamiento de datos lo domina el
almacenamiento y el movimiento de los datos, no las operaciones aritméticas**.

El análisis del acelerador Eyeriss [Chen *et al.* 2016] y el panorama posterior sobre procesamiento
eficiente de redes neuronales [Sze *et al.* 2017] establecen que el acceso a memoria consume órdenes
de magnitud más energía que una multiplicación, y que en consecuencia la arquitectura debe
organizarse alrededor del flujo de datos y no alrededor de las unidades aritméticas.

> La contribución de este trabajo a esa línea no es teórica sino de escala y de método: mide el mismo
> fenómeno **en el extremo opuesto del rango** —sistemas completos de uno a diez milímetros
> cuadrados, no aceleradores de decenas— **sobre silicio firmado y con el circuito gemelo como
> control**. Que la misma ley aparezca a esa escala, con un presupuesto miles de veces menor y sobre
> algoritmos clásicos en lugar de redes neuronales, sugiere que no es una propiedad del aprendizaje
> profundo sino del sustrato.

## 2.7 El sustrato: RISC-V y el flujo abierto a silicio

El procesador empleado implementa el conjunto de instrucciones **RV32I**, el subconjunto entero de 32
bits de la especificación abierta RISC-V [Waterman *et al.*]. La elección responde a que un conjunto
abierto permite implementaciones mínimas sin restricciones de licencia, y a que existen núcleos de
tamaño compatible con el presupuesto de este trabajo.

El paso a silicio se realiza con el flujo abierto **OpenLane** sobre el kit de diseño **sky130A**, y
con LibreLane sobre IHP SG13G2 para la segunda tecnología. La disponibilidad de estos flujos es
reciente y es lo que hace posible que un trabajo de maestría produzca GDSII verificado sin licencias
comerciales.

Entre una FPGA y un ASIC cambian cosas que el RTL no expresa: la inicialización de los registros, la
existencia de memoria en el sustrato, la disponibilidad de tri-estado interno y las primitivas
específicas del fabricante. La §4.7 las enumera; aquí basta señalar que **ninguna de ellas produce un
error de simulación**, lo que las convierte en una clase de problema particularmente incómoda.

## 2.8 Trabajos relacionados

Dos trabajos del mismo grupo de investigación sirven de referencia directa.

El primero implementa conversión a escala de grises y filtrado de Sobel sobre sky130, llevado a
fabricación mediante Tiny Tapeout, con verificación en cocotb y una interfaz serie. Emplea la misma
expresión del gradiente que este trabajo, `|Gx|+|Gy|`, de modo que **en Sobel puro ambas
implementaciones son equivalentes**. La diferencia es de alcance —aquí hay procesador, tres filtros
seleccionables, cadena completa con cámara y pantalla, y un clasificador— y **no de calidad**.
Constituye una referencia inicial, no una base que este trabajo extienda.

El segundo implementa un SoC basado en FemtoRV32 con memorias externas, también sobre Tiny Tapeout, y
sirve de punto de comparación para el subsistema de procesamiento.

### El reconocimiento de dígitos en FPGA, y el presupuesto en que se hace

Existe una literatura abundante —académica y de la comunidad de código abierto— sobre implementación
de clasificadores de MNIST en FPGA. Revisarla sitúa este trabajo con precisión, porque **la diferencia
no está en la tarea sino en el presupuesto**.

Los trabajos comparables emplean de forma característica plataformas de gama media o alta:

| Plataforma | Dispositivo | Precio aproximado |
|---|---|---:|
| Terasic DE2-115 | Cyclone IV E EP4CE115 | 779 USD (423 académico) |
| Digilent ZedBoard | Zynq-7000, ARM + FPGA | 475 USD |
| **iCESugar v1.5** *(este trabajo)* | **iCE40UP5K** | **≈ 48 USD** |

La diferencia de precio —un factor de diez respecto de la ZedBoard y de dieciséis respecto de la
DE2-115— refleja una diferencia mucho mayor de recursos. Una implementación representativa sobre la
DE2-115 emplea una red convolucional de siete capas con **144 multiplicadores dedicados y 128
sumadores** en aritmética de punto fijo de dieciséis bits, ocupando menos de la mitad del
dispositivo. Otra, sobre ZedBoard, dispone además de un procesador ARM de aplicación junto a la
lógica programable.

El sistema de este trabajo opera sobre un dispositivo de 5 280 celdas lógicas y **no emplea ningún
multiplicador en el camino de datos de imagen**. La comparación no pretende mostrar superioridad: las
tareas resueltas no son equivalentes, y una red convolucional de siete capas reconoce mejor que un
clasificador lineal sobre descriptores de orientación. Lo que muestra es **dónde se sitúa el punto de
operación elegido**: en el extremo del rango donde la restricción de recursos es la variable
dominante, que es precisamente el régimen que este trabajo estudia.

> Y hay una consecuencia que conviene enunciar: **una implementación que dispone de 144
> multiplicadores no encuentra el problema que este trabajo investiga**. Con esa cantidad de
> aritmética disponible, la pregunta de qué cabe no se plantea, y la memoria deja de ser el recurso
> escaso. Las conclusiones de los capítulos 5 y 6 sólo son visibles desde el presupuesto pequeño.

### Una confirmación independiente, desde diez veces más presupuesto

El proyecto de la Universidad Técnica de Viena [Baischer *et al.*] es el más documentado de los
revisados, y merece atención porque **llega a la misma conclusión que este trabajo desde el otro
extremo del rango de recursos**.

Sus autores implementan una red convolucional sobre una ZedBoard —diez veces el precio del
dispositivo empleado aquí, y con un procesador ARM de aplicación incorporado— y, sin embargo,
escriben:

> *«Portar directamente todos los pesos y sesgos a la FPGA **no es viable debido a la limitada
> cantidad de recursos disponibles**.»*

y más adelante, al justificar la ausencia de interfaz gráfica:

> *«los **escasos recursos** de la ZedBoard se conservan tanto como es posible.»*

La solución que adoptan es exactamente la misma estrategia que el Capítulo 5 documenta:
**cuantizar**. Reducen los pesos de treinta y dos bits en coma flotante a ocho bits con una
configuración única para toda la red, y hasta **cuatro bits** eligiendo la configuración por capa,
con una caída de exactitud de **98,35 % a 97,37 %** —algo más de un punto porcentual a cambio de un
factor de ocho en memoria.

> Que un grupo con diez veces más presupuesto de hardware describa sus recursos como escasos y
> acabe recurriendo a pesos de cuatro bits **no debilita la premisa de este trabajo: la confirma**.
> La restricción de memoria no es un artefacto de haber elegido un dispositivo pequeño; es la
> variable dominante en todo el rango, y elegir un dispositivo pequeño sólo la hace visible antes.
>
> Conviene señalar además la coincidencia en la solución. Aquel trabajo llega a cuatro bits por capa
> partiendo de una red entrenada; éste llega a **cuatrocientos pesos de cuatro bits** partiendo de un
> descriptor diseñado. Dos caminos distintos, el mismo destino — y la misma razón de fondo, que es
> dónde está el recurso escaso.

> **Sobre la naturaleza de estas fuentes.** Los proyectos consultados son repositorios públicos de
> código, no publicaciones revisadas por pares, y varios de ellos no reportan exactitud ni consumo de
> recursos. Se citan como **evidencia del punto de operación habitual en la comunidad**, no como
> resultados con los que comparar cifras. Las plataformas y sus precios sí están verificados.

### Por qué el silicio verificado es reciente en este contexto

La posición de este trabajo frente a la literatura más amplia de implementación de detectores de
bordes en hardware conviene enunciarla con cuidado, porque la afirmación fácil —«casi todo se queda
en FPGA»— es difícil de sostener con rigor y fácil de atacar.

Lo que sí puede afirmarse, y explica el resto, es una cuestión de **acceso**. Hasta 2020, todo kit de
diseño de un proceso comercial estaba sujeto a un acuerdo de confidencialidad, de modo que la
reproducibilidad académica, las herramientas abiertas de diseño físico y las fabricaciones de bajo
costo eran inviables por construcción [SkyWater 2020]. La apertura del kit sky130 cambió esa
situación, y el flujo OpenLane construido sobre él [Shalan y Edwards 2020] puso al alcance de un
grupo de investigación un camino completo de RTL a GDSII. Más de cincuenta universidades lo emplean
actualmente en docencia y en investigación.

De ahí se sigue la posición de este trabajo, enunciada sin cuantificadores que no puedan defenderse:
**la implementación en FPGA de estos algoritmos tiene una literatura extensa y consolidada, mientras
que llevarlos hasta silicio verificado es una posibilidad abierta hace pocos años**, y los trabajos
que la ejercen son en consecuencia recientes. Lo que este trabajo aporta en ese contexto no es haber
llegado a GDSII —cada vez más grupos lo hacen— sino **haber llevado la misma cadena por ese camino
seis veces, variando una sola cosa cada vez**.

Esa condición de igualdad —mismo sistema, misma resolución, mismo flujo, misma esquina de proceso—
es lo que permite atribuir cada diferencia medida a una causa concreta, y es lo que distingue una
comparación de una colección de implementaciones.

> **Sobre el alcance de esta afirmación.** Lo anterior se apoya en una revisión no sistemática: la
> literatura consultada sobre implementación en hardware de los operadores de Sobel y Canny es
> predominantemente de FPGA, y las fuentes citadas documentan la apertura del kit y su adopción. **No
> se ha realizado un recuento de publicaciones**, y por eso el texto evita la palabra «mayoría» y se
> limita a lo que las fuentes sostienen.

---

## Referencias citadas en este capítulo

**Las diecisiete se verificaron contra la fuente el 21 de septiembre de 2026.** Volumen, número y
páginas están comprobados salvo donde se indica.

| Cita | Referencia |
|---|---|
| Hu 1962 | M.-K. Hu, «Visual Pattern Recognition by Moment Invariants», *IRE Trans. Information Theory*, vol. 8, n.º 2, pp. 179–187, 1962. |
| Sobel y Feldman 1968 | I. Sobel y G. Feldman, «A 3×3 Isotropic Gradient Operator for Image Processing», **charla en el Stanford Artificial Intelligence Laboratory**, 1968. *No es una publicación formal* (véase la nota). |
| Prewitt 1970 | J. M. S. Prewitt, «Object Enhancement and Extraction», en B. Lipkin y A. Rosenfeld (eds.), *Picture Processing and Psychopictorics*, Academic Press, pp. 75–149, 1970. |
| Kirsch 1971 | R. A. Kirsch, «Computer determination of the constituent structure of biological images», *Computers and Biomedical Research*, vol. 4, n.º 3, pp. 315–328, 1971. |
| Otsu 1979 | N. Otsu, «A Threshold Selection Method from Gray-Level Histograms», *IEEE Trans. Systems, Man, and Cybernetics*, vol. SMC-9, n.º 1, pp. 62–66, ene. 1979. |
| Canny 1986 | J. Canny, «A Computational Approach to Edge Detection», *IEEE Trans. Pattern Analysis and Machine Intelligence*, vol. PAMI-8, n.º 6, pp. 679–698, nov. 1986. |
| Vincent 1993 | L. Vincent, «Morphological Grayscale Reconstruction in Image Analysis: Applications and Efficient Algorithms», *IEEE Trans. Image Processing*, vol. 2, n.º 2, pp. 176–201, abr. 1993. |
| LeCun *et al.* 1998 | Y. LeCun, L. Bottou, Y. Bengio y P. Haffner, «Gradient-Based Learning Applied to Document Recognition», *Proceedings of the IEEE*, vol. 86, n.º 11, pp. 2278–2324, 1998. |
| Lowe 2004 | D. G. Lowe, «Distinctive Image Features from Scale-Invariant Keypoints», *International Journal of Computer Vision*, vol. 60, n.º 2, pp. 91–110, 2004. |
| Dalal y Triggs 2005 | N. Dalal y B. Triggs, «Histograms of Oriented Gradients for Human Detection», *IEEE CVPR*, vol. 1, pp. 886–893, 2005. |
| Lazebnik *et al.* 2006 | S. Lazebnik, C. Schmid y J. Ponce, «Beyond Bags of Features: Spatial Pyramid Matching for Recognizing Natural Scene Categories», *IEEE CVPR*, vol. 2, pp. 2169–2178, 2006. |
| Chen *et al.* 2016 | Y.-H. Chen, J. Emer y V. Sze, «Eyeriss: A Spatial Architecture for Energy-Efficient Dataflow for Convolutional Neural Networks», *ISCA*, 2016. |
| Sze *et al.* 2017 | V. Sze, Y.-H. Chen, T.-J. Yang y J. S. Emer, «Efficient Processing of Deep Neural Networks: A Tutorial and Survey», *Proceedings of the IEEE*, vol. 105, n.º 12, pp. 2295–2329, 2017. |
| Waterman *et al.* | A. Waterman y K. Asanović (eds.), *The RISC-V Instruction Set Manual, Volume I: Unprivileged ISA*, RISC-V International. **Indicar la versión y el año de la edición efectivamente consultada.** |
| SkyWater 2020 | SkyWater Technology y Google, *SKY130 Open Source PDK*, 2020. Primer kit de diseño de un proceso comercial publicado sin acuerdo de confidencialidad. |
| Shalan y Edwards 2020 | M. Shalan y T. Edwards, «Building OpenLANE: A 130nm OpenROAD-based Tapeout-Proven Flow», *ICCAD*, 2020. |
| Baischer *et al.* | L. Baischer, A. Leitner, B. Kulnik, S. Marschner y M. Cerv, *FPGA-Net: A Neural Network Hardware Accelerator*, proyecto universitario, Technische Universität Wien. Documentación y código en `github.com/kayaleitner/FPGA_MNIST`. **No es una publicación revisada por pares**, y así debe citarse. |

### Tres precisiones que la verificación produjo

**Sobel y Feldman nunca publicaron su operador.** Fue una charla en el Stanford Artificial
Intelligence Laboratory en 1968, descrita después por terceros —Pingle en 1969 y Duda y Hart en su
libro de 1973—. Por eso buena parte de la literatura lo cita como «Duda y Hart 1973», o directamente
como «el operador de Sobel» sin referencia. **Citar la charla de 1968 es correcto siempre que se
indique que no es una publicación formal**, y conviene hacerlo explícito para que un revisor no lo
tome por un descuido.

**El artículo de Eyeriss que corresponde citar es el de ISCA 2016**, no el de ISSCC del mismo año.
Los dos existen y describen el mismo sistema, pero el que desarrolla el argumento sobre el flujo de
datos —que es el que la §2.6 invoca— es el de ISCA.

**Otsu aparece con dos numeraciones de volumen en la literatura**, «vol. 9» y «vol. SMC-9». Ambas
remiten al mismo artículo; se adopta la segunda por ser la que figura en el índice de la revista.

---

> ⚠️ **Lo que sigue pendiente en este capítulo.** La afirmación de la §2.8 sobre el estado de la
> literatura **se reformuló** tras la búsqueda: donde antes decía que «la mayoría de los trabajos se
> detienen en FPGA» —un cuantificador que no podía defenderse— ahora describe una cuestión de acceso
> que las fuentes sí sostienen. La revisión realizada **no es sistemática**, y el texto lo declara.
>
> El contraste con las 36 referencias ya recopiladas **está hecho** (21 de septiembre): ocho obras
> estaban en ambas listas y se fundieron conservando los datos verificados, nueve son aportación de
> esta verificación, y el resultado son **45 entradas sin duplicados** en `bibliografia.md`. Se
> comprobó además que ninguna entrada de la tabla anterior queda sin citar en el cuerpo del capítulo,
> y ninguna cita del cuerpo queda sin entrada.