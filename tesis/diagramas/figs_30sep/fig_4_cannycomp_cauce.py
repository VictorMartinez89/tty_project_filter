#!/opt/anaconda3/bin/python
# fig_4_cannycomp_cauce.py — rehace tesis/figuras/fig_4_cannycomp_cauce.png (30-sep).
# Copia de la Parte 159 de conda/TTY_Filter_Sobel/TTY_Filter_Sobel.ipynb (celda 458) con los
# textos corregidos: español con tildes, «×», sin título interno, sin «line-buf».
import os, matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch, FancyArrowPatch
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "figuras", "fig_4_cannycomp_cauce.png")

fig, ax = plt.subplots(figsize=(13.2, 3.3)); ax.axis("off")
plt.subplots_adjust(left=0.005, right=0.995, top=0.99, bottom=0.01)
ax.set_xlim(0, 20.9); ax.set_ylim(1.5, 5.6)

boxes = [
    ("gris\n(entrada)",                 "#dfeffd", "#2980b9", ""),
    ("gaussiano 3×3\n(memoria de línea)", "#eafaf1", "#16a085", "elimina ruido"),
    ("Sobel 3×3\n(memoria de línea)",     "#fdf2e2", "#e67e22", "gradiente |Gx|+|Gy|"),
    ("doble umbral\n0 / 1 / 2",         "#f3e8fb", "#8e44ad", "fuerte / débil / nada"),
    ("histéresis\nde un salto",         "#fdeaea", "#c0392b", "el débil se salva\nsi toca a un fuerte"),
    ("borde\n0xFF / 0x00",              "#d5f5e3", "#27ae60", "binario: 1 bit"),
]
x = 0.4; w = 2.9; gap = 0.55; y = 2.6
centers = []
for i, (lab, fc, ec, note) in enumerate(boxes):
    ax.add_patch(FancyBboxPatch((x, y), w, 1.7, boxstyle="round,pad=0.05,rounding_size=0.12",
                                lw=1.8, edgecolor=ec, facecolor=fc))
    ax.text(x+w/2, y+0.85, lab, ha="center", va="center", fontsize=8.6, fontweight="bold")
    if note: ax.text(x+w/2, y-0.25, note, ha="center", va="top",
                     fontsize=7.2, color=ec, style="italic")
    centers.append(x+w/2)
    if i < len(boxes)-1:
        ax.add_patch(FancyArrowPatch((x+w, y+0.85), (x+w+gap, y+0.85),
                     arrowstyle="-|>", mutation_scale=14, lw=1.9, color="#2d3436"))
    x += w + gap

# marcas de memorias de línea (las 3 etapas con memoria de fila)
for idx in (1, 2, 4):
    ax.text(centers[idx], 4.75, "memoria de línea", ha="center", fontsize=7.0, color="#555")
    ax.plot([centers[idx]-0.9, centers[idx]+0.9], [4.55, 4.55], color="#999", lw=1.0)
ax.text(10.45, 5.25, "3 memorias de línea ≈ 8 ciclos de latencia (frente a 1 del Sobel)",
        ha="center", fontsize=8.4, color="#333", fontweight="bold")
fig.savefig(OUT, dpi=100, bbox_inches="tight", pad_inches=0.1)
print("escrito", os.path.abspath(OUT))
