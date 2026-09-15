# === Cuaderno 2 · figura 37: Sobel contra Canny en silicio, en cuatro niveles ===
#   Los tres primeros son MEDIDOS (chips #1-#4, #9-#10 de la tesis, sky130).
#   El cuarto es la estimacion del reconocedor para Tiny Tapeout (§28).
import numpy as np, matplotlib.pyplot as plt
from matplotlib.gridspec import GridSpec

NIV = [("filtro\nsolo",        4651, 10284, True),
       ("+ CPU",               9906, 22054, True),
       ("sistema completo\ncámara + filtro\n+ framebuffer + LCD", 35653, 41925, True),
       ("reconocedor\n(estimado, §28)", 14540, 15850, False)]
CS, CC = "#546e7a", "#66bb6a"

fig = plt.figure(figsize=(15.0, 6.4))
gs = GridSpec(1, 2, figure=fig, width_ratios=[1.45, 1], wspace=.26)

# ═══ A · celdas lado a lado ═══
ax = fig.add_subplot(gs[0, 0])
x = np.arange(4); w = .36
ax.bar(x-w/2, [n[1] for n in NIV], w, color=CS, ec="#37474f", lw=.8, label="Sobel")
ax.bar(x+w/2, [n[2] for n in NIV], w, color=CC, ec="#37474f", lw=.8, label="Canny 1-salto")
for i,(n,s,c,med) in enumerate(NIV):
    ax.text(i, max(s,c)+1300, f"{c/s:.2f}×", ha="center", fontsize=12, weight="bold",
            color="#c62828" if c/s > 1.5 else "#2e7d32")
    if not med:
        ax.text(i, -3400, "estimado", ha="center", fontsize=7.6, color="#90a4ae", style="italic")
ax.set_xticks(x); ax.set_xticklabels([n[0] for n in NIV], fontsize=8.8, linespacing=1.45)
ax.set_ylabel("celdas estándar sky130", fontsize=10.5)
ax.set_ylim(-4500, 47000); ax.grid(axis="y", alpha=.28); ax.legend(fontsize=9.6)
for s_ in ("top","right"): ax.spines[s_].set_visible(False)
ax.set_title("A · El sobrecosto del Canny se DILUYE conforme crece el sistema",
             fontsize=11.6, weight="bold", pad=12)

# ═══ B · el factor, cayendo ═══
ax = fig.add_subplot(gs[0, 1])
f = [n[2]/n[1] for n in NIV]
ax.plot(range(3), f[:3], "o-", color="#c62828", lw=3.0, ms=12, zorder=3)
ax.plot([2,3], f[2:], "o--", color="#c62828", lw=2.0, ms=11, alpha=.5, zorder=3)
for i,v in enumerate(f):
    ax.text(i, v+.075, f"{v:.2f}×", ha="center", fontsize=11.5, weight="bold", color="#c62828")
    ax.text(i, v-.10, f"+{100*(v-1):.0f} %", ha="center", fontsize=9, color="#78909c")
ax.axhline(1.0, color="#2e7d32", lw=2.0, ls="--")
ax.text(3.35, 1.03, "empate", ha="right", fontsize=9.4, color="#2e7d32", weight="bold")
ax.set_xticks(range(4))
ax.set_xticklabels(["filtro\nsolo","+ CPU","sistema\ncompleto","reconocedor\n(est.)"],
                   fontsize=8.8, linespacing=1.45)
ax.set_ylabel("cuánto más grande es el Canny", fontsize=10.5)
ax.set_ylim(.85, 2.55); ax.grid(axis="y", alpha=.28)
for s_ in ("top","right"): ax.spines[s_].set_visible(False)
ax.set_title("B · De 2.21× a 1.18×:\nla penalización se evapora", fontsize=11.6,
             weight="bold", pad=12, linespacing=1.5)
ax.annotate("", xy=(2,1.20), xytext=(1,2.20),
            arrowprops=dict(arrowstyle="-|>", color="#c62828", lw=2.6, alpha=.35,
                            connectionstyle="arc3,rad=.25"))

fig.text(.5, -.05, "En el sistema completo el filtro es solo el 13 % del chip (4 651 de 35 653): "
         "duplicarlo agrega un 18 %, no un 121 %.\n"
         "El Sobel gana en área SOLO cuando el filtro ES el chip.",
         ha="center", fontsize=10.4, weight="bold", color="#263238", linespacing=1.6)
plt.savefig("fig_quien_gana.png", dpi=140, bbox_inches="tight")
print("ok ·", " ".join(f"{n[2]/n[1]:.2f}x" for n in NIV))
