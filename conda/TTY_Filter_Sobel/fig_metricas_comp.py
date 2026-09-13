# === Cuaderno 2 · figura 7: todas las metricas, Sobel vs Canny, mismo procedimiento ===
import numpy as np, matplotlib.pyplot as plt
d = np.load("../../clasificador_mnist/comparar_metricas.npz")
S = {k: d[f"Sobel_{k}"] for k in ["P","R","F"]}
C = {k: d[f"Canny1_{k}"] for k in ["P","R","F"]}
eS, eC = d["Sobel_esc"], d["Canny1_esc"]     # acc, f1, cob, prec, nVP, nFP, nFN, nVN

fig = plt.figure(figsize=(13.4, 5.2))
gs = fig.add_gridspec(1, 3, width_ratios=[1.25, 1.1, 1], wspace=.3)

# A · precision vs recall por clase, y como se MUEVEN
a = fig.add_subplot(gs[0])
for c in range(10):
    a.annotate("", xy=(C["R"][c]*100, C["P"][c]*100), xytext=(S["R"][c]*100, S["P"][c]*100),
               arrowprops=dict(arrowstyle="->", color="#bbb", lw=1.1))
a.scatter(S["R"]*100, S["P"]*100, s=70, c="#546e7a", label="Sobel", zorder=3)
a.scatter(C["R"]*100, C["P"]*100, s=70, c="#2e7d32", marker="s", label="Canny1", zorder=3)
for c in range(10):
    a.annotate(str(c), (S["R"][c]*100, S["P"][c]*100), fontsize=9,
               xytext=(-11, -4), textcoords="offset points", color="#546e7a")
    a.annotate(str(c), (C["R"][c]*100, C["P"][c]*100), fontsize=9, weight="bold",
               xytext=(6, -4), textcoords="offset points", color="#2e7d32")
a.plot([70,100],[70,100], "--", c="grey", lw=.9)
a.set_xlabel("recall %"); a.set_ylabel("precisión %")
a.set_title("A · Cada dígito, y adónde lo mueve el Canny\n"
            "(la flecha va de Sobel a Canny)", fontsize=10.5)
a.legend(fontsize=8.5, loc="lower left"); a.grid(alpha=.3)

# B · F1 por clase
b = fig.add_subplot(gs[1])
x = np.arange(10); w = .38
b.bar(x-w/2, S["F"], w, color="#546e7a", ec="#333", label="Sobel")
b.bar(x+w/2, C["F"], w, color="#2e7d32", ec="#333", label="Canny1")
b.set_xticks(x); b.set_xlabel("dígito"); b.set_ylabel("F1")
b.set_ylim(.75, 1.0); b.grid(axis="y", alpha=.3); b.legend(fontsize=8.5)
b.set_title(f"B · F1 por clase\nmacro: {eS[1]:.3f} → {eC[1]:.3f}", fontsize=10.5)

# C · el 2x2 de la clase NADA, lado a lado
c = fig.add_subplot(gs[2]); c.axis("off")
et = ["VP\nhabló y acertó", "FP\nhabló y erró", "FN\nse calló, sabía", "VN\nse calló, no sabía"]
col = ["#2e7d32", "#c62828", "#ef6c00", "#1565c0"]
for i in range(4):
    y = 3-i
    c.add_patch(plt.Rectangle((0,y), .46, .86, color=col[i], alpha=.85))
    c.add_patch(plt.Rectangle((.54,y), .46, .86, color=col[i], alpha=.85))
    c.text(.23, y+.55, f"{int(eS[4+i])}", ha="center", color="w", fontsize=13, weight="bold")
    c.text(.77, y+.55, f"{int(eC[4+i])}", ha="center", color="w", fontsize=13, weight="bold")
    c.text(.5, y+.14, et[i], ha="center", color="w", fontsize=7.6)
c.text(.23, 3.95, "Sobel", ha="center", fontsize=10, weight="bold")
c.text(.77, 3.95, "Canny1", ha="center", fontsize=10, weight="bold")
c.set_xlim(-.05,1.05); c.set_ylim(-.15,4.25)
c.set_title(f"C · La clase NADA\ncobertura {eS[2]:.0%}→{eC[2]:.0%} · "
            f"precisión {eS[3]:.1%}→{eC[3]:.1%}", fontsize=10.5)
plt.savefig("fig_metricas_comp.png", dpi=140, bbox_inches="tight")
plt.show()

print(f"exactitud   Sobel {eS[0]:.2%}   Canny {eC[0]:.2%}   ({eC[0]-eS[0]:+.2%})")
print(f"F1 macro    Sobel {eS[1]:.3f}    Canny {eC[1]:.3f}")
print("\ndonde MAS cambia el F1:")
dif = C["F"] - S["F"]
for c in np.argsort(-np.abs(dif))[:4]:
    print(f"   dígito {c}: {S['F'][c]:.3f} -> {C['F'][c]:.3f}  ({dif[c]:+.3f})")
