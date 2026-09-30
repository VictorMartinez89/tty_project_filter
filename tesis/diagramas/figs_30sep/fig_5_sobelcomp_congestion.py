#!/opt/anaconda3/bin/python
# fig_5_sobelcomp_congestion.py — rehace tesis/figuras/fig_5_sobelcomp_congestion.png (30-sep).
# Copia de la Parte 158 de conda/TTY_Filter_Sobel/TTY_Filter_Sobel.ipynb (celda 454) con los
# textos corregidos: tildes, «dado», «núcleo», «×», decimales con coma, mm².
import os, matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.ticker import FuncFormatter
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "figuras", "fig_5_sobelcomp_congestion.png")
coma = lambda v, d: f"{v:.{d}f}".replace(".", ",")

fig, (axL, axR) = plt.subplots(1, 2, figsize=(12.6, 4.7))

# --- izquierda: colapso de violaciones DRC en el enrutado detallado ---
vals = [954332, 1]  # 1 = marcador visible para «0» en escala logarítmica
axL.bar([0, 1], vals, color=["#c0392b", "#27ae60"], edgecolor="#333", log=True, width=0.6)
axL.set_xticks([0, 1]); axL.set_xticklabels(["utilización 35 %\nframebuffer de 8 bits", "utilización 15 %\nframebuffer de 1 bit"], fontsize=9)
axL.set_ylabel("violaciones DRC (escala logarítmica)", fontsize=10)
axL.set_title("El framebuffer de 1 bit eliminó la congestión", fontsize=11, fontweight="bold")
axL.text(0, 954332*1.6, "954 332", ha="center", fontsize=10, fontweight="bold", color="#c0392b")
axL.text(1, 2.2, "0", ha="center", fontsize=12, fontweight="bold", color="#1e8449")
axL.set_ylim(0.5, 5_000_000)
for s in ("top", "right"): axL.spines[s].set_visible(False)

# --- derecha: área del dado, núcleo a secas frente a la cadena completa ---
areas = [0.16, 2.447]
axR.bar([0, 1], areas, color=["#0984e3", "#8e44ad"], edgecolor="#333", width=0.6)
axR.set_xticks([0, 1]); axR.set_xticklabels(["núcleo Sobel\n(a secas)", "Sobel completo\n(cadena que ve)"], fontsize=9)
axR.set_ylabel("área del dado (mm²)", fontsize=10)
axR.set_title("El chip que ve es ≈ 15× el núcleo", fontsize=11, fontweight="bold")
for i, v in enumerate(areas): axR.text(i, v+0.06, f"{coma(v, 2)} mm²", ha="center", fontsize=9.5, fontweight="bold")
axR.set_ylim(0, 2.8)
axR.yaxis.set_major_formatter(FuncFormatter(lambda v, p: coma(v, 1)))
for s in ("top", "right"): axR.spines[s].set_visible(False)

plt.tight_layout()
fig.savefig(OUT, dpi=100, bbox_inches="tight", pad_inches=0.1)
print("escrito", os.path.abspath(OUT))
