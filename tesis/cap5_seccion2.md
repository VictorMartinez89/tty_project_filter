# 5.2 Resultados en FPGA

> **Estado:** borrador 2, 2026-09-21. Fuente: cuaderno 1, Partes 25-28 y 68-82, y los informes de
> `nextpnr-ice40` conservados de las corridas del 30 de julio y del 3 de agosto de 2026.

Los resultados de esta sección son de una clase distinta a los del resto del capítulo: no provienen
de un informe de herramienta sino de **un circuito que funciona sobre una mesa**, con una cámara
apuntando a un objeto y una pantalla mostrando el resultado. Es la única parte del trabajo donde el
sistema completo existe físicamente, y por eso condiciona lo que puede afirmarse de las demás.

## 5.2.1 La plataforma

La implementación física se realizó sobre una **iCE40UP5K** en tarjeta iCESugar v1.5, con una cámara
**OV7670** y una pantalla **TFT ILI9341** por SPI. El flujo de síntesis e implementación es enteramente
abierto: `yosys` para síntesis, `nextpnr-ice40` para emplazamiento y ruteo, `icepack` para el
*bitstream*.

La elección del dispositivo no es incidental. La iCE40UP5K ofrece 5 280 celdas lógicas, 30 bloques de
memoria de 4 kbit y **cuatro bloques de SPRAM de 256 kbit** — y son estos últimos los que hacen
posible el filtro transitivo, porque permiten alojar el cuadro completo sin consumir lógica. Esa
disponibilidad es exactamente lo que desaparece al pasar a un ASIC sin macro de memoria, y es el
origen del resultado de la §5.4.3.

## 5.2.2 Los tres filtros, funcionando

| Filtro | Arquitectura | Implementación física | Umbrales en la placa |
|---|---|---|---|
| Sobel | flujo | hardware, con procesador FemtoRV32 | 90 |
| Canny de un salto | flujo | hardware, con procesador FemtoRV32 | 50 / 20 |
| Canny transitivo | **framebuffer** | hardware, motor en Verilog **sin procesador** | 60 / 30 |

Los tres funcionan sobre la placa con cámara y pantalla en vivo. El transitivo produce contornos
**conectados y completos** —una letra cerrada aparece cerrada— frente a los bordes locales de los
otros dos, que es precisamente lo que su punto fijo debe conseguir.

## 5.2.3 Utilización del dispositivo

La tabla recoge el **Device utilisation** que informa `nextpnr-ice40` tras el emplazamiento y ruteado
—`--up5k --package sg48`, reloj objetivo 12 MHz—, que es la medida autoritativa: la que dice si el
diseño entra en el dispositivo. Se acompaña de la frecuencia máxima de los dos dominios de reloj, el
del sistema y el que impone el sensor.

| Diseño | LC / 5 280 | BRAM / 30 | SPRAM / 4 | E/S / 39 | *f*máx sistema | *f*máx cámara |
|---|---:|---:|---:|---:|---:|---:|
| Transitivo, motor dedicado **sin procesador** | 2 426 (45 %) | 17 (56 %) | **2 (50 %)** | 18 (46 %) | **28,9 MHz** ✓ | 19,3 MHz ✓ |
| SoC + Sobel | 4 878 (92 %) | 20 (67 %) | 0 | — | — | — |
| SoC + Canny de un salto | 5 234 (**99 %**) | 24 (80 %) | 0 | 18 (46 %) | 9,0 MHz ✗ | 18,1 MHz ✓ |
| SoC + transitivo **por software** | 5 251 (**99 %**) | 28 (93 %) | 0 | 18 (46 %) | 9,1 MHz ✗ | 21,3 MHz ✓ |
| SoC + transitivo **como periférico** | no emplaza (≈ 127 %) | — | — | — | — | — |

> **Procedencia.** Las filas primera, tercera y cuarta proceden de informes de `nextpnr` conservados
> y verificables. La segunda procede del informe capturado en la Parte 61 del cuaderno; su diseño se
> volvió a sintetizar para este documento y reprodujo exactamente los 1 722 biestables y los 20
> bloques de memoria allí registrados, pero **el informe de emplazamiento no se conservó** y la cifra
> de celdas no pudo recomprobarse. La quinta no dispone de informe: el emplazamiento no llegó a
> completarse, y el ≈ 127 % es el valor documentado en su momento.

De la tabla se desprenden tres lecturas.

**La memoria grande sólo la usa un diseño.** Los cuatro bloques de SPRAM —256 kbit cada uno— están sin
tocar en todas las variantes de flujo, y sólo el transitivo consume dos. Es coherente con su
arquitectura: es el único que necesita el cuadro entero a la vez. Los filtros de flujo se las arreglan
con dos filas de retardo, que caben en los bloques de memoria pequeños.

**La ocupación y el temporizado no son independientes.** Los dos diseños que no cierran a 12 MHz son
exactamente los dos que están al 99 %, y el que cierra a 28,9 MHz —tres veces más rápido— es el que
ocupa el 45 %. No es casualidad: con el dispositivo casi lleno el emplazador pierde libertad para
acercar las celdas de un mismo camino, y el retardo de ruteado domina. **El espacio libre no sólo
permite crecer: permite ir rápido.**

**El sensor nunca fue el límite.** En las tres filas donde se midió, el dominio de la cámara cierra
con holgura —entre 18 y 21 MHz frente a los 12 necesarios— mientras que el del sistema es el que
falla. El cuello de botella lo introduce el procesador, no la adquisición.

## 5.2.4 El hallazgo de co-diseño

El dato más importante de esta sección no es una cifra de utilización sino una **decisión de
arquitectura que la medida forzó**.

La intención inicial era que el procesador calculara la histéresis transitiva por software, como hace
en las versiones de los otros dos filtros. Esa versión existe y funciona en simulación, con un 92,8 %
de concordancia. Pero al intentar sintetizar el conjunto —procesador, memoria, framebuffers y
motor— la ocupación de celdas lógicas alcanzó el **127 %**: no cabía.

La respuesta fue mover el motor de histéresis de software a hardware, como camino de datos en Verilog
sin intervención del procesador. Así implementado, la síntesis reporta **1 728 tablas de consulta** y
el emplazamiento **2 426 celdas lógicas, el 45 % del dispositivo**, cerrando el temporizado a
**28,9 MHz** con holgura.

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

Este resultado reaparece transformado en la §5.4.2: en el ASIC, donde el área no está acotada por un
dispositivo fijo, el procesador vuelve a ser viable junto al transitivo y cuesta unas nueve mil celdas.
La misma pregunta tiene respuestas opuestas en los dos sustratos.

## 5.2.5 Umbrales de laboratorio y umbrales de cámara

Las tres filas de la tabla anterior muestran umbrales distintos de los que se usan en simulación. El
transitivo, por ejemplo, pasó de 110/70 en el banco de pruebas a **60/30 en la placa**.

El ajuste no es arbitrario ni es un defecto: una imagen almacenada y un flujo de cámara tienen
histogramas distintos, y el punto de operación que extrae la estructura de una no es el que la extrae
de la otra. La §5.6.4 mide exactamente cuánto importa esa elección, y muestra que **mover el umbral
dentro de un filtro cambia el resultado de clasificación más que cambiar de filtro**.

---

> **Lo que queda por medir.** De las cinco filas, la del **SoC + Sobel** es la única cuya ocupación de
> celdas no pudo reconfirmarse contra un informe conservado. Reproducirla exige una corrida de
> `nextpnr` sobre fuentes que sí están íntegras; el guion `medir_utilizacion_vm.sh` la deja lista.
> Hasta entonces la cifra se presenta como lo que es: un valor capturado y documentado en su momento,
> con la síntesis recomprobada y el emplazamiento no.
