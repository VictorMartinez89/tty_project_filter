# === Cuaderno 2 · figura 21: como funciona la piramide espacial, y por que hace falta ===
import numpy as np, sys
import matplotlib.pyplot as plt
from matplotlib.gridspec import GridSpec
from matplotlib.patches import Rectangle
sys.path.insert(0, "../../clasificador_mnist")
import frente_golden as fg

B = "../../clasificador_mnist/"
X, y, Xt, yt = fg.cargar_mnist(B + "mnist.npz")
d = np.load(B + "piramide_6vs9.npz"); f6, f9 = d["f6"], d["f9"]
def dif(a, b): return np.abs(a-b).sum() / ((a.sum()+b.sum())/2) * 100

img6 = X[np.where(y == 6)[0][0]]; img9 = X[np.where(y == 9)[0][0]]
C6, C9 = "#1565c0", "#c62828"

fig = plt.figure(figsize=(15.0, 9.2))
gs = GridSpec(2, 3, figure=fig, height_ratios=[1, 1.08], hspace=.40, wspace=.30)

# ═══════ fila 1: los tres niveles ═══════
NIV = [(0, 1, "nivel 0", "1 región: la imagen entera", "8 rasgos", "«bolsa de orientaciones»\nTIRA toda la posición"),
       (1, 2, "nivel 1", "2×2 = 4 regiones", "32 rasgos", "recupera la posición EN GRUESO\n← hasta acá llega el circuito"),
       (2, 4, "nivel 2", "4×4 = 16 regiones", "128 rasgos", "más fino, pero 4× el costo\nNO se construyó")]
for col, (L, n, tit, reg, nr, nota) in enumerate(NIV):
    ax = fig.add_subplot(gs[0, col])
    ax.imshow(img6, cmap="gray_r", extent=[0, 1, 0, 1])
    for i in range(1, n):
        ax.axhline(i/n, color="#e53935", lw=2.0); ax.axvline(i/n, color="#e53935", lw=2.0)
    ax.add_patch(Rectangle((0, 0), 1, 1, fc="none", ec="#e53935", lw=2.4))
    ax.set_xticks([]); ax.set_yticks([])
    ax.set_title(f"{tit}  ·  {reg}\n{nr}   =   {n*n} × 8 orientaciones",
                 fontsize=10.2, weight="bold", linespacing=1.6,
                 color="#263238" if L != 2 else "#78909c", pad=10)
    ax.text(.5, .028, nota, transform=ax.transAxes, ha="center", va="bottom", fontsize=8.2,
            color="#455a64" if L != 2 else "#90a4ae", linespacing=1.5,
            bbox=dict(fc="#fff", ec="none", alpha=.88, boxstyle="round,pad=0.30"))
    if L == 1:
        for s in ax.spines.values(): s.set(edgecolor="#2e7d32", linewidth=3.0)

fig.text(.5, .535, "la pirámide es la CONCATENACIÓN de los niveles:   8 + 32  =  40 rasgos   "
         "—   «qué trazos hay»  Y  «dónde están»",
         ha="center", fontsize=11.0, weight="bold", color="#1b5e20",
         bbox=dict(fc="#e8f5e9", ec="#a5d6a7", lw=1.2, boxstyle="round,pad=0.5"))

# ═══════ fila 2, A: el nivel 0 no separa ═══════
ax = fig.add_subplot(gs[1, 0])
w = .38; xs = np.arange(8)
ax.bar(xs-w/2, f6[:8], w, color=C6, label="seis (300 imgs)")
ax.bar(xs+w/2, f9[:8], w, color=C9, label="nueve (300 imgs)")
ax.set_xticks(xs); ax.set_xlabel("octante", fontsize=8.8); ax.set_ylabel("bordes (promedio)", fontsize=8.8)
ax.legend(fontsize=7.6, loc="upper right"); ax.tick_params(labelsize=7.4); ax.grid(axis="y", alpha=.25)
ax.set_title(f"A · NIVEL 0 solo — no los separa\ndifieren apenas {dif(f6[:8], f9[:8]):.1f} %",
             fontsize=10.2, weight="bold", color="#c62828", linespacing=1.5, pad=9)
ax.text(.47, .60, "octante 0:  56.0  vs  55.9\nprácticamente el MISMO número",
        transform=ax.transAxes, ha="center", va="center", linespacing=1.5,
        fontsize=8.0, color="#37474f",
        bbox=dict(fc="#fff3e0", ec="#ffb74d", lw=.9, boxstyle="round,pad=0.35"))

# ═══════ fila 2, B: el nivel 1 sí separa ═══════
ax = fig.add_subplot(gs[1, 1])
z6 = [f6[8+z*8:16+z*8].sum() for z in range(4)]; z9 = [f9[8+z*8:16+z*8].sum() for z in range(4)]
zs = np.arange(4)
ax.bar(zs-w/2, z6, w, color=C6); ax.bar(zs+w/2, z9, w, color=C9)
ax.set_xticks(zs); ax.set_xticklabels(["arr-izq", "arr-der", "aba-izq", "aba-der"], fontsize=8.0)
ax.set_ylabel("bordes por zona (promedio)", fontsize=8.8)
ax.tick_params(labelsize=7.4); ax.grid(axis="y", alpha=.25)
ax.set_title(f"B · NIVEL 1 — acá sí\ndifieren {dif(f6[8:], f9[8:]):.1f} %  ·  3.6× más",
             fontsize=10.2, weight="bold", color="#2e7d32", linespacing=1.5, pad=9)
ax.annotate("el 6 tiene la panza\nABAJO", xy=(3+w/2-.38, z6[3]), xytext=(2.1, z6[3]*1.17),
            fontsize=7.8, color=C6, ha="center", linespacing=1.4,
            arrowprops=dict(arrowstyle="->", color=C6, lw=1.2))
ax.set_ylim(0, max(z6+z9)*1.32)

# ═══════ fila 2, C: el costo medido ═══════
ax = fig.add_subplot(gs[1, 2])
niv = ["nivel 0\n8 rasgos", "nivel 0+1\n40 rasgos", "nivel 0+1+2\n168 rasgos"]
ff  = [80, 400, 1680]; ex4 = [61.1, 94.2, 98.1]
axb = ax.twinx()
axb.bar(range(3), ff, color="#cfd8dc", ec="#90a4ae", width=.55, zorder=1)
axb.set_ylabel("flip-flops", fontsize=8.8, color="#78909c"); axb.tick_params(labelsize=7.4, colors="#78909c"); axb.set_ylim(0, 2600)
axb.axhline(2200, color="#78909c", ls="--", lw=1.1)
axb.text(-0.42, 2250, "presupuesto 8×2 tiles", fontsize=6.8, color="#78909c", ha="left")
ax.plot(range(3), ex4, "o-", color="#2e7d32", lw=2.4, ms=9, zorder=3)
for i, v in enumerate(ex4):
    ax.text(i, v+2.2, f"{v:.1f} %", ha="center", fontsize=8.6, weight="bold", color="#2e7d32", zorder=4)
ax.set_xticks(range(3)); ax.set_xticklabels(niv, fontsize=8.0, linespacing=1.5)
ax.set_ylabel("exactitud a 4 bits", fontsize=8.8, color="#2e7d32")
ax.tick_params(labelsize=7.4, colors="#2e7d32"); ax.set_ylim(52, 108); ax.set_zorder(2); ax.patch.set_visible(False)
ax.set_title("C · el salto está en el nivel 1\n+33 puntos por 5× el área; +3.9 más cuesta 4× otra vez",
             fontsize=10.2, weight="bold", color="#263238", linespacing=1.5, pad=9)
ax.annotate("", xy=(1, 94.2), xytext=(0, 61.1),
            arrowprops=dict(arrowstyle="->", color="#2e7d32", lw=2.6, alpha=.30))
ax.text(.42, 76, "+33 pp", fontsize=10, weight="bold", color="#2e7d32", rotation=52)

fig.text(.5, .015, "medido en la Parte 167 del cuaderno 1 · el circuito guarda solo 32 contadores: "
         "el nivel 0 se DERIVA sumando los cuatro cuadrantes, y sale gratis",
         ha="center", fontsize=8.8, color="#546e7a", style="italic")
plt.savefig("fig_piramide_espacial.png", dpi=140, bbox_inches="tight")
print(f"nivel0 {dif(f6[:8],f9[:8]):.1f} %  ·  nivel1 {dif(f6[8:],f9[8:]):.1f} %")
