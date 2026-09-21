# 5.5 Rendimiento: caudal y latencia

> **Estado:** borrador 2, 2026-09-21. Fuente: cuaderno 1, Partes 154-156, y la corrida de
> `tb_latencia_final.v` del 21 de septiembre.
> Todas las latencias de esta sección están **medidas en simulación**, no estimadas — incluida la del
> Canny, que hasta esta versión provenía de una fórmula y resultó estar sobrestimada en un 20 %.

Las secciones anteriores midieron el costo de cada circuito. Ésta mide su velocidad, y lo hace
separando dos magnitudes que la palabra «rápido» confunde: el **caudal**, o cuántos píxeles salen por
segundo, y la **latencia**, o cuánto tarda un píxel concreto desde que entra hasta que sale.

La distinción importa porque las dos arquitecturas de este trabajo se sitúan en extremos opuestos. Un
cauce segmentado puede tener latencia alta y caudal altísimo, porque los resultados salen uno tras
otro una vez lleno; y un motor iterativo puede terminar un cuadro entero de una vez pero tardar
milisegundos en hacerlo.

## 5.5.1 Las dos arquitecturas

| | Flujo (Sobel, Canny de un salto) | Framebuffer (Canny transitivo) |
|---|---|---|
| Ritmo | un píxel por ciclo, una vez lleno el cauce | barre el cuadro **K** veces hasta el punto fijo |
| Latencia | baja — llenar el cauce | alta — todo el cuadro por K barridos |
| Caudal | alto | bajo |

La razón de la asimetría está en la §4.3: la histéresis transitiva resuelve un **punto fijo** sobre el
cuadro completo, y no puede emitir su primer píxel definitivo hasta haber comprobado que ningún píxel
del cuadro cambia de estado.

## 5.5.2 Las dos latencias, y por qué no son la misma

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

## 5.5.3 El número de barridos del transitivo, medido

El motor de histéresis transitiva repite barridos hasta que ninguno produce cambios. Ese número, **K**,
no es una constante del diseño sino una propiedad de la imagen, de modo que estimarlo no sirve: hay
que contarlo. Un banco instrumentado cuenta las entradas al estado de barrido y los ciclos totales
hasta la señal de terminado:

| Imagen de clases | K | Ciclos totales | A 81 MHz | A 106 MHz |
|---|---:|---:|---:|---:|
| Sólo bordes fuertes | **1** | 19 772 | 243 µs | 187 µs |
| **Bordes típicos** | **2** | **24 859** | **306 µs** | 235 µs |
| Peor caso: cadena débil de 50 px | **51** | 274 122 | 3,37 ms | 2,59 ms |

El hallazgo es que **una imagen de bordes real converge en dos barridos**, no en los ocho que una
estimación conservadora sugeriría. La razón es propia del Canny: los píxeles débiles forman un halo
fino alrededor de los fuertes, de modo que casi todos están a un solo salto de un borde fuerte. El
primer barrido los confirma y el segundo verifica que ya nada cambia.

El peor caso es una **cadena débil larga**, porque la confirmación avanza aproximadamente un salto por
barrido: una cadena de cincuenta píxeles exige cincuenta y un barridos. Conviene documentarlo como lo
que es —una cota superior real— y señalar a la vez que esa configuración casi no aparece en bordes de
escenas reales, donde el ruido débil aislado se descarta y los tramos débiles conectados son cortos.

## 5.5.4 La brecha

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

**La latencia separa a las dos familias por un factor de entre ochenta y trescientos** —dos órdenes de
magnitud— y el caudal por un factor de seis a ocho. No es una diferencia de eficiencia de
implementación: es la consecuencia directa de que una arquitectura decide con información local y la
otra necesita el cuadro entero.

> Esa brecha, junto con las noventa y cuatro mil quinientas celdas de la §5.4.3, describe el mismo
> fenómeno desde dos ángulos. Ampliar el alcance del patrón de local a global cuesta casi cien mil
> celdas **y** trescientas veces más latencia. El Capítulo 6 discute cuándo ese precio se justifica.
