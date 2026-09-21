# 5.5 Rendimiento: caudal y latencia

> **Estado:** borrador 1, escrito el 2026-09-16. Fuente: cuaderno 1, Partes 154-156.
> Todas las latencias de esta sección están **medidas en simulación**, no estimadas.

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

## 5.5.2 Latencia de cauce, medida

Un banco de pruebas inyecta un flujo continuo de píxeles y cuenta los ciclos que transcurren entre el
primer `in_valid` y el primer `out_valid`:

| Filtro | Latencia de cauce | En tiempo, a su reloj |
|---|---:|---:|
| Sobel | **4 ciclos** | ≈ 31 ns |
| Canny de un salto | **8 ciclos** | ≈ 68 ns |
| SoC + Sobel | 4 ciclos | ≈ 34 ns |
| SoC + Canny de un salto | 8 ciclos | ≈ 76 ns |

Los números tienen una explicación estructural directa: el Sobel necesita **una** línea de retardo para
formar su ventana de 3×3 y el Canny de un salto necesita **tres**, porque encadena suavizado, gradiente
y doble umbral. Cada etapa de ventana 3×3 cuesta, medido, `W+1` píxeles de latencia.

Obsérvese además que **la presencia del procesador no altera la latencia**: cuatro ciclos siguen siendo
cuatro ciclos. El FemtoRV32 escribe el umbral en un registro de configuración y no participa del camino
de datos de imagen, de modo que su única influencia es indirecta —baja algo la frecuencia máxima
alcanzable, y por eso los mismos cuatro ciclos tardan 34 ns en lugar de 31.

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

Reuniendo las dos medidas anteriores:

| Filtro | Reloj máximo | Caudal | Latencia |
|---|---:|---:|---:|
| Sobel | 130 MHz | ≈ 130 Mpx/s | **≈ 0,9 µs** |
| Canny de un salto | 117 MHz | ≈ 117 Mpx/s | ≈ 3,2 µs |
| SoC + Sobel | 119 MHz | ≈ 119 Mpx/s | ≈ 1,0 µs |
| SoC + Canny de un salto | 106 MHz | ≈ 106 Mpx/s | ≈ 3,5 µs |
| Transitivo | 81 MHz | ≈ 16 Mpx/s | **≈ 306 µs/cuadro** |
| SoC + transitivo | 106 MHz | ≈ 20 Mpx/s | ≈ 235 µs/cuadro |

**La latencia separa a las dos familias por un factor de alrededor de trescientos**, y el caudal por
un factor de seis a ocho. No es una diferencia de eficiencia de implementación: es la consecuencia
directa de que una arquitectura decide con información local y la otra necesita el cuadro entero.

> Esa brecha, junto con las noventa y cuatro mil quinientas celdas de la §5.4.3, describe el mismo
> fenómeno desde dos ángulos. Ampliar el alcance del patrón de local a global cuesta casi cien mil
> celdas **y** trescientas veces más latencia. El Capítulo 6 discute cuándo ese precio se justifica.
