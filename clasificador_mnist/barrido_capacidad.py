#!/usr/bin/env python3
"""barrido_capacidad.py — cuanto cuesta cada punto de exactitud, en pesos.

La pregunta de la tesis es que decide si un algoritmo cabe en silicio. Aqui se
mide sobre el clasificador: se barre la CAPACIDAD del modelo en dos ejes
   - niveles de piramide  ->  8, 40 o 168 caracteristicas
   - bits por peso        ->  2 a 8
y para cada punto se anota exactitud y numero de pesos, que es la ROM.

El front-end es el Canny de un salto con los umbrales del firmware (hi=90 lo=32).
Las caracteristicas se calculan UNA vez: el nivel 2 contiene al 1 y al 0, asi que
basta con quedarse con las primeras 8, 40 o 168 columnas.

  python3 barrido_capacidad.py
"""
import json, time, numpy as np, warnings; warnings.filterwarnings("ignore")
from sklearn.linear_model import LogisticRegression
import frente_golden as fg
from canny1_mnist import frente_canny1

HI, LO = 90, 32
NIVELES = {0: 8, 1: 40, 2: 168}
CES     = [0.0005, 0.002, 0.01, 0.05]
BITS    = [2, 3, 4, 5, 6, 8]

t0 = time.time()
Xtr, ytr, Xte, yte = fg.cargar_mnist()
mtr, otr = frente_canny1(Xtr, HI, LO); mte, ote = frente_canny1(Xte, HI, LO)
Ftr = fg.piramide(mtr, otr, 2); Fte = fg.piramide(mte, ote, 2)
print(f"[{time.time()-t0:6.1f}s] caracteristicas listas\n", flush=True)

filas = []
print(f"  {'niv':>3} {'caracs':>7} {'C':>8} {'float':>8}" +
      "".join(f"{b:>2}b".rjust(8) for b in BITS) + f"{'pesos':>8}", flush=True)
print("  " + "-"*(3+8+9+9+8*len(BITS)+9), flush=True)

for niv, nc in NIVELES.items():
    for C in CES:
        t = time.time()
        clf = LogisticRegression(max_iter=5000, C=C).fit(Ftr[:, :nc], ytr)
        flo = clf.score(Fte[:, :nc], yte)
        fila = {"niveles": niv, "caracs": nc, "C": C, "float": flo,
                "pesos": 10*nc, "segundos": round(time.time()-t, 1)}
        cad = f"  {niv:>3} {nc:>7} {C:>8} {flo:>7.2%}"
        for b in BITS:
            W, esc = fg.cuantizar(clf.coef_, b)
            bb = np.round(clf.intercept_/esc).astype(int)
            acc = ((Fte[:, :nc] @ W.T + bb).argmax(1) == yte).mean()
            fila[f"b{b}"] = float(acc); cad += f"{acc:>8.2%}"
        cad += f"{10*nc:>8}"
        filas.append(fila); print(cad, flush=True)

json.dump(filas, open("barrido_capacidad.json", "w"), indent=1)
mej = max(filas, key=lambda r: r["b4"])
print(f"\n  mejor a 4 bits: niveles={mej['niveles']} C={mej['C']} -> {mej['b4']:.2%} "
      f"con {mej['pesos']} pesos", flush=True)
print(f"  referencia actual (niveles=1, C=0.002, 4 bits): "
      f"{[r for r in filas if r['niveles']==1 and r['C']==0.002][0]['b4']:.2%} con 400 pesos", flush=True)
print(f"\n[{time.time()-t0:6.1f}s] fin  ->  barrido_capacidad.json", flush=True)
