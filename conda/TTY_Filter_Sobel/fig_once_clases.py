# === Cuaderno 2 · figura 22: las ONCE clases atravesando el circuito entero ===
#   Una fila por clase [0..9, nada].  Columnas: 784 px -> bordes -> forma ->
#   40 rasgos (piramide) -> 10 puntajes -> 1 digito.  Pesos reales de la ROM.
import numpy as np, re, sys
import matplotlib.pyplot as plt
from matplotlib.gridspec import GridSpec
from matplotlib.patches import Rectangle
sys.path.insert(0, "../../clasificador_mnist")
import frente_golden as fg

B = "../../clasificador_mnist/"
X, y, Xt, yt = fg.cargar_mnist(B + "mnist.npz")
vh = open(B + "rtl/mnist_weights.vh").read()
W = np.array([int(s+n) for s, n in re.findall(r"w_rom = (-?)4'sd(\d+)", vh)], float).reshape(10, 40)
BIAS = np.array([int(s+n) for s, n in re.findall(r"b_rom = (-?)16'sd(\d+)", vh)], float)
B_MIN, B_MAX, MARGEN = 140, 430, 30

ANG = {0:202.5, 1:247.5, 2:337.5, 3:292.5, 4:157.5, 5:112.5, 6:22.5, 7:67.5}
CZ  = ["#1e88e5", "#43a047", "#fb8c00", "#8e24aa"]

IDX = [3, 2, 35, 30, 4, 8, 11, 0, 61, 9]          # uno por digito, verificados
CASOS = [(str(d), Xt[i]) for d, i in enumerate(IDX)]
CASOS.append(("nada", np.full((28, 28), 20, np.uint8)))   # hoja en blanco: gen_escena.py -1

def procesar(img):
    m, o = fg.frente(img); m, o = m[0], o[0]
    c32 = fg.contadores(m, o); f40 = fg.descriptor(c32).astype(float)
    p = W @ f40 + BIAS; d = int(np.argmax(p))
    s = np.sort(p)[::-1]; mar = s[0] - s[1]; nb = int(m.sum())
    habla = (B_MIN <= nb <= B_MAX) and mar > MARGEN
    return m, o, c32, f40, p, d, mar, nb, habla

N = len(CASOS)
fig = plt.figure(figsize=(16.4, 1.52 * N + 1.5))
gs = GridSpec(N, 6, figure=fig, width_ratios=[.80, .80, .92, 2.25, 1.15, .62],
              hspace=.30, wspace=.22, top=.955, bottom=.032, left=.035, right=.985)

TIT = ["1 · 784 PÍXELES", "2 · BORDES", "3 · FORMA\n4 zonas × 8 octantes",
       "4 · 40 RASGOS  (pirámide espacial:  8 del nivel 0  +  32 del nivel 1)",
       "5 · 10 PUNTAJES → argmax", "6 · SALIDA"]

for r, (nom, img) in enumerate(CASOS):
    m, o, c32, f40, p, d, mar, nb, habla = procesar(img)
    es_nada = (nom == "nada")
    ok = habla and (not es_nada) and (str(d) == nom)
    bien = ok or (es_nada and not habla)
    mx = c32.max() if c32.max() else 1

    # --- 1 · pixeles ---
    ax = fig.add_subplot(gs[r, 0]); ax.imshow(img, cmap="gray_r", vmin=0, vmax=255); ax.axis("off")
    ax.text(-.20, .5, f"«{nom}»", transform=ax.transAxes, ha="right", va="center",
            fontsize=14, weight="bold", color="#263238" if not es_nada else "#78909c")
    if r == 0: ax.set_title(TIT[0], fontsize=9.2, weight="bold", pad=8)

    # --- 2 · bordes, coloreados por zona ---
    ax = fig.add_subplot(gs[r, 1])
    H2, W2 = m.shape; rgb = np.ones(m.shape + (3,))
    for zy in (0, 1):
        for zx in (0, 1):
            z = zy*2 + zx
            sl = (slice(zy*H2//2, (zy+1)*H2//2), slice(zx*W2//2, (zx+1)*W2//2))
            mm = m[sl]; col = np.array([int(CZ[z][k:k+2], 16)/255 for k in (1, 3, 5)])
            blk = rgb[sl]; blk[mm] = col; rgb[sl] = blk
    ax.imshow(rgb); ax.axhline(H2/2-.5, c="#b0bec5", lw=.7); ax.axvline(W2/2-.5, c="#b0bec5", lw=.7)
    ax.axis("off")
    ax.text(.5, -.04, f"{nb} bordes", transform=ax.transAxes, ha="center", va="top",
            fontsize=7.4, color="#c62828" if not (B_MIN <= nb <= B_MAX) else "#546e7a",
            weight="bold" if not (B_MIN <= nb <= B_MAX) else "normal")
    if r == 0: ax.set_title(TIT[1], fontsize=9.2, weight="bold", pad=8)

    # --- 3 · forma: 4 rosas ---
    ax = fig.add_subplot(gs[r, 2]); ax.set_xlim(-1.05, 1.05); ax.set_ylim(-1.05, 1.05)
    ax.set_aspect("equal"); ax.axis("off")
    for z in range(4):
        cy, cx = (-.5 if z >= 2 else .5), (-.5 if z % 2 == 0 else .5)
        for bb in range(8):
            rr = .44 * c32[z*8+bb] / mx; a = np.deg2rad(ANG[bb])
            ax.plot([cx, cx+rr*np.cos(a)], [cy, cy+rr*np.sin(a)], color=CZ[z], lw=2.6,
                    solid_capstyle="round")
        ax.add_patch(plt.Circle((cx, cy), .022, color=CZ[z]))
    ax.axhline(0, c="#e0e0e0", lw=.8); ax.axvline(0, c="#e0e0e0", lw=.8)
    if r == 0: ax.set_title(TIT[2], fontsize=9.2, weight="bold", pad=8, linespacing=1.4)

    # --- 4 · los 40 rasgos ---
    ax = fig.add_subplot(gs[r, 3])
    cols = ["#37474f"]*8 + [CZ[k//8] for k in range(32)]
    ax.bar(range(40), f40, color=cols, width=.80)
    ax.axvline(7.5, c="#90a4ae", lw=1.0, ls="--")
    ax.set_xlim(-.9, 39.9); ax.set_ylim(0, max(f40.max()*1.18, 1))
    ax.tick_params(labelsize=6.2, length=2); ax.grid(axis="y", alpha=.22)
    ax.set_yticks([]) if es_nada else None
    if r == 0:
        ax.set_title(TIT[3], fontsize=9.2, weight="bold", pad=8)
        ax.text(3.7, ax.get_ylim()[1]*.97, "nivel 0", ha="center", va="top", fontsize=6.8,
                color="#37474f", weight="bold")
        ax.text(24, ax.get_ylim()[1]*.97, "nivel 1 — un histograma por zona", ha="center",
                va="top", fontsize=6.8, color="#455a64")
    if r == N-1: ax.set_xlabel("k  (rasgo)", fontsize=7.6)
    else: ax.set_xticklabels([])

    # --- 5 · los 10 puntajes ---
    ax = fig.add_subplot(gs[r, 4])
    colb = ["#cfd8dc"]*10
    colb[d] = "#2e7d32" if bien and not es_nada else ("#c62828" if not es_nada else "#90a4ae")
    ax.barh(range(10), p, color=colb, ec="#b0bec5", lw=.4, height=.72)
    ax.set_yticks(range(10)); ax.set_yticklabels(range(10), fontsize=6.0)
    ax.invert_yaxis(); ax.axvline(0, c="#78909c", lw=.7)
    ax.tick_params(labelsize=6.0, length=2); ax.grid(axis="x", alpha=.22)
    ax.text(.98, .04, f"margen {mar:.0f}", transform=ax.transAxes, ha="right", va="bottom",
            fontsize=6.8, weight="bold", color="#2e7d32" if mar > MARGEN else "#c62828")
    if r == 0: ax.set_title(TIT[4], fontsize=9.2, weight="bold", pad=8)

    # --- 6 · la salida ---
    ax = fig.add_subplot(gs[r, 5]); ax.axis("off")
    if habla:
        ax.text(.5, .56, str(d), ha="center", va="center", fontsize=34, weight="bold",
                color="#2e7d32" if bien else "#c62828")
        ax.text(.5, .08, "habla ✔" if bien else "habla ✘", ha="center", fontsize=7.4,
                color="#2e7d32" if bien else "#c62828")
    else:
        ax.text(.5, .58, "NADA", ha="center", va="center", fontsize=17, weight="bold",
                color="#2e7d32" if bien else "#c62828")
        razon = "0 bordes < 140" if nb < B_MIN else (f"{nb} bordes > {B_MAX}" if nb > B_MAX
                                                     else f"margen {mar:.0f} < {MARGEN}")
        ax.text(.5, .10, "se calla ✔\n" + razon, ha="center", fontsize=6.8, linespacing=1.4,
                color="#2e7d32" if bien else "#c62828")
    if r == 0: ax.set_title(TIT[5], fontsize=9.2, weight="bold", pad=8)

fig.suptitle("LAS ONCE CLASES ATRAVESANDO EL CIRCUITO ENTERO   ·   "
             "[0,1,2,3,4,5,6,7,8,9,nada]  ×  (784 px → 32 contadores → 40 rasgos → 10 puntajes → 1 dígito)",
             fontsize=12.6, weight="bold", y=.988)
plt.savefig("fig_once_clases.png", dpi=125, bbox_inches="tight")

print(f"{'clase':>6}{'pred':>6}{'bordes':>8}{'margen':>8}  veredicto")
for nom, img in CASOS:
    *_, p, d, mar, nb, habla = procesar(img)
    v = f"dice {d}" if habla else "NADA"
    ok = (habla and str(d) == nom) or (nom == "nada" and not habla)
    print(f"{nom:>6}{d:>6}{nb:>8}{mar:>8.0f}  {v:<8} {'✔' if ok else '✘'}")
