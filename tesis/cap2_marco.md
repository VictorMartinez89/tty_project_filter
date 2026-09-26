# 2. Marco teórico y estado del arte

> **Estado:** borrador 2, 2026-09-21. **Las diecisiete citas están verificadas contra la fuente** y
> cotejadas con las 36 ya recopiladas; el resultado son las 47 entradas de `bibliografia.md`. Ver la
> nota al final del capítulo para las tres precisiones que la verificación produjo.

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

### Y por qué esto puede hacerse hoy en un trabajo de maestría

Conviene precisar qué es lo reciente, porque el arreglo que permite llevar estos diseños a silicio no
es nuevo: lo nuevo es que sea abierto. **Mead y Conway** establecieron en 1980 los tres elementos que
lo sostienen [Mead y Conway 1980]. El primero es un conjunto de **reglas de diseño escalables**,
expresadas en una unidad normalizada, que permite razonar sobre el circuito sin conocer la física del
proceso. El segundo es su consecuencia: la **separación entre diseñar y fabricar**, que convierte el
plano en un objeto intercambiable entre dos organizaciones distintas. Y el tercero es la **oblea
compartida**, que reparte el costo de una máscara entre muchos diseños pequeños y fue lo que puso el
silicio al alcance de un curso universitario.

Los tres reaparecen, cuatro décadas después, en la forma que este trabajo utiliza: el kit de diseño
cumple el papel de las reglas, el fichero de plano el del objeto intercambiable, y las lanzas
educativas el de la oblea compartida. **La novedad no es la posibilidad sino el precio de entrada**,
y es sobre esa distinción que se apoya la §2.8.

> Merece señalarse que la §5.7 de este trabajo mide un **límite** de la primera de esas tres ideas.
> La abstracción que permite diseñar sin conocer el proceso funciona porque alguien caracterizó cada
> celda sobre su dibujo; cuando el modelo que se entrega a una herramienta es el esquema y no el
> dibujo, **la abstracción se rompe en silencio, y en un 22 % del retardo**.

> La contribución de este trabajo a esa línea no es teórica sino de escala y de método: mide el mismo
> fenómeno **en el extremo opuesto del rango** —sistemas completos de uno a diez milímetros
> cuadrados, no aceleradores de decenas— **sobre silicio firmado y con el circuito gemelo como
> control**. Que la misma ley aparezca a esa escala, con un presupuesto miles de veces menor y sobre
> algoritmos clásicos en lugar de redes neuronales, sugiere que no es una propiedad del aprendizaje
> profundo sino del sustrato.

## 2.7 El sustrato: RISC-V y el flujo abierto a silicio

El procesador empleado implementa el conjunto de instrucciones **RV32I**, el subconjunto entero de 32
bits de la especificación abierta RISC-V [Waterman y Asanović 2017]. La elección responde a que un conjunto
abierto permite implementaciones mínimas sin restricciones de licencia, y a que existen núcleos de
tamaño compatible con el presupuesto de este trabajo.

El paso a silicio se realiza con el flujo abierto **OpenLane** sobre el kit de diseño **sky130A**, y
con LibreLane sobre IHP SG13G2 para la segunda tecnología. La disponibilidad de estos flujos es
reciente y es lo que hace posible que un trabajo de maestría produzca GDSII verificado sin licencias
comerciales.


Entre una FPGA y un ASIC cambian cosas que el RTL no expresa: la inicialización de los registros, la
existencia de memoria en el sustrato, la disponibilidad de tri-estado interno y las primitivas
específicas del fabricante. La §4.8 las enumera; aquí basta señalar que **ninguna de ellas produce un
error de simulación**, lo que las convierte en una clase de problema particularmente incómoda.

## 2.8 Trabajos relacionados

Dos trabajos del mismo grupo de investigación sirven de referencia directa.

El primero implementa conversión a escala de grises y filtrado de Sobel sobre sky130, llevado a
fabricación mediante Tiny Tapeout, con verificación en cocotb y una interfaz serie. Emplea la misma
expresión del gradiente que este trabajo, `|Gx|+|Gy|`, aunque no la misma aritmética: la §2.9 lo
detalla. La diferencia es de alcance —aquí hay procesador, tres filtros
seleccionables, cadena completa con cámara y pantalla, y un clasificador— y **no de calidad**.
Constituye una referencia inicial, no una base que este trabajo extienda. Por ser el antecedente directo, se
analiza aparte en la §2.9.

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

## 2.9 El antecedente directo: el chip de escala de grises y Sobel de Diana Maldonado

El punto de partida de este trabajo no es un artículo sino un chip. Diana Natali Maldonado Ramírez,
del mismo grupo de investigación de la Universidad Nacional de Colombia, diseñó un conversor a escala de
grises con filtro de Sobel, lo llevó a silicio en la lanzadera **Tiny Tapeout 06** (sky130) y **lo midió
fabricado** [Maldonado Ramírez 2024]. Su repositorio, `tt06_grayscale_sobel`, contiene el RTL, el banco
de pruebas, los registros del flujo físico y las mediciones de laboratorio. Esta sección lo resume a partir
de esas fuentes, que se leyeron y se ejecutaron el 26 de septiembre de 2026, y lo compara con el trabajo
presente.

### Qué hace

El chip recibe una imagen en color por **SPI**, un píxel RGB de 24 bits por palabra, y devuelve por el
mismo bus el píxel procesado. Dos pines eligen uno de cuatro modos: **gris**, **Sobel**, **gris y luego
Sobel**, o **paso directo**, lo que permite probar cada bloque por separado. Tiene además un **LFSR de
autoprueba**, que genera píxeles pseudoaleatorios dentro del chip para medir la lógica sin el cuello de
botella del bus, y **sincronizadores** para el reinicio y las señales que llegan de afuera sin relación con
el reloj.

```
  host ──SPI──▷ gray_scale_core ──▷ sobel_control ──▷ sobel_core ──▷ SPI ──▷ host
  (RGB 24 b)     (gris, 8 b)          (ventana 3×3)      (|Gx|+|Gy|)       (8 b)

  el modo (2 pines) elige: gris · Sobel · gris y Sobel · paso directo
  el LFSR de autoprueba puede reemplazar al host como fuente de píxeles
```

Ocupa **1×2 tiles**: 0,036 mm² de dado, **2 104 celdas** tras la síntesis y 2 183 tras el emplazamiento
—310 de ellas biestables—, con DRC, LVS y antenas en cero.

### El código

El estilo es el mismo que adopta este trabajo: **nada de multiplicadores**. La luminancia
`0,299 R + 0,587 G + 0,114 B` se aproxima con desplazamientos y sumas:

```systemverilog
// gray_scale_core.sv
out_px_gray_o <= (red>>2)+(red>>5)+(green>>1)+(green>>4)+(blue>>4)+(blue>>5);
//                0,28125·R         0,5625·G           0,09375·B
```

y el gradiente es la norma L1 con saturación, escrita con restas y un desplazamiento:

```systemverilog
// sobel_core.sv
assign x_grad = (v0.pix2 - v0.pix0) + ((v1.pix2 - v1.pix0) << 1) + (v2.pix2 - v2.pix0);
assign y_grad = (v2.pix0 - v0.pix0) + ((v2.pix1 - v0.pix1) << 1) + (v2.pix2 - v0.pix2);
assign sum_xy_grad = |x_grad| + |y_grad|;                        // (se abrevia el valor absoluto)
assign out_sobel_core_o = (sum_xy_grad > 255) ? 255 : sum_xy_grad;
```

### El algoritmo

Con la notación de la §4.4:

```
──────────────────────────────────────────────────────────────────────
 Algoritmo 0   Gris + Sobel de Maldonado (TT06)
──────────────────────────────────────────────────────────────────────
 GRAY_SOBEL(palabra SPI de 24 bits, modo)
 ▷ etapa 1 — gris, un registro
 1.  y ← (R≫2)+(R≫5) + (G≫1)+(G≫4) + (B≫4)+(B≫5)    ▷ blanco puro da 234, no 255
 ▷ etapa 2 — la ventana la arma el HOST, no el chip
 2.  si es la primera ventana:  w₀₀…w₂₂ ← 9 píxeles recibidos, uno por palabra
 3.  si no:                     w₀ ← w₁ ;  w₁ ← w₂ ;  w₂ ← 3 píxeles nuevos
 ▷ etapa 3 — gradiente, combinacional
 4.  Gx ≔ (w₀₂−w₀₀) + 2(w₁₂−w₁₀) + (w₂₂−w₂₀)
 5.  Gy ≔ (w₂₀−w₀₀) + 2(w₂₁−w₀₁) + (w₂₂−w₀₂)
 6.  mag ← mín(|Gx|+|Gy|, 255)                       ▷ sale la magnitud: no hay umbral
 7.  por cada píxel de salida entran 3 palabras SPI (9 en la primera ventana)
──────────────────────────────────────────────────────────────────────
```

La diferencia estructural con el Algoritmo 1 de este trabajo está en la línea 2: **no hay búfer de
líneas**. El chip no guarda ninguna fila de la imagen; es el host el que la tiene entera en memoria y le
reenvía, para cada píxel de salida, la columna nueva de la ventana. Esa decisión es la que le permite caber
en dos tiles, y es también la que fija su caudal.

### Lo que midió en silicio

Con una Raspberry Pi como host, Maldonado barrió la frecuencia del chip, la del bus y la tensión de
alimentación, y comparó cada imagen devuelta con la calculada en software:

| Medición (modo gris, imagen de 320×240) | Resultado |
|---|---|
| Caudal más alto con la imagen **idéntica** a la de software | **371 662 píxeles/s** (reloj del chip 100 MHz, SPI 9,8 MHz, 1,8 V) |
| Potencia a 1,8 V, 100 MHz, SPI a 9 MHz | **2,87 mW** |
| A 1,3 V, según su propia figura | sigue exacta a 346 514 píxeles/s, con ≈ 1,3 mW |

El caudal lo fija el bus: una palabra de 24 bits por píxel, así que la frecuencia del SPI dividida entre 24
predice las cifras medidas. En modo Sobel entran tres palabras por píxel de salida; por cuenta —no por
medida— eso deja el caudal en un tercio.

### Ventajas y desventajas, frente a este trabajo

| | Maldonado (TT06) | Este trabajo |
|---|---|---|
| **Silicio** | **fabricado y medido** | 17 chips con GDS firmado, **ninguno fabricado todavía** |
| Área del chip Sobel | **2 183 celdas**, 0,036 mm² (con gris, SPI y LFSR) | 5 823 celdas, 0,167 mm² (con un búfer de líneas para 60 píxeles de ancho) |
| Memoria de imagen | **ninguna en el chip**: la tiene el host | búferes de líneas: dominan el área |
| Entrada | imagen previa por SPI, 3 palabras por píxel | **flujo de cámara**, 1 píxel por ciclo |
| Salida | magnitud de 8 bits | borde (con umbral), y con Canny, octante y clase |
| Filtros | Sobel | Sobel, Canny de un salto, Canny transitivo, y un clasificador |
| Autoprueba | **LFSR en el chip** | no la hay |
| Verificación | cocotb, **por inspección visual** de la imagen | comparación **bit a bit** contra un modelo golden |

Las dos columnas no compiten: responden preguntas distintas. La de Maldonado es **cuánto cuesta el
filtro solo, y si el silicio hace lo que dice**; su respuesta —dos tiles, milivatios, imagen exacta a
cientos de miles de píxeles por segundo— es la única medición física de toda esta línea de trabajo. La de
éste es **qué pasa cuando el filtro tiene que vivir en un sistema**: con cámara, con memoria y con una
decisión aguas abajo. Y la respuesta que da el Capítulo 5 es que entonces **lo caro deja de ser el
filtro y pasa a ser la memoria**, que es exactamente lo que el diseño de Maldonado había dejado fuera del
chip.

### Una observación de verificación

Al simular `sobel_core` con Icarus Verilog aparece un detalle que conviene dejar escrito, porque ilustra
la regla metodológica de la §3.3. La ventana declara los píxeles como `logic signed [7:0]`, de modo que un
gris mayor que 127 se lee como negativo: 200 entra como −56. Mientras los nueve píxeles caen del mismo
lado de 128, la resta da lo mismo; cuando una ventana **cruza** ese valor, el gradiente se deforma. Un
escalón suave de 120 a 140, que debería dar 80, da 255, y uno de 0 a 200 da 224 en lugar de saturar. Sobre
la mariposa de sus propias pruebas afecta al **8,8 %** de los píxeles de salida. El núcleo de este
trabajo extiende cada píxel con un cero antes de restar (`{1'b0, pix}`) y no tiene el problema.

El error no aparece en su modo gris —el que midió a fondo— y la imagen de diferencias que ella misma
registró en modo Sobel sí muestra marcas que éste predice, pero también diferencias mayores que éste no
explica. Esa comparación se hizo entre dos ficheros JPEG, y la compresión basta para que dos imágenes
iguales no coincidan. **No es un reparo al chip, sino al instrumento**: una comparación que no puede dar
cero no puede distinguir un error de una pérdida de compresión. Es la razón por la que en este trabajo
todo se juzga **bit a bit contra el modelo golden**, sin imágenes intermedias y sin mirar.

### Qué toma este trabajo de él

El estilo de la aritmética —desplazamientos y sumas, ningún multiplicador—; las imágenes de prueba
(`flower`, `monarch`, `butterfly`), que atraviesan todo el Capítulo 5; la norma L1 con saturación como
magnitud; y, para Tiny Tapeout, la lección de **serializar la entrada y la salida** para ahorrar pines y área. Lo
que agrega es lo que Maldonado dejó conscientemente fuera: la cámara, la memoria de líneas, el procesador y
el reconocimiento.

## Referencias citadas en este capítulo

**Las dieciocho primeras se verificaron contra la fuente el 21 de septiembre de 2026; la de Maldonado Ramírez, el 26.** Volumen, número y
páginas están comprobados salvo donde se indica.

| Cita | Referencia |
|---|---|
| Hu 1962 | M.-K. Hu, «Visual Pattern Recognition by Moment Invariants», *IRE Trans. Information Theory*, vol. 8, n.º 2, pp. 179–187, 1962. |
| Sobel y Feldman 1968 | I. Sobel y G. Feldman, «A 3×3 Isotropic Gradient Operator for Image Processing», **charla en el Stanford Artificial Intelligence Laboratory**, 1968. *No es una publicación formal* (véase la nota). |
| Prewitt 1970 | J. M. S. Prewitt, «Object Enhancement and Extraction», en B. Lipkin y A. Rosenfeld (eds.), *Picture Processing and Psychopictorics*, Academic Press, pp. 75–149, 1970. |
| Kirsch 1971 | R. A. Kirsch, «Computer determination of the constituent structure of biological images», *Computers and Biomedical Research*, vol. 4, n.º 3, pp. 315–328, 1971. |
| Otsu 1979 | N. Otsu, «A Threshold Selection Method from Gray-Level Histograms», *IEEE Trans. Systems, Man, and Cybernetics*, vol. SMC-9, n.º 1, pp. 62–66, ene. 1979. |
| Mead y Conway 1980 | C. Mead y L. Conway, *Introduction to VLSI Systems*, Addison-Wesley, 1980. |
| Canny 1986 | J. Canny, «A Computational Approach to Edge Detection», *IEEE Trans. Pattern Analysis and Machine Intelligence*, vol. PAMI-8, n.º 6, pp. 679–698, nov. 1986. |
| Vincent 1993 | L. Vincent, «Morphological Grayscale Reconstruction in Image Analysis: Applications and Efficient Algorithms», *IEEE Trans. Image Processing*, vol. 2, n.º 2, pp. 176–201, abr. 1993. |
| LeCun *et al.* 1998 | Y. LeCun, L. Bottou, Y. Bengio y P. Haffner, «Gradient-Based Learning Applied to Document Recognition», *Proceedings of the IEEE*, vol. 86, n.º 11, pp. 2278–2324, 1998. |
| Lowe 2004 | D. G. Lowe, «Distinctive Image Features from Scale-Invariant Keypoints», *International Journal of Computer Vision*, vol. 60, n.º 2, pp. 91–110, 2004. |
| Dalal y Triggs 2005 | N. Dalal y B. Triggs, «Histograms of Oriented Gradients for Human Detection», *IEEE CVPR*, vol. 1, pp. 886–893, 2005. |
| Lazebnik *et al.* 2006 | S. Lazebnik, C. Schmid y J. Ponce, «Beyond Bags of Features: Spatial Pyramid Matching for Recognizing Natural Scene Categories», *IEEE CVPR*, vol. 2, pp. 2169–2178, 2006. |
| Chen *et al.* 2016 | Y.-H. Chen, J. Emer y V. Sze, «Eyeriss: A Spatial Architecture for Energy-Efficient Dataflow for Convolutional Neural Networks», *ISCA*, 2016. |
| Sze *et al.* 2017 | V. Sze, Y.-H. Chen, T.-J. Yang y J. S. Emer, «Efficient Processing of Deep Neural Networks: A Tutorial and Survey», *Proceedings of the IEEE*, vol. 105, n.º 12, pp. 2295–2329, 2017. |
| Waterman y Asanović 2017 | A. Waterman y K. Asanović (eds.), *The RISC-V Instruction Set Manual, Volume I: User-Level ISA, Document Version 2.2*, may. 2017. Es la edición contra la que está escrito el decodificador del núcleo empleado, que la cita en su propio código. |
| SkyWater 2020 | SkyWater Technology y Google, *SKY130 Open Source PDK*, 2020. Primer kit de diseño de un proceso comercial publicado sin acuerdo de confidencialidad. |
| Shalan y Edwards 2020 | M. Shalan y T. Edwards, «Building OpenLANE: A 130nm OpenROAD-based Tapeout-Proven Flow», *ICCAD*, 2020. |
| Baischer *et al.* | L. Baischer, A. Leitner, B. Kulnik, S. Marschner y M. Cerv, *FPGA-Net: A Neural Network Hardware Accelerator*, proyecto universitario, Technische Universität Wien. Documentación y código en `github.com/kayaleitner/FPGA_MNIST`. **No es una publicación revisada por pares**, y así debe citarse. |
| Maldonado Ramírez 2024 | D. N. Maldonado Ramírez, *tt06_grayscale_sobel — Gray scale and Sobel filter*, Tiny Tapeout 06, sky130, 2024. Repositorio con RTL, banco de pruebas, registros del flujo y mediciones del chip fabricado: `github.com/DianaNatali/tt06_grayscale_sobel`. **No es una publicación revisada por pares.** |

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

> **El alcance de esta revisión, declarado.** La revisión bibliográfica de este capítulo **no es
> sistemática**: no se siguió un protocolo de búsqueda reproducible, ni se acotó un conjunto de bases
> de datos, ni se aplicaron criterios de inclusión y exclusión documentados. Es una revisión
> **orientada al argumento**: se buscó aquello que sostiene o refuta las afirmaciones que el capítulo
> necesita hacer. Decirlo importa porque delimita qué puede concluirse de él —sitúa el trabajo en su
> tradición— y qué no: **no autoriza ninguna afirmación sobre la frecuencia relativa de unas prácticas
> frente a otras en la literatura.**
>
> Esa distinción tuvo una consecuencia concreta. La §2.8 afirmaba en su primera redacción que «la
> mayoría de los trabajos se detienen en FPGA», un cuantificador que **exigiría precisamente el
> recuento que esta revisión no hizo**. Se reformuló: donde había una afirmación sobre proporciones
> hay ahora una sobre condiciones de acceso, que las fuentes sí sostienen. Se deja constancia del
> cambio porque la afirmación retirada era cómoda para el argumento, y conviene que se vea que se
> retiró por no poder sostenerla y no por haber dejado de ser útil.
>
> **Las diecisiete citas del capítulo están verificadas contra la fuente** y cotejadas con las 36 ya
> recopiladas: ocho obras coincidían y se fundieron conservando los datos verificados, nueve son
> aportación de esta verificación, y el resultado son las **47 entradas sin duplicados** de
> `bibliografia.md`. Se comprobó además, en las dos direcciones, que ninguna entrada de la tabla
> anterior queda sin citar en el cuerpo del capítulo y ninguna cita del cuerpo queda sin entrada.