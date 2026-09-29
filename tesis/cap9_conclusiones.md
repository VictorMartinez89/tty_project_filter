# 9. Conclusiones y trabajo futuro

## 9.1 Conclusiones por objetivo

**Sobre el modelo de referencia.** Se construyó un modelo en Python de los tres filtros y del
clasificador, y se usó como verdad de referencia en lugar de como ilustración. La decisión de
escribirlo *antes* que el RTL permitió que la verificación fuera una comparación numérica y no una
inspección visual, lo que a su vez hizo detectables errores —un desplazamiento de fila, una
saturación, un signo invertido— que producen salidas de aspecto correcto.

**Sobre la verificación.** Los tres núcleos de filtrado resultaron **idénticos bit a bit** al modelo:
cero píxeles de diferencia sobre 4 800, en las cinco imágenes de prueba. El clasificador se sometió a
una prueba más exigente —las **diez mil** imágenes del conjunto de evaluación de MNIST, comparadas una
por una— y el resultado fue el mismo: **diez mil predicciones y diez mil veredictos de rechazo
idénticos**, con la matriz de confusión coincidiendo casilla por casilla. La prueba se repitió después
con Canny-78, el reconocedor de 97,22 %, y ya no en el simulador sino **en la tarjeta**: las diez mil
imágenes enviadas por el puerto serie y diez mil respuestas iguales a la simulación, dígito y rechazo
incluidos; y otra vez con Canny-98, de 98,45 %, con el mismo resultado. Esa exactitud no es fortuita
sino consecuencia de haber elegido una aritmética que la admite —enteros, pesos que son potencias de
dos, norma L1, umbral por comparación—, y constituye por tanto una conclusión de diseño y no sólo de
verificación.

**Sobre la integración en FPGA.** El sistema completo —cámara, tres filtros seleccionables, procesador
RISC-V y pantalla— funciona **físicamente** sobre una iCE40UP5K. Enfrentado a dígitos manuscritos
sostenidos ante la cámara, el sistema con front-end Canny **reconoció nueve de diez**, coincidiendo
con lo que la simulación predecía. Y en un segundo ensayo con diez dígitos grabados en el propio
*bitstream*, el circuito reprodujo la simulación **incluidos sus dos errores**: los mismos dos
dígitos, con las mismas respuestas equivocadas. Reproducir un acierto puede ser casualidad;
reproducir un error específico y repetido, no. El ensayo definitivo fue el de Canny-78: **diez mil de
diez mil** sobre el conjunto de prueba completo, en la misma iCE40UP5K, al 55 % de sus celdas lógicas.
Frente a la cámara, en cambio, el reconocedor aún depende de que el dígito llegue centrado (§8.11).

**Sobre el paso a silicio.** Se llevaron a GDSII **diecisiete circuitos** en dos procesos —quince en sky130A
con OpenLane y dos en IHP SG13G2 con LibreLane—, todos ellos con **DRC, LVS y XOR en cero**. El
decimoséptimo es el reconocedor Canny-78 de la §7.3, firmado cuando el resto del capítulo ya
estaba medido; por eso el procedimiento de recuento de la §5.2 y el Anexo D hablan de dieciséis. La verificación
eléctrica se cerró por dos vías independientes: los circuitos **cierran el temporizado con los
parásitos del interconexionado extraídos** —holgura de 0,00 ns sobre el peor camino—, y el camino
crítico de **dos** de ellos se simuló además en SPICE hasta repartir su retardo en sumandos sin
residuo (§5.4).
Ninguno ha sido fabricado, y esa distinción se mantiene en todo el documento: **silicio firmado no es
silicio**.

**Sobre la medición de compromisos.** El objetivo que dio origen al trabajo era medir qué cambia al
cruzar de un sustrato al otro, en cuatro dimensiones:

- **Área.** Es la dimensión que articula el Capítulo 8: **cambia el precio de la memoria, y ese
  precio decide qué algoritmo cabe.** Un procesador RISC-V completo cuesta alrededor de nueve mil
  celdas; ampliar el alcance del patrón de una ventana de 3×3 al cuadro completo cuesta noventa y
  cuatro mil quinientas.
- **Frecuencia.** En la FPGA el límite no lo pone la ocupación sino el procesador: las tres variantes
  que lo incorporan se agrupan en torno a los 9 MHz, con independencia de que ocupen el 91 % o el
  99 % del dispositivo, mientras que la que prescinde de él alcanza 28,7 MHz. La causa está medida —un
  camino de medio período que nace en el registro de instrucción— y no se corrige emplazando mejor.
- **Latencia.** Separa a las dos arquitecturas por **dos órdenes de magnitud** —entre ochenta y
  trescientas veces: microsegundos el flujo, centenas de microsegundos por cuadro el transitivo—, y no por eficiencia de
  implementación sino porque una decide con información local y la otra necesita el cuadro entero. El
  procesador no la altera: contada en ciclos es la misma con él y sin él, porque escribe un registro
  de configuración y no participa del camino de datos de imagen.
- **Manufacturabilidad.** Los diseños con memoria de cuadro grande acumulan violaciones de antena muy
  por encima del resto, porque sus redes de direccionamiento son largas y ramificadas.

> Las tres primeras no son independientes: **área, frecuencia y manufacturabilidad son tres
> manifestaciones del mismo hecho.** Quien optimice sólo el área concluirá que la memoria de cuadro
> es aceptable, porque habrá visto un tercio del problema.

## 9.2 Contribuciones

1. **Un sistema de visión embebido completo y verificado**, con tres detectores de bordes
   seleccionables por software sobre video en vivo, funcionando físicamente en una FPGA de bolsillo y
   llevado a silicio firmado.

2. **Un motor de histéresis transitiva en hardware**, que resuelve la reconstrucción morfológica como
   punto fijo sin intervención del procesador, junto con el hallazgo de co-diseño que lo motivó: la
   misma función, expresada como programa, apenas cabía y dejaba el sistema en 8,7 MHz; como circuito
   junto al procesador no cabía; como circuito sin él ocupa el 45 % del dispositivo y corre a 28,7 MHz.

3. **Una comparación sistemática de dos front-ends sobre silicio firmado**, a igualdad de todo lo
   demás, a lo largo de seis sistemas de complejidad creciente. De ella se desprende el resultado de
   ingeniería que el trabajo propone: **el front-end y el procesador son alternativas para comprar
   robustez, no complementos**, y comprarla en el front-end resulta unas seis veces más barato.

4. **Un clasificador de patrones que cabe donde no cabe una red**: 400 pesos de cuatro bits
   —doscientos bytes— alcanzan sobre MNIST la misma exactitud que los 784 píxeles crudos con la
   vigésima parte de la memoria, y el circuito reproduce ese resultado sin discrepancia. Su versión
   ampliada, **Canny-78** —dieciséis zonas y 78 rasgos elegidos—, llega al **97,22 %** en la misma
   iCE40UP5K, lo reproduce en la tarjeta sobre las diez mil imágenes de prueba y firma en sky130 en
   0,829 mm². **Canny-98**, con una capa oculta de 120 neuronas sobre los mismos rasgos, llega al **98,45 %** y
   lo reproduce en la tarjeta sobre las diez mil imágenes con menos lógica que Canny-78. La versión de cuarenta
   rasgos para Tiny Tapeout, de 94,20 %, cabe en 8×2 mosaicos con el
   42 % de utilización.

5. **Dos cuadernos reproducibles** que contienen el código, los datos y las figuras de cada
   afirmación del documento, incluidas las que fueron corregidas.

## 9.3 Seis afirmaciones propias que este trabajo corrigió

Se listan porque forman parte del resultado. Un documento que enumera sus propios errores con fecha y
evidencia es más difícil de atacar que uno que no enumera ninguno; y un jurado que encuentra un error
por su cuenta es mucho peor que uno que lo ve ya corregido.

| # | Lo que se afirmó | Lo que la medida mostró |
|---|---|---|
| 1 | Una señal de sincronismo ausente en el sensor | Era un desplazamiento de uno en el conteo de línea |
| 2 | Un umbral óptimo hallado sobre 20 000 imágenes | No se transfiere al conjunto completo de 60 000 |
| 3 | Una exactitud del **97,3 %** | Provenía de un defecto del banco de medida |
| 4 | Una dispersión estimada con cinco semillas | **Subestimada en un factor de 1,8** por solapamiento de las submuestras |
| 5 | El Canny supera al Sobel bajo condiciones degradadas | Comparaba **dos puntos de operación**, no dos filtros; con el umbral implementado el resultado se invierte |
| 6 | La discrepancia entre SPICE y el analizador estático es la **resistencia** de la interconexión | La resistencia aporta **0,017 ns**, el 0,1 %. La causa son los parásitos internos de la celda (§5.4.3) |

Table: Seis afirmaciones propias que la medida corrigió.

Las seis comparten una forma, y conviene enunciarla porque es la lección metodológica del trabajo:
**ninguna procedía de una medición equivocada.** Las mediciones eran correctas en todos los casos. Lo
que falló fue la lectura: comparar en puntos de operación distintos, estimar la variabilidad con un
procedimiento sesgado, confiar en un instrumento sin verificarlo, y —en la sexta— **tomar por
conclusión lo que era una hipótesis obtenida por eliminación**.

> Una deducción por eliminación vale lo que valga la lista de alternativas consideradas. En el caso
> de la sexta, aquella lista no incluía «el modelo de celda del PDK es esquemático y no de layout»,
> que era la respuesta. La regla que se deja escrita: **las deducciones se escriben como hipótesis
> hasta que exista una medida que las sostenga.**

## 9.4 Trabajo futuro

**Fabricar.** Los circuitos están firmados pero no existen. La vía practicable es un servicio de
oblea compartida como Tiny Tapeout, que reparte el costo entre cientos de diseños pequeños a cambio
de caber en mosaicos de dimensiones fijas. Los proyectos necesarios están preparados y han superado
los chequeos de admisión; lo que falta es enviarlos a una ventana de fabricación. El primero en la
fila es el reconocedor de 94,20 % para la lanzadera SKY26d, con DRC, LVS y antenas en cero.

**Normalizar el dígito en silicio.** Canny-78 reproduce el modelo sobre MNIST pero no frente a la
cámara, y la causa está medida: el encuadre. Un normalizador que recorte y centre el dígito, como se
hizo al construir MNIST, devuelve al 97 % la exactitud que un corrimiento de tres píxeles había bajado al
63 %. Llevarlo al circuito —delante de la ventana de 28×28— es el paso que separa un reconocedor
verificado de uno utilizable.

**Canny-98: usar lo que Canny-78 deja quieto.** Canny-78 es lineal y ocupa la mitad de la iCE40UP5K sin tocar dos de sus
recursos más valiosos: los ocho DSP de 16×16 con acumulador y el megabit de SPRAM. Se midió en Python, sobre las diez
mil imágenes de prueba, cuánto reconocería la misma tarjeta si el clasificador lineal se sustituye por una red de una
capa oculta con pesos de 8 bits —lo que multiplica un DSP—:

| entrada | capa oculta | pesos | SPRAM | ciclos con 8 DSP | exactitud |
|---|---:|---:|---:|---:|---:|
| Canny-78, 78 rasgos (el circuito actual) | — | 780 de 4 bits | — | 647 | 97,22 % |
| 168 rasgos de la pirámide | 32 | 5 696 | 4,3 % | 712 | 98,28 % |
| 168 rasgos de la pirámide | 64 | 11 392 | 8,7 % | 1 424 | 98,43 % |
| 168 rasgos de la pirámide | 128 | 22 784 | 17,4 % | 2 848 | **98,75 %** |
| 784 píxeles crudos | 128 | 101 632 | 77,5 % | 12 704 | 97,75 % |

Table: Exactitud medida en Python de una capa oculta con pesos de 8 bits sobre el presupuesto de la iCE40UP5K.

Tres lecturas. La red más pequeña cabe en el **mismo presupuesto de tiempo** que Canny-78 —712 ciclos frente a los 784
de un cuadro— y ya gana un punto. La de 128 neuronas llega al **98,75 %** con los pesos, las activaciones y la entrada
en 8 bits, usa la sexta parte de la SPRAM y clasificaría más de cuatro mil imágenes por segundo a 12 MHz; con 256
neuronas ya no sube (98,65 %), de modo que el techo lo pone el descriptor y no el clasificador. Y **la misma red sobre
los píxeles crudos reconoce menos (97,75 %) con cuatro veces y media más pesos**: el front-end de bordes sigue pagándose
a sí mismo aunque el clasificador ya no sea lineal, que es la tesis del Capítulo 8 vista desde el otro lado. Son cotas
medidas sobre el modelo y no un circuito; llevarlas al silicio exige repetir la verificación de diez mil imágenes que
este trabajo hizo con Canny-78.

El ancho de los pesos decide cuánta memoria pide esa red, y se midió también, con las activaciones en 8 bits:

| pesos | 32 neuronas | 128 neuronas | memoria de la de 128 |
|---|---:|---:|---:|
| 8 bits | 98,26 % | 98,74 % | 178 kbit |
| 4 bits | 97,58 % | 98,09 % | 89 kbit |
| 2 bits (−1, 0, +1) | 93,29 % | 94,07 % | 44 kbit |
| 1 bit (sólo el signo) | 78,89 % | 74,13 % | 22 kbit |

Table: Exactitud de la capa oculta según el ancho de los pesos, cuantizados después de entrenar.

Con **4 bits** —los mismos de Canny-78— la red sigue por encima del 98 % con la mitad de memoria. Ese camino
ya se recorrió una vez: **Canny-98** (§6.3.6) —el mismo front-end, los 168 rasgos y una capa oculta de 120 neuronas con
pesos de 4 bits, en aritmética entera exacta— llega al **98,45 %** y reproduce el modelo en la tarjeta sobre las diez
mil imágenes de prueba, con el 45 % de las celdas lógicas y todos los bloques de BRAM. Lo que queda por delante es la
versión de 8 bits, la regla de rechazo calibrada y su paso a silicio. Por debajo, la caída
es en buena parte del método: los pesos se cuantizaron **después** de entrenar, y a 2 y 1 bit la práctica habitual es
entrenar ya cuantizado, que no se ensayó aquí.

**Sustituir los framebuffers de biestables por un macro de SRAM.** Es la respuesta directa al
hallazgo central. Todo el precio documentado en el Capítulo 8 —área, frecuencia y
manufacturabilidad— procede de implementar memoria con lógica porque el flujo empleado no ofrecía
otra cosa. Un generador de memoria cambiaría los tres a la vez, y permitiría cuantificar cuánto de lo
medido es propiedad del problema y cuánto del sustrato.

**Subir de resolución.** Las resoluciones empleadas —60×80 y 160×120 para procesar, 28×28 para
reconocer— son exactamente lo que la memoria disponible permite. Con almacenamiento adecuado, la
pregunta de si las conclusiones escalan es empírica y está abierta.

**Completar la matriz de reconocedores.** Los circuitos que reconocen cubren dos de los tres
front-ends del trabajo. Falta el transitivo, cuya incorporación exige un extractor de características
nuevo y un reentrenamiento de los pesos. Su ausencia es además coherente con el argumento: el
transitivo es precisamente el que no cabe.

**Cerrar la verificación eléctrica.** La extracción del layout de las celdas estándar recupera la
mayor parte de la discrepancia entre SPICE y el analizador estático, pero no toda. La fracción
restante se atribuye a la resistencia interna de la celda sin haberlo comprobado, y comprobarlo exige
repetir la extracción con resistencias.
