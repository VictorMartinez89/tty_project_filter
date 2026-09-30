# 6. El reconocimiento: pirámides espaciales y MNIST

Los capítulos anteriores presentaron un sistema que **procesa** imágenes: detecta bordes, los almacena
y los muestra. Éste presenta un sistema que las **reconoce**. La diferencia no es de grado sino de naturaleza: la salida deja de ser una imagen y
pasa a ser una decisión —un dígito de 0 a 9, o la declaración explícita de no saber— y con ello el
trabajo enlaza con el planteamiento del Capítulo 1.

Los resultados que siguen son **mediciones**, no proyecciones: un clasificador verificado contra su
modelo de referencia sobre 70 000 imágenes, validado físicamente sobre una FPGA frente a una cámara
real. Su implementación en silicio es el Capítulo 7.

## 6.1 Arquitectura del reconocedor

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

## 6.2 Exactitud sobre MNIST

Se entrenó el clasificador sobre las 60 000 imágenes de entrenamiento de MNIST y se evaluó sobre las
10 000 de prueba, con los pesos cuantizados a 4 bits y la regla de rechazo calibrada **exclusivamente
sobre el conjunto de entrenamiento**. Se compararon seis configuraciones de front-end bajo idéntico
procedimiento; las cinco primeras comparten el clasificador de 40 rasgos descrito en la §6.1, y la
sexta, **Canny-78**, es la versión ampliada que presenta la §6.3.5:

| front-end | exactitud | F1 macro | precisión al responder | falsos positivos |
|-------------------|---------:|--------:|----------------------:|----------------:|
| Sobel | 91,04 % | 0,910 | 98,43 % | 98 |
| SoC + Sobel | 91,03 % | 0,910 | 98,38 % | 103 |
| Canny 1-salto | 92,03 % | 0,920 | 98,66 % | 85 |
| SoC + Canny 1-salto | 92,46 % | 0,924 | 98,84 % | 73 |
| Canny transitivo | 89,76 % | 0,897 | 97,80 % | 139 |
| **Canny-78** *(§6.3.5)* | **97,22 %** | **0,972** | **99,92 %** | **5** |

Table: Exactitud sobre MNIST según el front-end.

El ruido experimental del procedimiento se estimó mediante **validación cruzada de diez pliegues
disjuntos** sobre las 60 000 imágenes, obteniéndose **σ = 1,32 puntos porcentuales**. Bajo ese
criterio, **las diferencias entre los cuatro primeros front-ends no son estadísticamente
demostrables**: el margen entre el mejor y el Sobel es de 1,42 pp, inferior a la propia σ. Únicamente
el Canny transitivo se separa del conjunto, con 2,70 pp (2,05 σ), resultado que una prueba de
Mann-Whitney sobre los pliegues confirma.

La sexta fila es de otra escala. **Canny-78 aventaja al mejor de los cinco en 4,76 pp, es decir, en
3,6 σ**, y lo hace con el mismo front-end que el SoC + Canny 1-salto: lo que cambia no es el filtro
sino el descriptor y el clasificador que lo leen. A una cobertura comparable —66 % frente a 63 %—
responde y se equivoca **cinco veces en diez mil**, contra setenta y tres. Es, además, la base de
Canny-98 (§6.3.6), que corre en la misma tarjeta.

![**Figura 6.1.** El espacio de diseño del clasificador, con el eje horizontal en escala
logarítmica. Cada curva es un nivel de la pirámide espacial y cada punto una precisión de peso
distinta. El hallazgo está en el cruce: **400 pesos de 4 bits —1 600 biestables— superan a los 784
píxeles crudos usando la vigésima parte de la memoria**, y caben bajo el presupuesto real de un chip
de 8×2 mosaicos, marcado con la línea vertical. A igualdad de memoria, la precisión de los pesos vale
más que el número de zonas.](figuras/fig_5_4_espacio_de_diseno.png)

## 6.3 Los diseños: los reconocedores

La tabla de la §6.2 compara front-ends; esta sección presenta los circuitos que los llevan. Son seis,
y se describen con el mismo formato que los diseños de la §4.3: qué hacen, su pseudocódigo, dónde está
el código, qué predice el modelo, qué muestra la simulación del hardware, qué se midió en la tarjeta y
qué dio en silicio. Los cuatro primeros usan el descriptor de cuarenta rasgos de la §6.1 y difieren en
dos decisiones: si el umbral lo fija un **procesador** o un cable, y si el resultado se **muestra** en
una pantalla o sólo se entrega en unos pines. El quinto, Canny-78, es el mismo camino llevado al límite
de la tarjeta, y el sexto, Canny-98, le añade una capa oculta.

### Pan Sobel

#### Resumen

Es el primer circuito del trabajo cuya salida no es una imagen. Toma la luminancia de la cámara
OV7670, recorta la **ventana central de 448×448** píxeles y la reduce a 28×28 promediando bloques de
16×16 —un promedio y no una decimación, para que un trazo fino no caiga entre dos muestras—, invierte
el resultado porque MNIST es trazo claro sobre fondo oscuro, y lo entrega al extractor y al clasificador
de la §6.1. La salida son **cuatro bits con el dígito y uno que dice «me lo creo»**. No hay
*framebuffer* ni controlador de pantalla.

Lo que aporta el procesador es lo mismo que en el SoC de la §4.3.4: el umbral del Sobel deja de estar
cableado y lo escribe el programa, 90, a través del periférico en `0x0045`. El SoC se incorporó **sin
su propio Sobel** —el extractor ya trae uno—, porque ese datapath duplicado era la diferencia entre
entrar en la iCE40UP5K y no entrar.

#### Pseudocódigo

```
──────────────────────────────────────────────────────────────────────
 Algoritmo 14   Pan Sobel: la cámara, el procesador y el clasificador
──────────────────────────────────────────────────────────────────────
 ▷ el procesador, una vez: el programa del Algoritmo 4
 1.  THR(0x0045+4) ← 0x5A00                   ▷ thr = 90
 ▷ por cada píxel de la cámara (reloj pclk)
 2.  si (x, y) está en la ventana central de 448×448 entonces
 3.      acumular Y en el bloque de 16×16 que le toca
 4.      al cerrar el bloque: p ← 255 − (suma ≫ 8)   ▷ promedio, invertido
 5.      (zona, octante, borde) ≔ EXTRACTOR_SOBEL(p, thr)
 6.      si borde entonces h[zona][octante] ← h[zona][octante] + 1
 ▷ al terminar las 28×28
 7.  rasgos ← h (32) y la suma de las cuatro zonas (8) ▷ 40 rasgos
 8.  s[c] ← suma de W[c][k] · rasgos[k], c = 0..9  ▷ 400 MAC
 9.  si bordes plausibles y s₁ − s₂ ≥ margen entonces
10.      digito ← argmax s ; valido ← 1
11.  si no valido ← 0                                   ▷ NADA
──────────────────────────────────────────────────────────────────────
```

#### El código

`pan_sobel.v` une la ventana `cam_win28.v` con `soc_mnist_top.v`, que reúne el SoC reducido
`soc_ctrl.v`, el extractor `mnist_feat.v` y el clasificador `mnist_clf.v`. Se reproducen en el Anexo
G.14; el periférico es el de la G.4 y el generador de ventana el de la G.12.

![**Figura 6.2.** De los pines a las cajas: `pan_sobel`. Todo el chip corre al reloj de píxel de la cámara, `pclk`. La ventana `cam_win28` reduce el centro del cuadro a 28×28; dentro de `soc_mnist_top`, el SoC reducido `soc_ctrl` —el FemtoRV32 con su ROM y el periférico `0x0045`— fija el umbral en 90, el extractor cuenta los bordes en 32 contadores y el clasificador decide. Al terminar, `done` limpia los contadores para el cuadro siguiente. Los puertos son pads del chip, y dos de ellos dejan ver el umbral que usó y si el procesador llegó a escribirlo.](figuras/fig_6_pansobel_pines.png)

#### Simulación en Python

Su modelo es la fila **SoC + Sobel** de la tabla de la §6.2: **91,03 %** sobre las diez mil imágenes de
prueba, a una décima de la fila sin procesador. Es lo esperable, porque el procesador escribe un número
y no toca la aritmética.

#### Simulación en Verilog: las señales

![**Figura 6.3.** Pan Sobel en GTKWave, con la cámara emulada mostrando un 3. `cpu_escribio` está en
alto y `thr_usado` vale `5A`, el 90 que escribió el programa; el extractor cuenta **354** píxeles de
borde (`nb_latch`) y, al subir `done`, el clasificador entrega `digito` = 3 con `valido` en
alto.](figuras/fig_6_pansobel_gtkwave.png)

#### Simulación en Verilog: la imagen

![**Figura 6.4.** Pan Sobel frente a once escenas de cámara simuladas —los diez dígitos y una escena
vacía—. A la izquierda, lo que vio en su ventana de 28×28; a la derecha, qué respondió en cada escena: **ocho de
once**. Los fallos son el 2, que toma por 6, y el 6 y el 9, en los que prefiere
callar.](figuras/fig_6_cadena_socsobel.png)

#### En la tarjeta

En la tarjeta corrió su núcleo —extractor y clasificador con el Sobel, sin cámara ni procesador— en el
primer ensayo de la §6.7: ocho de diez dígitos, con los mismos dos errores que la simulación.

#### En silicio

En sky130 ocupa **0,845 mm²** y **16 718 celdas** tras la síntesis, cierra a 30 ns y firma con DRC, LVS
y XOR en cero. Su plano es la Figura 7.1 (§7.1).

### Pan Canny

#### Resumen

Es el circuito anterior con el Canny de un salto en el extractor. El programa del procesador cambia en
una constante que resultó decisiva: escribe **los dos umbrales**, 90 y 32 (`0x5A20`). Con el programa
original del Sobel, `0x5A00`, el umbral bajo queda en cero, todo píxel es borde débil y la histéresis
los promueve casi todos: la exactitud cae de 92,46 a 89,93 %. El umbral bajo sale del periférico por un
**puerto declarado** —la lección de la §6.7—.

#### Pseudocódigo

```
──────────────────────────────────────────────────────────────────────
 Algoritmo 15   Pan Canny
──────────────────────────────────────────────────────────────────────
 1.  THR(0x0045+4) ← 0x5A20                   ▷ thr_hi = 90 ; thr_lo = 32
 2.  pasos 2 a 4 del Algoritmo 14             ▷ ventana, promedio, inversión
 3.  (zona, octante, borde) ≔ EXTRACTOR_CANNY1(p, thr_hi, thr_lo)
 4.  pasos 6 a 11 del Algoritmo 14, con los pesos del Canny
──────────────────────────────────────────────────────────────────────
```

#### El código

`pan_canny.v` y `soc_mnist_canny_fw_top.v` son los que cambian; el extractor `mnist_feat_canny.v` añade
al de la G.14 el doble umbral y la histéresis. Se reproducen en el Anexo G.15. El clasificador es el de
la G.14 con otros pesos y otros límites de rechazo.

![**Figura 6.5.** De los pines a las cajas: `pan_canny`. Es la Figura 6.2 con tres cambios: el programa escribe `0x5A20` —los dos umbrales, 90 y 32—, el extractor añade el doble umbral y la histéresis, y el clasificador lleva los pesos y los límites de rechazo del Canny.](figuras/fig_6_pancanny_pines.png)

#### Simulación en Python

Su modelo es la fila **SoC + Canny 1-salto**: **92,46 %**, la mejor de los cinco front-ends de cuarenta
rasgos, y la de menos falsos positivos, 73.

#### Simulación en Verilog: las señales

![**Figura 6.6.** Pan Canny en GTKWave. Los umbrales que escribió el procesador, `thr_hi` = `5A` y
`thr_lo` = `20` —90 y 32—, gobiernan el extractor; en este cuadro el clasificador responde
5.](figuras/fig_6_pancanny_gtkwave.png)

#### Simulación en Verilog: la imagen

![**Figura 6.7.** Pan Canny frente a las mismas once escenas: **cuatro de once**. Donde falla, sobre
todo, calla: responde NADA ante el 0, el 1, el 3, el 6, el 8 y el 9, y toma el 2 por 6. Con escenas de cámara el Canny se abstiene
más que el Sobel, que es la otra cara de su precisión al responder.](figuras/fig_6_cadena_soccanny.png)

#### En la tarjeta

Su versión para la FPGA es la del segundo ensayo de la §6.7: procesador, periférico, Canny y
clasificador ante dígitos manuscritos y la cámara real, **nueve de diez**, lo mismo que predecía la
simulación.

En la FPGA, el Pan llevó además la pantalla, para ver lo que el circuito ve; en silicio se quitó,
porque la salida son los cinco bits del veredicto.

![**Figura 6.8.** Uno de los dos Pan en la iCESugar —la foto no registra si
el filtro era el Sobel o el Canny—. Arriba, la ventana de 28×28 ampliada ocho veces dentro del marco
verde; abajo, la respuesta en siete segmentos: un 7. El dígito quedó cortado contra el borde de la
ventana y un segundo trazo entra por la derecha: es la escena mal encuadrada que mide la §6.3.5, donde
tres píxeles de corrimiento bastan para hundir la exactitud. Por eso esta foto ilustra el montaje y no
es una medida.](figuras/fig_6_pan_placa.jpg)

#### En silicio

En sky130 ocupa **0,890 mm²** y **17 373 celdas** tras la síntesis, a 30 ns, con DRC, LVS y XOR en
cero. Su plano es la Figura 7.2.

### Visión Sobel MNIST

#### Resumen

Es el único par de circuitos que **ve, reconoce y muestra**. Parte de la misma ventana de 28×28, la
clasifica y la dibuja en la pantalla ILI9341: la ventana ampliada ocho veces, con un **marco verde**
que pide a la persona centrar el dígito, y debajo el dígito reconocido en **siete segmentos** dibujados
con comparaciones —`glifo.v`—, sin memoria de fuente. Si el clasificador calla, el glifo es una raya.

No lleva procesador: el umbral está cableado a 60. Conserva los dos dominios de reloj de `vision_top`
(§4.3.9): la captura, la ventana y el clasificador al ritmo de la cámara; la configuración y la pantalla
al del sistema. El dígito cruza entre ambos con dos biestables, porque cambia a lo sumo una vez por
cuadro. Se portó del diseño que corrió en la FPGA, `mnist_cam_display.v`, con los tres cambios que
exige el silicio (§5.1).

#### Pseudocódigo

```
──────────────────────────────────────────────────────────────────────
 Algoritmo 16   Visión MNIST: ver, reconocer y mostrar
──────────────────────────────────────────────────────────────────────
 ▷ dominio de la cámara (cam_pclk)
 1.  p ← ventana 28×28 del Algoritmo 14, pasos 2 a 4
 2.  FB28[i] ← p                                  ▷ 784 bytes
 3.  (digito, valido) ≔ pasos 5 a 11 del Algoritmo 14, con thr = 60
 ▷ dominio del sistema (clk)
 4.  d ← sincronizar(valido ? digito : 10)        ▷ dos biestables
 5.  por cada píxel (x, y) de la pantalla de 240×320:
 6.      si y < 224: FB28 ampliado ×8, con marco verde de 3 píxeles
 7.      si no:      glifo de siete segmentos de d
──────────────────────────────────────────────────────────────────────
```

`vision_sobel_mnist.v` contiene la configuración de la cámara, la ventana, el *framebuffer* de 28×28 y
el controlador de pantalla; `glifo.v` dibuja el dígito, y `mnist_top.v` une el extractor y el
clasificador de la G.14. Se reproducen en el Anexo G.16.

![**Figura 6.9.** De los pines a las cajas: `vision_sobel_mnist`. En el dominio de la cámara, la captura de la luma, la ventana de 28×28 y el clasificador, con el umbral cableado en 60; en el del sistema, la configuración de la cámara y el controlador de la pantalla, que dibuja la ventana ampliada, el marco verde y el dígito. Los unen dos cruces: el *framebuffer* de 784 bytes y los dos biestables por los que pasa el dígito.](figuras/fig_6_visionsobel_pines.png)

Su modelo es la fila **Sobel** de la §6.2: **91,04 %**.

![**Figura 6.10.** La cadena sin procesador en GTKWave: el umbral es el 60 cableado (`3C`), y el
clasificador reconoce el 3 de la escena. Es el mismo extractor y el mismo clasificador que dieron diez
mil de diez mil contra el modelo en la §6.6.](figuras/fig_6_visionsobel_gtkwave.png)

![**Figura 6.11.** La cadena del Sobel sin procesador frente a las once escenas: **ocho de once**, como
con el procesador. En estas escenas, que el umbral sea 60 o 90 no cambia el
recuento.](figuras/fig_6_cadena_sobel.png)

Su versión para la FPGA, `mnist_cam_display.v`, corrió en la iCESugar con la cámara y la pantalla.

En sky130 ocupa **2,032 mm²** y **30 745 celdas** tras la síntesis —38 643 emplazadas—, con DRC, LVS y
XOR en cero. Es el mayor de los reconocedores por el *framebuffer* de 28×28 y el controlador de pantalla.
Su plano es la Figura 7.3.

### Visión Canny MNIST

#### Resumen

Es el circuito anterior con el extractor de Canny de un salto, con los umbrales cableados a 110 y 40.
El fichero difiere del del Sobel en tres líneas: el nombre del módulo, el del clasificador que instancia
y los umbrales que le pasa. Se portó de `mnist_cam_canny.v`, el hermano para la FPGA del diseño
probado en la tarjeta.

#### Pseudocódigo

```
──────────────────────────────────────────────────────────────────────
 Algoritmo 17   Visión Canny MNIST
──────────────────────────────────────────────────────────────────────
 1.  el Algoritmo 16, con el paso 3 cambiado por:
 3.  (digito, valido) ≔ Algoritmo 15, paso 3, con (thr_hi, thr_lo) = (110, 40)
──────────────────────────────────────────────────────────────────────
```

`vision_canny_mnist.v` es el de la G.16 con esas tres líneas cambiadas; `mnist_top_canny.v` une el
extractor de la G.15 con su clasificador. Se reproducen en el Anexo G.17.

![**Figura 6.12.** De los pines a las cajas: `vision_canny_mnist`. Es la Figura 6.9 con `mnist_top_canny` en lugar de `mnist_top` y los umbrales cableados en 110 y 40.](figuras/fig_6_visioncanny_pines.png)

#### Simulación en Python

Su modelo es la fila **Canny 1-salto**: **92,03 %**.

#### Simulación en Verilog: las señales

![**Figura 6.13.** La cadena del Canny sin procesador en GTKWave, con los umbrales cableados, 110 y 40
(`6E` y `28`): el extractor cuenta 156 bordes y el clasificador responde 5.](figuras/fig_6_visioncanny_gtkwave.png)

![**Figura 6.14.** La cadena del Canny sin procesador frente a las once escenas: **cuatro de once**, los
mismos cuatro aciertos que con el procesador. La única diferencia es el 8, que aquí toma por 9 en lugar
de callar.](figuras/fig_6_cadena_canny.png)

Este circuito no se ensayó tal cual en la tarjeta: el ensayo con la cámara que se informa en la §6.7 es
el de su pariente con procesador, el Pan Canny de la §6.3.2.

En sky130 ocupa **2,092 mm²** y **31 620 celdas** tras la síntesis —39 794 emplazadas—, con DRC, LVS y
XOR en cero: un **2,8 %** más que el del Sobel, la cifra que la §7.2 pone al final de su tabla. Su plano
es la Figura 7.4.

### Canny-78

#### Resumen

Los cuatro diseños anteriores fijaron el descriptor —cuatro zonas, cuarenta rasgos— y variaron el
front-end. Éste hace lo contrario: fija el front-end que resultó mejor, el Canny 1-salto con
los umbrales 90/32 del firmware, y pregunta **cuánto más puede reconocer la misma iCE40UP5K** si se
amplía el descriptor. El resultado se denomina **Canny-78** por el número de rasgos con que opera.

#### Pseudocódigo

```
──────────────────────────────────────────────────────────────────────
 Algoritmo 18   Canny-78: dieciséis zonas y 78 rasgos elegidos
──────────────────────────────────────────────────────────────────────
 ▷ por cada píxel de la imagen de 28×28
 1.  (zona16, octante, borde) ≔ EXTRACTOR_CANNY1(p, 90, 32)   ▷ rejilla 4×4
 2.  si borde entonces FMEM[zona16·8 + octante] += 1          ▷ memoria síncrona
 ▷ al terminar el cuadro: el trasvase, 130 ciclos
 3.  para a = 0..127: CLF[a] ← FMEM[a] ; FMEM[a] ← 0          ▷ leer y vaciar
 ▷ el clasificador, dos clases por pasada
 4.  para cada pareja (c, c+1), c = 0, 2, …, 8:
 5.      para cada rasgo elegido k = 1..78:
 6.          f ← rasgo k (de CLF, o suma de zonas si es de otro nivel)
 7.          (w_c, w_c+1) ← W2[c/2][k]                       ▷ una palabra, dos pesos
 8.          s[c] += w_c · f ; s[c+1] += w_c+1 · f
 9.  digito, valido ≔ argmax y regla de rechazo, como en el Algoritmo 14
──────────────────────────────────────────────────────────────────────
```

#### Del modelo al circuito

**El silicio dice que no, y dice por qué.** La primera implementación —los 128 contadores de las
dieciséis zonas en registros, leídos con índice variable— no cabía: se estimó en el **202 %** del
dispositivo. El desglose mostró que el costo no estaba en el tamaño de los datos —los 780 pesos son
3 120 bits— sino en **cómo se leían**: cada lectura de un contador entre 128 exigía un multiplexor de
128 entradas y 1 323 LUT, y había tres en el mismo camino. Trasladar los contadores a una **memoria
síncrona** redujo esa lectura a 17 LUT. Dos restricciones propias de una memoria obligaron a
rediseñar la interfaz: una memoria no se borra en un ciclo —el borrado pasó a ser secuencial— y **tiene
un solo puerto de lectura**, de modo que el extractor dejó de entregar un bus de 128 contadores y pasó
a exponer un puerto que el clasificador recorre. Por último, para cumplir el presupuesto de tiempo,
el clasificador calcula **dos clases por ciclo** con una sola lectura del rasgo, y los dos pesos que
se usan a la vez se almacenan **en la misma palabra de 8 bits**: el mismo modelo, los mismos bits, la
mitad de accesos.

> **El mismo modelo en tres circuitos, sin cambiar una cifra de la exactitud:** con los contadores en
> registros no cabe en área; en memoria con un peso por palabra cabe en área pero no en tiempo; en
> memoria con dos pesos por palabra cabe en las dos. **Lo que decide no es el tamaño de la memoria,
> ni siquiera dónde está, sino cuántas veces hay que ir a buscarla y si se trae algo útil en cada
> viaje.**

`mnist_top78.v` une el extractor de dieciséis zonas con memoria, `mnist_feat16_mem.v`, y el clasificador
de dos clases por pasada, `mnist_clf78_x2.v`, y hace el trasvase entre ambos. Se reproducen en el Anexo
G.18; el generador de ventana es el de la G.12. La misma cadena, sin cambiar un fichero, es la del
diseño de la tarjeta con el puerto serie, la del diseño con cámara y pantalla, y la que va a silicio.

![**Figura 6.15.** De los pines a las cajas: `mnist_top78`, Canny-78. El extractor cuenta los bordes en 128 contadores —16 zonas por 8 octantes— guardados en una memoria síncrona; al terminar el cuadro, el trasvase los copia en 130 ciclos a la memoria del clasificador, vaciándolos al leerlos. El clasificador deriva los niveles 1 y 0 de la pirámide, recorre los 78 rasgos elegidos calculando dos clases por pasada y aplica la regla de rechazo: 777 ciclos en total, siete menos de los 784 que dura un cuadro.](figuras/fig_6_canny78_pines.png)

**El techo del descriptor de cuarenta rasgos.** Un barrido de capacidad mostró que el nivel 1 de la
pirámide no supera el **94,86 % ni siquiera con pesos en coma flotante**, mientras que el nivel 2
—dieciséis zonas, 168 rasgos— alcanza el 97,56 % con pesos de 4 bits. Con 168 rasgos de 3 bits se
obtiene más que con 40 rasgos de 8 bits: **la resolución espacial vale más que la precisión de los
pesos**. La razón se hizo visible al observar la cadena etapa por etapa: sobre MNIST, con estos
umbrales, la máscara no es un contorno sino la silueta engrosada del trazo, y lo que el descriptor
mide es **dónde hay tinta**; para eso, más zonas es exactamente lo que falta.

**Elegir cuáles, no cuántas.** El clasificador es serie —una multiplicación-acumulación por ciclo— y
entre dos cuadros de 28×28 dispone de 784 ciclos. Diez clases por 78 rasgos suman 780: el máximo
que cabe. Se seleccionaron **los 78 rasgos más informativos** de los 168, y el resultado fue
**97,22 %**, a un tercio de punto del modelo completo: los 168 rasgos dan 97,56 % con pesos de 4 bits y 98,16 % en coma flotante. Con sólo 40 rasgos elegidos, en lugar de los 40 por
omisión, la exactitud sube de 92,46 % a 95,38 % —95,56 % con los sesgos recalibrados—: con el mismo
número de pesos y la misma memoria, el mero hecho de escoger qué se mide vale casi tres puntos.

**Verificación.** La cadena completa —extractor de dieciséis zonas, trasvase de contadores y
clasificador— se verificó en `iverilog` contra el modelo en flujo continuo de imágenes encadenadas y
con tiempos muertos entre píxeles: **10 000 de 10 000** veredictos idénticos, dígito y clase de
rechazo incluidos. La verificación destapó siete fallos reales que la comparación por totales había
ocultado; el más instructivo fue una **latencia de encadenado de `k·(W+1)` y no de `k·(W+2)`**, error
que compartían otros tres módulos del trabajo. Emplazado y ruteado con `nextpnr`, Canny-78 ocupa
**2 606 celdas lógicas (49 %)** y nueve bloques de BRAM, y cierra a **16,45 MHz** frente a los 12 MHz
que exige la tarjeta. Cabe dentro de los 784 ciclos de un cuadro con cinco de margen.

![**Figura 6.16.** Canny-78 en GTKWave, en el paso que el diseño de cuarenta rasgos no tiene: el
**trasvase**. Al subir `frame_done` el extractor ha contado 238 bordes; `trasvase` pasa a 1 y `cuenta`
recorre las 128 posiciones de la memoria de rasgos en unos 1,3 µs, vaciando cada contador al leerlo
—`n_bordes` vuelve a 0—. Sólo entonces el clasificador sale de reposo (`estado` = 1) y empieza sus
multiplicaciones-acumulaciones. Mientras tanto la imagen siguiente ya está entrando por
`in_pix`.](figuras/fig_6_canny78_gtkwave.png)

![**Figura 6.17.** La cadena de Canny-78 en el simulador, sobre muchos 0, 3 y 7 del conjunto de
prueba. En verde, las imágenes que acierta; en gris, las que calla (NADA) porque el margen entre los dos
mejores puntajes, `m`, no llega al umbral de 70; en rojo, las que falla. A la derecha, el recuento de
cada dígito sobre sus mil imágenes: de los 887 treses a los que responde, no falla
ninguno.](figuras/fig_simulador_078_varios.png)

#### En la tarjeta

**En la tarjeta: diez mil de diez mil.** Los ensayos físicos de la §6.7 usaron diez dígitos, que es
lo que cabe en la memoria de configuración. Para Canny-78 se adoptó otro procedimiento: la tarjeta
no almacena imágenes, sino que recibe **las 10 000 de prueba por el puerto serie** del mismo conector
USB y responde un byte por imagen con el dígito y la decisión de rechazo. El diseño incorpora un
realineo por silencio y un aviso de lote corrupto, para que un byte perdido invalide un lote y no el
resto de la corrida. Antes de grabarlo se verificó en cuatro niveles: el RTL con la línea serie
simulada bit a bit; el comportamiento ante un byte perdido a propósito; **el circuito que construyó
el sintetizador**, simulado con sus celdas de la iCE40 sobre imágenes elegidas para fallar si un aviso
del sintetizador sobre los sesgos del clasificador hubiera sido cierto —no lo era—; y el emplazamiento
final, **2 937 celdas lógicas (55 %) a 17,55 MHz**.

![**Figura 6.18.** El diseño de la tarjeta simulado con su puerto serie bit a bit antes de grabarlo.
El panel A muestra dos lotes de cuatro imágenes que entran por `uart_rx_pin`, la pausa que realinea la
cadena (`reset_cad`) y los ocho veredictos, todos iguales al modelo. El panel B es un píxel entrando
—bit de inicio, ocho bits y bit de parada— y el C un veredicto saliendo: de `frame_done` a `done` pasan
778 ciclos, y el dígito sale como un byte por `uart_tx_pin`.](figuras/fig_ondas_stream78.png)

| medición en la tarjeta | resultado |
|-------------------------------------------------------|---------------:|
| **veredictos idénticos a la simulación (dígito y rechazo)** | **10 000 / 10 000** |
| exactitud | 97,22 % |
| cobertura (responde) | 84,65 % |
| precisión al responder | 99,15 % |
| lotes repetidos por error de transmisión | 0 |

Table: Canny-78 medido en la tarjeta sobre las diez mil imágenes de prueba.

> **La iCE40UP5K reproduce el modelo sobre el conjunto de prueba completo de MNIST, imagen por
> imagen, sin una sola discrepancia.** El «nueve de diez» de la §6.7 demostraba que el circuito
> funcionaba; esto demuestra que funciona **exactamente** como se diseñó, sobre diez mil casos.

La cobertura de la tabla (84,65 %) corresponde al punto de operación grabado en la tarjeta, más
propenso a responder que el de la §6.2 (66 %, calibrado con el mismo procedimiento que los otros
cinco front-ends). Ambos son puntos de la misma curva y no se comparan entre sí.

**Frente a la cámara, lo que aún falta.** Canny-78 se integró también en el diseño de cámara y
pantalla —**4 748 celdas lógicas (89 %)**, once bloques de BRAM, los dos relojes con margen— y, con la
cámara emulada mostrando los diez dígitos dos cuadros cada uno, **coincidió con el modelo en los veinte
cuadros** —incluido el 1, que el modelo también rechaza por tener un trazo demasiado fino—. Frente a dígitos
manuscritos reales, en cambio, acertó **seis de treinta y seis intentos** (16,7 %), cifra que con tan
pocos ensayos no se distingue del azar. El circuito no es la causa: es el mismo que dio diez mil de
diez mil. La causa es la escena, y se midió: desplazando las diez mil imágenes de prueba como lo
haría una cámara mal encuadrada, **tres píxeles de corrimiento bastan para que la exactitud caiga del
97 al 63 %**, y un normalizador que recorte y centre el dígito como lo hace MNIST la devuelve al 97 %.
El marco verde de la pantalla —que pide a la persona centrar el dígito— es la versión manual de ese
normalizador; la versión en silicio queda como trabajo futuro, con su costo ya acotado.

![**Figura 6.19.** La brecha de la cámara, medida sobre las diez mil imágenes de prueba con la cadena de Canny-78.
A la izquierda, el dígito desplazado. Tal como lo vería una cámara mal encuadrada (rojo), la exactitud cae del 97,22 %
al 84,72 % con dos píxeles, al 63,19 % con tres y al 14,21 % con ocho, cerca del azar. Con un normalizador que recorte
y centre el dígito como se hizo al construir MNIST (verde), se sostiene por encima del 97 % hasta cuatro píxeles y
baja al 94,28 % con seis y al 81,57 % con ocho. A la derecha, el tamaño del trazo: a la mitad de escala el circuito
acierta el 47,76 %, y con el normalizador, el 95,29 %. El circuito no cambia entre una curva y otra; cambia lo que se
le muestra.](figuras/fig_brecha_camara.png)

Por dígito, los más difíciles siguen siendo el **9, el 8 y el 7** (F1 de 0,956, 0,961 y 0,963), y las
confusiones que quedan son las mismas familias de siempre: el trazo recto con diagonal del 4, el 7 y
el 9, y las curvas cerradas del 8 y el 9. **Canny-78 reduce los errores, pero no los cambia de
sitio**: lo que distingue a esos dígitos es la geometría del trazo, y ésa no depende del circuito.

#### En silicio

Canny-78 es el decimoséptimo circuito de este trabajo: en sky130 ocupa **1,122 mm²** y **29 449 celdas**
tras la síntesis, y la variante con la memoria de rasgos recortada baja a **0,829 mm²**, las dos con DRC,
LVS y XOR en cero. Los números, el porqué del recorte y su plano están en la §7.3.

### Canny-98

#### Resumen

Canny-78 es lineal y, con la mitad de la iCE40UP5K ocupada, deja quietos dos recursos: la mayor parte de la BRAM y
el megabit de SPRAM. Canny-98 los usa. Conserva el mismo front-end, el mismo extractor de dieciséis zonas y la misma
memoria de 168 rasgos, y cambia sólo el clasificador: en lugar de una suma ponderada, **una capa oculta de 120
neuronas** con activación ReLU y, detrás, las diez clases. Todo sigue siendo entero y sin una sola multiplicación por
constante: pesos de 4 bits con una escala por capa, una activación de 8 bits que se obtiene con un desplazamiento, y el
`argmax` al final.

El tamaño no se eligió por la exactitud sino por la memoria. Con 128 neuronas el modelo da 98,43 % pero sus pesos
piden 31 bloques de BRAM de los 30 que tiene el dispositivo; con 120 dan **98,45 %** y los 21 360 pesos de las dos
capas caben juntos en la BRAM que deja libre el extractor: el diseño completo usa exactamente los 30 bloques. Las 120 activaciones van a
la SPRAM, que no necesita inicializarse.

#### Pseudocódigo

```
──────────────────────────────────────────────────────────────────────
 Algoritmo 19   Canny-98: una capa oculta sobre los 168 rasgos
──────────────────────────────────────────────────────────────────────
 1–3.  idénticos al Algoritmo 18                  ▷ extractor y trasvase
 4.    derivar los niveles 1 y 0 en fmem          ▷ 168 rasgos f[k]
 ▷ capa oculta: 120 neuronas, pesos de 4 bits en BRAM
 5.    para j = 0..119:
 6.        acc ← b1[j] + suma de W1[j][k] · f[k], k = 0..167
 7.        h[j] ← min(255, max(0, acc ≫ 2))       ▷ a la SPRAM
 ▷ capa de salida
 8.    para c = 0..9:
 9.        s[c] ← b2[c] + suma de W2[c][j] · h[j], j = 0..119
10.    digito ← argmax s ; valido ← bordes plausibles
──────────────────────────────────────────────────────────────────────
```

#### El código

`mnist_clf98.v` sustituye a `mnist_clf78_x2.v` con la misma interfaz, de modo que `mnist_top98.v` es el `mnist_top78.v`
con un nombre cambiado. Conserva sin tocar la memoria de rasgos y su derivación, y añade las dos capas: una
multiplicación-acumulación por ciclo, 21 992 ciclos por imagen —1,8 ms a 12 MHz—. Se reproduce en el Anexo G.19.

![**Figura 6.20.** De los pines a las cajas: `mnist_top98`, Canny-98. El extractor y el trasvase son los de Canny-78;
lo nuevo está en `mnist_clf98`. La capa oculta lee los 168 rasgos de `fmem` y sus pesos de `wmem` —21 360 pesos de
4 bits en 21 bloques de BRAM—, y deja cada activación de 8 bits en la SPRAM; la capa de salida las lee de ahí con los
pesos de la segunda capa y se queda con la clase de mayor puntaje. El chip entero ocupa el 45 % de las celdas lógicas
y los 30 bloques de BRAM.](figuras/fig_6_canny98_pines.png)

#### Simulación en Python

El modelo de referencia no es la red en coma flotante sino su versión **entera, bit a bit como la calcula el
circuito**: 98,65 % en coma flotante y **98,45 %** con los pesos de 4 bits, la activación de 8 bits y el
desplazamiento. Ese es el número que el circuito tiene que reproducir.

#### Simulación en Verilog

El clasificador se simuló en `iverilog` sobre las diez mil imágenes de prueba, en un solo lote: **10 000 de 10 000**
veredictos idénticos al modelo entero, dígito, decisión de rechazo y puntaje incluidos. El diseño completo de la
tarjeta —con la UART simulada bit a bit y un byte perdido a propósito— dio además ocho de ocho.

Para mirarlo por dentro, un banco aparte encadena las cuatro primeras imágenes de prueba —un 7, un 2, un 1 y un 0—
con un píxel cada 32 ciclos, como llegarían de la cámara o del puerto serie, y deja las señales con nombres legibles
para GTKWave. Las cuatro respuestas coinciden con el modelo.

![**Figura 6.21.** Canny-98 en GTKWave, las cuatro imágenes enteras. Cada `frame_done` dispara el trasvase
(`cuenta` llega a 128), el clasificador recorre la capa oculta (`estado` 2, `neurona` de 0 a 119) y la de salida
(`estado` 3, `clase` de 0 a 9), y `done` entrega `digito` = 7, 2, 1 y 0, con puntajes ganadores de 5 340, 3 680, 2 692
y 4 036. Con el 1, `valido` baja: su trazo deja pocos bordes y la regla de densidad lo calla, como en el
modelo.](figuras/fig_6_canny98_gtk_panorama.png)

![**Figura 6.22.** El arranque, a los 251 µs. Sube `frame_done` con 238 bordes contados; el trasvase copia los 128
contadores (`cuenta` de 0 a 128) y los vacía —`n_bordes` vuelve a 0—; en `estado` 1 se derivan los niveles 1 y 0 de
la pirámide, y en `estado` 2 empieza la capa oculta: `indice` recorre los 168 rasgos y `acc` va
acumulando.](figuras/fig_6_canny98_gtk_arranque.png)

![**Figura 6.23.** La capa oculta por dentro. Cada neurona tarda 171 ciclos —1,71 µs—: 168 productos, dos de
tubería y el cierre, en el que un pulso de `escribe_h` deja en la SPRAM su activación `h8`, el acumulador desplazado
dos bits y recortado entre 0 y 255.](figuras/fig_6_canny98_gtk_oculta.png)

![**Figura 6.24.** La capa de salida y la decisión. `clase` recorre las diez clases, cada una con sus 120
activaciones; `mejor` sólo cambia cuando una clase supera a la anterior: −1 596 con la clase 0, −38 con la 2, 110 con la 3 y
5 340 con la 7; y, al terminar, `done` entrega `digito` = 7 con `valido` en alto, a los 472 µs.](figuras/fig_6_canny98_gtk_salida.png)

#### En la tarjeta

Con el mismo procedimiento que Canny-78 —las diez mil imágenes de prueba enviadas por el puerto serie y un byte de
respuesta por imagen—:

| medición en la tarjeta | Canny-78 | **Canny-98** |
|-------------------------------------------|---------------:|---------------:|
| **veredictos idénticos a la simulación** | 10 000 / 10 000 | **10 000 / 10 000** |
| exactitud | 97,22 % | **98,45 %** |
| celdas lógicas | 2 937 (55 %) | **2 380 (45 %)** |
| bloques de BRAM | 9 de 30 | **30 de 30** |
| bloques de SPRAM | 0 de 4 | **1 de 4** |
| frecuencia máxima (la tarjeta exige 12 MHz) | 17,55 MHz | **17,76 MHz** |

Table: Canny-98 frente a Canny-78, medidos en la tarjeta sobre las diez mil imágenes de prueba.

> **Un punto y cuarto más, con menos lógica.** Canny-98 ocupa menos celdas lógicas que Canny-78: tiene un solo
> multiplicador en lugar de dos, y sus pesos viven en bloques de memoria que ya estaban en el chip. Es la tesis de este trabajo vista desde el lado bueno: en la FPGA la memoria dedicada es casi gratis, y el
> diseño que la usa es a la vez más exacto y más pequeño.

La regla de rechazo de Canny-98 no se calibró todavía: decide sólo por la densidad de bordes, sin margen. Por eso
responde el 90,47 % de las veces con un 98,30 % de acierto al responder, y no se compara con el 99,92 % de Canny-78, que
sí lleva el margen calibrado. La exactitud no depende de esa regla.

#### Métricas sobre las 10 000 imágenes

La exactitud resume el reconocedor en un número; las demás métricas dicen dónde acierta y dónde no. Se calcularon
las mismas para los siete reconocedores del capítulo, sobre las 10 000 imágenes de prueba y sobre el `argmax`,
sin regla de rechazo. Los cinco de la §6.2 se reentrenaron con su procedimiento original y reprodujeron su
matriz de confusión casilla por casilla; Canny-78 y Canny-98 son los modelos enteros que la tarjeta reproduce.

| reconocedor | exactitud | IC 95 % | precisión | recall | especif. | F1 | MCC | top-2 | AUC |
|-------------------|---------:|-----------:|---------:|------:|--------:|------:|------:|-------:|------:|
| Sobel | 91,04 % | 90,49–91,60 | 0,9147 | 0,9105 | 0,9901 | 0,9097 | 0,9011 | 97,25 % | 0,9942 |
| SoC + Sobel | 91,03 % | 90,50–91,59 | 0,9150 | 0,9099 | 0,9900 | 0,9100 | 0,9008 | 97,11 % | 0,9937 |
| Canny 1-salto | 92,03 % | 91,50–92,59 | 0,9248 | 0,9199 | 0,9911 | 0,9198 | 0,9120 | 97,70 % | 0,9954 |
| SoC + Canny 1-salto | 92,46 % | 91,93–92,95 | 0,9276 | 0,9245 | 0,9916 | 0,9241 | 0,9166 | 97,87 % | 0,9958 |
| Canny transitivo | 89,76 % | 89,16–90,35 | 0,9064 | 0,8980 | 0,9886 | 0,8966 | 0,8873 | 97,03 % | 0,9940 |
| Canny-78 | 97,22 % | 96,89–97,55 | 0,9720 | 0,9722 | 0,9969 | 0,9721 | 0,9691 | 99,35 % | 0,9987 |
| **Canny-98** | **98,45 %** | **98,21–98,69** | **0,9846** | **0,9845** | **0,9983** | **0,9845** | **0,9828** | **99,77 %** | **0,9991** |

Table: Métricas de los siete reconocedores sobre las 10 000 imágenes de prueba de MNIST.

Precisión, recall, especificidad y F1 son promedios macro de los diez dígitos; el MCC es el coeficiente de
Matthews multiclase, que usa la matriz de confusión entera y no se deja engañar por una clase fácil; top-2 cuenta
la imagen como acertada si el dígito correcto está entre los dos puntajes más altos. El intervalo de confianza
sale de 2 000 remuestreos del conjunto de prueba —la desviación de la exactitud es de 0,12 puntos para Canny-98
y de 0,17 para Canny-78— y mide la incertidumbre de la muestra de prueba, no la del entrenamiento, que es la σ de
1,32 puntos de la §6.2. El AUC es el macro uno-contra-el-resto sobre el logaritmo del softmax de los puntajes
enteros: con el softmax a secas, los puntajes de Canny-98 —de miles— saturan a 0 y 1 exactos en coma flotante y
el AUC cae artificialmente a 0,9965; el logaritmo ordena igual y no satura, y para los otros seis cambia sólo la
cuarta cifra respecto de la §6.4.

![**Figura 6.25.** Las métricas de la tabla anterior en un mapa de calor. Canny-98 encabeza las ocho
columnas; la especificidad y el AUC, casi saturadas en todos, separan poco, y el MCC y la exactitud son las que
más separan.](figuras/fig_6_metricas_modelos.png)

**La mejora sobre Canny-78 no es ruido.** Sobre las mismas 10 000 imágenes, 165 las acierta sólo Canny-98 y 42
sólo Canny-78; la prueba de McNemar, que compara dos clasificadores sobre los mismos ejemplos, da p ≈ 2·10^−18^, y
los dos intervalos de confianza no se tocan. Los errores bajan de 278 a 155, un 44 % menos.

![**Figura 6.26.** Las matrices de confusión de Canny-78 y Canny-98 sobre las 10 000 imágenes de prueba. En
verde, los aciertos de la diagonal; fuera de ella, el color crece con el número de errores. La mayor confusión de
Canny-78, un 9 leído como 7 (17 veces), baja a 6; la que queda como la mayor de Canny-98 es un 4 leído como 9
(13 veces), que Canny-78 cometía 12.](figuras/fig_6_confusion_98.png)

![**Figura 6.27.** El F1 de cada dígito en los siete reconocedores. Canny-98 queda por encima de los demás en
los diez dígitos, entre 0,976 —el 8 y el 9— y 0,992 —el 0—; los cinco de 40 rasgos caen por debajo de 0,90 en
varios, y el transitivo baja a 0,79 en el 7.](figuras/fig_6_f1_digitos.png)

![**Figura 6.28.** A la izquierda, la precisión y el recall de cada dígito de Canny-98 frente a Canny-78: sube
en los veinte, y lo que más sube es el recall del 2, el 8 y el 9. A la derecha, las curvas ROC macro de los siete
en su esquina superior izquierda, con el AUC entre paréntesis.](figuras/fig_6_digitos_98.png)

Los dígitos difíciles siguen siendo los mismos —el 7, el 8 y el 9, con F1 de 0,979, 0,976 y 0,976—, y las
confusiones, las mismas familias: el 4 con el 9, el 7 con el 2, el 8 con el 2 y el 9 con el 8. La capa oculta
reduce los errores de todas las familias, pero **no cambia cuáles son**: igual que en Canny-78, lo que separa
esos dígitos es la geometría del trazo que el descriptor ve.

#### Con la cámara y la pantalla

La versión con cámara OV7670 y pantalla TFT es la de Canny-78 con el clasificador cambiado: la misma ventana de
448×448 píxeles promediada en bloques de 16×16, el mismo realineo de cuadros y el mismo controlador de la
pantalla. Con la cámara emulada en el banco de pruebas —los diez dígitos, dos cuadros cada uno, sin reinicio
entre escenas— los **20 veredictos coinciden con el modelo entero**.

Lo que no coincide es el presupuesto. Canny-98 usa los 30 bloques de BRAM de la iCE40UP5K, y la vista previa
que la pantalla muestra para encuadrar el dígito —28×28 píxeles de 8 bits en la versión de Canny-78— pedía dos
más: **32 de 30**. Guardarla en lógica liberó la BRAM pero llevó el problema a las celdas, y se fue reduciendo
hasta que el diseño cupo:

| vista previa en la pantalla | síntesis | BRAM | celdas lógicas | emplaza |
|------------------------------|---------|----------:|---------------:|------------------------|
| 28×28, 8 bits, en BRAM (la de Canny-78) | — | 32 de 30 | — | no |
| 28×28, 1 bit, en lógica | — | 30 de 30 | 6 572 (124 %) | no |
| 14×14, 1 bit | — | 30 de 30 | 5 066 (96 %) | no |
| 14×14, 1 bit, submuestreada | con DSP | 30 de 30 | 4 733 (89 %) | no: las cadenas de acarreo |
| **7×7, 1 bit, submuestreada** | **con DSP** | **30 de 30** | **4 302 (81 %)** | **sí** |

Table: Lo que costó meter la vista previa junto a Canny-98 en la iCE40UP5K.

«Con DSP» quiere decir que uno de los dos multiplicadores del clasificador pasa a un bloque SB_MAC16, de los
ocho que la iCE40UP5K trae y que ningún otro diseño de este trabajo usaba. La fila del 89 % enseña que el límite
no es sólo el número de celdas: Canny-78 con cámara emplazó con 4 748, pero aquí, con la BRAM llena y un DSP,
las cadenas de acarreo de los contadores ya no encontraron columnas libres contiguas. El diseño final cierra
con holgura en tiempo —22,1 MHz en el reloj de la cámara y 22,9 MHz en el del sistema, frente a los 12 que se
exigen— y el clasificador no pierde nada: sigue recibiendo la ventana completa de 28×28 a 8 bits. Lo que se
empobrece es sólo lo que ve la persona que sostiene el papel: una rejilla de 7×7 que dice **dónde** hay trazo.

> Es la misma tesis del Capítulo 8 vista desde dentro de la FPGA: cuando el clasificador se queda con toda la
> memoria dedicada, lo siguiente que hay que guardar se construye con lógica, y 784 bits de una vista previa
> desbordaron el dispositivo en 1 292 celdas.

Frente al papel —cada dígito escrito con marcador en una hoja, varias respuestas por escena—, Canny-98 acertó **5 de 47 respuestas (10,6 %)**, lo que no se distingue del azar, y respondió «2» en
17 de ellas. Es el mismo cuadro que Canny-78 frente a la cámara, seis de treinta y seis (§6.3.5). La vista previa
muestra por qué: en la mayoría de los cuadros la ventana no contiene un trazo sino **manchas que ocupan media
ventana o más** —sombras de la mano y del teléfono, y la luz desigual sobre la hoja—, y en varios aparece la
costura horizontal que ya se había visto con Canny-78.

![**Figura 6.29.** Canny-98 frente al papel, en la iCESugar, el 29 de septiembre de 2026. A la izquierda, la
hoja con el dígito, tal como la ve el teléfono que graba; a la derecha, tres momentos de la pantalla: la
vista previa de 7×7 —en blanco lo que la cámara ve más oscuro que gris medio— y, debajo, el veredicto. Lo que
llega al clasificador son manchas de sombra y de luz, no el trazo; la raya es la
abstención.](figuras/fig_6_canny98_camara.jpg)

> La prueba no mide el reconocedor —que en la tarjeta reproduce el modelo en diez mil de diez mil imágenes y, con
> la cámara emulada, en veinte de veinte cuadros— sino **lo que la cámara le entrega**. Cerrar esa brecha pide
> iluminación controlada y el normalizador del dígito que la §6.3.5 ya midió, no un clasificador mejor.

#### En silicio

Canny-98 es el decimoctavo circuito de este trabajo: en sky130 ocupa **2,996 mm²** y **42 192 celdas** tras la
síntesis, con DRC, LVS y XOR en cero y el temporizado cerrado a 33 MHz. Es 2,7 veces el dado de Canny-78 con
1,43 veces sus celdas, porque lo que se agota primero es el cableado. Los números, el intento que no ruteó y su
plano están en la §7.4.

## 6.4 Lo que la exactitud no muestra

Las medidas basadas en el `argmax` descartan la información de los diez puntajes. Dos medidas que la
conservan revelan una diferencia que la exactitud oculta:

| front-end | AUC macro | Brier | Brier skill |
|---|---:|---:|---:|
| SoC + Canny 1-salto | **0,9960** | **0,1465** | **0,8371** |
| Canny 1-salto | 0,9957 | 0,1558 | 0,8268 |
| Sobel | 0,9945 | 0,1746 | 0,8059 |
| Canny transitivo | 0,9942 | **0,1991** | 0,7787 |
| SoC + Sobel | 0,9939 | 0,1749 | 0,8056 |

Table: Calibración del clasificador según el front-end: AUC y puntaje de Brier.

El resultado de interés corresponde al Canny transitivo. En AUC —que mide el **ordenamiento**— supera
al SoC+Sobel; en Brier —que mide la **calibración**— queda último por amplio margen. **Ordena
correctamente y decide mal.** Ello explica de forma mecánica sus 139 falsos positivos: la
reconstrucción morfológica engruesa los contornos, el engrosamiento infla los histogramas, y el
criterio de rechazo —que compara el mejor puntaje con el segundo— deja hablar al circuito cuando
debería callarlo.

## 6.5 El punto de operación pesa más que el front-end

Las comparaciones anteriores fijan el umbral y varían el filtro. El experimento complementario
—fijar el filtro y **barrer el umbral**— arroja el resultado de mayor consecuencia práctica de esta
sección:

| magnitud | rango de exactitud | en unidades de σ |
|---|---:|---:|
| el umbral, dentro del Sobel | **5,79 pp** | **4,4 σ** |
| el umbral, dentro del Canny | 0,90 pp | 0,7 σ |
| el filtro, cada uno en su óptimo | 0,38 pp | 0,3 σ |

Table: Peso del punto de operación frente al del front-end en la exactitud.

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

## 6.6 El RTL contra el modelo, sobre el conjunto completo

Las cifras anteriores son del modelo en Python. La pregunta que decide si sirven de algo es si el
circuito las reproduce, y se respondió por el camino más exigente disponible: **ejecutar el RTL sobre
las diez mil imágenes de prueba** en el simulador y comparar, no los porcentajes agregados, sino cada
predicción con la del modelo.

\needspace{12\baselineskip}

| Comparación | Resultado |
|------------------------------------------|-----------------------------------|
| Predicciones idénticas | **10 000 / 10 000** |
| Exactitud del RTL / del modelo | **91,04 % / 91,04 %** |
| Matriz de confusión | idéntica elemento por elemento |
| Veredictos de la clase de rechazo | **10 000 / 10 000** idénticos |
| Cuadros aceptados · precisión al responder | 8 838 (88,38 %) · 95,44 %, en ambos |

Table: El RTL del clasificador contra el modelo, sobre las diez mil imágenes de prueba.

![**Figura 6.30.** La ventana de 28×28 entrando al extractor, vista en el simulador. La señal
`w_valid` marca cada píxel válido y `w_pix` lleva su valor —`FF FD 2B 3A C1 A4`…—; los 784 de la
ventana pasan uno a uno antes de que `done` presente un dígito. Es el nivel al que se hizo la
comparación contra el modelo: no se compararon porcentajes, se compararon
señales.](figuras/fig_5_5_ventana_al_extractor.png)

No son cifras «parecidas» ni «dentro del margen de error»: **las diez mil predicciones y los diez mil
veredictos coinciden uno por uno**, y la matriz de confusión es la misma casilla por casilla. La
verificación de los filtros de la §4.8 se hizo sobre cinco imágenes; ésta se hizo sobre diez mil, e
incluye la decisión de rechazo, que es lógica de comparación y no de aritmética.

> Conviene precisar el alcance, porque más adelante aparece una cifra distinta. Lo que aquí es
> exacto es el **clasificador completo** —descriptor, pesos y decisión— evaluado imagen por imagen.
> El 99,91 % que informa la §6.7 se refiere a otra comparación: la del **extractor de bordes**
> píxel a píxel dentro de la cadena, cuyas discrepancias se concentran en la última fila del cuadro
> y no alteran ninguna de las diez mil clasificaciones. Son dos medidas de objetos distintos y no se
> contradicen.

## 6.7 Validación física

La validación sobre la placa se realizó en dos ensayos distintos, que miden cosas distintas y cuyos
resultados no deben confundirse.

![**Figura 6.31.** La cadena completa —cámara, procesador, filtro y clasificador— en señales, sobre
la escena del dígito 3. El panel A muestra los 19 ms de dos cuadros: el veredicto sale en el primero
y no cambia en el segundo. El panel B captura el instante en que **el procesador sustituye el umbral
por omisión del RTL, 110, por el 90 que escribe el firmware**, con el camino de datos todavía en
reinicio. El panel C mide los 639,5 µs que tardan las 400 multiplicaciones-acumulaciones y el
`argmax`.](figuras/fig_5_6_cadena_en_senales.png)

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

![**Figura 6.32.** La tarjeta durante ese primer ensayo, con el mapa de bits cargado. El diodo verde
está cableado a la señal de configuración terminada; el azul parpadea con el latido del sistema. Los
diez veredictos salen por el puerto serie del mismo conector que alimenta la tarjeta. A la derecha,
el mismo montaje con el cableado del módulo de pantalla ya
conectado.](figuras/fig_5_7_la_placa_uart.png)

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

La verificación del extractor contra su modelo de referencia arrojó **99,91 %** de coincidencia
exacta píxel a píxel para el Sobel y **99,93 %** para el Canny, concentrándose las diferencias en la
última fila del cuadro.
