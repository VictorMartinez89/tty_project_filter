# === Cuaderno 2 · figura 26: las cuatro cadenas en iverilog, y la pista del 4/11 ===
import numpy as np, matplotlib.pyplot as plt
from matplotlib.gridspec import GridSpec

ESC = ["0","1","2","3","4","5","6","7","8","9","NADA"]
CAD = [
 ("Sobel",       "#546e7a", ["0","1","6","3","4","5","NADA","7","8","NADA","NADA"],
                            [327,149,299,352,267,308,328,229,316,234,0]),
 ("SoC + Sobel", "#37474f", ["0","1","6","3","4","5","NADA","7","8","NADA","NADA"],
                            [306,140,289,344,254,292,312,219,303,223,0]),
 ("Canny 1-salto","#66bb6a",["NADA","NADA","6","NADA","4","5","NADA","7","9","NADA","NADA"],
                            [312,142,291,326,251,277,317,221,297,231,0]),
 ("SoC + Canny1","#1b5e20", ["NADA","NADA","6","NADA","4","5","NADA","7","NADA","NADA","NADA"],
                            [318,144,294,330,255,280,322,226,300,236,0]),
]
fig = plt.figure(figsize=(14.8, 7.0))
gs = GridSpec(1, 2, figure=fig, width_ratios=[1.75, 1], wspace=.26)

# ═══ A · las 11 escenas × 4 cadenas ═══
ax = fig.add_subplot(gs[0, 0])
for k,(nom,col,res,_) in enumerate(CAD):
    for i,(e,r) in enumerate(zip(ESC,res)):
        ok = (e == r)
        ax.add_patch(plt.Rectangle((k-.44, i-.42), .88, .84,
                     fc="#2e7d32" if ok else "#c62828", alpha=.85, ec="#37474f", lw=.6))
        ax.text(k, i, r, ha="center", va="center", fontsize=8.6, color="#fff", weight="bold")
    n = sum(e==r for e,r in zip(ESC,res))
    ax.text(k, -1.15, f"{n}/11", ha="center", fontsize=13, weight="bold", color=col)
    ax.text(k, -1.75, nom, ha="center", fontsize=9.6, weight="bold", color=col)
ax.set_xlim(-.75, 3.75); ax.set_ylim(-2.1, 10.7)
ax.set_yticks(range(11)); ax.set_yticklabels(ESC, fontsize=9)
ax.set_xticks([]); ax.invert_yaxis()
ax.set_ylabel("escena esperada", fontsize=10)
for s in ax.spines.values(): s.set_visible(False)
ax.set_title("A · Las cuatro cadenas cámara → filtro → clasificador\n"
             "11 escenas · iverilog · idéntico en el Mac y en la VM, número por número",
             fontsize=11.2, weight="bold", pad=12, linespacing=1.5)

# ═══ B · la pista: RTL contra golden ═══
ax = fig.add_subplot(gs[0, 1])
D = [("Sobel", 367, 352, "#546e7a"), ("Canny 1-salto", 360, 326, "#66bb6a")]
x = np.arange(2); w = .34
ax.bar(x-w/2, [d[1] for d in D], w, color="#b0bec5", ec="#37474f", lw=.8, label="golden (Python)")
ax.bar(x+w/2, [d[2] for d in D], w, color=[d[3] for d in D], ec="#37474f", lw=.8, label="RTL (iverilog)")
for i,(n,p,r,c) in enumerate(D):
    ax.text(i-w/2, p+5, str(p), ha="center", fontsize=9, color="#546e7a", weight="bold")
    ax.text(i+w/2, r+5, str(r), ha="center", fontsize=9, color=c, weight="bold")
    ax.text(i, 150, f"−{p-r}\n({100*(p-r)/p:.0f} %)", ha="center", fontsize=11,
            weight="bold", color="#c62828", linespacing=1.4)
ax.set_xticks(x); ax.set_xticklabels([d[0] for d in D], fontsize=10)
ax.set_ylabel("píxeles de borde · escena 3", fontsize=10)
ax.set_ylim(0, 430); ax.grid(axis="y", alpha=.28); ax.legend(fontsize=9, loc="upper right")
ax.set_title("B · LA PISTA: el RTL cuenta MENOS bordes\nque el golden, sobre la MISMA ventana",
             fontsize=11.2, weight="bold", pad=12, linespacing=1.5)
ax.text(.5, .035, "y los márgenes de esta imagen son de 10 y 35:\nun 9 % de bordes alcanza para darla vuelta",
        transform=ax.transAxes, ha="center", fontsize=8.6, color="#37474f", linespacing=1.5,
        bbox=dict(fc="#fff3e0", ec="#ffb74d", lw=.9, boxstyle="round,pad=0.45"))

fig.text(.5, -.03, "La cámara está VERIFICADA: su ventana de 28×28 reproduce la imagen de MNIST "
         "exactamente (mismos 367 bordes, mismo margen, misma predicción).  "
         "La diferencia aparece DESPUÉS, en el extractor.",
         ha="center", fontsize=9.8, color="#263238", weight="bold")
plt.savefig("fig_cadenas_iverilog.png", dpi=140, bbox_inches="tight")
print("ok")
