#!/opt/anaconda3/bin/python
# fig_4_visiontrans_diagrama.py — rehace tesis/figuras/fig_4_visiontrans_diagrama.png (30-sep).
# Copia de la Parte 161 de conda/TTY_Filter_Sobel/TTY_Filter_Sobel.ipynb (celda 466) con los
# textos corregidos: tildes, «×», sin título interno, «motor», «máquina de estados», «dado».
import os, matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch, FancyArrowPatch
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "figuras", "fig_4_visiontrans_diagrama.png")

fig, ax = plt.subplots(figsize=(13.2, 4.8)); ax.axis("off")
ax.set_xlim(0, 21); ax.set_ylim(0, 7.0)

def box(x, y, w, h, lab, fc, ec, fs=8.6):
    ax.add_patch(FancyBboxPatch((x, y), w, h, boxstyle="round,pad=0.05,rounding_size=0.12", lw=1.8, edgecolor=ec, facecolor=fc))
    ax.text(x+w/2, y+h/2, lab, ha="center", va="center", fontsize=fs, fontweight="bold")

y0 = 4.6; h = 1.5
box(0.3, y0, 2.5, h, "cámara\nOV7670", "#dfeffd", "#2980b9")
box(3.2, y0, 2.7, h, "grad_class\ngaussiano → Sobel\n→ doble umbral", "#eafaf1", "#16a085", 8.0)
box(6.3, y0, 2.3, h, "clsfb\n60×80 × 2 bits", "#fdf2e2", "#e67e22", 8.2)
box(9.0, y0, 3.2, h, "motor transitivo\n(barre K veces)", "#f3e8fb", "#8e44ad", 8.4)
box(12.6, y0, 2.3, h, "edgefb\n60×80 × 1 bit", "#d5f5e3", "#27ae60", 8.2)
box(15.3, y0, 2.4, h, "LCD\nILI9341", "#eaf4fb", "#2471a3")
box(18.1, y0, 2.5, h, "pantalla\nTFT", "#dfeffd", "#2980b9")

for x in [2.8, 5.9, 8.6, 12.2, 14.9, 17.7]:
    ax.add_patch(FancyArrowPatch((x, y0+h/2), (x+0.35, y0+h/2), arrowstyle="-|>", mutation_scale=13, lw=1.9, color="#2d3436"))

# etiquetas de dato
ax.text(2.95, y0+h+0.35, "gris 8 bits", fontsize=7.6, color="#2471a3")
ax.text(5.95, y0+h+0.35, "clase 2 bits", fontsize=7.6, color="#16a085")
ax.text(12.25, y0+h+0.35, "borde 1 bit", fontsize=7.6, color="#27ae60")

# el bucle del motor (debajo)
ax.add_patch(FancyBboxPatch((7.9, 1.2), 5.4, 2.4, boxstyle="round,pad=0.06,rounding_size=0.12",
             lw=1.4, edgecolor="#8e44ad", facecolor="#faf3fe", linestyle=(0, (4, 3))))
ax.text(10.6, 3.2, "bucle del motor: puente (máquina de estados)", ha="center", fontsize=8.0, color="#6c3483", fontweight="bold")
ax.text(10.6, 2.35, "E_RST → E_WLOAD → E_LOAD → E_READ\nreinicio → espera → carga → barre y lee",
        ha="center", fontsize=7.8, color="#4a235a")
ax.add_patch(FancyArrowPatch((10.6, 3.9), (10.6, 3.65), arrowstyle="-|>", mutation_scale=12, lw=1.5, color="#8e44ad"))

# nota memoria
ax.text(10.6, 0.5, "clsfb (2 bits) + edgefb (1 bit) + memoria del motor (cuadro con borde de 62×82 × 2 bits) = "
        "biestables (sin BRAM en el ASIC): el dado más grande de la tesis",
        ha="center", fontsize=7.8, color="#c0392b", style="italic")
plt.tight_layout()
fig.savefig(OUT, dpi=100, bbox_inches="tight", pad_inches=0.1)
print("escrito", os.path.abspath(OUT))
