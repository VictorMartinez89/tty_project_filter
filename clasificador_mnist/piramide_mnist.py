#!/usr/bin/env python3
# piramide_mnist.py — el clasificador de digitos que SI cabe en silicio.
#
#   Front-end IDENTICO al RTL de la tesis: Gaussiano 3x3 -> Sobel -> |Gx|+|Gy| saturado
#   a 8 bits -> umbral. De ahi salen las orientaciones (el compass de 8 direcciones).
#   Encima: histograma por zonas en PIRAMIDE ESPACIAL (Lazebnik 2006) y un clasificador
#   LINEAL cuyos pesos se cuantizan a 1/2/4/8 bits, que es lo que costaria en flip-flops.
#
#   Barrido: nivel de piramide x bits por peso -> precision vs flip-flops.
import numpy as np, sys
from sklearn.linear_model import LogisticRegression

import frente_golden as fg

Xtr, ytr, Xte, yte = fg.cargar_mnist(sys.argv[1] if len(sys.argv) > 1 else "mnist.npz")

# OJO: este experimento es el ORIGINAL, con la orientacion por atan2 redondeado. Se conserva
# porque es el que dio los numeros de la Parte 170, pero atan2 NO es implementable barato en
# silicio -pediria un CORDIC o una tabla-. El front-end que de verdad corre en el chip usa el
# OCTANTE y vive en frente_golden.py; con el, la precision a 4 bits es 91.0 %, no 94.2 %.
def frente(img, thr):
    g  = fg.conv3(img.astype(float), fg.GAUSS) / 16.0
    gx = fg.conv3(g, fg.SOBEL_X); gy = fg.conv3(g, fg.SOBEL_Y)
    mag = np.minimum(np.abs(gx) + np.abs(gy), 255.0)
    ori = (np.round(np.arctan2(gy, gx) / (2*np.pi) * 8) % 8).astype(np.int8)
    return mag > thr, ori

piramide  = fg.piramide
cuantizar = lambda W, bits: (W if bits is None else fg.cuantizar(W, bits)[0] * fg.cuantizar(W, bits)[1])

THR = 60
print(f"front-end: Gauss 3x3 -> Sobel -> |Gx|+|Gy| sat 255 -> umbral {THR} -> 8 orientaciones\n")
mtr, otr = frente(Xtr, THR); mte, ote = frente(Xte, THR)
print(f"densidad de borde: train {mtr.mean():.1%}  test {mte.mean():.1%}\n")

print(f"{'piramide':<12}{'zonas':>6}{'carac':>7}{'pesos':>7} | " + "".join(f"{b if b else 'float':>8}" for b in [None,8,4,2,1]))
print("-"*12 + "-"*20 + "-+-" + "-"*40)
resultados = {}
for niv, etq in [(0,"nivel 0"), (1,"nivel 0+1"), (2,"nivel 0+1+2")]:
    Ftr = piramide(mtr, otr, niv); Fte = piramide(mte, ote, niv)
    zonas = sum(4**L for L in range(niv+1)); nf = Ftr.shape[1]
    mu, sd = Ftr.mean(0), Ftr.std(0)+1e-6
    clf = LogisticRegression(max_iter=2000, C=0.05, multi_class="multinomial")
    clf.fit((Ftr-mu)/sd, ytr)
    fila = f"{etq:<12}{zonas:>6}{nf:>7}{nf*10:>7} | "
    for bits in [None,8,4,2,1]:
        Wq = cuantizar(clf.coef_, bits)
        pred = (((Fte-mu)/sd) @ Wq.T + clf.intercept_).argmax(1)
        acc = (pred == yte).mean()
        fila += f"{acc:>7.1%} "
        resultados[(niv,bits)] = (acc, nf, pred)
    print(fila)

# la prueba del 6 vs 9: es lo que la bolsa pura no puede separar
print("\nconfusion 6<->9 (test):")
for niv, etq in [(0,"nivel 0 (bolsa pura)"), (1,"nivel 0+1 (con piramide)")]:
    pred = resultados[(niv,4)][2]
    n69 = int(((yte==6)&(pred==9)).sum()); n96 = int(((yte==9)&(pred==6)).sum())
    tot6 = int((yte==6).sum()); tot9 = int((yte==9).sum())
    print(f"  {etq:<26} 6 leido como 9: {n69:4d}/{tot6}   9 leido como 6: {n96:4d}/{tot9}")

# linea de base: los pixeles crudos
clf = LogisticRegression(max_iter=400, C=0.01)
clf.fit(Xtr.reshape(len(Xtr),-1)/255.0, ytr)
acc = clf.score(Xte.reshape(len(Xte),-1)/255.0, yte)
print(f"\nlinea de base — 784 pixeles crudos + lineal: {acc:.1%}  ({784*10} pesos)")
