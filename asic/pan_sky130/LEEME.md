# pan_sobel y pan_canny — los dos chips «Pan Hablas en MNIST» en sky130

Camara OV7670 + FemtoRV32 + periferico 0x0045 + filtro + clasificador MNIST.
Sin framebuffer y sin driver de LCD: no dibujan, RECONOCEN.

|  | pan_sobel | pan_canny |
|---|---|---|
| run | `RUN_2026.09.04_09.42.15` | `RUN_2026.09.04_09.51.42` |
| die | 914x925 um · 0.85 mm² | 938x949 um · 0.89 mm² |
| instancias | 92 857 | 97 533 |
| logica (sin relleno ni taps) | 19 991 | 20 986 |

Los planos se dibujan desde el **DEF**, no desde el GDS:
`conda/TTY_Filter_Sobel/fig_plano_pan.py` -> `fig_plano_pan.png`  (§32 del cuaderno 2).

Los DEF comprimidos viven en la share, no en git (2.7 y 2.9 MB):
`/mnt/share/utm-share/pan_planos/pan_{sobel,canny}.def.gz`
y los planos durables (GDS, LEF, reportes) en la VM: `~/ASIC_planos/pan_{sobel,canny}/`.
Para rehacerlos: `bash /mnt/share/utm-share/traer_pan.sh` en la VM.

## Ojo con la nomenclatura de sky130
`dlxtp`/`dlrtp` son CERROJOS y `dlygate4sd3`/`dlymetal6s2s` son RETARDOS. Una regex que
capture `__dl` recoge las dos cosas: en pan_sobel eso contaba 2 573 retardos como
biestables e inflaba el registro de 3 175 a 5 753, un 81 % de mas. Ver §32.2.

## Las fotos
`fotos/pan_{sobel,canny}_{die,zoom}.png` — capturas de KLayout con GUI sobre el GDS de
fabricacion, con las capas de sky130A cargadas (§32.6 del cuaderno 2).

KLayout en modo DESATENDIDO (`klayout -z -r guion.py`) sin encontrar el .lyp devuelve una
mancha verde inservible; con la GUI y las capas cargadas sale bien. La limitacion es del
modo de invocarlo, no de la herramienta.

Las cuatro capturas pesaban 43 MB. Recortadas al lienzo, a media resolucion y cuantizadas
a 64 colores ocupan 2.5 MB (-94 %) sin perder legibilidad de ninguna etiqueta de pin: el
tramado de KLayout usa pocos colores reales sobre mucho patron repetido.

## Los pines delatan el front-end
    pan_sobel   thr_usado[7:0]                    <- UN umbral
    pan_canny   thr_hi_o[7:0], thr_lo_o[7:0]      <- DOS: la histeresis del Canny
El resto coincide: pclk reset href sync pix_y[7:0] pix_valid / done digito[3:0] valido
cpu_escribio. Ningun pin de video de salida: estos chips no dibujan.
