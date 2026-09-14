#!/usr/bin/env python3
"""soc_canny_firmware.py — el firmware del Sobel rompe el Canny 1-streaming.

El SoC de la tesis corre 7 instrucciones que escriben el periferico 0x0045:

    lui x3,0x6 ; addi x3,x3,-1536   ->  x3 = 0x5A00
    sw  x3,4(x1)                    ->  thr_lo = 0x00 = 0   ·   thr_hi = 0x5A = 90

Para el SOBEL da igual: solo usa thr_hi. Para el CANNY 1-salto es fatal: con thr_lo = 0
todo pixel con magnitud > 0 es "borde debil", y la histeresis promueve casi todos.

  El firmware no es neutral al datapath: la MISMA ROM sirve a un filtro y rompe al otro.
"""
import numpy as np, warnings; warnings.filterwarnings("ignore")
from sklearn.linear_model import LogisticRegression
import frente_golden as fg
from canny1_mnist import frente_canny1

Xtr, ytr, Xte, yte = fg.cargar_mnist()

def mide(hi, lo, et):
    mtr, otr = frente_canny1(Xtr, hi, lo); mte, ote = frente_canny1(Xte, hi, lo)
    Ftr = fg.piramide(mtr, otr, 1); Fte = fg.piramide(mte, ote, 1)
    clf = LogisticRegression(max_iter=5000, C=0.002).fit(Ftr, ytr)
    W, e = fg.cuantizar(clf.coef_, 4); b = np.round(clf.intercept_/e).astype(int)
    acc = ((Fte @ W.T + b).argmax(1) == yte).mean()
    print(f"  {et:<42} densidad {mtr.mean():6.1%}   4 bits {acc:6.2%}")
    return acc, mtr.mean()

print("Canny 1-streaming con distintos umbrales:\n")
a0 = mide(110, 40, "referencia del cuaderno (hi=110 lo=40)")
a1 = mide(90,   0, "con el FIRMWARE DEL SOBEL (hi=90 lo=0)")
a2 = mide(90,  32, "firmware corregido (hi=90 lo=32)")
a3 = mide(90,  58, "firmware corregido (hi=90 lo=58, razon 0.36 del diseno)")

print(f"\nel firmware del Sobel le cuesta al Canny: {a1[0]-a0[0]:+.2%}")
print(f"un firmware propio lo recupera:            {max(a2[0],a3[0])-a1[0]:+.2%}")

# la instruccion que habria que escribir
for lo in (32, 58):
    v = (90 << 8) | lo
    print(f"\npara thr_hi=90 thr_lo={lo}:  escribir 0x{v:04X} en 0x0045+4")
    hi20 = (v + 0x800) >> 12            # lui toma los 20 bits altos, con redondeo del addi
    imm = v - (hi20 << 12)
    print(f"   lui  x3,0x{hi20:X}")
    print(f"   addi x3,x3,{imm}")
    print(f"   sw   x3,4(x1)")
