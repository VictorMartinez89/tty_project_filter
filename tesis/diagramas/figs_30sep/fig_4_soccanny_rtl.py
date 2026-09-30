#!/opt/anaconda3/bin/python
# fig_4_soccanny_rtl.py — rehace tesis/figuras/fig_4_soccanny_rtl.png (30-sep) con los rótulos corregidos.
# Origen: recorte de soc_grid_3x5.png (Parte 58 del cuaderno), cuyo generador no está en el repo.
# Se reconstruye desde los mismos datos de la simulación Icarus en ~/utm-share/sim_spram/:
#   foto   = <img>_160.hex      (160x120, 8 bits)
#   bordes = <img>_exp1.hex     (salida del SoC, modo 1; los 'xx' se pintan negros, como en el original)
# Verificado: coincide píxel a píxel con la figura anterior.
import os, numpy as np, matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
D = os.path.expanduser("~/utm-share/sim_spram")
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "figuras", "fig_4_soccanny_rtl.png")
IMGS = [("flower", "flower"), ("monarch", "monarch"), ("butterfly", "butterfly"),
        ("mano", "mano"), ("hi", "HOLA")]
ROWLAB = ["foto\n(cámara)", "Canny de un salto\n(modo 1)"]
def load(p):
    v = [l.strip() for l in open(p) if l.strip() and not l.startswith("//")][:19200]
    return np.array([int(t, 16) if "x" not in t.lower() else 0 for t in v], np.uint8).reshape(120, 160)
fig, axs = plt.subplots(2, 5, figsize=(13.26, 3.96), dpi=100)
for k, (f, tit) in enumerate(IMGS):
    for r, suf in enumerate(["_160", "_exp1"]):
        ax = axs[r, k]
        ax.imshow(load(os.path.join(D, f + suf + ".hex")), cmap="gray", vmin=0, vmax=255,
                  interpolation="nearest")
        ax.set_xticks([]); ax.set_yticks([])
        for s in ax.spines.values(): s.set_visible(False)
        if r == 0: ax.set_title(tit, fontsize=13)
        if k == 0:
            ax.set_ylabel(ROWLAB[r], fontsize=12, fontweight="bold", rotation=0,
                          ha="right", va="center", labelpad=12)
plt.subplots_adjust(left=0.155, right=0.995, top=0.915, bottom=0.02, wspace=0.07, hspace=0.2)
fig.savefig(OUT, dpi=100)
print("escrito", os.path.abspath(OUT))
