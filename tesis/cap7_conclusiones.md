# 7. Conclusiones y trabajo futuro

> **Estado:** borrador 1, escrito el 2026-09-21.
> ⚠️ La §7.1 debe cerrarse contra la redacción definitiva de los objetivos específicos de la §1.4,
> que a su vez depende de la decisión de título aún pendiente.

## 7.1 Conclusiones por objetivo

**Sobre el modelo de referencia.** Se construyó un modelo en Python de los tres filtros y del
clasificador, y se usó como verdad de referencia en lugar de como ilustración. La decisión de
escribirlo *antes* que el RTL permitió que la verificación fuera una comparación numérica y no una
inspección visual, lo que a su vez hizo detectables errores —un desplazamiento de fila, una
saturación, un signo invertido— que producen salidas de aspecto correcto.

**Sobre la verificación.** Los tres núcleos de filtrado resultaron **idénticos bit a bit** al modelo:
cero píxeles de diferencia sobre 4 800, en las cinco imágenes de prueba. El clasificador se sometió a
una prueba más exigente —las **diez mil** imágenes del conjunto de evaluación de MNIST, comparadas una
por una— y el resultado fue el mismo: **diez mil predicciones y diez mil veredictos de rechazo
idénticos**, con la matriz de confusión coincidiendo casilla por casilla. Esa exactitud no es fortuita
sino consecuencia de haber elegido una aritmética que la admite —enteros, pesos que son potencias de
dos, norma L1, umbral por comparación—, y constituye por tanto una conclusión de diseño y no sólo de
verificación.

**Sobre la integración en FPGA.** El sistema completo —cámara, tres filtros seleccionables, procesador
RISC-V y pantalla— funciona **físicamente** sobre una iCE40UP5K. Enfrentado a dígitos manuscritos
sostenidos ante la cámara, el sistema con front-end Canny **reconoció nueve de diez**, coincidiendo
con lo que la simulación predecía. Y en un segundo ensayo con diez dígitos grabados en el propio
*bitstream*, el circuito reprodujo la simulación **incluidos sus dos errores**: los mismos dos
dígitos, con las mismas respuestas equivocadas. Reproducir un acierto puede ser casualidad;
reproducir un error específico y repetido, no.

**Sobre el paso a silicio.** Se llevaron a GDSII **dieciséis circuitos** en dos procesos —sky130A con
OpenLane e IHP SG13G2 con LibreLane—, todos ellos con **DRC, LVS y XOR en cero**. La verificación
eléctrica se cerró por dos vías independientes: los circuitos **cierran el temporizado con los
parásitos del interconexionado extraídos** —holgura de 0,00 ns sobre el peor camino—, y el camino
crítico de uno de ellos se simuló además en SPICE hasta explicar su retardo componente a componente.
Ninguno ha sido fabricado, y esa distinción se mantiene en todo el documento: **silicio firmado no es
silicio**.

**Sobre la medición de compromisos.** El objetivo que dio origen al trabajo era medir qué cambia al
cruzar de un sustrato al otro, en cuatro dimensiones:

- **Área.** Es la dimensión que articula el Capítulo 6: **cambia el precio de la memoria, y ese
  precio decide qué algoritmo cabe.** Un procesador RISC-V completo cuesta alrededor de nueve mil
  celdas; ampliar el alcance del patrón de una ventana de 3×3 al cuadro completo cuesta noventa y
  cuatro mil quinientas.
- **Frecuencia.** En la FPGA el límite no lo pone la ocupación sino el procesador: las tres variantes
  que lo incorporan se agrupan en torno a los 9 MHz, con independencia de que ocupen el 91 % o el
  99 % del dispositivo, mientras que la que prescinde de él alcanza 28,7 MHz. La causa está medida —un
  camino de medio período que nace en el registro de instrucción— y no se corrige emplazando mejor.
- **Latencia.** Separa a las dos arquitecturas por un factor cercano a **trescientos** —microsegundos
  el flujo, centenas de microsegundos por cuadro el transitivo—, y no por eficiencia de
  implementación sino porque una decide con información local y la otra necesita el cuadro entero. El
  procesador no la altera: contada en ciclos es la misma con él y sin él, porque escribe un registro
  de configuración y no participa del camino de datos de imagen.
- **Manufacturabilidad.** Los diseños con memoria de cuadro grande acumulan violaciones de antena muy
  por encima del resto, porque sus redes de direccionamiento son largas y ramificadas.

> Las tres primeras no son independientes: **área, frecuencia y manufacturabilidad son tres
> manifestaciones del mismo hecho.** Quien optimice sólo el área concluirá que la memoria de cuadro
> es aceptable, porque habrá visto un tercio del problema.

## 7.2 Contribuciones

1. **Un sistema de visión embebido completo y verificado**, con tres detectores de bordes
   seleccionables por software sobre video en vivo, funcionando físicamente en una FPGA de bolsillo y
   llevado a silicio firmado.

2. **Un motor de histéresis transitiva en hardware**, que resuelve la reconstrucción morfológica como
   punto fijo sin intervención del procesador, junto con el hallazgo de co-diseño que lo motivó: la
   misma función no cabía expresada como programa y ocupa un tercio del dispositivo expresada como
   circuito.

3. **Una comparación sistemática de dos front-ends sobre silicio firmado**, a igualdad de todo lo
   demás, a lo largo de seis sistemas de complejidad creciente. De ella se desprende el resultado de
   ingeniería que el trabajo propone: **el front-end y el procesador son alternativas para comprar
   robustez, no complementos**, y comprarla en el front-end resulta unas ocho veces más barato.

4. **Un clasificador de patrones que cabe donde no cabe una red**: 400 pesos de cuatro bits
   —doscientos bytes— alcanzan sobre MNIST la misma exactitud que los 784 píxeles crudos con la
   vigésima parte de la memoria, y el circuito reproduce ese resultado sin discrepancia.

5. **Dos cuadernos reproducibles** que contienen el código, los datos y las figuras de cada
   afirmación del documento, incluidas las que fueron corregidas.

## 7.3 Seis afirmaciones propias que este trabajo corrigió

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
| 6 | La discrepancia entre SPICE y el analizador estático es la **resistencia** de la interconexión | La resistencia aporta **0,017 ns**, el 0,1 %. La causa son los parásitos internos de la celda |

Las seis comparten una forma, y conviene enunciarla porque es la lección metodológica del trabajo:
**ninguna procedía de una medición equivocada.** Las mediciones eran correctas en todos los casos. Lo
que falló fue la lectura: comparar en puntos de operación distintos, estimar la variabilidad con un
procedimiento sesgado, confiar en un instrumento sin verificarlo, y —en la sexta— **tomar por
conclusión lo que era una hipótesis obtenida por eliminación**.

> Una deducción por eliminación vale lo que valga la lista de alternativas consideradas. En el caso
> de la sexta, aquella lista no incluía «el modelo de celda del PDK es esquemático y no de layout»,
> que era la respuesta. La regla que se deja escrita: **las deducciones se escriben como hipótesis
> hasta que exista una medida que las sostenga.**

## 7.4 Trabajo futuro

**Fabricar.** Los circuitos están firmados pero no existen. La vía practicable es un servicio de
oblea compartida como Tiny Tapeout, que reparte el costo entre cientos de diseños pequeños a cambio
de caber en mosaicos de dimensiones fijas. Los proyectos necesarios están preparados y han superado
los chequeos de admisión; lo que falta es enviarlos a una ventana de fabricación.

**Sustituir los framebuffers de biestables por un macro de SRAM.** Es la respuesta directa al
hallazgo central. Todo el precio documentado en el Capítulo 6 —área, frecuencia y
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
