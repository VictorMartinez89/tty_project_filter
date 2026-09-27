# 4. Los filtros y el SoC: del modelo a la tarjeta

Este capítulo describe **cómo está construido** el sistema y lo lleva hasta la tarjeta. Sigue el orden en
que los datos lo atraviesan —de la cámara a la pantalla—: los filtros, cada uno con su modelo en Python,
su simulación en Verilog y su foto en la iCE40UP5K; el procesador y su periférico; la memoria; y al final
la verificación contra el modelo, los resultados en la FPGA y el rendimiento medido. El paso a silicio es
el Capítulo 5. Las cifras y las expresiones que siguen se leyeron del RTL, no de las notas de trabajo.

## 4.1 Arquitectura

La cadena consta de cuatro etapas en serie y un procesador **al costado**, no en medio:

$$\text{cámara} \rightarrow \text{filtro} \rightarrow \text{almacenamiento} \rightarrow \text{pantalla}$$

Que el procesador quede al costado es la decisión de arquitectura más importante del trabajo. **Los
píxeles no pasan por el bus.** El FemtoRV32 no lee la imagen, no la escribe y no participa del camino
de datos: escribe un registro de configuración —el umbral— y lee un resultado. Si se detuviera, el
filtrado continuaría.

La consecuencia es que el caudal del sistema no depende de la frecuencia del procesador ni del número
de ciclos que consuma una instrucción, y por eso el §4.10 puede afirmar que la presencia del procesador
no altera la latencia del cauce: cuatro ciclos siguen siendo cuatro ciclos.

### Dos dominios de reloj

El sistema tiene **dos relojes asíncronos entre sí**:

| Dominio | Frecuencia | Qué vive ahí |
|---|---|---|
| `clk` | 50 MHz (20 ns) | configuración SCCB, generación del raster, driver de pantalla |
| `cam_pclk` | 25 MHz (40 ns) | captura, submuestreo, filtro, escritura del almacenamiento |

Table: Los dos dominios de reloj del sistema.

La frontera entre ambos atraviesa el circuito **por el almacenamiento**: la cámara escribe en su
reloj y la pantalla lee en el suyo. El único otro punto de cruce, en los diseños que reconocen, son
los dos biestables que llevan el dígito al dominio de la pantalla. Todo lo demás vive enteramente a
un lado o al otro, lo que reduce el problema de cruce de dominios a dos casos tratables por separado.
La Figura 4.18 dibuja esa frontera sobre el diseño concreto que corre en la tarjeta.

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

Table: Registros de la cámara OV7670 escritos por SCCB.

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

## 4.3 Los diseños: los filtros y los sistemas que los usan

### Filtro Sobel

#### Resumen

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
posible la igualdad bit a bit con el modelo de referencia que documenta la §4.8: no hay ninguna
operación cuyo redondeo pueda diferir entre una biblioteca de punto flotante y un circuito.

Los tres filtros necesitan una ventana de 3×3, es decir tres filas simultáneas de la imagen. El
módulo `linebuf3x3` las proporciona con **dos memorias de línea** —las filas *n−2* y *n−1*— mientras
la fila *n* llega directamente del flujo. Almacenar dos filas y no tres es la diferencia entre un
buffer y una copia de la imagen, y es el fundamento de toda la arquitectura de flujo.

#### Pseudocódigo

El Sobel es el más simple de los tres y fija el esqueleto que los otros dos extienden: suavizado,
gradiente y un umbral. La notación es la de la §4.4.

```
──────────────────────────────────────────────────────────────────────
 Algoritmo 1   Front-end Sobel
──────────────────────────────────────────────────────────────────────
 FRONTEND_SOBEL(in_pix, thr)                     ▷ parámetros: H, W
 ▷ etapa 1 — suavizado
 1.  (g₀₀…g₂₂, v_g) ≔ LINEBUF3X3⟨W,8⟩(in_valid, in_pix)
 2.  gsum ≔ g₀₀+2g₀₁+g₀₂ + 2g₁₀+4g₁₁+2g₁₂ + g₂₀+2g₂₁+g₂₂
 3.  gout ≔ gsum ≫ 4                             ▷ dividir entre 16 es desplazar
 ▷ etapa 2 — gradiente
 4.  (s₀₀…s₂₂, v_s) ≔ LINEBUF3X3⟨W,8⟩(v_g, gout)
 5.  Gx⁺ ≔ s₀₂+2s₁₂+s₂₂ ;   Gx⁻ ≔ s₀₀+2s₁₀+s₂₀
 6.  Gy⁺ ≔ s₂₀+2s₂₁+s₂₂ ;   Gy⁻ ≔ s₀₀+2s₀₁+s₀₂
 7.  σx ≔ (Gx⁺ ≥ Gx⁻) ;     σy ≔ (Gy⁺ ≥ Gy⁻)     ▷ los signos, que dan la orientación
 8.  |Gx| ≔ |Gx⁺−Gx⁻| ;     |Gy| ≔ |Gy⁺−Gy⁻|
 9.  mag ≔ mín(|Gx|+|Gy|, 255)                   ▷ norma L1: sin raíz y sin multiplicar
10.  borde ≔ (mag > thr)                         ▷ UN umbral
11.  LAT  ≔ 2·(W+2)                              ▷ dos etapas de ventana
──────────────────────────────────────────────────────────────────────
```

#### El código

El RTL del Sobel son dos ficheros: `sobel_top.v`, con el gradiente y el umbral, y `linebuf3x3.v`, el
generador de ventana que comparten los tres filtros. Los dos se reproducen completos en el Anexo G.1.

#### Simulación en Python

El modelo de referencia calcula el gradiente de cada imagen de prueba y sirve de criterio para todo lo
que sigue: el RTL se da por correcto sólo si lo reproduce bit a bit (§3.2).

![**Figura 4.1.** El modelo de referencia en Python sobre las cinco imágenes de prueba —`flower`,
`monarch`, `butterfly`, la mano y la tarjeta «HOLA»—: la imagen en gris, las componentes |Gx| y |Gy|,
y la magnitud |Gx|+|Gy| saturada a 255, antes del umbral.](figuras/fig_4_sobel_python.jpg)

#### Simulación en Verilog: las señales

El mismo filtro, descrito en Verilog, se simula con Icarus Verilog y se inspecciona con GTKWave sobre
una imagen de prueba de 16×12 píxeles, pequeña a propósito para que el cauce completo quepa en una
pantalla.

![**Figura 4.2.** El Sobel a 16×12 en GTKWave. Arriba, el banco de pruebas inyecta la imagen píxel a
píxel (`in_valid`, `in_pix`) y recoge la salida (`out_valid`, `out_pix`) mientras cuenta los bordes.
Abajo, dentro de `linebuf3x3`, las dos memorias de línea (`q_a`, `q_b`) y el primer registro de la
ventana, `w00`, que se llena antes de que `out_valid` suba.](figuras/fig_4_sobel_gtkwave.jpg)

#### Simulación en Verilog: la imagen

Las señales dicen cómo funciona el circuito; la imagen dice qué produce. El RTL se simula sobre las
mismas imágenes que el modelo y su salida se compara píxel a píxel con la de éste (§4.8): primero el
núcleo solo, y después la cadena completa, con una cámara OV7670 emulada en el banco de pruebas.

![**Figura 4.3.** El Sobel simulado en Verilog sobre las cinco imágenes a 60×80: la entrada, el modelo de
referencia, el núcleo RTL —idéntico al modelo píxel a píxel— y la cadena completa con la cámara OV7670
emulada, que concuerda salvo un desfase fijo en el borde del cuadro (§4.8).](figuras/fig_4_sobel_rtl.png)

#### En la tarjeta

Grabado en la iCE40UP5K, el filtro procesa en vivo la imagen de la cámara OV7670 y la muestra en la
pantalla TFT, sin intervención de ningún computador. La Figura 4.19 reúne las seis escenas.

![**Figura 4.4.** El Sobel corriendo en la iCESugar sobre las cinco escenas: la mariposa `monarch`, la flor, la
mariposa `butterfly`, la mano y la tarjeta «HOLA», fotografiadas directamente de la pantalla.](figuras/fig_4_sobel_placa.jpg)

#### En silicio

El filtro solo, sin cámara ni pantalla, se llevó a sky130 con OpenLane: **0,167 mm²** y **5 823
celdas** tras el emplazamiento, con DRC, LVS y XOR en cero (§5.2). Es la versión sin suavizado
gaussiano, con líneas de 60 píxeles (Anexo G.1). Su plano en KLayout se muestra en la §5.2.2. Es el circuito más pequeño de la
tabla, y el punto de partida de todos los demás.


#### Ventajas y desventajas frente al filtro de Maldonado

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

Table: Ventajas y desventajas del chip de Maldonado (TT06) frente a este trabajo.

Las dos columnas no compiten: responden preguntas distintas. La de Maldonado es **cuánto cuesta el
filtro solo, y si el silicio hace lo que dice**; su respuesta —dos tiles, milivatios, imagen exacta a
cientos de miles de píxeles por segundo— es la única medición física de toda esta línea de trabajo. La de
éste es **qué pasa cuando el filtro tiene que vivir en un sistema**: con cámara, con memoria y con una
decisión aguas abajo. Y la respuesta que da el Capítulo 5 es que entonces **lo caro deja de ser el
filtro y pasa a ser la memoria**, que es exactamente lo que el diseño de Maldonado había dejado fuera del
chip.

### Filtro Canny 1-streaming

#### Resumen

El Canny completo consta de suavizado gaussiano, cálculo del gradiente, supresión de no-máximos,
doble umbral e histéresis. La histéresis es el problema: exige seguir cadenas de píxeles débiles
conectados a fuertes, lo que en general requiere recorrer el cuadro varias veces.

La implementación en flujo aproxima ese paso con un **salto único**: un píxel débil se promueve a
borde si *alguno de sus ocho vecinos inmediatos* es fuerte. Es una histéresis de radio uno, y captura
la mayor parte del efecto porque en una imagen real los débiles forman un halo fino alrededor de los
fuertes —afirmación que la §4.10.3 confirma midiendo que el proceso completo converge en dos pasadas.

El precio arquitectónico es que esta cadena encadena **tres** etapas de ventana 3×3 en lugar de una,
y por eso necesita tres `linebuf3x3` y presenta ocho ciclos de latencia de cauce frente a los cuatro del
Sobel. El esquemático que genera el sintetizador muestra las tres cajas, y en las señales de la Figura 4.6 se
ven sus tres `valid`, escalonados.

#### Pseudocódigo

El Canny de un salto es el anterior **con una etapa más**, y con una dificultad que no se ve a simple
vista:

```
──────────────────────────────────────────────────────────────────────
 Algoritmo 2   Front-end Canny de un salto
──────────────────────────────────────────────────────────────────────
 FRONTEND_CANNY1(in_pix, thr_hi, thr_lo)
 1–9.  idéntico al Algoritmo 1                   ▷ mismo suavizado, mismo gradiente
10.  cls ≔ (mag > thr_hi) ? 2 : (mag > thr_lo) ? 1 : 0        ▷ DOBLE umbral
11.  bin_raw ≔ ⟨σy, σx, |Gy|>|Gx|⟩               ▷ el octante
 ▷ etapa 3 — histéresis de un salto
12.  (c₀₀…c₂₂, v_c) ≔ LINEBUF3X3⟨W,5⟩(v_s, ⟨bin_raw, cls⟩)    ▷ 5 bits: 3 + 2
13.  fuerte_cerca ≔ ⋁_{(i,j)≠(1,1)} (c_ij[1:0] = 2)
14.  cen ≔ c₁₁[1:0]
15.  borde ≔ (cen = 2) ? verdadero : (cen = 1) ? fuerte_cerca : falso
16.  LAT  ≔ 3·(W+2)                              ▷ TRES etapas, no dos
──────────────────────────────────────────────────────────────────────
```

> **El paso 12 merece explicación.** La histéresis necesita la *clase* del vecindario y la etapa
> siguiente necesita la *orientación* del píxel central. Si ambas viajan por memorias de línea
> separadas **llegan desfasadas**, y se acaba contando la orientación de un píxel con la decisión de
> otro.
>
> La solución es **empaquetarlas en la misma memoria**, cinco bits que viajan juntos. El punto
> central de la ventana devuelve entonces las dos cosas del mismo píxel **por construcción**, y no
> por cuidado de quien escribe. El desfase no se corrige: se vuelve imposible.
>
> Y el paso 16 no es un detalle: con la latencia mal puesta el histograma queda corrido dos columnas
> y las zonas se mezclan. Está anotado como advertencia en el propio archivo, porque costó
> encontrarlo.

#### El código

El RTL del Canny de un salto es `canny1_top.v`: suavizado gaussiano, gradiente, doble umbral e
histéresis de un salto, sobre tres instancias del mismo `linebuf3x3` del Sobel (Anexo G.1). Se reproduce
completo en el Anexo G.2.

#### Simulación en Python

El modelo de referencia en Python descompone el Canny clásico en sus pasos. El circuito se queda con
parte de ellos: **omite la supresión de no-máximos** y reemplaza la histéresis completa por un solo
salto. Su modelo exacto, el que el RTL tiene que igualar, es el de la Figura 4.7.

![**Figura 4.5.** El Canny clásico en Python, paso a paso sobre `flower`: la imagen original, el
suavizado gaussiano de 3×3, la magnitud del gradiente, la supresión de no-máximos, el doble umbral y la
histéresis.](figuras/fig_4_canny_python.png)

#### Simulación en Verilog: las señales

La misma imagen de prueba de 16×12 que el Sobel, ahora a través de las tres etapas de ventana.

![**Figura 4.6.** El Canny de un salto a 16×12 en GTKWave. Arriba, la entrada y la salida del banco
con el contador de bordes. Abajo, el interior: la salida del gaussiano (`gsum`, `gout`), las componentes
del gradiente (`gxp`, `gxn`, `gyp`, `gyn`), la magnitud (`mag`), la clase de cada píxel (`cls_in`,
`cw00`) y la decisión de la histéresis (`edge_1hop`, `any_strong`), con los dos umbrales. Las tres
últimas señales, `vg`, `vs` y `vc`, son los `valid` de las tres memorias de línea, cada uno detrás del
anterior.](figuras/fig_4_canny_gtkwave.jpg)

#### Simulación en Verilog: la imagen

Como con el Sobel, el RTL se compara píxel a píxel con el modelo (§4.8): primero el núcleo solo, y
después la cadena completa con la cámara emulada.

![**Figura 4.7.** El Canny de un salto simulado en Verilog sobre las cinco imágenes a 60×80: la
entrada, el modelo de referencia, el núcleo RTL —idéntico al modelo píxel a píxel— y la cadena completa
con la cámara OV7670 emulada. A esta resolución y con los umbrales del banco, las zonas con textura
quedan casi enteras marcadas como borde.](figuras/fig_4_canny_rtl.png)

#### En la tarjeta

Grabado en la iCE40UP5K, el filtro corre en vivo entre la cámara y la pantalla, igual que el Sobel.

![**Figura 4.8.** El Canny de un salto corriendo en la iCESugar sobre las cinco escenas: la mariposa
`monarch`, la flor, la mariposa `butterfly`, la mano y la tarjeta «HOLA», fotografiadas directamente
de la pantalla.](figuras/fig_4_canny_placa.jpg)

#### En silicio

Llevado solo a sky130, sin cámara ni pantalla, ocupa **0,360 mm²** y **12 993 celdas** tras el
emplazamiento, con DRC, LVS y XOR en cero (§5.2): algo más del doble que el Sobel, por el suavizado
gaussiano y la memoria de clases, dos memorias de línea más. Su plano en KLayout es la Figura 5.2.

### Filtro Canny Framebuffer Transitivo

#### Resumen

El tercer filtro no aproxima: resuelve la histéresis completa. Formalmente es una **reconstrucción
morfológica** —la reconstrucción de la máscara de píxeles débiles a partir de los fuertes como
marcadores, bajo conectividad de ocho vecinos— y su resultado es el **punto fijo** de la operación
«promover todo débil adyacente a un borde confirmado».

La implementación es un motor con máquina de estados que **barre el cuadro repetidamente** y termina
cuando un barrido completo no produce ningún cambio. El número de barridos, *K*, no es una constante
del diseño sino una propiedad de la imagen, y la §4.10.3 lo mide: dos para bordes reales, cincuenta y
uno en el peor caso construido.

Esta es la única de las tres arquitecturas que **exige el cuadro completo residente**, y de esa
exigencia se derivan casi todos los resultados del Capítulo 8.

#### Pseudocódigo

El transitivo, en cambio, **no es un filtro más caro: es otra clase de objeto**, y el enunciado lo
muestra en un solo paso:

```
──────────────────────────────────────────────────────────────────────
 Algoritmo 3   Front-end transitivo
──────────────────────────────────────────────────────────────────────
 FRONTEND_TRANS(in_pix, thr_hi, thr_lo)
 1–10. idéntico al Algoritmo 2 hasta `cls`       ▷ mismo doble umbral
 ▷ etapa 3 — reconstrucción morfológica
11.  M ← matriz (H+2)×(W+2) en memoria           ▷ EL CUADRO ENTERO
12.  CARGA:   M[y][x] ← cls  ∀ píxel             ▷ hay que esperar el cuadro completo
13.  repetir
14.     cambió ← falso
15.     BARRIDO: para cada (y,x) en orden de barrido
16.        si M[y][x] = 1 ∧ (∃ vecino 8-conexo con M = 2) entonces
17.           M[y][x] ← 2 ;  cambió ← verdadero  ▷ el débil asciende a fuerte
18.  hasta ¬cambió                               ▷ PUNTO FIJO: nº de barridos desconocido
19.  LECTURA: borde ≔ (M[y][x] = 2)  ∀ píxel
──────────────────────────────────────────────────────────────────────
```

> **El paso 18 lo saca de la familia.** Los Algoritmos 1 y 2 **deciden en el píxel**: cuando éste
> abandona la última memoria de línea su destino está sellado y el dato puede descartarse. Son
> transmisores: memoria `2·W` o `3·W` bytes, latencia fija y conocida, y funcionan con una cámara que
> entrega píxeles y no espera a nadie.
>
> El Algoritmo 3 **no puede decidir en el píxel**, porque un débil de la tercera fila puede ascender
> por una cadena que atraviesa la fila veinticinco. Necesita el cuadro completo en memoria —`H·W` y
> no `3·W`— y un número de barridos **que depende de la imagen**.
>
> De ahí salen, como consecuencias de una sola causa, las tres cosas que los Capítulos 4 y 5 miden por
> separado: que ocupe 65 659 celdas frente a 5 823, que no quepa en un proyecto de mosaicos, y que su
> latencia no esté acotada. Y en el propio código se reduce a una línea: una transición de vuelta al
> estado de barrido. **Un lazo cuyo número de vueltas no se conoce al sintetizar es, en hardware, lo
> más caro que puede escribirse.**

#### El código

El motor son dos ficheros: `trans_engine_top.v`, que lo envuelve, y `hysteresis_frame_bram_sync.sv`, la
máquina de estados que borra el cuadro, lo carga, lo barre hasta el punto fijo y lo lee. Los dos se
reproducen en el Anexo G.3.

#### Simulación en Python

El modelo compara la histéresis completa —la que resuelve este filtro— con la de un salto de la §4.3.2,
sobre la mariposa `monarch`. La diferencia es pequeña y está en las cadenas largas de píxeles débiles:
es lo que el transitivo recupera y el de un salto pierde.

![**Figura 4.9.** Histéresis completa frente a la de un salto, en Python, sobre `monarch`: los
candidatos fuertes y débiles tras la supresión de no-máximos, la histéresis completa, la de un salto y
su diferencia.](figuras/fig_4_trans_python.png)

#### Simulación en Verilog: las señales

Sobre la misma imagen de 16×12, el motor ya no procesa un flujo: carga el cuadro, lo barre y lo lee.

![**Figura 4.10.** El motor transitivo a 16×12 en GTKWave, en el instante en que termina la carga:
`load_ready` e `in_valid` bajan, `state` pasa de 001 (carga) a 010 (barrido) y las direcciones de la
memoria (`mem_ra`, `a1`, `a2`) empiezan a recorrer el cuadro.](figuras/fig_4_trans_gtkwave.jpg)

![**Figura 4.11.** La misma simulación, dibujada entera desde el VCD. Tras cargar el cuadro (estado
1), el motor encadena barridos (estado 2) mientras `changed` sube; en este cuadro son seis, cinco con
cambios y uno sin ellos. Ese último es el punto fijo: el motor pasa a la lectura (estado 4) y salen
`eng_out_valid` y los bordes.](figuras/fig_4_trans_motor.png)

#### Simulación en Verilog: la imagen

Como los otros dos, el RTL se compara píxel a píxel con el modelo (§4.8).

![**Figura 4.12.** El Canny transitivo simulado en Verilog sobre las cinco imágenes a 60×80: la
entrada, el modelo de referencia, el núcleo RTL —idéntico al modelo píxel a píxel— y la cadena completa
con la cámara OV7670 emulada.](figuras/fig_4_trans_rtl.png)

#### En la tarjeta

Grabado en la iCE40UP5K, con el cuadro de clases en la memoria SPRAM, corre en vivo como los otros dos.

![**Figura 4.13.** El Canny transitivo corriendo en la iCESugar sobre las cinco escenas: la mariposa
`monarch`, la flor, la mariposa `butterfly`, la mano y la tarjeta «HOLA», fotografiadas directamente de
la pantalla.](figuras/fig_4_trans_placa.jpg)

#### En silicio

Llevado solo a sky130 ocupa **3,13 mm²** y **65 659 celdas** tras el emplazamiento, con DRC, LVS y XOR
en cero (§5.2): casi veinte veces el área del Sobel, porque el cuadro que en la FPGA vivía en la SPRAM
aquí es un banco de biestables. Su plano en KLayout es la Figura 5.1.

### SoC Femto con filtro Sobel

#### Resumen

El primer sistema reúne el procesador FemtoRV32 (§4.5), una ROM con su programa y el periférico de
control en `0x0045` alrededor del Sobel de la §4.3.1. **Los píxeles no pasan por el procesador**: el
camino de imagen sigue siendo un flujo, y el procesador sólo escribe dos registros —el filtro activo y
el umbral—. Lo que se gana es que el umbral deja de estar cableado y lo fija el programa.

En silicio el programa no puede vivir en una RAM inicializada, que arrancaría con valores aleatorios:
va en una **ROM sintetizada de siete instrucciones**, y como el programa no usa datos, no hace falta
ninguna RAM escribible.

#### Pseudocódigo

```
──────────────────────────────────────────────────────────────────────
 Algoritmo 4   SoC Femto con filtro Sobel
──────────────────────────────────────────────────────────────────────
 ▷ el programa: siete instrucciones en ROM
 1.  x1 ← 0x0045_0000                         ▷ base del periférico
 2.  CTRL(x1+0) ← 0x10                        ▷ modo 0 = Sobel ; enable = 1
 3.  THR(x1+4)  ← 0x5A00                      ▷ thr_hi = 90 ; thr_lo = 0
 4.  repetir para siempre                     ▷ jal x0, 0
 ▷ el hardware, en paralelo y sin pasar por el procesador
 5.  (modo, thr_hi) ≔ registros del periférico
 6.  out_pix ≔ FRONTEND_SOBEL(in_pix, thr_hi) ▷ Algoritmo 1
──────────────────────────────────────────────────────────────────────
```

#### El código

`soc_sobel_top.v` instancia el procesador, la ROM, el periférico y el Sobel; `peripheral_filter.v` es
el periférico. Se reproducen en el Anexo G.4; el núcleo `femtorv32_quark.v` es de Levy y se cita.

#### Simulación en Python

El SoC **no cambia la aritmética**: su modelo en Python es el del Sobel (Figura 4.1) con el umbral que
escribe el programa, 90. Lo que el SoC agrega —que ese umbral lo fije el procesador y no un cable— sólo
se puede comprobar en la simulación del hardware, que es la que sigue.

#### Simulación en Verilog: las señales

![**Figura 4.14.** El SoC con el Sobel a 16×12 en GTKWave. `thr_o` vale `5A`: el 90 que escribió el
programa. El contador de programa del FemtoRV32, `PC`, está detenido en `0x18`, la séptima instrucción,
el lazo final; y mientras tanto el Sobel sigue sacando píxeles de borde (`FF`) y de fondo (`00`) por su
cuenta.](figuras/fig_4_socsobel_gtkwave.jpg)

#### Simulación en Verilog: la imagen

![**Figura 4.15.** Lo que produce el SoC simulado en Icarus Verilog a 160×120, con el programa que
elige el Sobel y fija el umbral en 90: arriba, las cinco imágenes de prueba; abajo, sus
bordes.](figuras/fig_4_socsobel_rtl.png)

#### En la tarjeta

![**Figura 4.16.** El SoC con el Sobel corriendo en la iCESugar sobre las cinco escenas —`monarch`, la
flor, `butterfly`, la mano y la tarjeta «HOLA»—, en fotogramas de los videos de la
tarjeta.](figuras/fig_4_socsobel_placa.jpg)

#### En silicio

En sky130 ocupa **0,37 mm²** y **12 043 celdas** tras el emplazamiento, con DRC, LVS y XOR en cero
(§5.2). Frente al Sobel solo, el procesador y su periférico añaden **6 220 celdas**: es el precio de que
el umbral lo fije un programa, la cifra que la §8.6 compara con la de comprar esa misma robustez en el
filtro. Su plano en KLayout es la Figura 5.4.

### Para concluir: lo que los filtros toman del de Maldonado

El estilo de la aritmética —desplazamientos y sumas, ningún multiplicador—; las imágenes de prueba
(`flower`, `monarch`, `butterfly`), que atraviesan los Capítulos 4 y 5; la norma L1 con saturación como
magnitud; y, para Tiny Tapeout, la lección de **serializar la entrada y la salida** para ahorrar pines y área. Lo
que agrega es lo que Maldonado dejó conscientemente fuera:

- **el control programable**: el FemtoRV32 escribe el modo y los umbrales en vivo, a través del
  periférico `0x0045` (§4.5);
- **el motor de histéresis transitiva**, la reconstrucción morfológica de punto fijo, que es el filtro
  que de verdad cuesta;
- **la cadena cámara → filtro → memoria → pantalla**, funcionando y fotografiada en una iCE40UP5K;
- **el co-diseño medido**: el Canny transitivo no cabía junto al procesador —127 % de ocupación— y por
  eso su motor pasó a hardware (§4.9);
- y **el reconocimiento de dígitos**, del borde al número (Capítulo 6).

## 4.4 Los tres filtros, enunciados como algoritmos

Las descripciones anteriores son narrativas. Esta sección las enuncia de forma que puedan compararse
sin ambigüedad, porque la afirmación central del trabajo —que dos de los filtros son objetos
computacionales de una clase y el tercero de otra— **no se sostiene sobre lo que los filtros hacen
sino sobre su estructura**, y la estructura hay que escribirla.

Se emplea una notación mínima que distingue lo que en hardware son dos cosas distintas:

| símbolo | significa | en Verilog |
|:--:|---|---|
| `x ← e` | **registro**: se actualiza al final del ciclo, y el bloque lee el valor anterior | `x <= e` |
| `x ≔ e` | **cable**: vale de inmediato y de forma continua | `wire` / `assign` |
| `▷` | comentario | `//` |

Table: Notación empleada para enunciar los filtros como algoritmos.

**Los tres comparten el esqueleto y se diferencian en una sola caja.** Ésa es la razón de que puedan
intercambiarse sin tocar nada aguas abajo, y de que la comparación de los Capítulos 4 y 5 sea limpia: se
cambia una pieza y nada más.

Los tres algoritmos se enuncian junto a su filtro: el del Sobel en la §4.3.1, el del Canny de un salto
en la §4.3.2 y el del transitivo en la §4.3.3, cada uno con lo que lo distingue del anterior.

## 4.5 El SoC: procesador, periférico y firmware

El procesador es un **FemtoRV32 Quark**, una implementación mínima de RV32I. Se le añaden una memoria
de programa y un **periférico mapeado en memoria en la base `0x0045_0000`** a través del cual escribe
el umbral del filtro y lee el estado.

Esa dirección no es arbitraria, y conviene explicarla porque sitúa el trabajo. La arquitectura de
bus, el decodificador que compara `mem_addr[31:16]` contra una lista de bases y el conjunto de
periféricos —comunicación serie en `0x0040`, puertos de propósito general en `0x0041`, multiplicador
en `0x0042`, divisor en `0x0043` y conversión a decimal codificado en `0x0044`— proceden del **SoC de
referencia descrito por Camargo (2025, §1.2.1)**, que es el material sobre el que se enseña diseño
digital en el programa. **Este trabajo añade un periférico más, en la base siguiente.**

![**Figura 4.17.** El sistema en silicio, en el lenguaje de bloques del SoC de referencia. Los siete
periféricos en gris son los heredados; el que aparece destacado, en la base `0x0045`, es la
aportación de este trabajo. Obsérvese que **el camino de datos de imagen no pasa por el bus**: los
píxeles entran de la cámara al filtro y salen de éste a la pantalla a un píxel por ciclo, y lo único
que el procesador pone en el bus es el umbral.](figuras/fig_4_1_soc.png)

![**Figura 4.18.** El mismo sistema, pero sin procesador, y bajado hasta los pines: los catorce
puertos del módulo de más alto nivel, las cuatro etapas del filtro y los dos dominios de reloj. La
frontera que la §4.1 enuncia se ve aquí dibujada: **el almacenamiento de 60x80 se escribe con el
reloj de píxel de la cámara y se lee con el del sistema**, y es el único punto por el que los dos
dominios se tocan. Los números de pin son los del fichero de restricciones verificado en la
tarjeta, no los de los comentarios del código.](figuras/fig_pines_a_cajas.png)

La figura muestra por qué este periférico no se parece a los demás. Un multiplicador o un divisor
reciben sus operandos por el bus y devuelven el resultado por el bus: el procesador los usa. El
filtro, en cambio, **tiene su propio camino de datos** —de la cámara a la pantalla, a un píxel por
ciclo— y del bus recibe únicamente un parámetro de configuración. El procesador no lo usa: lo
**ajusta**.

> Esa distinción es la que el Capítulo 8 convierte en argumento. Un periférico que procesa a través
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

Es el primero de los cuatro cambios obligatorios de la §5.1, y el que más sorprende a quien llega
desde FPGA, porque el código funciona idénticamente en simulación en ambos casos.

## 4.6 Memoria: la batalla de los recursos

La iCE40UP5K ofrece tres clases de almacenamiento, y el diseño usa las tres con criterios distintos:

| Recurso | Cantidad | Uso en este trabajo |
|---|---|---|
| Celdas lógicas | 5 280 | lógica y registros pequeños |
| Bloques de memoria (4 kbit) | 30 | **memorias de línea** de las ventanas 3×3 |
| SPRAM (256 kbit) | 4 | **framebuffers** del filtro transitivo |

Table: Recursos de memoria de la iCE40UP5K y su uso en este trabajo.

La asignación no es libre: una memoria de línea cabe en un bloque de memoria si el sintetizador la
reconoce como tal, y no la reconoce si el código la escribe de una forma que no encaja con el patrón
esperado. Varios de los problemas de recursos del desarrollo fueron de esa naturaleza —memorias que
se convertían en biestables por un detalle de escritura del RTL— y no de tamaño real del diseño.

El caso más costoso fue un **ancho de puntero insuficiente**: un contador de direcciones con un bit
de menos del necesario direcciona la mitad de la memoria y sobrescribe la otra, produciendo una
imagen que se ve plausible pero está mal. Como en el caso del byte de luminancia, el error sobrevive
a la inspección visual.

> Este apartado es el origen del título del Capítulo 8. En la FPGA los dos primeros recursos parecen
> gratuitos porque ya están en el sustrato; en el ASIC ninguno lo es, y el mismo RTL que allí cabía
> holgadamente aquí define el tamaño del dado.

## 4.7 Del RTL a la FPGA

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

## 4.8 Verificación funcional

Antes de presentar área, frecuencia o consumo conviene establecer que los circuitos **calculan lo que
deben calcular**. Esta sección lo hace, y distingue con cuidado dos preguntas que la literatura de
implementación mezcla con frecuencia: si el hardware coincide con su modelo de referencia, y si el
resultado es bueno. Aquí sólo se responde la primera. La segunda pertenece al Capítulo 6.

### 4.8.1 El criterio

Cada filtro se especificó primero como un programa en Python —el **modelo golden** descrito en la
§3.2— y sólo después se escribió su descripción en Verilog. La verificación consiste en ejecutar
ambos sobre la misma entrada y comparar **píxel a píxel**, no en inspeccionar visualmente la salida.

La distinción no es formal. Un mapa de bordes erróneo sigue pareciendo un mapa de bordes, de modo que
la inspección visual no distingue un circuito correcto de uno que desplaza una fila, satura un byte o
invierte un signo. Sólo la comparación numérica lo hace.

Al comparar se admite un **desplazamiento constante** entre ambas salidas —la técnica de *best-shift*
de la §3.3— porque la implementación en hardware introduce una latencia de segmentación que el modelo
en software no tiene. Un desfase uniforme de *k* píxeles no es un error de cálculo sino una propiedad
de la arquitectura segmentada, y se descuenta explícitamente; cualquier diferencia que sobreviva a esa
corrección sí lo es.

### 4.8.2 Resultado sobre los núcleos aislados

Los tres núcleos son **idénticos bit a bit** a su modelo de referencia. En el caso del Sobel sobre un
cuadro de 60×80, la comparación arroja **0 píxeles de diferencia sobre 4 800**, y el resultado se
sostiene para los tres filtros sobre las cinco imágenes de prueba.

| Núcleo | Imágenes | Píxeles comparados | Diferencias |
|---|---:|---:|---:|
| Sobel 3×3 | 5 / 5 | 4 800 por cuadro | **0** |
| Canny de un salto | 5 / 5 | 4 800 por cuadro | **0** |
| Canny transitivo | 5 / 5 | 4 800 por cuadro | **0** |

Table: Verificación bit a bit de los núcleos aislados contra el modelo de referencia.

Que la coincidencia sea exacta y no aproximada tiene una causa de diseño: los tres filtros operan
**sobre enteros y sin división**. La magnitud del gradiente usa la norma L1, `|Gx|+|Gy|`, en lugar de
la euclídea; los pesos del operador son potencias de dos, implementadas como desplazamientos; y el
umbral es una comparación. No hay ninguna operación cuyo redondeo pueda diferir entre una biblioteca
de punto flotante y un circuito. **La igualdad bit a bit no es una casualidad afortunada: es
consecuencia de haber elegido una aritmética que la permite.**

### 4.8.3 Resultado sobre la cadena completa con cámara

La verificación anterior alimenta el circuito con una imagen almacenada. La cadena real recibe en
cambio un flujo de video de la cámara OV7670, con sus bordes de línea, sus tiempos muertos y su
sincronismo propio. Medida sobre ese flujo, la concordancia entre el hardware y el modelo es:

| Cadena | Concordancia |
|---|---:|
| Sobel | 95 – 100 % |
| Canny de un salto | 88 – 99 % |
| Canny transitivo | 96 – 100 % |
| Promedio a través del SoC | **97,8 %** |

Table: Concordancia de la cadena completa con cámara frente al modelo.

La degradación respecto del 100 % de la §4.8.2 no proviene del filtro sino del **acoplamiento con la
cámara**: el muestreo del flujo, el recorte de la ventana y el instante exacto en que empieza un
cuadro introducen diferencias de uno o dos píxeles en los bordes de la imagen. El valor más bajo
corresponde al Canny de un salto, que es también el más sensible por construcción —un píxel que cruza
el umbral alto propaga su decisión a sus vecinos, de modo que una diferencia aislada en la entrada
puede producir varias en la salida.

> **Dos precisiones de terminología, porque el número se presta a confusión.**
>
> Primera: los porcentajes de esta tabla son **concordancia entre el hardware y su propio modelo de
> referencia**, no exactitud del filtro. Miden si el circuito hace lo que el programa hace, no si lo
> que el programa hace es correcto o útil. Un filtro mal diseñado puede alcanzar el 100 % de
> concordancia con un modelo igualmente mal diseñado.
>
> Segunda: la **densidad de bordes** —la fracción de píxeles marcados, en torno al 2 % en las
> imágenes de prueba— aparece en varias figuras de este trabajo y **no es una medida de calidad**. Es
> una propiedad de la escena y del punto de operación elegido, y su valor «correcto» depende de para
> qué se vaya a usar el mapa de bordes. La §6.4 muestra precisamente que mover ese punto de
> operación cambia el resultado de clasificación más que cambiar de filtro.

## 4.9 Resultados en FPGA

Los resultados de esta sección son de una clase distinta a los del resto del capítulo: no provienen
de un informe de herramienta sino de **un circuito que funciona sobre una mesa**, con una cámara
apuntando a un objeto y una pantalla mostrando el resultado. Es la única parte del trabajo donde el
sistema completo existe físicamente, y por eso condiciona lo que puede afirmarse de las demás.

### 4.9.1 La plataforma

La implementación física se realizó sobre una **iCE40UP5K** en tarjeta iCESugar v1.5, con una cámara
**OV7670** y una pantalla **TFT ILI9341** por SPI. El flujo de síntesis e implementación es enteramente
abierto: `yosys` para síntesis, `nextpnr-ice40` para emplazamiento y ruteo, `icepack` para el
*bitstream*.

La elección del dispositivo no es incidental. La iCE40UP5K ofrece 5 280 celdas lógicas, 30 bloques de
memoria de 4 kbit y **cuatro bloques de SPRAM de 256 kbit** — y son estos últimos los que hacen
posible el filtro transitivo, porque permiten alojar el cuadro completo sin consumir lógica. Esa
disponibilidad es exactamente lo que desaparece al pasar a un ASIC sin macro de memoria, y es el
origen del resultado de la §5.3.3.

### 4.9.2 Los tres filtros, funcionando

| Filtro | Arquitectura | Implementación física | Umbrales en la placa |
|---|---|---|---|
| Sobel | flujo | hardware, con procesador FemtoRV32 | 90 |
| Canny de un salto | flujo | hardware, con procesador FemtoRV32 | 50 / 20 |
| Canny transitivo | **framebuffer** | hardware, motor en Verilog **sin procesador** | 60 / 30 |

Table: Los tres filtros en la FPGA: arquitectura, implementación y umbrales.

Los tres funcionan sobre la placa con cámara y pantalla en vivo. El transitivo produce contornos
**conectados y completos** —una letra cerrada aparece cerrada— frente a los bordes locales de los
otros dos, que es precisamente lo que su punto fijo debe conseguir.

![**Figura 4.19.** El filtro Sobel corriendo en vivo sobre la iCESugar, fotografiado directamente de
la pantalla. Seis escenas distintas —una flor, dos mariposas, una mano y dos letras— recorren la
cadena completa cámara → filtro → pantalla sin intervención de ningún computador. Son capturas del
montaje físico, no reconstrucciones: la propia tarjeta y el cableado del módulo aparecen en el
encuadre.](figuras/fig_5_1_sobel_en_vivo.jpg)

### 4.9.3 Utilización del dispositivo

La tabla recoge el **Device utilisation** que informa `nextpnr-ice40` tras el emplazamiento y ruteado
—`--up5k --package sg48`—, que es la medida autoritativa: la que dice si el diseño entra en el
dispositivo. Las cinco filas de una misma columna proceden de **una sola corrida con una sola versión
de las herramientas**, para que sean comparables entre sí.

| Diseño | LC / 5 280 | BRAM / 30 | SPRAM / 4 | E/S / 39 | *f*máx sistema | *f*máx cámara |
|---|---:|---:|---:|---:|---:|---:|
| Transitivo, motor dedicado **sin procesador** | 2 426 (45 %) | 17 (56 %) | **2 (50 %)** | 18 (46 %) | **28,7 MHz** ✓ | 20,6 MHz ✓ |
| SoC + Sobel | 4 848 (91 %) | 20 (66 %) | 0 | 18 (46 %) | 9,5 MHz ✗ | 20,7 MHz ✓ |
| SoC + Canny de un salto | 5 234 (**99 %**) | 24 (80 %) | 0 | 18 (46 %) | 9,5 MHz ✗ | 17,7 MHz ✓ |
| SoC + transitivo **por software** | 5 251 (**99 %**) | 28 (93 %) | 0 | 18 (46 %) | 8,7 MHz ✗ | 20,5 MHz ✓ |
| SoC + transitivo **como periférico** | no emplaza (≈ 127 %) | — | — | — | — | — |

Table: Utilización de la iCE40UP5K y frecuencias máximas de cada diseño.

> **Procedencia.** Las cuatro primeras filas se midieron de nuevo para este documento. Tres de ellas
> —las filas primera, tercera y cuarta— reprodujeron **exactamente**, celda por celda y bloque por
> bloque, los informes conservados de las corridas originales de julio y agosto de 2026. La del
> SoC + Sobel, cuyo informe de emplazamiento no se había conservado, arrojó 4 848 celdas frente a las
> 4 878 anotadas entonces en el cuaderno; la diferencia, de treinta celdas sobre cinco mil, proviene
> de una versión distinta del sintetizador, que produce doce tablas de consulta menos. La quinta fila
> no dispone de informe: el emplazamiento no llegó a completarse, y el ≈ 127 % es el valor
> documentado en su momento.

De la tabla se desprenden tres lecturas.

**La memoria grande sólo la usa un diseño.** Los cuatro bloques de SPRAM —256 kbit cada uno— están sin
tocar en todas las variantes de flujo, y sólo el transitivo consume dos. Es coherente con su
arquitectura: es el único que necesita el cuadro entero a la vez. Los filtros de flujo se las arreglan
con dos filas de retardo, que caben en los bloques de memoria pequeños.

**El límite de frecuencia lo pone el procesador, y no la ocupación.** Los tres diseños que llevan el
FemtoRV32 se agrupan entre 8,7 y 9,5 MHz mientras que el que no lo lleva alcanza 28,7 MHz: **tres
veces más rápido**. La tentación es atribuirlo a la congestión —los dos más lentos están al 99 %—,
pero la tabla lo desmiente: el SoC del Sobel, **ocho puntos más vacío** que el del Canny, cierra a la
misma frecuencia, y de hecho una centésima por debajo. La causa está en el informe de caminos
críticos, que en los tres SoC señala el mismo origen: **el registro de instrucción del procesador**.
El camino va de un flanco de subida a uno de bajada, de modo que dispone de **medio período** en lugar
de uno entero, y eso divide por dos la frecuencia alcanzable. La síntesis lo confirma por otra vía:
los tres SoC contienen **2 048 biestables sensibles al flanco de bajada** y el diseño sin procesador
no contiene **ninguno**. No es un problema de emplazamiento sino una propiedad del procesador
elegido, y es la razón de fondo de que las tres variantes con CPU necesiten dividir el reloj.

**El sensor nunca fue el límite.** El dominio de la cámara cierra con holgura en las cuatro filas
medidas —entre 17,7 y 20,7 MHz frente a los 12 necesarios—, y es el del sistema el que falla. El
cuello de botella está del lado del procesamiento, no de la adquisición.

> **Y una observación sobre el sustrato.** En los cuatro diseños el retardo del camino crítico está
> dominado por el **ruteado**, que aporta entre el 62 % y el 72 % del total; la lógica aporta el
> resto. En una malla de interconexión fija como la de una FPGA esto es lo esperable, y conviene
> tenerlo presente al leer la §5.3: en el ASIC, donde el trazado se genera para el diseño concreto,
> ese reparto es otro.

### 4.9.4 El hallazgo de co-diseño

El dato más importante de esta sección no es una cifra de utilización sino una **decisión de
arquitectura que la medida forzó**.

La intención inicial era que el procesador calculara la histéresis transitiva por software, como hace
en las versiones de los otros dos filtros. Esa versión existe y funciona en simulación, con un 92,8 %
de concordancia. Pero al intentar sintetizar el conjunto —procesador, memoria, framebuffers y
motor— la ocupación de celdas lógicas alcanzó el **127 %**: no cabía.

La respuesta fue mover el motor de histéresis de software a hardware, como camino de datos en Verilog
sin intervención del procesador. Así implementado, la síntesis reporta **1 728 tablas de consulta** y
el emplazamiento **2 426 celdas lógicas, el 45 % del dispositivo**, cerrando el temporizado a
**28,7 MHz** con holgura.

> Las dos cifras anteriores no son la misma medida, y conviene no confundirlas: la celda lógica de la
> iCE40 empaqueta una tabla de consulta **y** un biestable, de modo que un diseño con muchos
> biestables sueltos ocupa más celdas que tablas tiene. Dividir el recuento de tablas entre las 5 280
> celdas del dispositivo da un 33 % que **subestima la ocupación real en doce puntos**. La cifra
> válida es la del emplazamiento, no la de la síntesis; esta sección usa sólo la primera.

> **Por qué esto es co-diseño y no una optimización.** No se trata de que el hardware sea más rápido
> que el software, que es lo esperable. Se trata de que **la restricción de recursos cambió el reparto
> de responsabilidades entre las dos mitades del sistema**: la misma función, expresada como programa,
> no cabía; expresada como circuito, ocupa un tercio del dispositivo. La frontera entre lo que ejecuta
> el procesador y lo que ejecuta la lógica dedicada no la fijó una preferencia de diseño sino una
> medición.

Este resultado reaparece transformado en la §5.3.2: en el ASIC, donde el área no está acotada por un
dispositivo fijo, el procesador vuelve a ser viable junto al transitivo y cuesta unas nueve mil celdas.
La misma pregunta tiene respuestas opuestas en los dos sustratos.

### 4.9.5 Umbrales de laboratorio y umbrales de cámara

Las tres filas de la tabla anterior muestran umbrales distintos de los que se usan en simulación. El
transitivo, por ejemplo, pasó de 110/70 en el banco de pruebas a **60/30 en la placa**.

El ajuste no es arbitrario ni es un defecto: una imagen almacenada y un flujo de cámara tienen
histogramas distintos, y el punto de operación que extrae la estructura de una no es el que la extrae
de la otra. La §6.4 mide exactamente cuánto importa esa elección, y muestra que **mover el umbral
dentro de un filtro cambia el resultado de clasificación más que cambiar de filtro**.

---

> **Sobre la reproducibilidad de estas cifras.** Las cuatro filas medidas se rehicieron con el guion `medir_utilizacion_vm.sh`, que aplica a cada diseño las mismas
> órdenes de lectura de fuentes que su guion de construcción original. Tres de las cuatro
> reprodujeron el informe conservado sin desviarse en una sola celda ni en un solo bloque de memoria,
> pese a mediar casi dos meses entre una corrida y otra. La cuarta se desvió en treinta celdas sobre
> cinco mil, y la causa está identificada: una versión distinta del sintetizador. **El flujo es
> determinista a herramientas iguales**, que es lo que permite presentar estas cifras como medidas y
> no como estimaciones.

## 4.10 Rendimiento: caudal y latencia

Todas las latencias de esta sección están **medidas en simulación**, no estimadas. La del Canny, que
en una versión anterior de este análisis provenía de una fórmula, resultó estar sobrestimada en un 20 %.

Las secciones anteriores midieron el costo de cada circuito. Ésta mide su velocidad, y lo hace
separando dos magnitudes que la palabra «rápido» confunde: el **caudal**, o cuántos píxeles salen por
segundo, y la **latencia**, o cuánto tarda un píxel concreto desde que entra hasta que sale.

La distinción importa porque las dos arquitecturas de este trabajo se sitúan en extremos opuestos. Un
cauce segmentado puede tener latencia alta y caudal altísimo, porque los resultados salen uno tras
otro una vez lleno; y un motor iterativo puede terminar un cuadro entero de una vez pero tardar
milisegundos en hacerlo.

### 4.10.1 Las dos arquitecturas

| | Flujo (Sobel, Canny de un salto) | Framebuffer (Canny transitivo) |
|---|---|---|
| Ritmo | un píxel por ciclo, una vez lleno el cauce | barre el cuadro **K** veces hasta el punto fijo |
| Latencia | baja — llenar el cauce | alta — todo el cuadro por K barridos |
| Caudal | alto | bajo |

Table: Las dos arquitecturas de procesamiento: flujo y framebuffer.

La razón de la asimetría está en la §4.4: la histéresis transitiva resuelve un **punto fijo** sobre el
cuadro completo, y no puede emitir su primer píxel definitivo hasta haber comprobado que ningún píxel
del cuadro cambia de estado.

### 4.10.2 Las dos latencias, y por qué no son la misma

La palabra «latencia» designa aquí dos magnitudes distintas, y confundirlas produce una discrepancia
de un factor treinta. Conviene separarlas antes de dar ningún número.

**La latencia de cauce** es la profundidad de la cadena de señales de validez: cuántos ciclos median
entre el primer píxel que entra y la primera salida marcada como válida. **La latencia hasta el primer
píxel utilizable** es otra cosa: el generador de ventana 3×3 levanta su señal de validez **sin esperar
a que sus líneas de retardo se hayan llenado**, de modo que las primeras salidas son válidas según la
señal pero se calculan sobre el contenido inicial de los buffers. El primer píxel del que puede uno
fiarse llega mucho después.

Un banco de pruebas mide las dos sobre un flujo continuo. La primera se obtiene contando ciclos entre
el primer `in_valid` y el primer `out_valid`. La segunda **no se estima con ninguna fórmula**: las
memorias de línea arrancan sin inicializar, y se busca el último ciclo cuya salida todavía depende de
ese contenido indefinido.

| Filtro | Etapas 3×3 | Latencia de cauce | Primer píxel utilizable | En tiempo, a su reloj |
|---|---:|---:|---:|---:|
| Sobel | 1 | **4 ciclos** | **125 ciclos** | ≈ 0,96 µs |
| Canny de un salto | 3 | **8 ciclos** | **313 ciclos** | ≈ 2,7 µs |
| SoC + Sobel | 1 | 4 ciclos | 125 ciclos | ≈ 1,05 µs |
| SoC + Canny de un salto | 3 | 8 ciclos | 313 ciclos | ≈ 3,0 µs |

Table: Latencias de cauce de los tres filtros.

Las dos columnas tienen explicación estructural, y no es la misma.

**La de cauce** cuenta dos ciclos por etapa de ventana: el Sobel encadena una y el Canny tres
—suavizado, gradiente y doble umbral—, de donde cuatro y ocho.

**La del primer píxel utilizable** la fija el llenado de las líneas de retardo, que escala con el
ancho de la imagen. Para el Sobel la medida da **exactamente 2·(W+2) = 124 ciclos** más uno, que es lo
que cuesta tener dos filas anteriores completas. Para el Canny **no da el triple**, como una
estimación conservadora sugeriría —6·(W+2) serían 372 ciclos—, sino 313: **las tres etapas se llenan
de forma solapada y no una después de otra**, porque cada una empieza a recibir datos en cuanto la
anterior empieza a producirlos, sin esperar a que termine de llenarse.

> Obsérvese que **la presencia del procesador no altera ninguna de las dos**, contadas en ciclos:
> cuatro siguen siendo cuatro y ciento veinticinco siguen siendo ciento veinticinco. El FemtoRV32
> escribe el umbral en un registro de configuración y no participa del camino de datos de imagen, de
> modo que su única influencia es indirecta —baja la frecuencia máxima alcanzable, y por eso los
> mismos 125 ciclos tardan 1,05 µs en lugar de 0,96.

### 4.10.3 El número de barridos del transitivo, medido

El motor de histéresis transitiva repite barridos hasta que ninguno produce cambios. Ese número, **K**,
no es una constante del diseño sino una propiedad de la imagen, de modo que estimarlo no sirve: hay
que contarlo. Un banco instrumentado cuenta las entradas al estado de barrido y los ciclos totales
hasta la señal de terminado:

| Imagen de clases | K | Ciclos totales | A 81 MHz | A 106 MHz |
|---|---:|---:|---:|---:|
| Sólo bordes fuertes | **1** | 19 772 | 243 µs | 187 µs |
| **Bordes típicos** | **2** | **24 859** | **306 µs** | 235 µs |
| Peor caso: cadena débil de 50 px | **51** | 274 122 | 3,37 ms | 2,59 ms |

Table: Número de barridos del Canny transitivo, medido, y su tiempo.

El hallazgo es que **una imagen de bordes real converge en dos barridos**, no en los ocho que una
estimación conservadora sugeriría. La razón es propia del Canny: los píxeles débiles forman un halo
fino alrededor de los fuertes, de modo que casi todos están a un solo salto de un borde fuerte. El
primer barrido los confirma y el segundo verifica que ya nada cambia.

El peor caso es una **cadena débil larga**, porque la confirmación avanza aproximadamente un salto por
barrido: una cadena de cincuenta píxeles exige cincuenta y un barridos. Conviene documentarlo como lo
que es —una cota superior real— y señalar a la vez que esa configuración casi no aparece en bordes de
escenas reales, donde el ruido débil aislado se descarta y los tramos débiles conectados son cortos.

### 4.10.4 La brecha

Reuniendo las dos medidas anteriores. La columna de latencia es la del **primer píxel utilizable**,
que es la que un sistema real debe esperar:

| Filtro | Reloj máximo | Caudal | Latencia |
|---|---:|---:|---:|
| Sobel | 130 MHz | ≈ 130 Mpx/s | **≈ 0,96 µs** |
| Canny de un salto | 117 MHz | ≈ 117 Mpx/s | ≈ 2,7 µs |
| SoC + Sobel | 119 MHz | ≈ 119 Mpx/s | ≈ 1,05 µs |
| SoC + Canny de un salto | 106 MHz | ≈ 106 Mpx/s | ≈ 3,0 µs |
| Transitivo | 81 MHz | ≈ 16 Mpx/s | **≈ 306 µs/cuadro** |
| SoC + transitivo | 106 MHz | ≈ 20 Mpx/s | ≈ 235 µs/cuadro |

Table: Reloj máximo, caudal y latencia de cada filtro.

**La latencia separa a las dos familias por un factor de entre ochenta y trescientos** —dos órdenes de
magnitud— y el caudal por un factor de seis a ocho. No es una diferencia de eficiencia de
implementación: es la consecuencia directa de que una arquitectura decide con información local y la
otra necesita el cuadro entero.

> Esa brecha, junto con las noventa y cuatro mil quinientas celdas de la §5.3.3, describe el mismo
> fenómeno desde dos ángulos. Ampliar el alcance del patrón de local a global cuesta casi cien mil
> celdas **y** trescientas veces más latencia. El Capítulo 8 discute cuándo ese precio se justifica.
