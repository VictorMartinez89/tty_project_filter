#!/opt/anaconda3/bin/python
# fig_4_visioncanny_cauces.py — rehace tesis/figuras/fig_4_visioncanny_cauces.png (30-sep).
# Copia de la Parte 128 de conda/TTY_Filter_Sobel/TTY_Filter_Sobel.ipynb (celda 365) con los
# textos corregidos (sin «fase N», tildes, «×», «memoria de línea») y la última caja dentro
# de los ejes (antes quedaba fuera del xlim y salía sin borde).
import os, matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch, FancyArrowPatch
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "figuras", "fig_4_visioncanny_cauces.png")

XMAX = 19.8
fig, (axT, axB) = plt.subplots(2, 1, figsize=(13.0, 5.2))
for ax in (axT, axB): ax.axis("off"); ax.set_xlim(0, XMAX); ax.set_ylim(0, 3)

def draw(ax, stages, title, tc):
    ax.text(0.1, 2.6, title, fontsize=10.5, fontweight="bold", color=tc)
    x = 0.3; prev = None
    for i, (t, fc, ec) in enumerate(stages):
        w = 2.5 if max(len(s) for s in t.split("\n")) > 13 else 2.1
        ax.add_patch(FancyBboxPatch((x, 0.7), w, 1.3, boxstyle="round,pad=0.04,rounding_size=0.10",
                     lw=1.5, edgecolor=ec, facecolor=fc))
        ax.text(x+w/2, 1.35, t, ha="center", va="center", fontsize=7.8, fontweight="bold")
        if prev is not None:
            ax.add_patch(FancyArrowPatch((prev, 1.35), (x, 1.35), arrowstyle="-|>", mutation_scale=11, lw=1.4, color="#2d3436"))
        prev = x+w; x += w+0.55
    return prev

LB="#d6eaf8"; LBE="#2980b9"; OP="#eafaf0"; OPE="#16a085"; FB="#f9d7d2"; FBE="#c0392b"
draw(axT, [("cámara\n60×80", "#fff3cd", "#e67e22"),
           ("memoria de línea\ndel Sobel (1 juego)", LB, LBE),
           ("|Gx|+|Gy|\n> umbral", OP, OPE),
           ("framebuffer\n(binario)", FB, FBE),
           ("pantalla", "#d5f5e3", "#27ae60")],
     "vision_top — Sobel: 1 juego de memorias de línea", "#0984e3")

end = draw(axB, [("cámara\n60×80", "#fff3cd", "#e67e22"),
           ("memoria de línea\ndel gaussiano", LB, LBE),
           ("memoria de línea\ndel Sobel", LB, LBE),
           ("doble umbral +\nmemoria de línea\nde la clase", LB, LBE),
           ("histéresis\nde un salto", OP, OPE),
           ("framebuffer\n(binario)", FB, FBE),
           ("pantalla", "#d5f5e3", "#27ae60")],
     "vision_canny_top — Canny: 3 juegos de memorias de línea (bordes más limpios)", "#8e44ad")
assert end < XMAX, end

axB.text(XMAX/2, 0.15, "Mismo esqueleto (cámara + framebuffer + pantalla); cambia el camino de datos: "
         "1 filtro 3×3 → cauce Canny de 3 etapas.",
         ha="center", fontsize=8.2, style="italic", color="#636e72")
plt.tight_layout()
fig.savefig(OUT, dpi=100, bbox_inches="tight", pad_inches=0.1)
print("escrito", os.path.abspath(OUT))
