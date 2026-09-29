#!/usr/bin/env python3
"""canny98_golden.py — Canny-98: el modelo de referencia ENTERO, bit a bit como lo calcularía el circuito.

Front-end y descriptor: los de Canny-78 (Canny de un salto hi=90 lo=32, pirámide de 3 niveles = 168 rasgos, conteos
enteros). Clasificador: una capa oculta de H neuronas con ReLU. Todo en enteros:
    acc1[j] = b1[j] + sum_k W1[j][k] * f[k]          W1 de 4 bits con signo, f = conteo entero (hasta 13 bits)
    h[j]    = min(255, max(0, acc1[j] >> S))          activación de 8 bits: un desplazamiento, no una división
    acc2[c] = b2[c] + sum_j W2[c][j] * h[j]           W2 de 4 bits con signo
    digito  = argmax(acc2)
Una sola escala por capa (el argmax es invariante a ella), así que no hay ninguna multiplicación por constante.
Orden de los rasgos = el de fmem en el hardware: 0..127 nivel 2, 128..159 nivel 1, 160..167 nivel 0.

  /opt/anaconda3/bin/python canny98_golden.py            -> canny98_golden.json + pesos_canny98_H<n>.npz
"""
import json, time, numpy as np, warnings; warnings.filterwarnings("ignore")
from sklearn.neural_network import MLPClassifier
import frente_golden as fg
from canny1_mnist import frente_canny1

t0 = time.time()
Xtr, ytr, Xte, yte = fg.cargar_mnist()
mtr, otr = frente_canny1(Xtr, 90, 32); mte, ote = frente_canny1(Xte, 90, 32)
def al_orden_hw(F):                                   # python: [niv0 8 | niv1 32 | niv2 128] -> hw: [niv2 | niv1 | niv0]
    return np.concatenate([F[:, 40:168], F[:, 8:40], F[:, 0:8]], axis=1).astype(np.int64)
Ftr = al_orden_hw(fg.piramide(mtr, otr, 2)); Fte = al_orden_hw(fg.piramide(mte, ote, 2))
nb_te = mte.reshape(len(mte), -1).sum(1)
ESC_IN = 64.0                                         # para entrenar: f/64 (una potencia de dos; no llega al circuito)
print(f"[{time.time()-t0:5.1f}s] rasgos listos; máximo {Ftr.max()}", flush=True)


def q4(W):
    """4 bits con signo (-7..7), escala de mínimo error cuadrático, una sola para toda la matriz."""
    mejor = None
    for f in np.linspace(0.05, 1.0, 60):
        s = np.abs(W).max() * f / 7
        Wq = np.clip(np.round(W / s), -7, 7)
        e = ((Wq * s - W) ** 2).sum()
        if mejor is None or e < mejor[0]:
            mejor = (e, Wq.astype(np.int64), s)
    return mejor[1], mejor[2]


def entero(W1q, b1i, S, W2q, b2i, F):
    acc1 = F @ W1q.T + b1i
    h = np.clip(acc1 >> S, 0, 255)
    return h @ W2q.T + b2i, acc1, h


res = []
import sys
for H in ([int(a) for a in sys.argv[1:]] or (64, 128)):
    t = time.time()
    m = MLPClassifier(hidden_layer_sizes=(H,), activation="relu", alpha=1e-4, batch_size=256, max_iter=80,
                      early_stopping=True, n_iter_no_change=8, random_state=0).fit(Ftr / ESC_IN, ytr)
    W1, W2 = m.coefs_[0].T, m.coefs_[1].T; b1, b2 = m.intercepts_
    W1q, s1 = q4(W1); W2q, s2 = q4(W2)
    u1 = s1 / ESC_IN                                  # valor real de una unidad de acc1
    b1i = np.round(b1 / u1).astype(np.int64)
    acc_tr = Ftr @ W1q.T + b1i
    S = int(np.ceil(np.log2(max(1.0, np.percentile(np.maximum(acc_tr, 0), 99.9) / 255))))
    u2 = s2 * u1 * 2 ** S                             # valor real de una unidad de acc2
    b2i = np.round(b2 / u2).astype(np.int64)
    out, acc1, h = entero(W1q, b1i, S, W2q, b2i, Fte)
    pred = out.argmax(1)
    exact = float((pred == yte).mean())
    fila = {"H": H, "float": float(m.score(Fte / ESC_IN, yte)), "entero_4bits": exact, "S": S,
            "acc1_bits": int(np.ceil(np.log2(np.abs(acc1).max() + 1))) + 1,
            "acc2_bits": int(np.ceil(np.log2(np.abs(out).max() + 1))) + 1,
            "b1_rango": [int(b1i.min()), int(b1i.max())], "b2_rango": [int(b2i.min()), int(b2i.max())],
            "pesos": int(W1q.size + W2q.size), "kbit_pesos": round((W1q.size + W2q.size) * 4 / 1024, 1),
            "ciclos_1mac": int(W1q.size + W2q.size), "segundos": round(time.time() - t, 1)}
    res.append(fila); print(fila, flush=True)
    np.savez(f"pesos_canny98_H{H}.npz", W1q=W1q, b1i=b1i, S=S, W2q=W2q, b2i=b2i)
json.dump(res, open(f"canny98_golden_{'_'.join(str(r["H"]) for r in res)}.json", "w"), indent=1)
print(f"[{time.time()-t0:5.1f}s] fin", flush=True)
