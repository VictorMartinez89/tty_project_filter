# === Cuaderno 2 · figura 40: los dos reconocedores en Tiny Tapeout (IHP SG13G2) ===
import numpy as np, matplotlib.pyplot as plt
from matplotlib.gridspec import GridSpec

S = dict(cel=13319, ff=1527, util=.366, ws=3.50, hold=.114, wl=401635, pw=6.58)
C = dict(cel=14970, ff=1776, util=.416, ws=7.52, hold=.108, wl=439971, pw=7.23)
DIE = 540938   # identico en los dos: los dos pidieron 8x2 y los dos entraron

fig = plt.figure(figsize=(15.0, 6.2))
gs = GridSpec(1, 3, figure=fig, wspace=.34)

# ═══ A · ocupacion del mismo die ═══
ax = fig.add_subplot(gs[0, 0])
for i,(n,d,col) in enumerate((("Sobel",S,"#546e7a"),("Canny 1-salto",C,"#66bb6a"))):
    ax.bar(i, 100, color="#eceff1", ec="#90a4ae", lw=1.2, width=.55)
    ax.bar(i, d["util"]*100, color=col, ec="#37474f", lw=1.0, width=.55)
    ax.text(i, d["util"]*100+3, f"{d['util']:.1%}", ha="center", fontsize=12,
            weight="bold", color=col)
    ax.text(i, 8, f"{d['cel']:,}".replace(",", " ")+"\nceldas", ha="center", va="bottom",
            fontsize=9, color="#fff", weight="bold", linespacing=1.4)
ax.set_xticks([0,1]); ax.set_xticklabels(["Sobel","Canny 1-salto"], fontsize=10)
ax.set_ylabel("ocupación del die (%)", fontsize=10.5); ax.set_ylim(0, 112)
ax.set_yticks([0,25,50,75,100]); ax.grid(axis="y", alpha=.25)
for s in ("top","right"): ax.spines[s].set_visible(False)
ax.set_title(f"A · El MISMO die de 8×2\n{DIE:,} µm² · los dos entraron".replace(",", " "),
             fontsize=11.4, weight="bold", pad=12, linespacing=1.5)

# ═══ B · el margen de temporizado ═══
ax = fig.add_subplot(gs[0, 1])
x = np.arange(2); w = .34
ax.bar(x-w/2, [S["ws"], S["hold"]*10], w, color="#546e7a", ec="#37474f", lw=.8, label="Sobel")
ax.bar(x+w/2, [C["ws"], C["hold"]*10], w, color="#66bb6a", ec="#37474f", lw=.8, label="Canny")
for i,(a,b) in enumerate((("+3.50","+7.52"),("+1.14","+1.08"))):
    ax.text(i-w/2, [S["ws"],S["hold"]*10][i]+.25, a, ha="center", fontsize=9.6, weight="bold", color="#546e7a")
    ax.text(i+w/2, [C["ws"],C["hold"]*10][i]+.25, b, ha="center", fontsize=9.6, weight="bold", color="#2e7d32")
ax.axhline(0, color="#c62828", lw=1.8)
ax.set_xticks(x); ax.set_xticklabels(["setup\n(peor esquina)","hold\n(×10, ns)"],
                                     fontsize=9.2, linespacing=1.45)
ax.set_ylabel("holgura (ns)", fontsize=10.5); ax.grid(axis="y", alpha=.25); ax.legend(fontsize=9)
for s in ("top","right"): ax.spines[s].set_visible(False)
ax.set_title("B · El Canny cierra con MÁS margen\npese a tener más lógica",
             fontsize=11.4, weight="bold", pad=12, linespacing=1.5)

# ═══ C · la ley de la dilucion, en tres procesos ═══
ax = fig.add_subplot(gs[0, 2])
P = [("filtro solo\nsky130", 2.21, "#c62828"), ("sistema visión\nsky130", 1.18, "#ef6c00"),
     ("reconocedor TT\nIHP", 1.12, "#66bb6a"), ("reconocedor\nsky130", 1.05, "#2e7d32")]
ax.barh(range(4), [p[1] for p in P], color=[p[2] for p in P], ec="#37474f", lw=.8, height=.6)
for i,(n,v,c) in enumerate(P):
    ax.text(v+.03, i, f"{v:.2f}×", va="center", fontsize=11, weight="bold", color=c)
ax.axvline(1.0, color="#90a4ae", lw=1.6, ls="--")
ax.set_yticks(range(4)); ax.set_yticklabels([p[0] for p in P], fontsize=8.8, linespacing=1.45)
ax.invert_yaxis(); ax.set_xlim(.9, 2.45)
ax.set_xlabel("cuánto más grande es el Canny", fontsize=10)
ax.grid(axis="x", alpha=.25)
for s in ("top","right"): ax.spines[s].set_visible(False)
ax.set_title("C · La misma ley, en dos procesos\ny cuatro tamaños de sistema",
             fontsize=11.4, weight="bold", pad=12, linespacing=1.5)

fig.text(.5, -.04, "Los dos superan DRC, LVS y antenas con cero observaciones, en las TRES esquinas "
         "de proceso.  ·  Nueve proyectos en Tiny Tapeout: los dos últimos reconocen dígitos.",
         ha="center", fontsize=10.2, weight="bold", color="#1b5e20")
plt.savefig("fig_tt_ihp.png", dpi=140, bbox_inches="tight")
print("ok")
