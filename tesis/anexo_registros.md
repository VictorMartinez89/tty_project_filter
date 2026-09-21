# Anexo B. Mapa de registros y firmware

> Fuente: `asic/soc_sobel_top/src/peripheral_filter.v`.

## B.1 El periférico de control

El procesador se comunica con el camino de imagen a través de un único periférico mapeado en memoria
en la base **`0x0045_0000`**. Su diseño obedece a la decisión de arquitectura de la §4.1: **los
píxeles no pasan por el bus**. El periférico expone tres registros y nada más.

| Desplazamiento | Nombre | Acceso | Campos |
|---|---|---|---|
| `0x00` | `CTRL` | escritura | `[1:0]` modo · `[4]` habilitación · `[5]` reinicio del motor |
| `0x04` | `THR` | escritura | `[7:0]` umbral bajo · `[15:8]` umbral alto |
| `0x08` | `STAT` | lectura | `[0]` configuración terminada · `[1]` motor ocupado · `[2]` sincronismo vivo · `[23:8]` cuenta de cuadros |

El campo de modo selecciona cuál de los tres filtros procesa la imagen:

| Valor | Filtro |
|---|---|
| `0` | Sobel |
| `1` | Canny de un salto |
| `2` | Canny transitivo |

### Dos decisiones de diseño visibles en la tabla

**Los dos umbrales caben en una sola escritura.** El registro `THR` empaqueta el umbral alto y el
bajo en una palabra de 32 bits. No es una optimización de espacio sino de **atomicidad**: escribir
los dos umbrales del Canny en dos accesos separados deja al filtro operando durante un intervalo con
una pareja inconsistente —un umbral nuevo y otro viejo— que puede producir un cuadro espurio. Una
sola escritura elimina ese estado transitorio.

**El estado incluye un indicador de vida.** El bit `vsync_alive` y la cuenta de cuadros permiten al
programa distinguir *«el filtro no encuentra bordes»* de *«la cámara dejó de entregar imagen»*, que
desde el punto de vista del procesador producen la misma salida: un mapa vacío. Es un mecanismo de
diagnóstico, y su existencia procede directamente de los episodios documentados en la §3.6.

## B.2 El firmware

El programa que ejecuta el procesador consta de **siete instrucciones**. Su estructura es:

1. Inicializar el puntero de pila.
2. Cargar la dirección base del periférico.
3. Escribir el modo y la habilitación en `CTRL`.
4. Escribir la pareja de umbrales en `THR`.
5. Entrar en un lazo de espera.

No se trata de un programa reducido por limitación de memoria sino **por diseño**: el procesador
existe para poder cambiar un parámetro en tiempo de ejecución, no para procesar imagen. Su presencia
se justifica por lo que habilita —recalibrar el sistema sin volver a sintetizar— y no por el trabajo
que realiza.

> Ese es el punto que la §6.6 desarrolla: recalibrar un sistema con procesador cuesta recompilar
> siete instrucciones; recalibrar uno sin procesador cuesta un ciclo completo de síntesis,
> emplazamiento y ruteo. La comparación entre ambas opciones es la que produce la razón 8:1.

## B.3 La ROM en dos sustratos

El mismo programa se almacena de forma distinta según el destino, y ésta es una de las cuatro
diferencias obligatorias de la §4.7:

| Destino | Implementación |
|---|---|
| FPGA | arreglo inicializado desde el *bitstream* |
| ASIC | **tabla de constantes sintetizada como lógica combinacional** |

En silicio no existe nada que cargue el contenido inicial de una memoria. El código Verilog que
funciona en ambos casos **simula idénticamente** y produce circuitos distintos, de los cuales uno no
arranca. Es el ejemplo más claro de por qué la simulación RTL no basta para validar un diseño
destinado a fabricación.
