# 5.4 Resultados en ASIC: la cadena de visión completa

> **Estado:** borrador 1, escrito el 2026-09-16. Fuente: cuaderno 1, Partes 157-165, y la tabla
> maestra `asic/tabla_maestra/tabla_6_chips.py`, que la genera desde los `metrics.csv` del flujo.

La §5.3 presentó bloques: filtros solos, un front-end de cámara, un driver de pantalla. Ésta presenta
**sistemas**: seis circuitos que llevan la cadena entera —captura, filtrado, almacenamiento y
visualización— en un solo dado. Los seis están organizados como una matriz de dos variables, el
**filtro** y la **presencia de procesador**, de modo que cada comparación entre dos de ellos aísla una
sola causa.

## 5.4.1 La tabla maestra

| # | Chip | Filtro | CPU | Área (mm²) | Celdas | Reloj de firma | Setup c/parásitos | DRC | LVS | XOR |
|---|---|---|:-:|---:|---:|---:|---:|:-:|:-:|:-:|
| #1 | `sobel_completo` ᵃ | Sobel | — | 2,45 | 36 730 | 20 ns (50,0 MHz) | sin dato ᵇ | 0 | 0 | 0 |
| #2 | `canny1_completo` ᵃ | Canny1 | — | 2,90 | 42 581 | 20 ns (50,0 MHz) | sin dato ᵇ | 0 | 0 | 0 |
| #3 | `trans_completo` | Transitivo | — | 9,61 | 137 092 | 20 ns (50,0 MHz) | **−19,35 ns** | 0 | 0 | 0 |
| #4 | `soc_sobel_completo` | Sobel | ✓ | 3,03 | 46 019 | 32 ns (31,2 MHz) | **+0,00 ns** | 0 | 0 | 0 |
| #5 | `soc_canny1_completo` | Canny1 | ✓ | 3,44 | 51 037 | 36 ns (27,8 MHz) | **+0,00 ns** | 0 | 0 | 0 |
| #6 | `soc_trans_completo` | Transitivo | ✓ | 10,19 | 146 216 | 36 ns (27,8 MHz) | **−18,23 ns** | 0 | 0 | 0 |

ᵃ Estos dos se archivaron sin el directorio de reportes; sus cifras provienen de la ficha del cuaderno
y no de un `metrics.csv` del flujo. Se marcan porque en una tabla de resultados debe poder decirse de
dónde sale cada número.

ᵇ Su ficha registra el **WNS nominal** —0,00 ns, sin violaciones— pero no quedó registrado el setup ya
con parásitos extraídos, que es justamente la columna que hunde a los dos transitivos. Se deja en
blanco antes que suponer que cierran.

**Los seis llegaron a GDSII con DRC, LVS y XOR en cero.** Cuatro cierran temporizado o carecen del dato
para afirmar lo contrario; los dos transitivos no cierran, y conviene decirlo con el número: el #3
pediría 39,4 ns —25,4 MHz— y el #6, 54,2 ns, es decir 18,4 MHz en lugar de los 27,8 solicitados.

> **Sobre el recuento de celdas, y es importante al leer junto a la §5.3.** Las cifras de esta tabla
> son **celdas de síntesis**; las de la §5.3 y la §5.6 son **celdas emplazadas**. Cada tabla es
> internamente homogénea, y el paso de una escala a otra **está medido sobre nueve circuitos que
> conservan las dos cifras**: el emplazamiento agrega entre un 16 % y un 26 %, con un factor medio de
> **×1,21** y una desviación típica de 0,04. Para comparar una cifra de aquí con una de allá,
> multiplíquese por 1,21; el detalle del procedimiento está en la §5.3.3.
>
> Dos de los seis circuitos de esta tabla se archivaron sin *netlist*, razón por la cual no se
> convirtió la tabla entera: se prefirió una tabla homogénea en su propia escala antes que una tabla
> mixta con dos filas estimadas.

![**Figura 5.3.** El mismo tipo de acercamiento, ahora sobre el sistema de visión completo. La
diferencia con la figura anterior no está en la textura sino en la escala: aquí caben cámara, filtro,
memoria de cuadro y controlador de pantalla en el mismo dado. Es la forma que toma en silicio la
frase «el filtro es una pieza y no el circuito».](figuras/fig_5_3_mar_de_celdas_vision.jpg)

## 5.4.2 El procesador cuesta lo mismo, sea cual sea el filtro

Restando cada chip de su gemelo con procesador se obtiene el costo del FemtoRV32, su memoria de
programa y su periférico:

| Filtro | sin CPU | con CPU | Δ celdas | Δ relativo |
|---|---:|---:|---:|---:|
| Sobel | 36 730 | 46 019 | **+9 289** | +25,3 % |
| Canny de un salto | 42 581 | 51 037 | **+8 456** | +19,9 % |
| Canny transitivo | 137 092 | 146 216 | **+9 124** | +6,7 % |

El incremento absoluto es **prácticamente constante**: alrededor de nueve mil celdas, con una
dispersión inferior al 5 % entre el caso más barato y el más caro. Es un resultado esperable —el
procesador no sabe qué filtro tiene al lado— pero conviene tenerlo medido, porque convierte al
procesador en un **costo fijo y presupuestable** frente a un datapath cuyo costo varía en un factor de
cuatro.

La columna relativa dice lo contrario que la absoluta, y las dos son ciertas: el mismo procesador
representa una cuarta parte del chip más pequeño y apenas una quinceava parte del más grande. Cuál de
las dos lecturas importa depende de la pregunta. Para decidir si añadir un procesador a un diseño
dado, manda la absoluta.

## 5.4.3 Lo que de verdad cuesta caro no es el cerebro: es la memoria

El mismo ejercicio, hecho ahora sobre el eje del filtro en lugar del procesador, produce el resultado
central de este capítulo:

| Alcance del patrón | Filtro | Celdas (sin CPU) | Δ respecto al anterior |
|---|---|---:|---:|
| local, ventana 3×3 | Sobel | 36 730 | — |
| local más un salto | Canny de un salto | 42 581 | +5 851 |
| **global, cuadro completo** | Canny transitivo | **137 092** | **+94 511** |

Pasar de mirar una ventana de 3×3 a mirar un salto más cuesta menos de seis mil celdas. Pasar de ahí a
**mirar el cuadro entero** cuesta noventa y cuatro mil quinientas once.

La comparación directa es la que conviene enunciar: **un procesador RISC-V completo, con su memoria y
su periférico, pesa aproximadamente la décima parte de lo que pesa cambiar el alcance del patrón de
local a global.** Nueve mil celdas contra noventa y cuatro mil quinientas.

Y la razón no está en la aritmética. Los tres filtros ejecutan esencialmente las mismas operaciones
sobre cada píxel; lo que cambia es **cuánto estado hay que sostener simultáneamente**. El Sobel y el
Canny de un salto procesan en flujo y necesitan unas pocas líneas de la imagen —los *line-buffers* de
la §4.5—, mientras que la histéresis transitiva necesita el cuadro completo residente y accesible en
cualquier orden, porque su punto fijo puede propagar una decisión desde cualquier píxel hacia
cualquier otro. En una FPGA ese cuadro es un bloque de memoria que ya está en el sustrato; en un ASIC
sin macro de memoria es un banco de biestables, y se paga en área, en potencia y en frecuencia.

> Éste es, en una sola cifra, el argumento que el Capítulo 6 desarrolla: **lo que decide si un
> algoritmo cabe en silicio no es su complejidad aritmética sino su huella de memoria.** Los dos
> transitivos son además los dos únicos chips de la tabla que no cierran temporizado, lo que muestra
> que el precio de esa memoria no se cobra sólo en milímetros cuadrados.

## 5.4.4 Balance

Seis circuitos, 459 675 celdas en total, **seis de seis con DRC = LVS = XOR = 0**. Dos cierran
temporizado con parásitos extraídos, dos carecen de ese dato por haberse archivado sin reportes, y dos
no cierran y se documentan con la frecuencia que sí soportarían.

Ninguno ha sido fabricado. La §5.6.1 describe la vía por la que podrían serlo.
