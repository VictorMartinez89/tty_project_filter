# === Cuaderno 2 · figura 35: presupuesto de area del reconocedor en silicio ===
import numpy as np, matplotlib.pyplot as plt
from matplotlib.gridspec import GridSpec

# (etiqueta, celdas genericas yosys, cabe en 8x2)
VAR = [("clasificador\nSobel",        7456,  "#546e7a"),
       ("clasificador\nCanny 1-salto", 8130, "#66bb6a"),
       ("+ CPU\n(SoC + Sobel)",       11077, "#f9a825"),
       ("+ CPU + cámara\n«Pan Hablas»",13915, "#c62828")]
K = 1.95                      # factor yosys -> sky130, MEDIDO en los TT de la tesis
TECHO = 18820                 # celdas sky130 que entraron de verdad en un 8x2

fig = plt.figure(figsize=(14.6, 6.4))
gs = GridSpec(1, 2, figure=fig, width_ratios=[1.5, 1], wspace=.26)

# ═══ A · presupuesto ═══
ax = fig.add_subplot(gs[0, 0])
x = np.arange(len(VAR)); sk = [v[1]*K for v in VAR]
b = ax.bar(x, sk, color=[v[2] for v in VAR], ec="#37474f", lw=.9, width=.62)
for i, v in enumerate(sk):
    cabe = v <= TECHO
    ax.text(i, v+500, f"{v:,.0f}".replace(",", " "), ha="center", fontsize=10, weight="bold",
            color="#2e7d32" if cabe else "#c62828")
    ax.text(i, v/2, "CABE" if cabe else "NO CABE", ha="center", va="center", fontsize=10.5,
            weight="bold", color="#fff", rotation=90 if not cabe else 0)
ax.axhline(TECHO, color="#c62828", lw=2.4, ls="--", zorder=3)
ax.text(-.42, TECHO+800, f"techo medido de un 8×2:  {TECHO:,} celdas".replace(",", " "),
        ha="left", fontsize=9.6, color="#c62828", weight="bold",
        bbox=dict(fc="#fff", ec="none", alpha=.9, boxstyle="round,pad=0.3"))
ax.axhspan(TECHO, 30000, color="#ffebee", alpha=.5, zorder=0)
ax.set_xticks(x); ax.set_xticklabels([v[0] for v in VAR], fontsize=9.2, linespacing=1.5)
ax.set_ylabel("celdas sky130 estimadas", fontsize=10.5); ax.set_ylim(0, 29500)
ax.grid(axis="y", alpha=.28)
for s in ("top","right"): ax.spines[s].set_visible(False)
ax.set_title("A · Qué entra en un 8×2 de Tiny Tapeout\n"
             "los dos clasificadores sí; agregarle el CPU o la cámara lo saca",
             fontsize=11.4, weight="bold", pad=12, linespacing=1.5)

# ═══ B · el factor, verificado ═══
ax = fig.add_subplot(gs[0, 1])
MED = [("tt_soc_sobel", 7185, 13922), ("tt_soc_canny1", 8314, 16368)]
for i,(n,g,s) in enumerate(MED):
    ax.scatter([g],[s], s=140, color="#1565c0", zorder=4)
    ax.annotate(f"{n}\n×{s/g:.2f}", (g,s), textcoords="offset points", xytext=(10,-16),
                fontsize=8.6, color="#1565c0", weight="bold", linespacing=1.4)
gg = np.linspace(6000, 15000, 50)
ax.plot(gg, gg*K, "-", color="#90a4ae", lw=1.8, label=f"×{K} (el factor usado)")
for n,g,c in [(v[0].replace("\n"," "),v[1],v[2]) for v in VAR]:
    ax.scatter([g],[g*K], s=95, color=c, marker="s", ec="#37474f", lw=.7, zorder=3)
ax.axhline(TECHO, color="#c62828", lw=1.8, ls="--")
ax.text(6200, TECHO+600, "techo 8×2", fontsize=8.6, color="#c62828", weight="bold")
ax.set_xlabel("celdas genéricas (yosys)", fontsize=10)
ax.set_ylabel("celdas sky130", fontsize=10)
ax.grid(alpha=.28); ax.legend(fontsize=9, loc="upper left")
for s in ("top","right"): ax.spines[s].set_visible(False)
ax.set_title("B · El factor no es de catálogo:\nsale de dos chips propios ya ruteados",
             fontsize=11.4, weight="bold", pad=12, linespacing=1.5)

fig.text(.5, -.03, "El clasificador completo —Sobel, histograma de 32 contadores, pirámide de 40 rasgos "
         "y 400 MAC de 4 bits— cabe en un 8×2 con 23 % de holgura.  "
         "Los 400 pesos viven en ROM combinacional y no cuestan un solo flip-flop.",
         ha="center", fontsize=9.8, color="#263238", weight="bold")
plt.savefig("fig_pan_hablas.png", dpi=140, bbox_inches="tight")
print("ok")
