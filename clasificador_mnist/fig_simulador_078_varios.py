#!/usr/bin/env python3
"""fig_simulador_078_varios.py — la cadena del 97,22 % sobre MUCHOS 0, 3 y 7, no sobre uno.

fig_simulador_078.py enseña un ejemplar de cada digito, el primero del test, y los tres aciertan.
Eso halaga al clasificador. Esta figura enseña los tres comportamientos que tiene de verdad:

  verde  · acierta y habla        (el caso normal)
  gris   · se calla (dice NADA)   bordes fuera de [174, 376] o margen <= 70
  rojo   · se equivoca            con el digito que dijo

Los aciertos se eligen repartidos por margen (del mas justo al mas holgado), para que se vea la
variedad de trazos que acepta, y no los cinco mas faciles. Los errores y los silencios son los de
MENOR margen primero. Los errores van al reves: primero los que HABLAN y fallan, del mas
seguro al menos, porque esos son los que el umbral NO atrapo; despues los que se callan.

Los numeros de la derecha se cuentan sobre TODOS los ejemplares del test de ese digito.
Los pesos son los del RTL verificado (pesos_sel78.npz).
"""
import numpy as np, warnings; warnings.filterwarnings("ignore")
import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt
import frente_golden as fg
from canny1_mnist import frente_canny1

HI, LO = 90, 32
DIGITOS = [0, 3, 7]
N_OK, N_CALLA, N_MAL = 6, 3, 4
B_MIN, B_MAX, MARGEN = 174, 376, 70
VERDE, GRIS, ROJO = "#1e7a3c", "#7f8c8d", "#c0392b"

p = np.load("pesos_sel78.npz"); W, b, idx = p["W"], p["b"], p["idx"]
_, _, Xte, yte = fg.cargar_mnist()
m, o = frente_canny1(Xte, HI, LO)
S = fg.piramide(m, o, 2)[:, idx] @ W.T + b
gan = S.argmax(1); ss = np.sort(S, 1); mar = ss[:, -1] - ss[:, -2]
nb = m.sum(axis=(1, 2))
habla = (nb >= B_MIN) & (nb <= B_MAX) & (mar > MARGEN)
print(f"  exactitud sobre las 10 000: {(gan == yte).mean():.2%}   (debe dar 97,22 %)")


def por_que_calla(i):
    if nb[i] < B_MIN: return f"pocos bordes ({nb[i]})"
    if nb[i] > B_MAX: return f"muchos bordes ({nb[i]})"
    return f"margen {int(mar[i])}"


ncol = N_OK + N_CALLA + N_MAL
fig = plt.figure(figsize=(1.35 * ncol + 3.6, 1.75 * len(DIGITOS) + 0.9))
gs = fig.add_gridspec(len(DIGITOS), ncol + 1, width_ratios=[1] * ncol + [2.6],
                      wspace=0.12, hspace=0.55)
for r, d in enumerate(DIGITOS):
    k = np.where(yte == d)[0]
    ok = k[habla[k] & (gan[k] == d)]
    ok = ok[np.argsort(mar[ok])]
    ok = ok[np.linspace(0, len(ok) - 1, N_OK).round().astype(int)]     # repartidos por margen
    calla = k[~habla[k]]; calla = calla[np.argsort(mar[calla])][:N_CALLA]
    mal = k[gan[k] != d]
    # primero los que HABLAN y fallan (los peligrosos), del mas seguro al menos; luego los callados
    mal = mal[np.lexsort((-mar[mal], ~habla[mal]))][:N_MAL]

    casos = ([(i, VERDE, f"dice {d} · m{int(mar[i])}") for i in ok] +
             [(i, GRIS, "NADA\n" + por_que_calla(i)) for i in calla] +
             [(i, ROJO, f"dice {gan[i]}" + ("" if habla[i] else " (calla)")
               + f"\nm{int(mar[i])}") for i in mal])
    for c, (i, color, txt) in enumerate(casos):
        ax = fig.add_subplot(gs[r, c])
        ax.imshow(Xte[i], cmap="gray_r", interpolation="nearest")
        ax.set_xticks([]); ax.set_yticks([])
        for sp in ax.spines.values(): sp.set_color(color); sp.set_linewidth(2.2)
        ax.set_title(txt, fontsize=7.5, color=color, pad=3)

    ax = fig.add_subplot(gs[r, ncol]); ax.axis("off")
    n = len(k); conf = np.bincount(gan[k][gan[k] != d], minlength=10)
    top = [f"{j} ({conf[j]})" for j in np.argsort(-conf)[:3] if conf[j]]
    ax.text(0.02, 0.95,
            f"los {n} «{d}» del test\n\n"
            f"acierta   {(gan[k] == d).mean():6.2%}\n"
            f"habla     {habla[k].mean():6.2%}\n"
            f"  y acierta {(habla[k] & (gan[k] == d)).sum():4d}\n"
            f"  y falla   {(habla[k] & (gan[k] != d)).sum():4d}\n\n"
            f"lo confunde con\n  " + ", ".join(top),
            va="top", ha="left", fontsize=8.5, family="monospace", transform=ax.transAxes)

fig.suptitle("La cadena del 97,22 % sobre muchos 0, 3 y 7 del test  ·  "
             "verde acierta · gris se calla (NADA) · rojo se equivoca  ·  m = margen (umbral 70)",
             fontsize=10.5, x=0.012, ha="left", y=0.995)
fig.savefig("../tesis/figuras/fig_simulador_078_varios.png", dpi=170,
            facecolor="white", bbox_inches="tight")
print("  -> tesis/figuras/fig_simulador_078_varios.png")
