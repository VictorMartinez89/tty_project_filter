#!/usr/bin/env python3
"""cv_exactitud.py — validacion cruzada de 10 pliegues sobre EXACTITUD.

Correccion de metodo: la sigma del cuaderno (0.74 pp) esta medida sobre EXACTITUD; la de
`metricas_avanzadas.py` esta medida sobre R2 (Brier skill), que es otra escala. Compararlas
directamente -como hizo la primera version de revisar_significancia.py- es comparar peras con
manzanas, y da un factor de 4x que no significa nada.

Para revisar si las afirmaciones del cuaderno se sostienen hay que medir el ruido SOBRE LA
MISMA CANTIDAD que se esta afirmando: la exactitud a 4 bits.
"""
import numpy as np, warnings, time; warnings.filterwarnings("ignore")
from sklearn.linear_model import LogisticRegression
from sklearn.model_selection import StratifiedKFold
import frente_golden as fg
from canny1_mnist import frente_canny1
from transitivo_mnist import frente_transitivo

FRENTES = {"Sobel":      lambda X: fg.frente(X, 60),
           "SoC+Sobel":  lambda X: fg.frente(X, 90),
           "Canny1":     lambda X: frente_canny1(X, 110, 40),
           "SoC+Canny1": lambda X: frente_canny1(X, 90, 32),
           "Transitivo": lambda X: frente_transitivo(X, 110, 40)}
Xtr, ytr, _, _ = fg.cargar_mnist()
print("10 pliegues sobre EXACTITUD a 4 bits (la misma cantidad que el cuaderno afirma):\n")
CV = {}
for n, f in FRENTES.items():
    m, o = f(Xtr); F = fg.piramide(m, o, 1)
    skf = StratifiedKFold(n_splits=10, shuffle=True, random_state=0)
    ac = []
    t0 = time.time()
    for tr, va in skf.split(F, ytr):
        c = LogisticRegression(max_iter=2000, C=0.002).fit(F[tr], ytr[tr])
        W, e = fg.cuantizar(c.coef_, 4); b = np.round(c.intercept_/e).astype(int)
        ac.append(((F[va] @ W.T + b).argmax(1) == ytr[va]).mean())
    CV[n] = np.array(ac)
    print(f"  {n:<12} mediana {np.median(ac):.4f}  sigma {np.std(ac):.4f}  "
          f"[{min(ac):.4f}, {max(ac):.4f}]  ({time.time()-t0:.0f}s)")
np.savez("cv_exactitud.npz", **CV)
s = np.mean([CV[n].std() for n in CV])
print(f"\n  sigma media entre pliegues: {s:.4f} = {s*100:.2f} pp")
print(f"  sigma del cuaderno (5 semillas, 20 000): 0.74 pp")
print(f"  -> el ruido real es {s*100/0.74:.1f}x el que suponiamos")
print("\n  las afirmaciones del cuaderno, con la sigma nueva:")
A=[("§3  Canny vs Sobel, igual area",0.0075),("§3  Canny vs Sobel, umbral barrido",0.0144),
   ("§8  Canny vs Sobel en la camara",0.0024),("§9  placa: Canny vs Sobel",0.0690),
   ("§18 SoC+Canny vs Sobel",0.0142),("§18 SoC+Canny vs Transitivo",0.0270)]
print(f"  {'afirmacion':<38}{'dif':>8}{'con 0.74':>11}{'con la nueva':>14}")
for t,dif in A:
    v1="si" if dif>2*0.0074 else "NO"; v2="si" if dif>2*s else "NO"
    print(f"  {t:<38}{dif:>8.2%}{v1:>11}{v2:>14}{'  <-- CAMBIA' if v1!=v2 else ''}")
