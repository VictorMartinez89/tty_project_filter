#!/usr/bin/env python3
"""metricas_avanzadas.py — AUC/ROC, Brier (MSE) y R2, y validacion cruzada de 10 pliegues.

NOTA CONCEPTUAL, porque la mezcla es facil de criticar:

  * AUC y ROC estan bien definidas para clasificacion. Se calculan uno-contra-el-resto sobre
    los puntajes del clasificador y se promedian (macro).
  * MSE y R2 son metricas de REGRESION. Sobre clasificacion no estan definidas de forma
    estandar. Lo que si tiene nombre propio es:
        - MSE entre la probabilidad predicha y el vector one-hot  =  BRIER SCORE
          (mide CALIBRACION: si el modelo dice 0.9, deberia acertar el 90 % de las veces)
        - R2 sobre lo mismo  =  BRIER SKILL SCORE
          (cuanto mejor que predecir siempre la frecuencia base de cada clase)
    Se reportan con esos nombres. Llamarlas "MSE" y "R2" a secas seria prestado de otro
    problema, y un jurado lo marcaria.

El clasificador del hardware NO produce probabilidades: produce 10 puntajes enteros y un
argmax. Para AUC y Brier hace falta pasarlos por un softmax, que es una interpretacion
razonable pero NO es lo que el silicio calcula. Tambien queda anotado.

  Uso:  python3 metricas_avanzadas.py [n_folds]
"""
import sys, warnings, time; warnings.filterwarnings("ignore")
import numpy as np
from sklearn.linear_model import LogisticRegression
from sklearn.model_selection import StratifiedKFold
from sklearn.metrics import roc_auc_score, roc_curve
import frente_golden as fg
from canny1_mnist import frente_canny1
from transitivo_mnist import frente_transitivo

K = int(sys.argv[1]) if len(sys.argv) > 1 else 10
FRENTES = {"Sobel":      lambda X: fg.frente(X, 60),
           "SoC+Sobel":  lambda X: fg.frente(X, 90),
           "Canny1":     lambda X: frente_canny1(X, 110, 40),
           "SoC+Canny1": lambda X: frente_canny1(X, 90, 32),
           "Transitivo": lambda X: frente_transitivo(X, 110, 40)}

Xtr, ytr, Xte, yte = fg.cargar_mnist()
print("extrayendo caracteristicas de los cinco front-ends...")
FEAT = {}
for n, f in FRENTES.items():
    t0 = time.time()
    m1, o1 = f(Xtr); m2, o2 = f(Xte)
    FEAT[n] = (fg.piramide(m1, o1, 1), fg.piramide(m2, o2, 1))
    print(f"  {n:<12} ({time.time()-t0:.0f}s)")

def softmax(S):
    S = S - S.max(1, keepdims=True)
    e = np.exp(S); return e / e.sum(1, keepdims=True)

Y1 = np.eye(10)[yte]                      # one-hot del test
base = np.eye(10)[ytr].mean(0)            # frecuencia base por clase

print(f"\n{'front-end':<12}{'AUC macro':>11}{'Brier (MSE)':>13}{'Brier skill (R2)':>18}")
RES, ROC = {}, {}
for n in FRENTES:
    Ftr, Fte = FEAT[n]
    clf = LogisticRegression(max_iter=5000, C=0.002).fit(Ftr, ytr)
    W, esc = fg.cuantizar(clf.coef_, 4); b = np.round(clf.intercept_/esc).astype(int)
    P = softmax((Fte @ W.T + b).astype(float))        # los puntajes del HW, via softmax
    auc = roc_auc_score(yte, P, multi_class="ovr", average="macro")
    brier = ((P - Y1) ** 2).sum(1).mean()
    brier_base = ((base[None, :] - Y1) ** 2).sum(1).mean()
    r2 = 1 - brier / brier_base
    RES[n] = (auc, brier, r2)
    print(f"{n:<12}{auc:>11.4f}{brier:>13.4f}{r2:>18.4f}")
    # curva ROC uno-contra-el-resto, promediada (macro) para la figura
    fpr_g = np.linspace(0, 1, 200); tpr_m = np.zeros(200)
    for c in range(10):
        fpr, tpr, _ = roc_curve(Y1[:, c], P[:, c]); tpr_m += np.interp(fpr_g, fpr, tpr)
    ROC[n] = (fpr_g, tpr_m / 10)

print(f"\nvalidacion cruzada de {K} pliegues (R2 = Brier skill score)...")
CV = {}
for n in FRENTES:
    Ftr, _ = FEAT[n]
    skf = StratifiedKFold(n_splits=K, shuffle=True, random_state=0)
    r2s = []
    t0 = time.time()
    for tr, va in skf.split(Ftr, ytr):
        c = LogisticRegression(max_iter=2000, C=0.002).fit(Ftr[tr], ytr[tr])
        Wq, e = fg.cuantizar(c.coef_, 4); bq = np.round(c.intercept_/e).astype(int)
        Pv = softmax((Ftr[va] @ Wq.T + bq).astype(float))
        Yv = np.eye(10)[ytr[va]]
        bb = ((np.eye(10)[ytr[tr]].mean(0)[None, :] - Yv) ** 2).sum(1).mean()
        r2s.append(1 - ((Pv - Yv) ** 2).sum(1).mean() / bb)
    CV[n] = np.array(r2s)
    print(f"  {n:<12} mediana {np.median(r2s):.4f}  ·  "
          f"[{np.min(r2s):.4f}, {np.max(r2s):.4f}]  ·  ({time.time()-t0:.0f}s)")

np.savez("metricas_avanzadas.npz",
         **{f"{n}_res": np.array(RES[n]) for n in RES},
         **{f"{n}_cv": CV[n] for n in CV},
         **{f"{n}_roc": np.stack(ROC[n]) for n in ROC})
print("\n-> metricas_avanzadas.npz")
