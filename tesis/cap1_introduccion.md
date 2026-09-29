# 1. Introducción

## 1.1 Contexto

Un sistema que mira y decide —una cámara, un algoritmo, una respuesta— es hoy trivial de construir si
se dispone de un computador. El problema cambia por completo cuando el presupuesto es un circuito
integrado de unos pocos milímetros cuadrados, sin sistema operativo, sin memoria externa y sin la
posibilidad de pedir más recursos.

En ese régimen, las preguntas útiles dejan de ser algorítmicas. Ya no se trata de qué método reconoce
mejor, sino de **qué método cabe**, y de qué se pierde al hacerlo caber. Es un problema de
arquitectura y de co-diseño, no de precisión estadística.

Hay un precedente que conviene tener presente porque describe exactamente esta disciplina. Gunpei
Yokoi, diseñador de la Game Boy, formuló su método como *pensamiento lateral con tecnología marchita*:
en lugar de perseguir el componente más avanzado, tomar uno maduro y barato y exprimir su
organización. La consola resultante tenía una pantalla peor que sus competidoras y las sobrevivió a
todas, porque su diseño estaba organizado alrededor de la restricción en vez de contra ella —los
gráficos por mosaicos que reutilizan una tabla pequeña son precisamente eso.

Ese es el espíritu del presente trabajo. La restricción no es el obstáculo: es el objeto de estudio.

## 1.2 El problema

La pregunta de investigación de este trabajo tiene una formulación anterior al trabajo mismo. Una
propuesta del autor, fechada en 2017, preguntaba:

> *«¿Será posible abordar la detección y clasificación de objetos sobre imágenes sin la necesidad de
> estos procesadores?»*

Su primer experimento fracasó, y su sección de trabajo futuro identificó la causa probable y la
corrección: mejorar el preprocesamiento binarizando las imágenes con un filtro de Canny o de Sobel
para mejorar la silueta del objeto. **Esta tesis es ese trabajo futuro**, construido y medido de la
FPGA al silicio.

La pregunta se retomó formalmente en la **propuesta de trabajo final**, *Diseño de un microcontrolador
con arquitectura RISC-V*, presentada con el aval del director
[Martínez Solarte 2025]. Ocho años después, la formulación había cambiado de signo: ya no se preguntaba
si era posible prescindir de los procesadores, sino si era posible hacerlo **con** ellos —con
procesadores pequeños, abiertos y propios—:

> *«¿Será posible abordar la detección y clasificación de IA con estos procesadores?»*

y la propuesta concretaba el problema así:

> *«¿Cómo puede el diseño de un System-on-Chip (SoC) basado en RISC-V, desarrollado con herramientas
> de código abierto y adaptado a las necesidades tecnológicas de Colombia, superar las barreras de
> costo, eficiencia y personalización que imponen los microcontroladores propietarios, permitiendo la
> implementación de aplicaciones de inteligencia artificial como la detección y la clasificación?»*

La misma propuesta fijaba ya la aplicación: un sistema embebido basado en RISC-V para **reconocer los
dígitos del cero al nueve del conjunto MNIST**, que es el que recorre el Capítulo 6.

Situado así, el problema se enuncia con precisión: **qué determina si un algoritmo de reconocimiento
cabe en un circuito integrado con restricciones duras, y qué se paga por hacerlo caber**.

La hipótesis de partida —y el trabajo la confirma— es que la respuesta no está donde la intuición
formada en software la busca. No la determina la complejidad aritmética del algoritmo, sino **la
cantidad de estado que exige sostener simultáneamente**. Dicho de otro modo: lo decide la memoria.

### Por qué importa: la justificación

La propuesta justificaba el trabajo en un argumento de soberanía tecnológica, que se reproduce aquí
porque sigue siendo el marco en que el resultado tiene sentido.

Colombia, como muchos países en desarrollo, depende de tecnologías importadas y de microcontroladores
propietarios, cuyas licencias aumentan los costos y limitan la innovación local; eso frena el
desarrollo de soluciones de hardware adaptadas a necesidades regionales, como la agricultura de
precisión o el monitoreo ambiental. La brecha no es sólo de hardware: según la Estrategia Nacional
Digital 2023-2026, el 49,3 % de los hogares aún carece de conexión fija a Internet, con un 6 % en las
zonas rurales dispersas frente a un 68 % en los centros urbanos [Estrategia Nacional Digital 2023]. Esa dualidad pide
soluciones locales que combinen accesibilidad, bajo costo y adaptación al contexto.

Un SoC RISC-V es una oportunidad en esa dirección. Al ser una arquitectura libre de licencias, elimina
el pago de regalías y favorece el diseño local, y las universidades colombianas pueden integrarlo en
sus currículos para formar ingenieros en sistemas embebidos, microelectrónica y **herramientas de
diseño electrónico de código abierto** —Yosys, OpenROAD—, que permiten a estudiantes y a empresas
pequeñas prototipar chips sin costos elevados. Este trabajo se hizo **íntegramente** con ese tipo de
herramientas, sobre una placa de menos de cincuenta dólares y un kit de diseño de proceso público; ese
hecho es parte de lo que demuestra.

\needspace{16\baselineskip}

## 1.3 Objetivo general

El objetivo general aprobado en la propuesta es:

> *«Diseñar e implementar un microcontrolador SoC basado en el conjunto de instrucciones RISC-V, capaz
> de ejecutar algoritmos de inteligencia artificial (IA), y validar su funcionamiento mediante
> herramientas EDA (Electronic Design Automation) como Yosys o Synopsys.»*

Este trabajo lo precisó, sin cambiar su alcance, en los siguientes términos:

Diseñar, verificar e implementar en silicio un sistema de reconocimiento de patrones sobre video en
vivo —un SoC RISC-V que orquesta tres detectores de bordes y un clasificador de dígitos— llevándolo
desde el modelo de referencia hasta GDSII firmado, y medir sobre esas implementaciones qué factores
determinan la viabilidad de cada algoritmo en un sustrato con restricciones duras.

## 1.4 Objetivos específicos

Los objetivos específicos aprobados en la propuesta son tres:

> 1. *Definir una arquitectura mínima del microcontrolador basado en el RISC-V.*
> 2. *Definir el algoritmo de inteligencia artificial que se implementará.*
> 3. *Realizar el flujo de diseño ASIC con herramientas EDA para el procesador y el algoritmo.*

Para cumplirlos con un criterio verificable, se desglosaron en cinco objetivos operativos, que son los
que la §9.1 cierra uno por uno:

1. **Construir un modelo de referencia** en software de los tres detectores de bordes y del
   clasificador, con precisión suficiente para servir de criterio de verificación y no de mera
   ilustración.

2. **Implementar y verificar el RTL** de cada bloque mediante comparación bit a bit contra ese
   modelo, estableciendo un criterio de aceptación numérico y no visual.

3. **Integrar el sistema completo sobre FPGA** —cámara, filtros seleccionables, procesador y
   pantalla— y validarlo físicamente sobre hardware real con una escena en vivo.

4. **Llevar los diseños a ASIC** mediante un flujo abierto, obteniendo GDSII con verificación
   geométrica y eléctrica limpia en al menos un proceso.

5. **Medir los compromisos** que el cambio de sustrato impone —área, frecuencia, latencia y
   manufacturabilidad— con condiciones de comparación controladas, de modo que cada diferencia
   observada pueda atribuirse a una causa.

La correspondencia entre unos y otros es la siguiente:

| Objetivo aprobado | Objetivos operativos | Dónde se cumple |
|------------------------------------------------------------|--------------------|------------------------------------------------------------|
| 1. Arquitectura mínima del microcontrolador RISC-V | 3 | §4.5: FemtoRV32 (RV32I) con su periférico de filtros, UART, pantalla por SPI y cámara por SCCB |
| 2. El algoritmo de inteligencia artificial | 1, 2 | Caps. 2 y 3, §4.8 y el Capítulo 6: los detectores de bordes y el clasificador de dígitos, verificados contra el modelo |
| 3. Flujo ASIC con herramientas EDA, para el procesador y el algoritmo | 4, 5 | §5.2, §5.3, §7.1 y §5.4: los circuitos con GDSII firmado, el procesador entre ellos, y la adaptación a Tiny Tapeout |

Table: Correspondencia entre los objetivos aprobados en la propuesta y los objetivos operativos de este trabajo.

Dos precisiones sobre la propuesta. Nombraba el LatticeMico32 (LM32) como referencia de procesador; el
núcleo adoptado fue FemtoRV32, del conjunto RV32I, por las razones de la §4.5. Y admitía como
herramienta Yosys **o** Synopsys; se usó sólo el flujo abierto —Yosys, OpenLane, Magic, KLayout—,
coherente con la justificación de la propia propuesta.

## 1.5 Alcance y límites

Conviene delimitar el trabajo con la misma precisión con la que se enuncia, y hacerlo aquí y no al
final:

- **Ningún circuito ha sido fabricado.** Todas las afirmaciones sobre silicio se refieren a GDSII
  firmado con verificación geométrica y de equivalencia en cero. La validación sobre hardware físico
  se realizó sobre FPGA.
- **Las resoluciones son pequeñas**: 60×80 y 160×120 píxeles para el procesamiento de imagen, y 28×28
  para el reconocimiento. No son una elección arbitraria sino el límite que impone la memoria
  disponible, y ese límite es parte de lo que el trabajo estudia.
- **El reconocimiento se restringe a dígitos manuscritos**, sobre un conjunto de referencia estándar,
  con un clasificador lineal sobre descriptores de orientación. No se abordan redes profundas, cuyo
  presupuesto de memoria excede en un orden de magnitud el de este sustrato — y esa imposibilidad es
  ella misma uno de los resultados.
- **Los algoritmos no son nuevos.** Datan de 1968, 1986 y 1993. La contribución no está en proponer
  un detector mejor sino en medir sistemáticamente qué cuesta cada uno cuando se lo lleva a silicio a
  igualdad de todo lo demás.

## 1.6 Estructura del documento

El **Capítulo 2** establece el marco conceptual, y sostiene la afirmación que organiza el resto: que
los tres detectores y el clasificador son casos de una misma operación —correlar, acumular, decidir—
que se diferencian en de dónde sale la plantilla, y que en silicio se separan por su huella de
memoria.

El **Capítulo 3** describe la metodología, e incluye dos apartados que no son método estándar sino
método aprendido de errores propios: la disciplina de medición y la verificación del instrumento
antes del dato.

El **Capítulo 4** presenta los filtros y el procesador desde el modelo hasta la tarjeta: la arquitectura,
cada filtro con su modelo en Python, su simulación en Verilog y su foto en la FPGA, el SoC y su
periférico, la gestión de la memoria, la verificación contra el modelo y el rendimiento medido.

El **Capítulo 5** lleva esos mismos circuitos a silicio con OpenLane, Magic y NGSpice: los cambios que el
RTL necesita para pasar a un ASIC, los bloques y la cadena completa firmados en sky130, y la
verificación eléctrica del camino crítico.

El **Capítulo 6** presenta el reconocimiento de dígitos: el descriptor de orientaciones por zonas —una
pirámide espacial—, el clasificador y su exactitud sobre MNIST; los seis circuitos que lo llevan —con
procesador o sin él, con pantalla o sin ella, Canny-78 y Canny-98—; su verificación contra el modelo y su
validación en la tarjeta frente a una cámara.

El **Capítulo 7** lleva el reconocedor a silicio: con cada front-end, en Tiny Tapeout y en su versión
más completa, Canny-78.

El **Capítulo 8** discute lo anterior como tesis defendibles, y es donde reside el aporte: que la
memoria decide qué cabe, y que el front-end y el procesador son alternativas para comprar robustez y
no complementos.

El **Capítulo 9** concluye por objetivo, enumera las contribuciones y dedica un apartado a las seis
afirmaciones propias que el trabajo tuvo que corregir durante su desarrollo — porque forman parte del
resultado y no de sus defectos.

---

> **Una nota sobre el tono de este documento.** A lo largo del trabajo hubo afirmaciones que
> resultaron falsas y se retractaron, mediciones que hubo que repetir porque el instrumento estaba
> roto, y conclusiones alcanzadas por eliminación que una medida posterior desmintió. Todo eso está
> escrito, con fecha y con la evidencia que lo corrigió.
>
> No se incluye por escrúpulo sino porque es información: un lector que sepa qué caminos resultaron
> falsos puede confiar más en los que no lo resultaron. Y porque la disciplina que produjo esas
> correcciones —medir antes de afirmar, verificar el instrumento antes de leer el dato, escribir las
> deducciones como hipótesis— es, a juicio del autor, lo más transferible que este trabajo tiene que
> ofrecer.
