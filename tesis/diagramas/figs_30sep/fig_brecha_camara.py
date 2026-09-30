#!/opt/anaconda3/bin/python
# fig_brecha_camara.py — rehace tesis/figuras/fig_brecha_camara.png (30-sep).
# Copia de la parte gráfica de clasificador_mnist/brecha_camara.py, leyendo los resultados ya
# medidos (clasificador_mnist/brecha_camara.json) en vez de recalcular. Textos corregidos:
# tildes, decimales con coma, sin título interno (el pie de la Figura lo describe).
import os, json, matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.ticker import FuncFormatter
AQUI = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.join(AQUI, "..", "..", "..")
OUT = os.path.join(REPO, "tesis", "figuras", "fig_brecha_camara.png")
res = json.load(open(os.path.join(REPO, "clasificador_mnist", "brecha_camara.json")))
coma = lambda v, p=None: (f"{v:g}").replace(".", ",")

fig, ax = plt.subplots(1, 2, figsize=(11, 3.8))
for a, k, xl in [(ax[0], "desplazamiento", "desplazamiento del dígito (píxeles)"),
                 (ax[1], "escala", "escala del trazo")]:
    xs = [r[0] for r in res[k]]
    a.plot(xs, [100*r[1][0] for r in res[k]], "o-", color="#c0392b", label="tal cual (lo que ve la cámara)")
    a.plot(xs, [100*r[2][0] for r in res[k]], "s-", color="#1e7a3c", label="con normalizador tipo MNIST")
    a.axhline(10, color="#999", lw=0.8, ls=":"); a.text(xs[0], 11.5, "azar", fontsize=8, color="#777")
    a.set_xlabel(xl); a.set_ylabel("acierto (%)"); a.set_ylim(0, 100); a.grid(alpha=.3)
    a.xaxis.set_major_formatter(FuncFormatter(coma if k == "desplazamiento" else
                                              (lambda v, p=None: f"{v:.1f}".replace(".", ","))))
    for sp in ("top", "right"): a.spines[sp].set_visible(False)
ax[0].legend(fontsize=8, loc="lower left", bbox_to_anchor=(0.0, 0.14))
fig.tight_layout(); fig.savefig(OUT, dpi=170, facecolor="white")
print("escrito", os.path.abspath(OUT))
