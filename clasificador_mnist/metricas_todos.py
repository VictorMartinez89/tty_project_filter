#!/usr/bin/env python3
"""metricas_todos.py — las metricas completas de los SIETE reconocedores del Capitulo 6 sobre los 10 000 de prueba.

Los cinco de la §6.2 se re-entrenan exactamente como en comparar_metricas.py (piramide nivel 1, regresion
logistica C=0.002, pesos de 4 bits) y se exige que su matriz de confusion sea la guardada. Canny-78 y
Canny-98 son sus modelos ENTEROS (pesos_sel78.npz, pesos_canny98_H120.npz), los que la tarjeta reproduce
10 000/10 000. Todo sobre el argmax, sin regla de rechazo: es la exactitud de la §6.2.

Por modelo: exactitud y su desviacion (bootstrap, 2 000 remuestreos), precision, recall (sensibilidad),
especificidad y F1 macro, MCC, top-2, AUC macro uno-contra-el-resto y Brier. AUC y Brier pasan los puntajes
enteros del hardware por un softmax, como metricas_avanzadas.py: es una interpretacion, no lo que el
silicio calcula.        /opt/anaconda3/bin/python metricas_todos.py   -> metricas_todos.npz
"""
import sys, time, warnings; warnings.filterwarnings("ignore")
sys.argv = sys.argv[:1]
import numpy as np
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import roc_auc_score, roc_curve, matthews_corrcoef, confusion_matrix
import frente_golden as fg
from canny1_mnist import frente_canny1
from transitivo_mnist import frente_transitivo

t0 = time.time()
Xtr, ytr, Xte, yte = fg.cargar_mnist()
FRENTES = {"Sobel":      lambda X: fg.frente(X, 60),
           "SoC+Sobel":  lambda X: fg.frente(X, 90),
           "Canny1":     lambda X: frente_canny1(X, 110, 40),
           "SoC+Canny1": lambda X: frente_canny1(X, 90, 32),
           "Transitivo": lambda X: frente_transitivo(X, 110, 40)}
guard = np.load("comparar_metricas.npz")
S = {}
for n, f in FRENTES.items():
    m1, o1 = f(Xtr); m2, o2 = f(Xte)
    Ftr, Fte = fg.piramide(m1, o1, 1), fg.piramide(m2, o2, 1)
    clf = LogisticRegression(max_iter=5000, C=0.002).fit(Ftr, ytr)
    W, esc = fg.cuantizar(clf.coef_, 4); b = np.round(clf.intercept_ / esc).astype(int)
    S[n] = (Fte @ W.T + b).astype(float)
    M = confusion_matrix(yte, S[n].argmax(1))
    igual = np.array_equal(M, guard[n + "_M"])
    print(f"[{time.time()-t0:5.0f}s] {n:<11} exactitud {100*np.trace(M)/1e4:.2f} %  matriz = la guardada: {igual}", flush=True)
# Canny-78 y Canny-98: los modelos enteros de la tarjeta
m, o = frente_canny1(Xte, 90, 32)
P2 = fg.piramide(m, o, 2)
p78 = np.load("pesos_sel78.npz"); S["Canny-78"] = (P2[:, p78["idx"]] @ p78["W"].T + p78["b"]).astype(float)
p = np.load("pesos_canny98_H120.npz")
F = np.concatenate([P2[:, 40:168], P2[:, 8:40], P2[:, 0:8]], axis=1).astype(np.int64)
h = np.clip((F @ p["W1q"].T + p["b1i"]) >> int(p["S"]), 0, 255)
S["Canny-98"] = (h @ p["W2q"].T + p["b2i"]).astype(float)

def softmax(Z):
    Z = Z - Z.max(1, keepdims=True); e = np.exp(Z); return e / e.sum(1, keepdims=True)
Y1 = np.eye(10)[yte]; rng = np.random.default_rng(0)
R, OUT = {}, {}
for n, Z in S.items():
    pred = Z.argmax(1); M = confusion_matrix(yte, pred, labels=range(10))
    VP = np.diag(M).astype(float); FP = M.sum(0) - VP; FN = M.sum(1) - VP; VN = M.sum() - VP - FP - FN
    prec = VP / np.maximum(VP + FP, 1); rec = VP / (VP + FN); esp = VN / (VN + FP)
    f1 = 2 * prec * rec / np.maximum(prec + rec, 1e-12)
    acierto = (pred == yte)
    boot = np.array([acierto[rng.integers(0, 10000, 10000)].mean() for _ in range(2000)])
    top2 = (np.argsort(-Z, 1)[:, :2] == yte[:, None]).any(1).mean()
    P = softmax(Z)
    auc = roc_auc_score(yte, P, multi_class="ovr", average="macro")
    brier = ((P - Y1) ** 2).sum(1).mean()
    fg_ = np.linspace(0, 1, 200); tm = np.zeros(200)
    for c in range(10):
        fpr, tpr, _ = roc_curve(Y1[:, c], P[:, c]); tm += np.interp(fg_, fpr, tpr)
    R[n] = dict(acc=acierto.mean(), sd=boot.std(ddof=1), lo=np.percentile(boot, 2.5), hi=np.percentile(boot, 97.5),
                prec=prec.mean(), rec=rec.mean(), esp=esp.mean(), f1=f1.mean(),
                mcc=matthews_corrcoef(yte, pred), top2=top2, auc=auc, brier=brier)
    OUT.update({f"{n}_M": M, f"{n}_P": prec, f"{n}_R": rec, f"{n}_E": esp, f"{n}_F": f1,
                f"{n}_roc": np.stack([fg_, tm / 10])})
print(f"\n{'modelo':<11}{'exact.':>8}{'±σ':>7}{'prec':>7}{'recall':>7}{'espec':>8}{'F1':>7}{'MCC':>7}{'top-2':>8}{'AUC':>8}{'Brier':>7}")
for n, r in R.items():
    print(f"{n:<11}{100*r['acc']:8.2f}{100*r['sd']:7.2f}{r['prec']:7.4f}{r['rec']:7.4f}{r['esp']:8.4f}{r['f1']:7.4f}"
          f"{r['mcc']:7.4f}{100*r['top2']:8.2f}{r['auc']:8.4f}{r['brier']:7.4f}")
np.savez("metricas_todos.npz", nombres=np.array(list(R)), **OUT,
         **{f"{n}_{k}": v for n, r in R.items() for k, v in r.items()})
print(f"\n-> metricas_todos.npz  ({time.time()-t0:.0f}s)")
