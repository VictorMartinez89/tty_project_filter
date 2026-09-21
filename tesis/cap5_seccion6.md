# 5.6 Reconocimiento de patrones: del borde al dígito

> **Estado:** borrador 1, escrito el 2026-09-15. Fuente: cuaderno 2 §21-§30.
> Formato Markdown para convertir con `pandoc` a Word o LaTeX según decida la guía de la Facultad.

Las secciones anteriores de este capítulo presentaron los resultados de un sistema que **procesa**
imágenes: detecta bordes, los almacena y los muestra. Ésta presenta los de un sistema que las
**reconoce**. La diferencia no es de grado sino de naturaleza: la salida deja de ser una imagen y
pasa a ser una decisión —un dígito de 0 a 9, o la declaración explícita de no saber— y con ello el
trabajo enlaza con el planteamiento del Capítulo 1.

Los resultados que siguen son **mediciones**, no proyecciones: un clasificador verificado contra su
modelo de referencia sobre 70 000 imágenes, validado físicamente sobre una FPGA frente a una cámara
real, e implementado en dos circuitos integrados con GDS firmado.

## 5.6.1 Arquitectura del reconocedor

El reconocedor reutiliza íntegramente el extractor de bordes descrito en la §4.3 y le añade dos
etapas. La cadena completa consta de cuatro pasos, y **ninguno de ellos contiene un multiplicador en
el camino de datos de imagen**:

1. **Extracción de bordes.** El operador Sobel 3×3 sobre una ventana de 28×28 píxeles. La magnitud se
   calcula con la norma L1, `|Gx|+|Gy|`, evitando la raíz cuadrada. La orientación se codifica como
   **octante** mediante la terna `⟨sgn Gy, sgn Gx, |Gy|>|Gx|⟩`: tres comparaciones en lugar de una
   arcotangente.

2. **Histograma de orientaciones por zona.** El cuadro se divide en cuatro cuadrantes y cada píxel de
   borde incrementa uno de **32 contadores** (4 zonas × 8 octantes). Los contadores saturan en lugar
   de desbordar, de modo que una escena con exceso de bordes produce un valor máximo y no un valor
   pequeño espurio.

3. **Pirámide espacial.** El descriptor final consta de **40 rasgos**: los 32 contadores más ocho
   correspondientes a la imagen completa. Estos ocho **no se cuentan: se derivan** sumando los cuatro
   cuadrantes, que constituyen una partición del cuadro. Es la razón por la que el circuito almacena
   32 contadores y no 40, y ahorra ocho registros de 9 bits.

4. **Clasificador lineal cuantizado.** Diez clases por cuarenta rasgos suman **400 pesos de 4 bits con
   signo**, una multiplicación-acumulación por ciclo, seguidas de `argmax`. Los pesos residen en una
   memoria de sólo lectura combinacional: **no consumen un solo biestable**.

A la decisión se le superpone una **regla de rechazo** —clasificación con opción de rechazo, en los
términos de Chow [1970]— que exige dos condiciones simultáneas: que el número de bordes sea plausible
y que el ganador aventaje al segundo clasificado por un margen mínimo. Si alguna falla, el circuito
responde **NADA** en lugar de arriesgar una respuesta.

> **Sobre la elección del descriptor.** La combinación de rejilla espacial e histograma de
> orientaciones no es original de este trabajo: corresponde al esquema HOG propuesto por Dalal y
> Triggs [2005], sobre la receta que Lowe [2004] había establecido para SIFT, organizada en niveles
> según la pirámide espacial de Lazebnik, Schmid y Ponce [2006]. Lo que este trabajo aporta es su
> realización en hardware bajo restricciones severas, con cuatro decisiones propias: el octante sin
> arcotangente, el nivel 0 derivado en lugar de contado, el voto binario en lugar de ponderado por
> magnitud, y la construcción del descriptor **sin almacenar la imagen**.

## 5.6.2 Exactitud sobre MNIST

Se entrenó el clasificador sobre las 60 000 imágenes de entrenamiento de MNIST y se evaluó sobre las
10 000 de prueba, con los pesos cuantizados a 4 bits y la regla de rechazo calibrada **exclusivamente
sobre el conjunto de entrenamiento**. Se compararon cinco configuraciones de front-end bajo idéntico
procedimiento:

| front-end | exactitud | F1 macro | precisión al responder | falsos positivos |
|---|---:|---:|---:|---:|
| Sobel | 91.04 % | 0.910 | 98.43 % | 98 |
| SoC + Sobel | 91.03 % | 0.910 | 98.38 % | 103 |
| Canny 1-salto | 92.03 % | 0.920 | 98.66 % | 85 |
| **SoC + Canny 1-salto** | **92.46 %** | **0.924** | **98.84 %** | **73** |
| Canny transitivo | 89.76 % | 0.897 | 97.80 % | 139 |

El ruido experimental del procedimiento se estimó mediante **validación cruzada de diez pliegues
disjuntos** sobre las 60 000 imágenes, obteniéndose **σ = 1.32 puntos porcentuales**. Bajo ese
criterio, **las diferencias entre los cuatro primeros front-ends no son estadísticamente
demostrables**: el margen entre el mejor y el Sobel es de 1.42 pp, inferior a la propia σ. Únicamente
el Canny transitivo se separa del conjunto, con 2.70 pp (2.05 σ), resultado que una prueba de
Mann-Whitney sobre los pliegues confirma.

## 5.6.3 Lo que la exactitud no muestra

Las medidas basadas en el `argmax` descartan la información de los diez puntajes. Dos medidas que la
conservan revelan una diferencia que la exactitud oculta:

| front-end | AUC macro | Brier | Brier skill |
|---|---:|---:|---:|
| SoC + Canny 1-salto | **0.9960** | **0.1465** | **0.8371** |
| Canny 1-salto | 0.9957 | 0.1558 | 0.8268 |
| Sobel | 0.9945 | 0.1746 | 0.8059 |
| Canny transitivo | 0.9942 | **0.1991** | 0.7787 |
| SoC + Sobel | 0.9939 | 0.1749 | 0.8056 |

El resultado de interés corresponde al Canny transitivo. En AUC —que mide el **ordenamiento**— supera
al SoC+Sobel; en Brier —que mide la **calibración**— queda último por amplio margen. **Ordena
correctamente y decide mal.** Ello explica de forma mecánica sus 139 falsos positivos: la
reconstrucción morfológica engruesa los contornos, el engrosamiento infla los histogramas, y el
criterio de rechazo —que compara el mejor puntaje con el segundo— deja hablar al circuito cuando
debería callarlo.

## 5.6.4 El punto de operación pesa más que el front-end

Las comparaciones anteriores fijan el umbral y varían el filtro. El experimento complementario
—fijar el filtro y **barrer el umbral**— arroja el resultado de mayor consecuencia práctica de esta
sección:

| magnitud | rango de exactitud | en unidades de σ |
|---|---:|---:|
| el umbral, dentro del Sobel | **5.79 pp** | **4.4 σ** |
| el umbral, dentro del Canny | 0.90 pp | 0.7 σ |
| el filtro, cada uno en su óptimo | 0.38 pp | 0.3 σ |

**Mover el umbral dentro del Sobel altera el resultado quince veces más que cambiar de filtro.** Y la
asimetría entre ambos front-ends es el hallazgo: el Sobel presenta un óptimo estrecho —su exactitud
recorre casi seis puntos a lo largo del rango útil— mientras que el Canny se mantiene en una meseta
de nueve décimas. **El Canny en su peor umbral supera al Sobel en diez de los once umbrales
ensayados.**

El mecanismo reside en el algoritmo: el Sobel aplica un corte único y nada recupera al píxel que
queda por debajo; el Canny dispone de dos umbrales y una histéresis que promueve el píxel débil
adyacente a uno fuerte. **La histéresis es un mecanismo de recuperación**, y de ahí su insensibilidad.

> **Consecuencia de diseño.** El front-end y el registro escribible resuelven el mismo problema por
> vías distintas: el Canny adquiere **en hardware** —un *line-buffer* adicional y ocho
> comparaciones— buena parte de la robustez que el Sobel obtiene mediante **un procesador** capaz de
> reescribir el umbral. No son decisiones que se sumen: son, en buena medida, **alternativas**.

## 5.6.5 El RTL contra el modelo, sobre el conjunto completo

Las cifras anteriores son del modelo en Python. La pregunta que decide si sirven de algo es si el
circuito las reproduce, y se respondió por el camino más exigente disponible: **ejecutar el RTL sobre
las diez mil imágenes de prueba** en el simulador y comparar, no los porcentajes agregados, sino cada
predicción con la del modelo.

| Comparación | Resultado |
|---|---|
| Predicciones idénticas | **10 000 / 10 000** |
| Exactitud del RTL / del modelo | **91.04 % / 91.04 %** |
| Matriz de confusión | idéntica elemento por elemento |
| Veredictos de la clase de rechazo | **10 000 / 10 000** idénticos |
| Cuadros aceptados · precisión al responder | 8 838 (88.38 %) · 95.44 %, en ambos |

No son cifras «parecidas» ni «dentro del margen de error»: **las diez mil predicciones y los diez mil
veredictos coinciden uno por uno**, y la matriz de confusión es la misma casilla por casilla. La
verificación de los filtros de la §5.1 se hizo sobre cinco imágenes; ésta se hizo sobre diez mil, e
incluye la decisión de rechazo, que es lógica de comparación y no de aritmética.

> Conviene precisar el alcance, porque más adelante aparece una cifra distinta. Lo que aquí es
> exacto es el **clasificador completo** —descriptor, pesos y decisión— evaluado imagen por imagen.
> El 99.91 % que informa la §5.6.6 se refiere a otra comparación: la del **extractor de bordes**
> píxel a píxel dentro de la cadena, cuyas discrepancias se concentran en la última fila del cuadro
> y no alteran ninguna de las diez mil clasificaciones. Son dos medidas de objetos distintos y no se
> contradicen.

## 5.6.6 Validación física

La validación sobre la placa se realizó en dos ensayos distintos, que miden cosas distintas y cuyos
resultados no deben confundirse.

**Primer ensayo: diez dígitos grabados en el propio bitstream.** Se embebieron diez imágenes de MNIST
en la memoria de configuración y se hizo que el circuito informara sus veredictos por el puerto
serie, sin cámara. La placa acertó **ocho de los diez**, y lo relevante no son los ocho aciertos sino
los dos fallos: el circuito confunde el **2** con un 0 y el **3** con un 8, **exactamente los mismos
dos dígitos y exactamente las mismas respuestas equivocadas** que había dado la simulación del diseño
completo. Ninguno de los diez cambió de respuesta a lo largo de unas treinta repeticiones.

> Reproducir un acierto puede ser casualidad; reproducir un error específico y repetido, no. Este
> ensayo no mide la exactitud del sistema —diez imágenes no son una medida estadística— sino que
> **cierra el último eslabón de la traducción**: el diseño sintetizado, emplazado, ruteado y cargado
> en silicio se comporta como el RTL verificado, errores incluidos.

**Segundo ensayo: dígitos manuscritos ante la cámara.** El sistema completo —procesador RISC-V,
periférico de umbrales, front-end Canny y clasificador— se enfrentó a dígitos escritos a mano y
captados por una cámara OV7670. **El circuito reconoció nueve de diez dígitos**, coincidiendo
exactamente con lo que la simulación había predicho para esa configuración.

Ese acuerdo, sin embargo, no se obtuvo al primer intento, y la causa merece registrarse porque es la
única discrepancia entre simulación y silicio de todo el trabajo. En la primera versión la placa
respondía **ocho de diez** mientras la simulación sostenía nueve. El umbral inferior del front-end
se leía desde el módulo de control mediante una **referencia jerárquica** —`SOC.flt_tlo`— en lugar de
un puerto declarado. Ambas herramientas aceptaron el archivo sin una sola advertencia y construyeron
circuitos distintos: `iverilog` resuelve la referencia y simula con el umbral escrito por el
procesador, mientras que el sintetizador crea un cable implícito de un bit que nadie gobierna y fija
el umbral inferior en cero. Sustituida la referencia por un **puerto real**, la placa pasó a nueve de
diez: el valor que la simulación predecía.

> **La lección no es que hubiera un error, sino dónde estaba.** El RTL era legal, la simulación era
> correcta y la síntesis también lo era; lo que falló fue suponer que ambas leían la misma
> descripción. Una construcción que el lenguaje admite y que las dos herramientas interpretan de
> forma distinta es indetectable por inspección y silenciosa en los registros de ambas. Se deja
> escrita la regla de trabajo que se adoptó a partir de aquí: **toda señal que cruce una frontera de
> módulo se declara como puerto**, aunque el simulador acepte el atajo.

La verificación del extractor contra su modelo de referencia arrojó **99.91 %** de coincidencia
exacta píxel a píxel para el Sobel y **99.93 %** para el Canny, concentrándose las diferencias en la
última fila del cuadro.

## 5.6.7 Implementación en silicio

El reconocedor se llevó a tecnología `sky130_fd_sc_hd` en dos variantes, ejecutando el flujo completo
de OpenLane hasta la firma del GDS:

| magnitud | Sobel | Canny 1-salto |
|---|---:|---:|
| área del *die* | 0.845 mm² | 0.890 mm² |
| celdas tras síntesis | 16 718 | 17 373 |
| celdas emplazadas | 19 949 | 20 921 |
| período de reloj | 30 ns (33.3 MHz) | 30 ns (33.3 MHz) |
| holgura con parásitos (`spef_wns`) | **0.00 ns** | **0.00 ns** |
| DRC · LVS · XOR | 0 · 0 · 0 | 0 · 0 · 0 |

Ambos circuitos cierran el temporizado con los parásitos del interconexionado extraídos y superan las
tres verificaciones de firma sin observaciones. Merece señalarse que **cierran más rápido que los
circuitos de visión equivalentes** —que requirieron 32 y 36 ns—, lo que resulta coherente con la
ausencia de memoria de cuadro: es el multiplexor de lectura del *framebuffer* el que constituye el
camino crítico de aquéllos.

**Son los primeros circuitos de este trabajo cuya salida no es una imagen.** Los diez presentados en
las secciones §5.3 y §5.4 procesan; éstos reconocen.

## 5.6.8 El costo relativo del front-end depende del sistema

La comparación de área entre ambos front-ends admite cuatro niveles de integración, tres de ellos
medidos con anterioridad y el cuarto aportado por esta sección:

| nivel | Sobel | Canny | factor |
|---|---:|---:|---:|
| filtro aislado | 4 651 | 10 284 | **2.21×** |
| con procesador | 9 906 | 22 054 | 2.23× |
| sistema de visión completo | 35 653 | 41 925 | 1.18× |
| **reconocedor** | **19 949** | **20 921** | **1.05×** |

**El sobrecosto del Canny se diluye conforme crece el sistema que lo rodea.** Considerado de forma
aislada cuesta un 121 % más; integrado en un reconocedor, un 5 %. El motivo es que el clasificador
—histograma, pirámide y 400 multiplicaciones— es idéntico en ambas variantes y domina el área,
mientras que la diferencia se reduce al tercer *line-buffer*.

De ello se sigue una conclusión condicional: **el Sobel aventaja al Canny en área únicamente cuando
el filtro constituye el circuito completo.** En un sistema que reconoce, esa ventaja —la única que el
Sobel conserva, según §5.6.2 a §5.6.4— deja de ser determinante.

---

## Referencias de la sección

- Chow, C. K. (1970). *On Optimum Recognition Error and Reject Tradeoff.* IEEE Trans. Inf. Theory, 16(1), 41-46.
- Dalal, N. y Triggs, B. (2005). *Histograms of Oriented Gradients for Human Detection.* CVPR, 886-893.
- Lazebnik, S., Schmid, C. y Ponce, J. (2006). *Beyond Bags of Features: Spatial Pyramid Matching.* CVPR, 2169-2178.
- Lowe, D. G. (2004). *Distinctive Image Features from Scale-Invariant Keypoints.* IJCV, 60(2), 91-110.
