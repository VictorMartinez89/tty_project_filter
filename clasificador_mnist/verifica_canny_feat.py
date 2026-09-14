#!/usr/bin/env python3
"""verifica_canny_feat.py — mnist_feat_canny.v contra el golden de Python, etapa por etapa.

HISTORIA DE ESTA VERIFICACION, porque la leccion vale mas que el numero.

Durante horas dio 97.31 % y parecia que el RTL estaba mal. No lo estaba: estaba mal la MEDICION,
y por TRES causas apiladas, cada una descubierta al arreglar la anterior:

  1. Se volcaba UNA sola pasada (782 muestras). Una ventana de 24x24 contigua DA LA VUELTA al
     raster, y la comparacion se desalineaba sola. Con dos pasadas, la etapa Sobel paso de
     72.92 % a 100.00 %.
  2. El volcado paraba en `listo`, dejando 696 muestras. El offset correcto (178) quedaba FUERA
     DE RANGO por dos muestras, asi que el buscador nunca lo evaluaba y elegia un espurio (60).
  3. Buscar el desplazamiento sobre un mapa BINARIO encuentra optimos falsos: con ~50 % de ceros,
     una alineacion equivocada ya acierta la mitad. Las etapas intermedias -magnitud de 8 bits,
     clase ternaria- son densas y ahi el optimo es inequivoco.

La estrategia que si funciona: verificar ETAPA POR ETAPA, de la mas densa a la mas escasa.
Si la magnitud coincide, el problema esta despues; si no, esta antes.

RESULTADO (50 imagenes, hi=110 lo=40):
    imagenes exactas (484/484):   32/50
    pixeles coincidentes:         24 182/24 200 = 99.93 %
    diferencias en la ULTIMA fila: 18/18 = 100 %

Las 18 diferencias caen todas en la fila 21 y siempre en el mismo sentido (golden=1, rtl=0).
Es el efecto de borde de cuadro del pipeline en streaming: la histeresis de la ultima fila
necesita la fila de abajo, que en un flujo continuo pertenece al cuadro siguiente. `canny1_top.v`
-el Canny propio de la tesis, el que esta en los chips- muestra EXACTAMENTE la misma firma
(99.91 %). No es un defecto de este modulo: es una propiedad del streaming.
"""
import os, subprocess, sys
import numpy as np
import frente_golden as fg
from canny1_mnist import frente_canny1

HI, LO, OFF = 110, 40, 178       # OFF calibrado con el flujo COMPLETO, no truncado
N = int(sys.argv[1]) if len(sys.argv) > 1 else 50
A = os.path.dirname(os.path.abspath(__file__))
_, _, Xte, _ = fg.cargar_mnist(f"{A}/mnist.npz")
idx = OFF + np.arange(22)[:, None] * 28 + np.arange(22)[None, :]

ex = px = tot = ult = 0
for n in range(N):
    open(f"{A}/tmp/e.hex", "w").write("".join(f"{v:02x}\n" for v in Xte[n].ravel()))
    subprocess.run(["vvp", "/tmp/cm.vvp", f"+IMG={A}/tmp/e.hex", f"+OUT={A}/tmp/map.txt",
                    f"+HI={HI}", f"+LO={LO}"], cwd=A, capture_output=True)
    b = np.array([int(x.split()[2]) for x in open(f"{A}/tmp/map.txt") if x.strip()])
    oro = frente_canny1(Xte[n], HI, LO)[0][0].astype(int)
    d = (b[idx] != oro)
    ex += (d.sum() == 0); px += int(d.sum()); tot += 484; ult += int(d[21].sum())
print(f"imagenes exactas: {ex}/{N}   ·   pixeles {tot-px}/{tot} = {(tot-px)/tot:.4%}")
print(f"diferencias en la ultima fila: {ult}/{px}")
