# 1. Introducción

> **Estado:** borrador 1, escrito el 2026-09-21, con el título **C**:
> *«De FPGA a silicio: reconocimiento de patrones bajo restricciones duras»*.
> Los objetivos de la §1.4 están redactados para cerrar el círculo con las conclusiones de la §7.1;
> si se modifican, deben modificarse ambos.

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

Situado así, el problema se enuncia con precisión: **qué determina si un algoritmo de reconocimiento
cabe en un circuito integrado con restricciones duras, y qué se paga por hacerlo caber**.

La hipótesis de partida —y el trabajo la confirma— es que la respuesta no está donde la intuición
formada en software la busca. No la determina la complejidad aritmética del algoritmo, sino **la
cantidad de estado que exige sostener simultáneamente**. Dicho de otro modo: lo decide la memoria.

## 1.3 Objetivo general

Diseñar, verificar e implementar en silicio un sistema de reconocimiento de patrones sobre video en
vivo —un SoC RISC-V que orquesta tres detectores de bordes y un clasificador de dígitos— llevándolo
desde el modelo de referencia hasta GDSII firmado, y medir sobre esas implementaciones qué factores
determinan la viabilidad de cada algoritmo en un sustrato con restricciones duras.

## 1.4 Objetivos específicos

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

El **Capítulo 4** describe el diseño: la arquitectura del sistema, los tres filtros, el procesador y
su periférico, la gestión de la memoria, y las dos traducciones que el mismo RTL requirió para
existir en FPGA y en ASIC.

El **Capítulo 5** presenta los resultados —verificación funcional, implementación en FPGA, los
circuitos en silicio, el rendimiento medido, el reconocimiento de dígitos y la verificación eléctrica
del camino crítico— y distingue con cuidado qué acredita cada cifra.

El **Capítulo 6** discute lo anterior como tesis defendibles, y es donde reside el aporte: que la
memoria decide qué cabe, y que el front-end y el procesador son alternativas para comprar robustez y
no complementos.

El **Capítulo 7** concluye por objetivo, enumera las contribuciones y dedica un apartado a las seis
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
