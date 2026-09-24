#!/usr/bin/env python3
"""fig_confusion_s3_s4.py — las matrices de confusion de las cinco cadenas de metricas_s3_s4.py.

Fila = lo que era, columna = lo que dijo el circuito (4 bits). Cada celda en % de su FILA, asi que
la diagonal es el recall de ese digito. Abajo a la derecha, la de 11 clases de la cadena que
corre en silicio: la columna NADA dice cuantas veces se callo en vez de equivocarse.
Lee metricas_s3_s4.json; no reentrena nada.
"""
import json, numpy as np
import matplotlib; matplotlib.use("Agg"); import matplotlib.pyplot as plt
d = json.load(open("metricas_s3_s4.json"))
noms = list(d["matrices"])
fig, axs = plt.subplots(2, 3, figsize=(17, 11))
def dibuja(ax, M, titulo, etiq_x):
    M = np.array(M); Mn = M / M.sum(1, keepdims=True) * 100
    ax.imshow(np.where(np.eye(*M.shape, dtype=bool), np.nan, Mn), cmap="Reds", vmin=0, vmax=6)
    for i in range(M.shape[0]):
        for j in range(M.shape[1]):
            if M[i, j] == 0: continue
            diag = (i == j)
            ax.text(j, i, f"{Mn[i,j]:.0f}" if diag else str(M[i, j]), ha="center", va="center",
                    fontsize=8 if diag else 7.2, weight="bold" if diag else None,
                    color="#1e7a3c" if diag else ("w" if Mn[i, j] > 3 else "#333"))
    ax.set_xticks(range(M.shape[1])); ax.set_xticklabels(etiq_x, fontsize=8)
    ax.set_yticks(range(10)); ax.set_yticklabels(range(10), fontsize=8)
    ax.set_xlabel("lo que dijo el circuito", fontsize=8.5); ax.set_ylabel("lo que era", fontsize=8.5)
    ok = np.trace(M[:, :10]) / M.sum()
    ax.set_title(f"{titulo}\nexactitud {ok:.2%}", fontsize=10, loc="left")
for ax, n in zip(axs.ravel()[:5], noms):
    dibuja(ax, d["matrices"][n], n, [str(k) for k in range(10)])
ax = axs.ravel()[5]
dibuja(ax, d["M11"]["silicio"], "silicio · 78 caracs, CON la clase NADA", [str(k) for k in range(10)] + ["NADA"])
ax.axvline(9.5, color="#c0392b", lw=2)
fig.suptitle("Matrices de confusión, 4 bits, test de 10 000 · diagonal (verde) = recall en % · "
             "fuera de la diagonal = cuántas imágenes, en rojo más intenso cuanto más se confunde",
             fontsize=11, x=.01, ha="left")
fig.tight_layout(rect=[0, 0, 1, .96])
fig.savefig("../tesis/figuras/fig_confusion_s3_s4.png", dpi=150, facecolor="white")
print("  -> tesis/figuras/fig_confusion_s3_s4.png")
