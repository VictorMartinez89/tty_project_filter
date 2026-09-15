# === Cuaderno 2 · figura 30: el RTL contra el golden, en las 11 escenas ===
import numpy as np, matplotlib.pyplot as plt
from matplotlib.gridspec import GridSpec

ESC = [str(d) for d in range(10)]+["NADA"]
CAD = [("sobel","Sobel","#546e7a"), ("soc_sobel","SoC + Sobel","#37474f"),
       ("canny1","Canny 1-salto","#66bb6a"), ("soc_canny1","SoC + Canny1","#1b5e20")]
RTL = {"sobel":     ["0","1","6","3","4","5","NADA","7","8","NADA","NADA"],
       "soc_sobel": ["0","1","6","3","4","5","NADA","7","8","NADA","NADA"],
       "canny1":    ["NADA","NADA","6","NADA","4","5","NADA","7","9","NADA","NADA"],
       "soc_canny1":["NADA","NADA","6","NADA","4","5","NADA","7","NADA","NADA","NADA"]}
GLD = {"sobel":     ["0","1","NADA","NADA","4","5","6","7","8","NADA","NADA"],
       "soc_sobel": ["0","1","NADA","NADA","4","5","6","7","8","NADA","NADA"],
       "canny1":    ["0","NADA","NADA","NADA","4","5","6","7","NADA","9","NADA"],
       "soc_canny1":["0","NADA","NADA","NADA","4","5","6","7","NADA","NADA","NADA"]}
RB = {"sobel":[327,149,299,352,267,308,328,229,316,234,0],
      "soc_sobel":[306,140,289,344,254,292,312,219,303,223,0],
      "canny1":[312,142,291,326,251,277,317,221,297,231,0],
      "soc_canny1":[318,144,294,330,255,280,322,226,300,236,0]}
GB = {"sobel":[339,158,310,367,270,324,343,229,326,234,0],
      "soc_sobel":[317,148,301,357,256,303,326,219,311,223,0],
      "canny1":[337,155,300,360,273,319,342,232,324,235,0],
      "soc_canny1":[344,157,302,363,280,322,346,238,330,240,0]}

fig = plt.figure(figsize=(15.2, 7.6))
gs = GridSpec(1, 2, figure=fig, width_ratios=[1.25, 1], wspace=.24)

# ═══ A · el déficit, escena por escena ═══
ax = fig.add_subplot(gs[0, 0])
x = np.arange(11); w = .21
for k,(n,tit,col) in enumerate(CAD):
    d = [g-r for g,r in zip(GB[n], RB[n])]
    ax.bar(x+(k-1.5)*w, d, w, color=col, ec="#37474f", lw=.5, label=tit)
ax.set_xticks(x); ax.set_xticklabels(ESC, fontsize=9)
ax.set_xlabel("escena", fontsize=10); ax.axhline(0, color="#37474f", lw=1.1)
ax.set_ylabel("bordes que el RTL NO cuenta  (golden − RTL)", fontsize=10)
ax.grid(axis="y", alpha=.28); ax.legend(fontsize=8.8, ncol=2)
ax.set_title("A · El déficit es SISTEMÁTICO y siempre POSITIVO\n"
             "en las 44 combinaciones, el golden nunca cuenta menos que el RTL",
             fontsize=11.2, weight="bold", pad=12, linespacing=1.5)
ax.text(.03,.95, "Sobel  medio +9.1\nCanny  medio +21.2   ←  2.3×", transform=ax.transAxes,
        va="top", fontsize=9.4, weight="bold", color="#263238", linespacing=1.6,
        bbox=dict(fc="#fff3e0", ec="#ffb74d", lw=1.0, boxstyle="round,pad=0.5"))

# ═══ B · los veredictos, RTL contra golden ═══
ax = fig.add_subplot(gs[0, 1])
for k,(n,tit,col) in enumerate(CAD):
    for i,e in enumerate(ESC):
        r, g = RTL[n][i], GLD[n][i]
        ok_r, ok_g = (r==e), (g==e)
        for j,(v,ok) in enumerate(((r,ok_r),(g,ok_g))):
            ax.add_patch(plt.Rectangle((k*2.1+j*.95, i-.4), .9, .8,
                         fc="#2e7d32" if ok else "#c62828", alpha=.85, ec="#37474f", lw=.5))
            ax.text(k*2.1+j*.95+.45, i, v if v!="NADA" else "–", ha="center", va="center",
                    fontsize=7.6, color="#fff", weight="bold")
    okr=sum(a==b for a,b in zip(RTL[n],ESC)); okg=sum(a==b for a,b in zip(GLD[n],ESC))
    ax.text(k*2.1+.45, -1.15, f"{okr}", ha="center", fontsize=12, weight="bold", color=col)
    ax.text(k*2.1+1.40, -1.15, f"{okg}", ha="center", fontsize=12, weight="bold", color=col)
    ax.text(k*2.1+.45, -1.85, "RTL", ha="center", fontsize=7.8, color="#607d8b")
    ax.text(k*2.1+1.40, -1.85, "gold", ha="center", fontsize=7.8, color="#607d8b")
    ax.text(k*2.1+.95, -2.55, tit, ha="center", fontsize=8.8, weight="bold", color=col)
ax.set_xlim(-.3, 4*2.1); ax.set_ylim(-2.9, 11)
ax.set_yticks(range(11)); ax.set_yticklabels(ESC, fontsize=8.4); ax.invert_yaxis()
ax.set_xticks([]); ax.set_ylabel("escena esperada", fontsize=10)
for s in ("top","right","left"): ax.spines[s].set_visible(False)
ax.set_title("B · Y le cuesta al Canny TRES escenas\n"
             "el Sobel empata 8-8; el Canny va de 4 a 7",
             fontsize=11.2, weight="bold", pad=12, linespacing=1.5)

fig.text(.5, -.035, "Mismo modelo, mismos pesos de la ROM, misma regla NADA.  Lo único que cambia es "
         "quién calcula los bordes: el RTL en iverilog o el golden en Python.",
         ha="center", fontsize=10.2, weight="bold", color="#263238")
plt.savefig("fig_rtl_vs_golden.png", dpi=140, bbox_inches="tight")
print("ok")
