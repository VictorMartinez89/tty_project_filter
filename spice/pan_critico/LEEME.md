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
    python3 correr.py [rpt] [nombre] [cual] [spef]            # las 5 variantes
    python3 perfil.py [rpt] [nombre]                          # etapa por etapa
    python3 celda.py [celda pin_ent pin_sal slew cap]         # UNA celda: Liberty vs SPICE
    python3 pincap.py [celda pin]                             # C de pin: Liberty vs esquematico

Las variantes de `correr.py`:

    A   cadena desnuda, flanco ideal        -> solo las puertas
    B   + la capacitancia agrupada del rpt  -> + la carga de cable y fanout
    C   + el flanco real de entrada         -> + la degradacion del frente de onda
    D0  + la topologia RC del SPEF, R = 0   -> + repartir la C donde de verdad esta
    D   + la resistencia medida del SPEF    -> + la R de la interconexion

D0 es el CONTROL: identico a D salvo las resistencias a cero. Es lo que separa lo que
aporta la R de lo que aporta repartir la C, y sin el las dos cosas se confunden.

Necesita `ngspice` y el PDK en `~/.volare/sky130A`. Corre en el Mac; no hace falta la VM.
El SPEF se busca en `~/ASIC_planos/<nombre>/<nombre>.spef`; sin el, D y D0 se saltan.

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

**3. La diferencia con el STA no es la capacitancia. Tampoco es la resistencia.**
    correlación desviación-capacitancia   r = -0.15
    correlación desviación-fanout         r = -0.06
Ninguna de las dos. La primera version de esta seccion concluyo, POR ELIMINACION, que
tenia que ser la RESISTENCIA del cable, que el reporte de texto no publica y solo vive en
el SPEF. Recuperado el SPEF, se midio -- y era falso:

    topologia real del SPEF, R = 0        7.603 ns
    topologia real del SPEF, con la R     7.620 ns
    aporte de la resistencia              0.017 ns   (0.1 %)

Lo decia el propio reporte del STA, y no se leyo: imputa 12.18 ns a pines de SALIDA
(celda) y 0.04 ns a pines de ENTRADA (cable). La diferencia estaba DENTRO de las celdas.

Lo que es: el `.subckt` del PDK es el netlist ESQUEMATICO, sin un solo parasito, mientras
que la Liberty se caracterizo sobre la celda dibujada. Medido con `celda.py` (una celda
sola, mismo arco, misma pendiente, misma carga) la razon Liberty/SPICE es 1.31 de media
sobre las 37 etapas; y con `pincap.py`, la capacitancia que la Liberty declara para un pin
llega a ser 1.8x la que el esquematico tiene.

**Moraleja de forma:** una conclusion por eliminacion vale lo que valga la lista de
alternativas. Aquella lista no incluia "el modelo de celda", y por eso senalo al cable.
Escribir las deducciones como hipotesis hasta que haya una medida que las sostenga.

## El banco se auto-verifica

Si la sensibilización estuviera mal, la salida no conmutaría y `.meas` devolvería «failed»
en vez de un número plausible y falso. Eso es una comprobación, no un fallo silencioso —y
de hecho saltó con el canny, donde señaló un problema real (el de la medida, no el de la
sensibilización).

## Las ondas

`ondas_ngspice.py` genera las formas de onda **con el propio NGSpice**, no con matplotlib:
usa la orden `hardcopy` en SVG, que es el plotter nativo del simulador. Diez trazas de las
~37 del camino, escalonadas 2 V. La escalera descendente ES el retardo del camino.

    python3 ondas_ngspice.py          # -> pan_{sobel,canny}_ng.svg
    python3 -c "import cairosvg; cairosvg.svg2png(url='pan_sobel_ng.svg',
                write_to='pan_sobel_ng.png', scale=2.2, background_color='black')"

Se ven tres cosas que un numero no dice: los flancos no son verticales, se DEGRADAN al
avanzar por la cadena (por eso las tablas Liberty interpolan por pendiente de entrada), y
el reposo despues de ~10 ns es graficamente la holgura con la que el chip cerro la firma.
