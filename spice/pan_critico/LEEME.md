# Verificación eléctrica del camino crítico de `pan_sobel` y `pan_canny`

§33 del cuaderno 2. Comprueba en NGSpice —resolviendo las ecuaciones del transistor— el
retardo que el analizador estático de tiempos (OpenSTA) obtuvo sumando tablas Liberty.

## Por qué el camino crítico y no el chip entero

El **tamaño** no es el obstáculo: `pan_sobel` tiene 116 314 transistores y esta tesis ya
simuló `femto`, de 121 310, durante 200 µs.

El obstáculo es el **tiempo simulado**. `cam_win28` está fijado a 640×480, así que para que
el clasificador vea sus 784 píxeles hay que meter un cuadro VGA entero:

    (640*2 + 40) * 480 + 200 = 633 800 ciclos = 6.34 ms    ->  32x lo de femto

Impracticable. El camino crítico son 37 celdas y 48 segundos.

## Uso

    python3 gen_camino.py <reporte_sta.rpt> <salida.spice>   # genera el banco
    python3 correr.py [rpt] [nombre]                          # las 3 variantes
    python3 perfil.py                                         # etapa por etapa

Necesita `ngspice` y el PDK en `~/.volare/sky130A`. Corre en el Mac; no hace falta la VM.

Los reportes de entrada son los que `traer_pan.sh` deja en
`/mnt/share/utm-share/asic_pan_{sobel,canny}/results_final/signoff/31-rcx_sta.max.rpt`.

## Cómo funciona

1. Localiza el camino registro-a-registro más lento. Corta en `data arrival time`: lo que
   sigue es el árbol de reloj del destino, no camino combinacional.
2. Lee el orden de pines de los `.subckt` del PDK. No lo supone.
3. Sensibiliza cada celda a partir de la nomenclatura de sky130 (grupos `aN..o` / `oN..a`,
   entradas negadas `_N`, multiplexores).
4. Cuelga de cada nodo la capacitancia que el reporte post-extracción le atribuye.
5. Vuelca el perfil nodo a nodo, para ver DONDE se pierde el tiempo.

## Tres cosas que costaron y conviene no repetir

**1. Sensibilizar no basta: hay que reproducir el SENTIDO del flanco.**
La regla habitual ata las laterales al valor que deja pasar el camino. La cadena conmuta y
el número parece bueno. Pero en una XOR la lateral ELIGE la polaridad: `X = A^0 = A`
conserva el borde y `X = A^1 = !A` lo invierte. Y en CMOS subir y bajar no cuestan lo
mismo. Contrastando contra la columna `^`/`v` del reporte, sólo 14 de 37 bordes coincidían.
Corregido: 24 de 37, y +0.35 ns. Los 13 restantes son AND/OR/AOI, donde la polaridad la fija
la función y haría falta conocer el valor real de cada lateral.

**2. `.meas ... RISE=1` sólo vale si el camino arranca subiendo.**
El de `pan_canny` arranca con flanco de BAJADA. Con `RISE=1` la medida fallaba y el banco
informaba «NO CONMUTA», aunque el perfil mostraba los 36 nodos conmutando perfectamente.
Se usa `CROSS=1`, que vale para los dos sentidos.

**3. La diferencia con el STA no es la capacitancia.**
    correlación desviación-capacitancia   r = -0.15
    correlación desviación-fanout         r = -0.06
Ninguna. Por eliminación es la RESISTENCIA del cable, que el reporte de texto no publica:
vive en el SPEF, y el de `pan_*` no se conservó (`limpiar_disco.sh` lo borra por
regenerable). Con el SPEF la comparación sería concluyente.

## El banco se auto-verifica

Si la sensibilización estuviera mal, la salida no conmutaría y `.meas` devolvería «failed»
en vez de un número plausible y falso. Eso es una comprobación, no un fallo silencioso —y
de hecho saltó con el canny, donde señaló un problema real (el de la medida, no el de la
sensibilización).
