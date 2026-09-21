# fig_sobel_vs_canny.py — el balance entre los dos filtros, medido sobre silicio firmado.
#   Cinco parejas Sobel/Canny con GDS limpio (DRC/LVS/XOR = 0) mas una de sintesis.
#   Datos: ASIC_planos/README.txt (post-layout) y la sintesis de asic/vision_mnist/ (yosys).
import numpy as np
import matplotlib.pyplot as plt

plt.rcParams["figure.dpi"] = 120
SOBEL, CANNY = "#4c72b0", "#c44e52"     # paleta validada: CVD dE 14.5, contraste > 3:1
FONDO = "white"

#            etiqueta                        celdas S  celdas C  mm2 S  mm2 C  post-layout
P = [("el filtro, solo",                       4651,   10284,  .167,  .360, True),
     ("+ CPU FemtoRV32 (SoC)",                 9906,   22054,  .370,  .670, True),
     ("cámara + framebuffer + display",       35653,   41925, 1.750, 2.040, True),
     ("MNIST en IHP · Tiny Tapeout",          13319,   14970,  .541,  .541, True),
     ("cámara + CPU + clasificador",          16718,   17373,  .845,  .890, True),
     ("cámara + clasificador + LCD",          30745,   31620, 2.032, 2.092, True)]

fig = plt.figure(figsize=(15.5, 8.6))
gs = fig.add_gridspec(2, 3, hspace=.52, wspace=.34)

# --- A · las seis parejas, en celdas -------------------------------------
ax = fig.add_subplot(gs[0, :2])
y = np.arange(len(P))
ax.barh(y + .19, [p[1] for p in P], .34, color=SOBEL,
        edgecolor=FONDO, linewidth=1.2, label="Sobel")
ax.barh(y - .19, [p[2] for p in P], .34, color=CANNY,
        edgecolor=FONDO, linewidth=1.2, label="Canny")
for i, p in enumerate(P):
    ax.text(p[1] + 700, i + .19, "%d" % p[1], va="center", fontsize=8.6, color=SOBEL)
    ax.text(p[2] + 700, i - .19, "%d" % p[2], va="center", fontsize=8.6,
            color=CANNY, weight="bold")
ax.set_yticks(y); ax.set_yticklabels([p[0] for p in P], fontsize=9)
ax.set_ylim(len(P) - .5, -.75)
ax.set_xlim(0, 48000); ax.set_xlabel("celdas estándar")
ax.set_title("A · Seis sistemas, los dos filtros\n"
             "las seis parejas, con GDS firmado",
             fontsize=11.5, loc="left")
for s in ("top", "right"): ax.spines[s].set_visible(False)
ax.grid(axis="x", alpha=.25); ax.set_axisbelow(True)
ax.legend(fontsize=9, frameon=False, loc="lower right")

# --- B · el titular: el sobrecoste se derrumba ---------------------------
ax = fig.add_subplot(gs[0, 2])
sob = [100 * (p[2] - p[1]) / p[1] for p in P]
o = np.argsort(sob)[::-1]
yy = np.arange(len(P))
ax.barh(yy, [sob[i] for i in o], .55,
        color=[CANNY if sob[i] > 50 else "#d59aa0" for i in o],
        edgecolor=FONDO, linewidth=1.2)
for k, i in enumerate(o):
    ax.text(sob[i] + 3, k, "+%.0f %%" % sob[i], va="center", fontsize=9.5,
            weight="bold", color=CANNY)
# las etiquetas TIENEN que reordenarse con los valores: al ordenar por sobrecoste y
# dejarlas en el orden original, "el filtro ES el chip" salia con el +123 % del SoC.
# indexado por POSICION en P, no por numero de celdas: al actualizar las cifras
# post-layout, una clave por celdas deja de encajar y la figura revienta.
CORTO = ["el filtro ES el chip", "+ CPU", "cám+fb+display",
         "MNIST · IHP", "cám+CPU+clf", "cám+clf+LCD"]
ax.set_yticks(yy)
ax.set_yticklabels([CORTO[i] for i in o], fontsize=8.6)
ax.set_ylim(len(P) - .5, -.7)
ax.set_xlim(0, 150); ax.set_xlabel("sobrecoste del Canny, en %")
ax.set_title("B · De +121 % a +3 %\n"
             "cuanto más hace el chip, menos pesa el filtro",
             fontsize=11.5, loc="left")
for s in ("top", "right"): ax.spines[s].set_visible(False)
ax.grid(axis="x", alpha=.25); ax.set_axisbelow(True)

# --- C · y sin embargo el Δ absoluto NO es constante ---------------------
ax = fig.add_subplot(gs[1, 0])
# una caja con tres puntos no es un resumen, es un adorno: se dibujan los seis deltas
PROC = (0, 1, 2)                        # los que procesan la escena 60x80
orden = sorted(range(len(P)), key=lambda i: -(P[i][2] - P[i][1]))
dd  = [P[i][2] - P[i][1] for i in orden]
col = [CANNY if i in PROC else "#d59aa0" for i in orden]
et  = [("60×80  " if i in PROC else "28×28  ") + CORTO[i] for i in orden]
yb = np.arange(len(P))
ax.barh(yb, dd, .55, color=col, edgecolor=FONDO, linewidth=1.2)
for k, v in enumerate(dd):
    ax.text(v + 250, k, "%d" % v, va="center", fontsize=8.8, weight="bold", color=col[k])
ax.set_yticks(yb); ax.set_yticklabels(et, fontsize=8.2, family="monospace")
ax.set_ylim(len(P) - .5, -.7)
ax.set_xlim(0, 14500)
ax.set_xlabel("celdas que AÑADE el Canny")
ax.set_title("C · El coste no escala con el chip\n"
             "escala con la IMAGEN que atraviesa", fontsize=11.5, loc="left")
for s in ("top", "right"): ax.spines[s].set_visible(False)
ax.grid(axis="x", alpha=.25); ax.set_axisbelow(True)

# --- D · las otras tres dimensiones -------------------------------------
ax = fig.add_subplot(gs[1, 1])
ax.axis("off")
ax.set_title("D · Las otras tres balanzas", fontsize=11.5, loc="left")
ax.text(0, .98,
        "CAMINO CRITICO  -> gana el CANNY\n"
        "   pan_sobel   12.23 ns\n"
        "   pan_canny    9.89 ns  ← 19 % mas corto\n"
        "   (§33; y el mismo signo en IHP, §31.4)\n"
        "   Reparte el trabajo en mas etapas, asi\n"
        "   que su camino es mas CORTO pese a\n"
        "   tener mas logica.\n\n"
        "EXACTITUD       -> EMPATE\n"
        "   entre filtros: 0.38 pp  (§25)\n"
        "   El Canny no reconoce mejor.\n\n"
        "ROBUSTEZ        -> gana el CANNY, y goleada\n"
        "   mover el umbral cambia el resultado\n"
        "      Sobel   5.79 pp   (4.4 sigma)\n"
        "      Canny   0.90 pp   (0.7 sigma)\n"
        "   El Sobel vive en un pico angosto;\n"
        "   el Canny, en una meseta.",
        va="top", family="monospace", fontsize=8.7, linespacing=1.45)

# --- E · la razon 8:1 ----------------------------------------------------
ax = fig.add_subplot(gs[1, 2])
ax.bar(["el Canny\nen el chip\ncompleto", "el CPU que el\nSobel necesita\npara el umbral"],
       [655, 5255], .5, color=[CANNY, SOBEL], edgecolor=FONDO, linewidth=1.2)
for i, v in enumerate([655, 5255]):
    ax.text(i, v + 150, "%d celdas" % v, ha="center", fontsize=10, weight="bold",
            color=[CANNY, SOBEL][i])
ax.set_ylim(0, 6400); ax.set_ylabel("celdas estándar")
ax.set_title("E · Ocho veces más barato\n"
             "comprar la robustez en el front-end", fontsize=11.5, loc="left")
for s in ("top", "right"): ax.spines[s].set_visible(False)
ax.grid(axis="y", alpha=.25); ax.set_axisbelow(True)

fig.suptitle("§34 · Sobel contra Canny, medido sobre silicio: seis parejas con GDS firmado\n"
             "el Canny pierde en área y gana en velocidad, empata en exactitud y "
             "arrasa en robustez", fontsize=13, y=1.0)
plt.savefig("fig_sobel_vs_canny.png", dpi=120, bbox_inches="tight")
plt.show()

for e, s, c, *_ in P:
    print("%-32s Sobel %6d  Canny %6d  %+6d celdas  %+5.0f %%" % (e, s, c, c - s, 100*(c-s)/s))
