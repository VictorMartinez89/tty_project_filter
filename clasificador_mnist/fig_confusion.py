#!/usr/bin/env python3
"""fig_confusion.py — la matriz de confusion del clasificador que corre en la iCE40UP5K."""
import numpy as np
import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt

d = np.load("confusion.npz")
M, acc_tr, acc_te = d["M"], float(d["acc_tr"]), float(d["acc_te"])
Mn = M / M.sum(axis=1, keepdims=True)          # normalizada por fila = exhaustividad

fig = plt.figure(figsize=(14.6, 6.4))
gs = fig.add_gridspec(1, 2, width_ratios=[1.25, 1], wspace=0.28)

# --- matriz ---
ax = fig.add_subplot(gs[0])
im = ax.imshow(Mn, cmap="Blues", vmin=0, vmax=1)
for i in range(10):
    for j in range(10):
        if M[i, j] == 0: continue
        ax.text(j, i, M[i, j], ha="center", va="center", fontsize=8.4,
                fontweight="bold" if i == j else "normal",
                color="white" if Mn[i, j] > 0.55 else ("#c0392b" if i != j and M[i,j] >= 30 else "#333"))
ax.set_xticks(range(10)); ax.set_yticks(range(10))
ax.set_xlabel("predicción del chip", fontsize=11, fontweight="bold")
ax.set_ylabel("dígito real", fontsize=11, fontweight="bold")
ax.set_title(f"Matriz de confusión · MNIST test (10 000)\nprecisión global {acc_te:.2%}",
             fontsize=12, fontweight="bold")
for s in ax.spines.values(): s.set_edgecolor("#999")
fig.colorbar(im, ax=ax, fraction=0.046, label="fracción de la fila")

# --- por clase ---
ax2 = fig.add_subplot(gs[1])
rec = np.array([M[i, i]/M[i].sum() for i in range(10)])
pre = np.array([M[i, i]/M[:, i].sum() for i in range(10)])
x = np.arange(10); w = 0.4
ax2.barh(x - w/2, rec*100, w, color="#16a085", label="exhaustividad (recall)")
ax2.barh(x + w/2, pre*100, w, color="#8e44ad", label="precisión")
for i in range(10):
    ax2.text(rec[i]*100+0.8, i-w/2, f"{rec[i]:.0%}", va="center", fontsize=8)
    ax2.text(pre[i]*100+0.8, i+w/2, f"{pre[i]:.0%}", va="center", fontsize=8)
ax2.axvline(acc_te*100, color="#c0392b", ls="--", lw=1.6)
ax2.text(acc_te*100-1, 9.9, f"global {acc_te:.1%}", color="#c0392b", fontsize=9,
         ha="right", fontweight="bold")
ax2.set_yticks(x); ax2.set_yticklabels([str(i) for i in range(10)])
ax2.invert_yaxis(); ax2.set_xlim(60, 106); ax2.set_xlabel("%", fontsize=11)
ax2.set_ylabel("dígito", fontsize=11, fontweight="bold")
ax2.set_title("Por clase: qué tan bien se encuentra\ny qué tan confiable es cada respuesta",
              fontsize=12, fontweight="bold")
ax2.legend(loc="lower left", fontsize=9.5); ax2.grid(axis="x", alpha=0.25)

fig.suptitle("Clasificador de dígitos en la iCESugar (iCE40UP5K) · 400 pesos de 4 bits · "
             f"entrenamiento {acc_tr:.2%} · prueba {acc_te:.2%}",
             fontsize=13, fontweight="bold", y=1.0)
plt.tight_layout(rect=[0, 0, 1, 0.94])
plt.savefig("matriz_confusion.png", dpi=140, bbox_inches="tight")
print("-> matriz_confusion.png")
