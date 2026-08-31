#!/usr/bin/env python3
# fig_piramide.py — precision vs flip-flops: donde el clasificador de digitos cabe en silicio.
import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt

DAT = {"nivel 0 (bolsa pura)":      (80,   {8:63.2, 4:61.1, 2:36.5, 1:31.0}),
       "nivel 0+1 (5 zonas)":       (400,  {8:94.6, 4:94.2, 2:86.7, 1:74.2}),
       "nivel 0+1+2 (21 zonas)":    (1680, {8:98.1, 4:98.1, 2:96.1, 1:88.7})}
COL = {"nivel 0 (bolsa pura)":"#c0392b", "nivel 0+1 (5 zonas)":"#16a085", "nivel 0+1+2 (21 zonas)":"#8e44ad"}
PRESU = 2200        # flip-flops disponibles en un proyecto de 8x2 tiles (medido, Parte 167)

fig, ax = plt.subplots(figsize=(9.6, 6.0))
ax.axvspan(1, PRESU, color="#2ecc71", alpha=0.07)
ax.axvline(PRESU, color="#27ae60", lw=2, ls="--")
ax.text(PRESU*0.93, 21.5, "presupuesto real de un chip 8x2\n~2 200 flip-flops (Parte 167)",
        ha="right", va="bottom", fontsize=9, color="#27ae60", fontweight="bold")

for etq,(pesos,accs) in DAT.items():
    xs = [pesos*b for b in sorted(accs)]; ys = [accs[b] for b in sorted(accs)]
    ax.plot(xs, ys, "o-", color=COL[etq], lw=2.2, ms=7, label=etq)
    for b in sorted(accs):
        ax.annotate(f"{b}b", (pesos*b, accs[b]), textcoords="offset points",
                    xytext=(6,-11), fontsize=8, color=COL[etq], fontweight="bold")

ax.plot([7840*8], [91.9], "k*", ms=17, zorder=5)
ax.annotate("784 pixeles crudos + lineal\n91.9 % — 7 840 pesos (62 720 FF)",
            (7840*8, 91.9), textcoords="offset points", xytext=(0, -34),
            ha="center", fontsize=9, fontweight="bold")

ax.annotate("400 pesos a 4 bits = 1 600 FF  ->  94.2 %\nmejor que los 784 pixeles crudos,\ncon 19.6x menos pesos, y CABE",
            (400*4, 94.2), xytext=(45, 74), textcoords="data",
            fontsize=10, fontweight="bold", color="#16a085", ha="center",
            arrowprops=dict(arrowstyle="->", color="#16a085", lw=1.8,
                            connectionstyle="arc3,rad=-0.12"))
ax.annotate("a igual presupuesto (~1 600 FF):\nmenos zonas con mas bits (94.2 %)\nle gana a mas zonas con 1 bit (88.7 %)",
            (1680, 88.7), xytext=(60, 45), textcoords="data",
            fontsize=9, color="#8e44ad", ha="center",
            arrowprops=dict(arrowstyle="->", color="#8e44ad", lw=1.4,
                            connectionstyle="arc3,rad=0.2"))

ax.set_xscale("log"); ax.set_xlabel("flip-flops de pesos  (pesos x bits)", fontsize=11)
ax.set_ylabel("precision sobre MNIST test (%)", fontsize=11)
ax.set_title("Clasificador de digitos sobre el front-end de la tesis (Gauss->Sobel->8 orientaciones)\n"
             "piramide espacial x bits por peso: lo que cabe en silicio y lo que no",
             fontsize=12.4, fontweight="bold")
ax.grid(alpha=0.25); ax.legend(loc="upper left", fontsize=10, framealpha=0.95); ax.set_ylim(20, 102)
plt.tight_layout(); plt.savefig("piramide_mnist.png", dpi=140)
print("-> piramide_mnist.png")
