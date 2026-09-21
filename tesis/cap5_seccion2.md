# 5.2 Resultados en FPGA

> **Estado:** borrador 1, escrito el 2026-09-16. Fuente: cuaderno 1, Partes 25-28 y 68-82.
> ⚠️ Faltan por completar las cifras exactas de utilización (LC, BRAM, SPRAM) de los tres diseños;
> ver la nota al final de la sección.

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

## 5.2.3 El hallazgo de co-diseño

El dato más importante de esta sección no es una cifra de utilización sino una **decisión de
arquitectura que la medida forzó**.

La intención inicial era que el procesador calculara la histéresis transitiva por software, como hace
en las versiones de los otros dos filtros. Esa versión existe y funciona en simulación, con un 92,8 %
de concordancia. Pero al intentar sintetizar el conjunto —procesador, memoria, framebuffers y
motor— la ocupación de celdas lógicas alcanzó el **127 %**: no cabía.

La respuesta fue mover el motor de histéresis de software a hardware, como camino de datos en Verilog
sin intervención del procesador. Así implementado ocupa aproximadamente **1 723 LUT, el 33 % del
dispositivo**, y cierra temporizado a **28,9 MHz** con holgura.

> **Por qué esto es co-diseño y no una optimización.** No se trata de que el hardware sea más rápido
> que el software, que es lo esperable. Se trata de que **la restricción de recursos cambió el reparto
> de responsabilidades entre las dos mitades del sistema**: la misma función, expresada como programa,
> no cabía; expresada como circuito, ocupa un tercio del dispositivo. La frontera entre lo que ejecuta
> el procesador y lo que ejecuta la lógica dedicada no la fijó una preferencia de diseño sino una
> medición.

Este resultado reaparece transformado en la §5.4.2: en el ASIC, donde el área no está acotada por un
dispositivo fijo, el procesador vuelve a ser viable junto al transitivo y cuesta unas nueve mil celdas.
La misma pregunta tiene respuestas opuestas en los dos sustratos.

## 5.2.4 Umbrales de laboratorio y umbrales de cámara

Las tres filas de la tabla anterior muestran umbrales distintos de los que se usan en simulación. El
transitivo, por ejemplo, pasó de 110/70 en el banco de pruebas a **60/30 en la placa**.

El ajuste no es arbitrario ni es un defecto: una imagen almacenada y un flujo de cámara tienen
histogramas distintos, y el punto de operación que extrae la estructura de una no es el que la extrae
de la otra. La §5.6.4 mide exactamente cuánto importa esa elección, y muestra que **mover el umbral
dentro de un filtro cambia el resultado de clasificación más que cambiar de filtro**.

---

> ⚠️ **Pendiente de esta sección.** Falta la tabla de utilización real de los tres diseños —celdas
> lógicas, bloques de memoria y SPRAM ocupados, con su porcentaje— que el cuaderno registra en las
> Partes 68-82. Está el dato del transitivo (1 723 LUT, 33 %, 28,9 MHz) y el del conjunto que no cupo
> (127 %), pero no la tabla completa de los tres. **No se transcriben aquí cifras aproximadas: se deja
> el hueco marcado hasta extraerlas del informe de `nextpnr`.**
