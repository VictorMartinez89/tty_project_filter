# === Cuaderno 2 · figura 24: el Sobel vive en un pico, el Canny en una meseta ===
#   Barrido del umbral dentro de cada filtro, misma metodologia que la §18:
#   entrenar sobre 60 000, cuantizar a 4 bits, medir sobre 10 000.
import numpy as np, matplotlib.pyplot as plt
from matplotlib.gridspec import GridSpec

SOB = np.array([[40,88.54],[50,90.17],[60,91.04],[70,90.55],[80,92.08],[90,91.03],
                [100,88.82],[110,86.29],[120,87.14],[130,88.38],[140,86.80]])
CAN = np.array([[60,92.21],[70,92.40],[80,92.03],[90,92.46],[100,91.82],[110,92.03],
                [120,91.94],[130,91.74],[140,91.56]])
SIG = 1.32
CS, CC = "#546e7a", "#2e7d32"

fig = plt.figure(figsize=(14.6, 6.8))
gs = GridSpec(1, 2, figure=fig, width_ratios=[2.5, 1], wspace=.24)

# ═══════ A · las dos curvas ═══════
ax = fig.add_subplot(gs[0, 0])
ax.axhspan(CAN[:,1].min(), CAN[:,1].max(), color=CC, alpha=.13, zorder=0)
ax.text(141, (CAN[:,1].min()+CAN[:,1].max())/2, "  la MESETA\n  del Canny\n  0.90 pp",
        fontsize=8.6, color=CC, va="center", weight="bold", linespacing=1.5)
ax.plot(SOB[:,0], SOB[:,1], "o-", color=CS, lw=2.3, ms=7, label="Sobel  (un umbral)", zorder=3)
ax.plot(CAN[:,0], CAN[:,1], "s-", color=CC, lw=2.6, ms=7, label="Canny 1-salto  (hi, lo=0.36·hi)", zorder=4)

# el pico y el pozo del Sobel
i_max, i_min = SOB[:,1].argmax(), SOB[:,1].argmin()
ax.annotate(f"pico  {SOB[i_max,1]:.2f} %", xy=tuple(SOB[i_max]), xytext=(SOB[i_max,0]-19, 93.3),
            fontsize=8.8, color=CS, weight="bold",
            arrowprops=dict(arrowstyle="->", color=CS, lw=1.2))
ax.annotate(f"pozo  {SOB[i_min,1]:.2f} %", xy=tuple(SOB[i_min]), xytext=(SOB[i_min,0]-4, 85.0),
            fontsize=8.8, color="#c62828", weight="bold", ha="center",
            arrowprops=dict(arrowstyle="->", color="#c62828", lw=1.2))
ax.annotate("", xy=(SOB[i_max,0], SOB[i_max,1]), xytext=(SOB[i_max,0], SOB[i_min,1]),
            arrowprops=dict(arrowstyle="<->", color="#c62828", lw=2.0, alpha=.55))
ax.text(SOB[i_max,0]+1.5, 89.2, f"5.79 pp\n= 4.4 σ", fontsize=9.2, color="#c62828",
        weight="bold", linespacing=1.4)

# lo que hay grabado en el chip
for x, txt, col in ((60, "grabado en\nmnist_feat.v", CS),
                    (90, "lo que escribe\nel firmware", "#f9a825")):
    ax.axvline(x, color=col, ls=":", lw=1.3, alpha=.75, zorder=1)
    ax.text(x, 93.55, txt, fontsize=7.4, color=col, ha="center", va="top", linespacing=1.4,
            bbox=dict(fc="#fff", ec="none", alpha=.85, boxstyle="round,pad=0.25"))

ax.set_xlabel("umbral  (thr del Sobel  ·  thr_hi del Canny)", fontsize=10)
ax.set_ylabel("exactitud sobre las 10 000 de test  (%)", fontsize=10)
ax.set_xlim(34, 152); ax.set_ylim(84.8, 94.2)
ax.grid(alpha=.28); ax.legend(fontsize=9.2, loc="lower left", framealpha=.95)
ax.set_title("A · El Sobel vive en un PICO.  El Canny vive en una MESETA.",
             fontsize=11.6, weight="bold", pad=12)

# ═══════ B · los rangos contra el ruido ═══════
ax = fig.add_subplot(gs[0, 1])
R = [("el UMBRAL\nmueve al Sobel", SOB[:,1].max()-SOB[:,1].min(), CS),
     ("el UMBRAL\nmueve al Canny", CAN[:,1].max()-CAN[:,1].min(), CC),
     ("el FILTRO,\ncada uno en su pico", abs(CAN[:,1].max()-SOB[:,1].max()), "#8e24aa")]
for i, (t, v, c) in enumerate(R):
    ax.barh(2-i, v, color=c, alpha=.85, height=.56, ec="#37474f", lw=.7, zorder=3)
    ax.text(v+.12, 2-i, f"{v:.2f} pp\n{v/SIG:.1f} σ", va="center", fontsize=9.0,
            weight="bold", color=c, linespacing=1.4)
    ax.text(-.15, 2-i, t, ha="right", va="center", fontsize=8.8, linespacing=1.5)
ax.axvline(2*SIG, color="#ef6c00", lw=2.2, ls="--", zorder=4)
ax.text(2*SIG+.1, -.72, "2σ = 2.64 pp\nel umbral para afirmar", fontsize=8.4,
        color="#ef6c00", weight="bold", linespacing=1.4)
ax.axvspan(0, 2*SIG, color="#ffebee", alpha=.55, zorder=0)
ax.set_xlim(0, 7.6); ax.set_ylim(-1.15, 2.6); ax.set_yticks([])
ax.set_xlabel("rango de exactitud  (pp)", fontsize=9.6)
ax.grid(axis="x", alpha=.28)
for s in ("top","right","left"): ax.spines[s].set_visible(False)
ax.set_title("B · Qué palanca es más grande", fontsize=11.6, weight="bold", pad=12)

n = int((SOB[:,1] < CAN[:,1].min()).sum())
fig.text(.5, -.02, f"El Canny en su PEOR umbral ({CAN[:,1].min():.2f} %) le gana al Sobel en "
         f"{n} de sus {len(SOB)} umbrales.   ·   El Canny no compra exactitud: compra INSENSIBILIDAD.",
         ha="center", fontsize=10.4, weight="bold", color="#1b5e20")
plt.savefig("fig_pico_meseta.png", dpi=140, bbox_inches="tight")
print(f"Sobel rango {SOB[:,1].max()-SOB[:,1].min():.2f} pp · Canny {CAN[:,1].max()-CAN[:,1].min():.2f} pp")
print(f"el peor Canny ({CAN[:,1].min():.2f}) le gana al Sobel en {n}/{len(SOB)} umbrales")
