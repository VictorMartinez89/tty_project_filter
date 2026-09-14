# === Cuaderno 2 · figura 19: la jerarquia de 3Blue1Brown, esperada vs construida ===
import numpy as np, matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch

fig, axes = plt.subplots(1, 2, figsize=(15.6, 8.4))
GRIS="#cfd8dc"; TXT="#263238"; SUB="#546e7a"

def columna(ax, x, n, y0, y1, color, r=.030, puntos=True):
    ys = np.linspace(y1, y0, n)
    for yy in ys:
        ax.add_patch(plt.Circle((x, yy), r, fc="#fff", ec=color, lw=1.6, zorder=3))
    if puntos:
        ax.text(x, (y0+y1)/2, "⋮", ha="center", va="center", fontsize=15, color=color, zorder=4,
                bbox=dict(fc="#fff", ec="none", pad=1.5))
    return ys

def conectar(ax, xs, ys1, ys2, color, alpha=.13, lw=.5):
    for a in ys1:
        for b in ys2:
            ax.plot([xs[0], xs[1]], [a, b], color=color, alpha=alpha, lw=lw, zorder=1)

def etiqueta(ax, x, t, sub, color, y=.055):
    ax.text(x, y+.045, t, ha="center", fontsize=10.0, weight="bold", color=color)
    ax.text(x, y-.035, sub, ha="center", va="top", fontsize=7.8, color=SUB, linespacing=1.55)

# ══════════════ A · el MLP de 3Blue1Brown ══════════════
ax = axes[0]; ax.set_xlim(0, 1); ax.set_ylim(0, 1); ax.axis("off")
ax.set_title("A · La red de 3Blue1Brown  —  la jerarquía que se ESPERA\n"
             "784 → 16 → 16 → 10,  13 002 parámetros",
             fontsize=11.6, weight="bold", color=TXT, pad=16, linespacing=1.6)
X = [.10, .37, .63, .90]
c0 = columna(ax, X[0], 9, .18, .82, "#78909c")
c1 = columna(ax, X[1], 7, .25, .75, "#5c6bc0")
c2 = columna(ax, X[2], 7, .25, .75, "#5c6bc0")
c3 = columna(ax, X[3], 10, .17, .83, "#c62828", puntos=False)
conectar(ax, X[0:2], c0, c1, "#90a4ae"); conectar(ax, X[1:3], c1, c2, "#7986cb")
conectar(ax, X[2:4], c2, c3, "#7986cb")
etiqueta(ax, X[0], "784 píxeles", "la imagen", "#455a64")
etiqueta(ax, X[1], "16 neuronas", "«¿bordes?»", "#5c6bc0")
etiqueta(ax, X[2], "16 neuronas", "«¿trazos, bucles?»", "#5c6bc0")
etiqueta(ax, X[3], "10 salidas", "el dígito", "#c62828")
for x in (X[1], X[2]):
    ax.text(x, .843, "?", ha="center", fontsize=22, color="#ef5350", weight="bold")
ax.add_patch(FancyBboxPatch((.055, .885), .89, .085, boxstyle="round,pad=0.012",
             fc="#ffebee", ec="#ef9a9a", lw=1.3, zorder=0))
ax.text(.5, .928, "Sanderson plantea esta jerarquía como una ESPERANZA — y después muestra\n"
        "que la red entrenada NO se organiza así: los pesos parecen ruido.",
        ha="center", va="center", fontsize=8.6, color="#b71c1c", linespacing=1.6, zorder=2)

# ══════════════ B · el circuito de la tesis ══════════════
ax = axes[1]; ax.set_xlim(0, 1); ax.set_ylim(0, 1); ax.axis("off")
ax.set_title("B · El circuito de esta tesis  —  la misma jerarquía, CONSTRUIDA\n"
             "784 → 32 → 40 → 10,  400 pesos de 4 bits",
             fontsize=11.6, weight="bold", color=TXT, pad=16, linespacing=1.6)
c0 = columna(ax, X[0], 9, .18, .82, "#78909c")
c1 = columna(ax, X[1], 8, .23, .77, "#2e7d32")
c2 = columna(ax, X[2], 8, .23, .77, "#f9a825")
c3 = columna(ax, X[3], 10, .17, .83, "#c62828", puntos=False)
# las dos primeras flechas NO son pesos: son operadores fijos
for a, b in zip(c0[:8], c1):
    ax.annotate("", xy=(X[1]-.035, b), xytext=(X[0]+.035, a),
                arrowprops=dict(arrowstyle="-", color="#2e7d32", lw=.9, alpha=.35))
for a, b in zip(c1, c2):
    ax.annotate("", xy=(X[2]-.035, b), xytext=(X[1]+.035, a),
                arrowprops=dict(arrowstyle="-", color="#f9a825", lw=1.4, alpha=.55))
conectar(ax, X[2:4], c2, c3, "#c62828", alpha=.20, lw=.6)
etiqueta(ax, X[0], "784 píxeles", "la imagen", "#455a64")
etiqueta(ax, X[1], "32 contadores", "BORDES por octante y zona\nSobel/Canny — CABLEADO", "#2e7d32")
etiqueta(ax, X[2], "40 rasgos", "FORMA: pirámide espacial\nnivel 0 DERIVADO — CABLEADO", "#f9a825")
etiqueta(ax, X[3], "10 puntajes", "el dígito\nMAC 4 bits — APRENDIDO", "#c62828")
for x, t in ((X[1], "Sobel\n1968"), (X[2], "suma de\ncuadrantes")):
    ax.text(x, .838, t, ha="center", fontsize=7.6, color="#33691e", weight="bold", linespacing=1.4)
ax.add_patch(FancyBboxPatch((.055, .885), .89, .085, boxstyle="round,pad=0.012",
             fc="#e8f5e9", ec="#a5d6a7", lw=1.3, zorder=0))
ax.text(.5, .928, "Acá la jerarquía SÍ ocurre — porque no se esperó que emergiera: se escribió.\n"
        "Las dos primeras capas no tienen un solo peso entrenado.",
        ha="center", va="center", fontsize=8.6, color="#1b5e20", linespacing=1.6, zorder=2)
for xl, cl in ((.245, "#2e7d32"), (.505, "#f9a825"), (.765, "#c62828")):
    ax.plot([xl, xl], [.185, .795], color=cl, lw=1.1, ls=":")
ax.text(.765, .158, "↑ la ÚNICA capa entrenada", ha="center", fontsize=8.2, color="#c62828",
        weight="bold")
ax.text(.375, .158, "↑ sin un solo peso: aritmética fija", ha="center", fontsize=8.2,
        color="#2e7d32", weight="bold")

fig.text(.5, .022, "13 002 parámetros en coma flotante (52 KB)   vs   400 pesos de 4 bits "
         "+ 10 sesgos  =  220 BYTES        ·        236× menos memoria, 3 puntos menos de exactitud",
         ha="center", fontsize=10.2, color=TXT, weight="bold",
         bbox=dict(fc="#eceff1", ec="#b0bec5", lw=1.1, boxstyle="round,pad=0.55"))
plt.tight_layout(rect=[0, .065, 1, 1])
plt.savefig("fig_jerarquia_3b1b.png", dpi=140, bbox_inches="tight")
print("ok  ·  MLP:", 784*16+16 + 16*16+16 + 16*10+10, "params")
