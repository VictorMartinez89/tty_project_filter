#!/usr/bin/env python3
"""fig_metricas_98.py — las figuras de metricas de Canny-98 contra los otros seis reconocedores
(lee metricas_todos.npz y auc_puntajes.npz).
  fig_6_metricas_modelos.png   las metricas de los siete, en un mapa de calor
  fig_6_confusion_98.png       matrices de confusion de Canny-78 y Canny-98 sobre los 10 000
  fig_6_f1_digitos.png         F1 por digito de los siete
  fig_6_digitos_98.png         precision y recall por digito de Canny-98, y las curvas ROC de los siete"""
import os, numpy as np
import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt
FIG = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tesis", "figuras")
d = dict(np.load("metricas_todos.npz"))
d.update(np.load("auc_puntajes.npz"))          # AUC y ROC con log-softmax (sin saturacion)
N = [str(n) for n in d["nombres"]]
ET = {"Sobel": "Sobel", "SoC+Sobel": "SoC+Sobel", "Canny1": "Canny 1-salto", "SoC+Canny1": "SoC+Canny 1-salto",
      "Transitivo": "Canny transitivo", "Canny-78": "Canny-78", "Canny-98": "Canny-98"}
COL = {"Sobel": "#4c72b0", "SoC+Sobel": "#8fb3e0", "Canny1": "#dd8452", "SoC+Canny1": "#f0b27a",
       "Transitivo": "#937860", "Canny-78": "#55a868", "Canny-98": "#c44e52"}
coma = lambda x, f: (f % x).replace(".", ",")
from matplotlib.ticker import FuncFormatter
COMA = FuncFormatter(lambda v, _: ("%g" % round(v, 4)).replace(".", ","))

# 1) mapa de calor de metricas
MET = [("acc", "exactitud"), ("prec", "precisión"), ("rec", "recall"), ("esp", "especificidad"), ("f1", "F1"),
       ("mcc", "MCC"), ("top2", "top-2"), ("auc", "AUC")]
V = np.array([[float(d[f"{n}_{k}"]) for k, _ in MET] for n in N])
fig, ax = plt.subplots(figsize=(11, 4.6))
ax.imshow(V, cmap="YlGn", vmin=0.88, vmax=1.0, aspect="auto")
for i in range(len(N)):
    for j in range(len(MET)):
        ax.text(j, i, coma(V[i, j], "%.4f"), ha="center", va="center", fontsize=10,
                fontweight="bold" if N[i] == "Canny-98" else "normal")
ax.set_xticks(range(len(MET))); ax.set_xticklabels([m for _, m in MET], fontsize=11)
ax.set_yticks(range(len(N))); ax.set_yticklabels([ET[n] for n in N], fontsize=11)
ax.set_xticks(np.arange(-.5, len(MET)), minor=True); ax.set_yticks(np.arange(-.5, len(N)), minor=True)
ax.grid(which="minor", color="white", lw=2); ax.tick_params(which="minor", length=0)
plt.tight_layout(); fig.savefig(f"{FIG}/fig_6_metricas_modelos.png", dpi=150); plt.close(fig)

# 2) matrices de confusion: Canny-78 y Canny-98
fig, axs = plt.subplots(1, 2, figsize=(12, 5.4))
for ax, n in zip(axs, ["Canny-78", "Canny-98"]):
    M = d[f"{n}_M"].astype(float); Mo = M.copy(); np.fill_diagonal(Mo, np.nan)
    ax.imshow(Mo, cmap="Reds", vmin=0, vmax=30)
    for i in range(10):
        for j in range(10):
            v = int(M[i, j])
            if i == j: ax.text(j, i, str(v), ha="center", va="center", fontsize=8.5, color="#1f5f2f", fontweight="bold")
            elif v: ax.text(j, i, str(v), ha="center", va="center", fontsize=8.5, color="black" if v < 20 else "white")
    ax.set_xticks(range(10)); ax.set_yticks(range(10))
    ax.set_xlabel("dígito predicho", fontsize=11); ax.set_ylabel("dígito real", fontsize=11)
    ax.set_title(f"{n}: {coma(100*float(d[n+'_acc']), '%.2f')} %  ·  {int(10000-np.trace(M))} errores", fontsize=12)
plt.tight_layout(); fig.savefig(f"{FIG}/fig_6_confusion_98.png", dpi=150); plt.close(fig)

# 3) F1 por digito, siete modelos
fig, ax = plt.subplots(figsize=(11, 4.6))
x = np.arange(10)
for n in N:
    ax.plot(x, d[f"{n}_F"], "o-", color=COL[n], lw=3 if n == "Canny-98" else 1.6, ms=7 if n == "Canny-98" else 4,
            label=ET[n], zorder=5 if n == "Canny-98" else 2)
ax.set_xticks(x); ax.set_xlabel("dígito", fontsize=11); ax.set_ylabel("F1", fontsize=11)
ax.set_ylim(0.76, 1.005); ax.grid(alpha=.3); ax.yaxis.set_major_formatter(COMA)
ax.legend(ncol=7, fontsize=9, loc="upper center", bbox_to_anchor=(0.5, 1.13), frameon=False)
for s in ("top", "right"): ax.spines[s].set_visible(False)
plt.tight_layout(); fig.savefig(f"{FIG}/fig_6_f1_digitos.png", dpi=150); plt.close(fig)

# 4) precision y recall por digito de Canny-98 (y Canny-78 de fondo), y ROC macro de los siete
fig, (a1, a2) = plt.subplots(1, 2, figsize=(12.5, 4.8), gridspec_kw={"width_ratios": [1.5, 1]})
w = 0.2
for k, (n, key, lab, al) in enumerate([("Canny-78", "P", "precisión Canny-78", .45), ("Canny-98", "P", "precisión Canny-98", 1),
                                        ("Canny-78", "R", "recall Canny-78", .45), ("Canny-98", "R", "recall Canny-98", 1)]):
    a1.bar(x + (k - 1.5) * w, d[f"{n}_{key}"], w, color=("#4c72b0" if key == "P" else "#dd8452"), alpha=al, label=lab)
a1.set_ylim(0.94, 1.0); a1.set_xticks(x); a1.set_xlabel("dígito", fontsize=11)
a1.set_ylabel("sobre las 10 000 de prueba", fontsize=10.5); a1.yaxis.set_major_formatter(COMA)
a1.legend(ncol=4, fontsize=8.6, loc="upper center", bbox_to_anchor=(0.5, 1.12), frameon=False)
a1.grid(axis="y", alpha=.3)
for n in N:
    fpr, tpr = d[f"{n}_roc"]
    a2.plot(fpr, tpr, color=COL[n], lw=2.6 if n == "Canny-98" else 1.4,
            label=f"{ET[n]} ({coma(float(d[n+'_auc']), '%.4f')})")
a2.set_xlim(0, 0.1); a2.set_ylim(0.8, 1.0); a2.set_xlabel("tasa de falsos positivos", fontsize=10.5)
a2.set_ylabel("tasa de verdaderos positivos", fontsize=10.5); a2.legend(fontsize=8.2, loc="lower right"); a2.grid(alpha=.3)
a2.xaxis.set_major_formatter(COMA); a2.yaxis.set_major_formatter(COMA)
for a in (a1, a2):
    for s in ("top", "right"): a.spines[s].set_visible(False)
plt.tight_layout(); fig.savefig(f"{FIG}/fig_6_digitos_98.png", dpi=150); plt.close(fig)
print("figuras listas")
