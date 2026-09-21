# 5.1 Verificación funcional

> **Estado:** borrador 1, escrito el 2026-09-16. Fuente: cuaderno 1, Partes 29-35.
> Formato Markdown para convertir con `pandoc` a Word o LaTeX según decida la guía de la Facultad.

Antes de presentar área, frecuencia o consumo conviene establecer que los circuitos **calculan lo que
deben calcular**. Esta sección lo hace, y distingue con cuidado dos preguntas que la literatura de
implementación mezcla con frecuencia: si el hardware coincide con su modelo de referencia, y si el
resultado es bueno. Aquí sólo se responde la primera. La segunda pertenece a la §5.6.

## 5.1.1 El criterio

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

## 5.1.2 Resultado sobre los núcleos aislados

Los tres núcleos son **idénticos bit a bit** a su modelo de referencia. En el caso del Sobel sobre un
cuadro de 60×80, la comparación arroja **0 píxeles de diferencia sobre 4 800**, y el resultado se
sostiene para los tres filtros sobre las cinco imágenes de prueba.

| Núcleo | Imágenes | Píxeles comparados | Diferencias |
|---|---:|---:|---:|
| Sobel 3×3 | 5 / 5 | 4 800 por cuadro | **0** |
| Canny de un salto | 5 / 5 | 4 800 por cuadro | **0** |
| Canny transitivo | 5 / 5 | 4 800 por cuadro | **0** |

Que la coincidencia sea exacta y no aproximada tiene una causa de diseño: los tres filtros operan
**sobre enteros y sin división**. La magnitud del gradiente usa la norma L1, `|Gx|+|Gy|`, en lugar de
la euclídea; los pesos del operador son potencias de dos, implementadas como desplazamientos; y el
umbral es una comparación. No hay ninguna operación cuyo redondeo pueda diferir entre una biblioteca
de punto flotante y un circuito. **La igualdad bit a bit no es una casualidad afortunada: es
consecuencia de haber elegido una aritmética que la permite.**

## 5.1.3 Resultado sobre la cadena completa con cámara

La verificación anterior alimenta el circuito con una imagen almacenada. La cadena real recibe en
cambio un flujo de video de la cámara OV7670, con sus bordes de línea, sus tiempos muertos y su
sincronismo propio. Medida sobre ese flujo, la concordancia entre el hardware y el modelo es:

| Cadena | Concordancia |
|---|---:|
| Sobel | 95 – 100 % |
| Canny de un salto | 88 – 99 % |
| Canny transitivo | 96 – 100 % |
| Promedio a través del SoC | **97,8 %** |

La degradación respecto del 100 % de la §5.1.2 no proviene del filtro sino del **acoplamiento con la
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
> qué se vaya a usar el mapa de bordes. La §5.6.4 muestra precisamente que mover ese punto de
> operación cambia el resultado de clasificación más que cambiar de filtro.
