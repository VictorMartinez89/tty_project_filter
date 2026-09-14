# === Cuaderno 2 · figura 18: el clasificador por dentro, con un digito real ===
#   pixeles -> bordes -> forma (4 zonas x 8 octantes) -> 40 rasgos -> 10 puntajes -> digito
#   Los pesos son los de mnist_weights.vh: los MISMOS que estan grabados en la placa.
import numpy as np, re, sys, os
import matplotlib.pyplot as plt
from matplotlib.gridspec import GridSpec
sys.path.insert(0, "../../clasificador_mnist")
import frente_golden as fg

B = "../../clasificador_mnist/"
X, y, Xt, yt = fg.cargar_mnist(B + "mnist.npz")

# --- los pesos REALES de la ROM ---
vh = open(B + "rtl/mnist_weights.vh").read()
ws = [int(s + n) for s, n in re.findall(r"w_rom = (-?)4'sd(\d+)", vh)]
bs = [int(s + n) for s, n in re.findall(r"b_rom = (-?)16'sd(\d+)", vh)]
W = np.array(ws, float).reshape(10, 40); bias = np.array(bs, float)
print("pesos:", W.shape, "rango", int(W.min()), "..", int(W.max()), "| bias:", bias.shape)

# --- un digito real que el circuito acierta ---
idx = 0                      # el primer digito del test: un 7 limpio
img = Xt[idx]
masc, ori = fg.frente(img)
masc, ori = masc[0], ori[0]
cnt32 = fg.contadores(masc, ori)
f40 = fg.descriptor(cnt32).astype(float)
punt = W @ f40 + bias
pred = int(np.argmax(punt))
orden = np.argsort(punt)[::-1]
margen = punt[orden[0]] - punt[orden[1]]
nb_edges = int(masc.sum())
habla = (140 <= nb_edges <= 430) and margen > 30
print(f"verdad {yt[idx]} -> circuito {pred} | bordes {nb_edges} | margen {margen:.0f} | "
      f"{'HABLA' if habla else 'SE CALLA (NADA)'}")

ANG = {0:202.5, 1:247.5, 2:337.5, 3:292.5, 4:157.5, 5:112.5, 6:22.5, 7:67.5}
CZ = ["#1e88e5", "#43a047", "#fb8c00", "#8e24aa"]   # color por zona

fig = plt.figure(figsize=(16.2, 6.9))
POS = {1:[.030,.155,.130,.50], 2:[.188,.155,.130,.50],
       3:[.345,.155,.150,.50], 4:[.545,.155,.250,.50], 5:[.845,.155,.140,.50]}

def panel(n, t, sub):
    ax = fig.add_axes(POS[n])
    x = POS[n][0] + POS[n][2] / 2
    fig.text(POS[n][0], .855, str(n), fontsize=15, weight="bold", color="#b0bec5")
    fig.text(x, .805, t, ha="center", fontsize=10.4, weight="bold", color="#263238")
    fig.text(x, .700, sub, ha="center", va="top", fontsize=8.0, color="#546e7a", linespacing=1.6)
    return ax

# --- 1 · los pixeles ---
ax = panel(1, "784 PÍXELES", "lo que entra:\n8 bits, orden raster")
ax.imshow(img, cmap="gray_r"); ax.axis("off")

# --- 2 · los bordes ---
ax = panel(2, "BORDES", f"{nb_edges} píxeles · Sobel de 1968\ncoloreados por ZONA")
rgb = np.ones(masc.shape + (3,)); H2, W2 = masc.shape
for zy in (0, 1):
    for zx in (0, 1):
        z = zy * 2 + zx
        sl = (slice(zy*H2//2, (zy+1)*H2//2), slice(zx*W2//2, (zx+1)*W2//2))
        m = masc[sl]; col = np.array([int(CZ[z][i:i+2],16)/255 for i in (1,3,5)])
        blk = rgb[sl]; blk[m] = col; rgb[sl] = blk
ax.imshow(rgb); ax.axhline(H2/2-.5, c="#90a4ae", lw=.9); ax.axvline(W2/2-.5, c="#90a4ae", lw=.9)
ax.axis("off")

# --- 3 · la forma ---
ax = panel(3, "FORMA", "32 contadores = 4 zonas × 8 octantes\nqué trazos, y DÓNDE")
ax.set_xlim(-1.1, 1.1); ax.set_ylim(-1.1, 1.1); ax.set_aspect("equal"); ax.axis("off")
mx = cnt32.max()
for z in range(4):
    cy, cx = (-.52 if z >= 2 else .52), (-.52 if z % 2 == 0 else .52)
    for b in range(8):
        r = .46 * cnt32[z*8+b] / mx; a = np.deg2rad(ANG[b])
        ax.plot([cx, cx+r*np.cos(a)], [cy, cy+r*np.sin(a)], color=CZ[z], lw=3.6,
                solid_capstyle="round")
    ax.add_patch(plt.Circle((cx, cy), .022, color=CZ[z]))
ax.axhline(0, c="#cfd8dc", lw=1.0); ax.axvline(0, c="#cfd8dc", lw=1.0)

# --- 4 · los 40 rasgos ---
ax = panel(4, "40 RASGOS  (pirámide espacial)",
           "los 8 del nivel 0 no se cuentan: se DERIVAN sumando los 4 cuadrantes")
cols = ["#37474f"]*8 + [CZ[k//8] for k in range(32)]
ax.bar(range(40), f40, color=cols, width=.78)
ax.axvline(7.5, c="#90a4ae", lw=1.2, ls="--")
top = f40.max()
ax.text(3.5, top*1.20, "nivel 0\nla imagen\nentera", ha="center", va="center", fontsize=7.2,
        color="#37474f", linespacing=1.45)
ax.text(24.5, top*1.24, "nivel 1 — un histograma por zona", ha="center", fontsize=7.4,
        color="#455a64")
for z in range(4):
    ax.text(8+z*8+3.5, -top*.115, f"z{z}", ha="center", fontsize=7.2, color=CZ[z], weight="bold")
ax.set_xlabel("k  (rasgo)", fontsize=8.4, labelpad=11)
ax.set_ylabel("cuenta de bordes", fontsize=8.4)
ax.tick_params(labelsize=7.2); ax.set_ylim(0, top*1.38); ax.grid(axis="y", alpha=.25)

# --- 5 · los 10 puntajes ---
ax = panel(5, "10 PUNTAJES → argmax", "10 clases × 40 pesos de 4 bits\n= 200 BYTES de ROM")
ax.barh(range(10), punt, color=["#c62828" if i==pred else "#cfd8dc" for i in range(10)],
        ec="#90a4ae", lw=.6)
ax.set_yticks(range(10)); ax.set_yticklabels(range(10), fontsize=8.4)
ax.invert_yaxis(); ax.axvline(0, c="#607d8b", lw=.9)
ax.set_xlabel("puntaje  (MAC 4 bits)", fontsize=8.4); ax.tick_params(labelsize=7.0)
ax.grid(axis="x", alpha=.25)
ax.text(punt[pred]*.96, pred, str(pred), va="center", ha="right", fontsize=13, weight="bold",
        color="#fff")
ax.set_xlim(punt.min()*1.12, punt.max()*1.12)
fig.text(.915, .075, f"margen sobre el 2.º: {margen:.0f}   (NADA exige > 30)\n"
         f"bordes: {nb_edges}   (NADA exige 140–430)\n"
         f"→  {'HABLA' if habla else 'SE CALLA'}", ha="center", va="top", fontsize=7.6,
         color="#37474f", linespacing=1.6,
         bbox=dict(fc="#fff", ec="#b0bec5", lw=.8, boxstyle="round,pad=0.5"))

for x in (.176, .333, .527, .827):
    fig.text(x, .40, "→", fontsize=19, color="#90a4ae", ha="center", va="center")

fig.text(.42, .055, "784 píxeles  →  32 contadores  →  40 rasgos  →  10 puntajes  →  1 dígito",
         ha="center", fontsize=13.2, weight="bold", color="#263238")
fig.text(.42, .010, "una reducción de 784 a 1 en cuatro pasos — y el clasificador, lo único "
         "entrenado, es solo el último", ha="center", fontsize=9.2, color="#546e7a", style="italic")
plt.savefig("fig_clf_dentro.png", dpi=140, bbox_inches="tight")
print("ok")
