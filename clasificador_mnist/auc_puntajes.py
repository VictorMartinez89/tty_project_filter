#!/usr/bin/env python3
"""auc_puntajes.py — AUC macro uno-contra-el-resto sobre el LOG-softmax de los puntajes enteros.
El AUC sólo depende del orden, y el log-softmax ordena igual que el softmax: da el mismo AUC en exactitud
aritmética. Pero en coma flotante el softmax de Canny-98 —puntajes de miles— satura a 0 y 1 exactos y crea
empates que bajan el AUC a 0,9965. El log-softmax no satura. Para los otros seis debe dar lo mismo que antes."""
import sys, warnings; warnings.filterwarnings("ignore"); sys.argv = sys.argv[:1]
import numpy as np
from sklearn.metrics import roc_auc_score, roc_curve
from scipy.special import logsumexp
exec(open("metricas_todos.py").read().split("def softmax")[0])       # mismos puntajes S{} que metricas_todos.py
Y1 = np.eye(10)[yte]; out = {}; viejo = np.load("metricas_todos.npz")
for n, Z in S.items():
    L = Z - logsumexp(Z, axis=1, keepdims=True)
    auc = np.mean([roc_auc_score(Y1[:, c], L[:, c]) for c in range(10)])
    fg_ = np.concatenate([np.linspace(0, 0.1, 1000), np.linspace(0.1, 1, 91)[1:]]); tm = np.zeros(len(fg_))
    for c in range(10):
        fpr, tpr, _ = roc_curve(Y1[:, c], L[:, c]); tm += np.interp(fg_, fpr, tpr)
    out[f"{n}_auc"] = auc; out[f"{n}_roc"] = np.stack([fg_, tm / 10])
    print(f"{n:<11} AUC log-softmax {auc:.4f}   (softmax en coma flotante {float(viejo[n+'_auc']):.4f})")
np.savez("auc_puntajes.npz", **out)
