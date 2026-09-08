# === Parte 186: los dos diagramas — el flujo de herramientas y el viaje de un pixel ===
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch, FancyArrowPatch

fig = plt.figure(figsize=(13.2, 8.4))
gs = fig.add_gridspec(2, 1, height_ratios=[1, 1.55], hspace=.18)

def caja(ax, x, y, w, h, tit, sub, col, fs=9.2):
    ax.add_patch(FancyBboxPatch((x, y), w, h, boxstyle="round,pad=0.012,rounding_size=0.02",
                                fc=col, ec="#333", lw=1.1))
    ax.text(x+w/2, y+h*.66, tit, ha="center", va="center", fontsize=fs, weight="bold")
    ax.text(x+w/2, y+h*.28, sub, ha="center", va="center", fontsize=7.3, linespacing=1.35)

def flecha(ax, x1, y1, x2, y2, txt="", c="#333"):
    ax.add_patch(FancyArrowPatch((x1, y1), (x2, y2), arrowstyle="-|>",
                                 mutation_scale=13, lw=1.3, color=c))
    if txt: ax.text((x1+x2)/2, y1+.035, txt, ha="center", fontsize=6.8, style="italic", color="#555")

# ---------------- A) el flujo de herramientas ----------------
a = fig.add_subplot(gs[0]); a.set_xlim(0, 10); a.set_ylim(0, 2.2); a.axis("off")
a.set_title("A · Cómo se «programa» un FPGA: no se compila un programa, se CONSTRUYE un circuito",
            fontsize=11.5, weight="bold", pad=6)
etapas = [
    (".v\nVerilog",       "lo que YO escribo\ndescripción del\ncircuito",        "#e3f2fd"),
    ("yosys\nsíntesis",   "texto → compuertas\n1 834 SB_LUT4\n20 BRAM",          "#fff3e0"),
    ("nextpnr\nplace&route","compuertas → celdas\nfísicas de la iCE40\n+ timing", "#f3e5f5"),
    ("icepack\nbitstream","celdas → 104 090 B\nmnist_uart.bin",                  "#e8f5e9"),
    ("iCELink\ncopiar",   "arrastrar el .bin\na /Volumes/iCELink\nLED verde",    "#fce4ec"),
]
w, gap = 1.62, .38
for i, (t, s, c) in enumerate(etapas):
    x = .25 + i*(w+gap)
    caja(a, x, .55, w, 1.0, t, s, c)
    if i: flecha(a, x-gap+.02, 1.05, x-.02, 1.05)
a.text(5.0, .18, "Ni una línea de C. El «programa» ES el circuito: los 400 MAC no son un bucle, "
                 "son 400 ciclos de un multiplicador real.",
       ha="center", fontsize=8.6, style="italic", color="#444")

# ---------------- B) el viaje de un pixel ----------------
b = fig.add_subplot(gs[1]); b.set_xlim(0, 10); b.set_ylim(0, 3.5); b.axis("off")
b.set_title("B · El viaje de un píxel: de 8 bits de la cámara al dígito, sin CPU",
            fontsize=11.5, weight="bold", pad=6)
fila1 = [
    ("in_pix 8b",      "stream raster\n28×28",              "#e3f2fd"),
    ("linebuf3x3",     "2 filas en BRAM\n→ ventana 3×3",    "#e1f5fe"),
    ("Gauss 3×3",      "÷16 = shift\nsuaviza el ruido",     "#e1f5fe"),
    ("linebuf3x3",     "otra ventana 3×3\nsobre lo suavizado","#e1f5fe"),
    ("Sobel 3×3",      "Gx y Gy\nsumas y shifts",           "#fff8e1"),
    ("|Gx|+|Gy|",      "sat. a 255\nsin raíz cuadrada",     "#fff8e1"),
]
fila2 = [
    ("> thr ?",        "¿es borde?\nel CPU fija thr",       "#fff8e1"),
    ("OCTANTE",        "{sgn Gy, sgn Gx,\n|Gy|>|Gx|}\n3 comparaciones", "#ffe0b2"),
    ("zona 2×2",       "en qué cuadrante\ncayó el borde",   "#ffe0b2"),
    ("32 contadores",  "cnt[zona][octante]\n+ n_bordes",    "#ffe0b2"),
    ("40 rasgos",      "nivel 0 = suma de\nlos 4 cuadrantes","#f3e5f5"),
    ("400 MAC",        "pesos 4b en ROM\n1 por ciclo",      "#f3e5f5"),
]
w2, g2 = 1.42, .21
def dibuja(lst, y):
    for i, (t, s, c) in enumerate(lst):
        x = .28 + i*(w2+g2)
        caja(b, x, y, w2, .78, t, s, c, fs=8.7)
        if i: flecha(b, x-g2+.01, y+.39, x-.01, y+.39)
dibuja(fila1, 2.35); dibuja(fila2, 1.15)

# --- conector fila 1 -> fila 2 (ortogonal, una sola punta de flecha) ---
xU = .28 + 5*(w2+g2) + w2/2          # centro de |Gx|+|Gy|
xT = .28 + w2/2                       # centro de "> thr ?"
b.plot([xU, xU], [2.35, 2.12], c="#333", lw=1.3)
b.plot([xU, xT], [2.12, 2.12], c="#333", lw=1.3)
flecha(b, xT, 2.12, xT, 1.945)
b.text((xU+xT)/2, 2.17, "sigue abajo", ha="center", fontsize=6.8, style="italic", color="#555")

# --- fila 3: argmax -> NADA -> salida ---
xM = .28 + 5*(w2+g2) + w2/2          # centro de 400 MAC
xA, xN = 3.05, 5.15
caja(b, xA, .12, w2, .72, "argmax", "el puntaje mayor\nde los 10", "#f3e5f5", fs=8.7)
caja(b, xN, .12, w2*1.35, .72, "¿NADA?", "bordes ∈ [140,430]\ny margen > 30", "#ffcdd2", fs=8.7)
b.plot([xM, xM], [1.15, .92], c="#333", lw=1.3)
b.plot([xM, xA + w2/2], [.92, .92], c="#333", lw=1.3)
flecha(b, xA + w2/2, .92, xA + w2/2, .855)
flecha(b, xA + w2 + .02, .48, xN - .02, .48)
flecha(b, xN + w2*1.35 + .02, .48, xN + w2*1.35 + .5, .48)
b.text(xN + w2*1.35 + .62, .48, "dígito 0…9\no «no sé»", ha="left", va="center",
       fontsize=9.5, weight="bold")
plt.savefig("../../clasificador_mnist/fig_p186_flujo.png", dpi=150, bbox_inches="tight")
plt.show()
