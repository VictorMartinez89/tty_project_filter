# === Cuaderno 2 · figura 19: los 40 rasgos, dibujados uno por uno ===
#   Cada rasgo es una pregunta: "cuantos pixeles de borde con ESTA orientacion hay en ESTA zona".
#   El relleno de cada icono es la cuenta real del 7 de la figura 18.
import numpy as np, re, sys
import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle, FancyArrowPatch, FancyBboxPatch
sys.path.insert(0, "../../clasificador_mnist")
import frente_golden as fg

B = "../../clasificador_mnist/"
X, y, Xt, yt = fg.cargar_mnist(B + "mnist.npz")
masc, ori = fg.frente(Xt[0]); masc, ori = masc[0], ori[0]
cnt32 = fg.contadores(masc, ori)
f40 = fg.descriptor(cnt32).astype(int)
mx = f40.max()

# octante -> angulo del GRADIENTE (grados).  bin = sy*4 + sx*2 + (|Gy|>|Gx|)
ANG = {0:202.5, 1:247.5, 2:337.5, 3:292.5, 4:157.5, 5:112.5, 6:22.5, 7:67.5}
CZ  = ["#1e88e5", "#43a047", "#fb8c00", "#8e24aa"]
NIV0 = "#37474f"

fig, ax = plt.subplots(figsize=(15.2, 11.4))
ax.set_xlim(0, 100); ax.set_ylim(0, 108); ax.axis("off"); ax.set_aspect("equal")

def icono(cx, cy, s, oct_, zona, k, val, col):
    """Un rasgo: el marco de la imagen, la zona sombreada, el trazo y el gradiente."""
    h = s / 2
    inten = val / mx if mx else 0
    ax.add_patch(Rectangle((cx-h, cy-h), s, s, fc="#fff", ec="#b0bec5", lw=.9, zorder=2))
    if zona is None:
        ax.add_patch(Rectangle((cx-h, cy-h), s, s, fc=col, alpha=.10+.55*inten, ec="none", zorder=3))
    else:
        zy, zx = zona // 2, zona % 2
        ax.add_patch(Rectangle((cx-h+zx*h, cy+h-(zy+1)*h), h, h,
                               fc=col, alpha=.12+.68*inten, ec="none", zorder=3))
        ax.plot([cx-h, cx+h], [cy, cy], color="#cfd8dc", lw=.7, zorder=4)
        ax.plot([cx, cx], [cy-h, cy+h], color="#cfd8dc", lw=.7, zorder=4)
    a = np.deg2rad(ANG[oct_]); e = a + np.pi/2      # el TRAZO es perpendicular al gradiente
    r = h * .62
    ax.plot([cx-r*np.cos(e), cx+r*np.cos(e)], [cy-r*np.sin(e), cy+r*np.sin(e)],
            color="#212121", lw=3.0, solid_capstyle="round", zorder=6)
    ax.add_patch(FancyArrowPatch((cx, cy), (cx+h*.46*np.cos(a), cy+h*.46*np.sin(a)),
                 arrowstyle="-|>", mutation_scale=7, color="#e53935", lw=1.3, zorder=7))
    ax.text(cx, cy-h-1.4, f"k={k}", ha="center", va="top", fontsize=6.6, color="#546e7a")
    ax.text(cx, cy+h+0.8, str(val), ha="center", va="bottom", fontsize=7.8,
            color=col if val > 0 else "#b0bec5", weight="bold")

# ═══ titulo ═══
ax.text(50, 106, "LOS 40 RASGOS, UNO POR UNO", ha="center", fontsize=15, weight="bold",
        color="#263238")
ax.text(50, 103, "cada rasgo es una pregunta:  «¿cuántos píxeles de borde con ESTA orientación "
        "hay en ESTA zona?»", ha="center", fontsize=9.8, color="#546e7a", style="italic")

# ═══ la leyenda, arriba del todo y sola ═══
lx, ly = 7.0, 93.0
ax.add_patch(FancyBboxPatch((lx, ly), 86, 7.6, boxstyle="round,pad=0.5",
             fc="#eceff1", ec="#b0bec5", lw=1.0, zorder=1))
ax.plot([lx+3.5, lx+8.0], [ly+5.0, ly+5.0], color="#212121", lw=3.0, solid_capstyle="round", zorder=3)
ax.text(lx+9.5, ly+5.0, "el TRAZO que se cuenta", va="center", fontsize=8.4, color="#212121", zorder=3)
ax.add_patch(FancyArrowPatch((lx+3.5, ly+2.2), (lx+8.0, ly+2.2), arrowstyle="-|>",
             mutation_scale=8, color="#e53935", lw=1.4, zorder=3))
ax.text(lx+9.5, ly+2.2, "el GRADIENTE (lo que mide el Sobel)",
        va="center", fontsize=8.4, color="#e53935", zorder=3)
ax.text(lx+40, ly+5.0, "el número de arriba = la cuenta REAL del 7 de la figura 18",
        va="center", fontsize=8.4, color="#37474f", zorder=3)
ax.text(lx+40, ly+2.2, "la intensidad del relleno = esa misma cuenta, de un vistazo",
        va="center", fontsize=8.4, color="#546e7a", zorder=3)

# ═══ nivel 0 ═══
ax.text(50, 88.5, "nivel 0  ·  k = 0…7  ·  LA IMAGEN ENTERA  —  no se cuentan: se DERIVAN "
        "sumando los cuatro cuadrantes", ha="center", fontsize=10.4, weight="bold", color=NIV0)
for b in range(8):
    icono(13.5 + b * 9.6, 81.0, 7.4, b, None, b, f40[b], NIV0)
ax.text(50, 73.2, f"y su suma es {f40[:8].sum()} = exactamente el total de píxeles de borde "
        "del cuadro", ha="center", fontsize=8.6, color=NIV0, style="italic")

ax.plot([6, 94], [70.0, 70.0], color="#cfd8dc", lw=1.1)
ax.text(50, 67.0, "nivel 1  ·  k = 8…39  ·  LOS 32 CONTADORES QUE EL CIRCUITO GUARDA DE VERDAD"
        "  —  ocho por zona", ha="center", fontsize=10.4, weight="bold", color="#455a64")

# ═══ nivel 1: cuatro bloques, colocados como las zonas ═══
BX = [(7.0, 33.0), (52.0, 33.0), (7.0, 1.5), (52.0, 1.5)]
NOM = ["z0 · arriba-izquierda", "z1 · arriba-derecha", "z2 · abajo-izquierda", "z3 · abajo-derecha"]
for z in range(4):
    bx, by = BX[z]
    ax.add_patch(FancyBboxPatch((bx, by), 41, 30, boxstyle="round,pad=0.5",
                 fc=CZ[z], ec="none", alpha=.055, zorder=0))
    ax.add_patch(FancyBboxPatch((bx, by), 41, 30, boxstyle="round,pad=0.5",
                 fc="none", ec=CZ[z], lw=1.4, zorder=1))
    ax.text(bx + 20.5, by + 27.2, NOM[z], ha="center", fontsize=9.6, weight="bold", color=CZ[z])
    ax.text(bx + 20.5, by + 24.4, f"k = {8+z*8}…{15+z*8}", ha="center", fontsize=7.8, color=CZ[z])
    for b in range(8):
        r, c = b // 4, b % 4
        icono(bx + 6.5 + c * 9.4, by + 17.0 - r * 11.2, 6.6, b, z, 8 + z*8 + b,
              cnt32[z*8 + b], CZ[z])

fig.text(.5, .012, "8 octantes = 4 orientaciones de trazo × 2 sentidos del gradiente   ·   "
         "los pares (0,6) (1,7) (2,4) (3,5) dibujan el MISMO trazo con el contraste invertido",
         ha="center", fontsize=9.0, color="#455a64", style="italic")
plt.savefig("fig_40_rasgos.png", dpi=140, bbox_inches="tight")
print("7:", f40[:8], "| suma nivel0 =", f40[:8].sum(), "= bordes", int(masc.sum()))
