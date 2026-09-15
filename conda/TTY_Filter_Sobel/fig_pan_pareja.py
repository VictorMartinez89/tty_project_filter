# === Cuaderno 2 · figura 39: los dos Pan Hablas, y la prediccion verificada ===
import numpy as np, matplotlib.pyplot as plt
from matplotlib.gridspec import GridSpec

fig = plt.figure(figsize=(15.2, 6.2))
gs = GridSpec(1, 3, figure=fig, width_ratios=[1.15, 1.25, 1], wspace=.32)

# ═══ A · los dos chips ═══
ax = fig.add_subplot(gs[0, 0])
M = [("área die\n(mm²)", .8452, .8903, 1), ("celdas\ncolocadas", 19949, 20921, 1000),
     ("interconexión\n(mm)", 745.264, 774.313, 1)]
x = np.arange(3); w = .36
ax.bar(x-w/2, [m[1]/m[3] for m in M], w, color="#546e7a", ec="#37474f", lw=.8, label="pan_sobel")
ax.bar(x+w/2, [m[2]/m[3] for m in M], w, color="#66bb6a", ec="#37474f", lw=.8, label="pan_canny")
for i,m in enumerate(M):
    ax.text(i, max(m[1],m[2])/m[3]*1.06, f"{m[2]/m[1]:.2f}×", ha="center",
            fontsize=11, weight="bold", color="#2e7d32")
ax.set_xticks(x); ax.set_xticklabels([m[0] for m in M], fontsize=8.8, linespacing=1.5)
ax.set_yticks([]); ax.legend(fontsize=9)
for s in ("top","right","left"): ax.spines[s].set_visible(False)
ax.set_title("A · Los dos chips difieren\nun 5 %, no un 121 %",
             fontsize=11.4, weight="bold", pad=12, linespacing=1.5)

# ═══ B · la dilucion, con el punto medido ═══
ax = fig.add_subplot(gs[0, 1])
NIV = ["filtro\nsolo", "+ CPU", "sistema\nvisión", "reconocedor\nMEDIDO"]
F   = [2.21, 2.23, 1.18, 1.05]
ax.plot(range(3), F[:3], "o-", color="#546e7a", lw=3.0, ms=11, zorder=3)
ax.plot([2,3], F[2:], "o-", color="#2e7d32", lw=3.0, ms=14, zorder=4)
ax.scatter([3],[1.09], s=170, marker="*", color="#c62828", zorder=5)
ax.annotate("predicho §29\n1.09×", (3,1.09), textcoords="offset points", xytext=(-14,24),
            fontsize=8.8, color="#c62828", weight="bold", ha="right", linespacing=1.4)
for i,v in enumerate(F):
    ax.text(i, v-.14, f"{v:.2f}×", ha="center", fontsize=10.6, weight="bold",
            color="#2e7d32" if i==3 else "#546e7a")
ax.axhline(1.0, color="#90a4ae", lw=1.6, ls="--")
ax.set_xticks(range(4)); ax.set_xticklabels(NIV, fontsize=8.8, linespacing=1.45)
ax.set_ylabel("cuánto más grande es el Canny", fontsize=10)
ax.set_ylim(.80, 2.55); ax.grid(axis="y", alpha=.28)
for s in ("top","right"): ax.spines[s].set_visible(False)
ax.set_title("B · La predicción se cumplió\ny el punto medido superó al predicho",
             fontsize=11.4, weight="bold", pad=12, linespacing=1.5)

# ═══ C · el factor, con dos puntos ═══
ax = fig.add_subplot(gs[0, 2])
P = [("pan_sobel", 13915, 19949, "#546e7a"), ("pan_canny", 14439, 20921, "#66bb6a")]
for n,g,c,col in P:
    ax.scatter([g],[c], s=150, color=col, zorder=4, ec="#37474f", lw=.8)
    ax.annotate(f"{n}\n×{c/g:.2f}", (g,c), textcoords="offset points", xytext=(-12,-30),
                fontsize=8.8, color=col, weight="bold", ha="center", linespacing=1.4)
gg = np.linspace(13000, 15500, 20)
ax.plot(gg, gg*1.44, "-", color="#90a4ae", lw=1.8, label="×1.44 (los dos)")
ax.plot(gg, gg*1.95, "--", color="#c62828", lw=1.6, label="×1.95 (lo que usé en §28)")
ax.set_xlabel("celdas genéricas (yosys)", fontsize=9.6)
ax.set_ylabel("celdas colocadas (sky130)", fontsize=9.6)
ax.grid(alpha=.28); ax.legend(fontsize=8.4, loc="upper left")
ax.tick_params(labelsize=8)
for s in ("top","right"): ax.spines[s].set_visible(False)
ax.set_title("C · El factor corregido,\nahora con DOS puntos",
             fontsize=11.4, weight="bold", pad=12, linespacing=1.5)

fig.text(.5, -.05, "Los dos circuitos cierran el temporizado a 30 ns con parásitos extraídos "
         "(spef_wns = 0.00) y con LVS, DRC y XOR limpios.",
         ha="center", fontsize=10.4, weight="bold", color="#1b5e20")
plt.savefig("fig_pan_pareja.png", dpi=140, bbox_inches="tight")
print("ok")
