# === Cuaderno 2 · figura 15: los CINCO front-ends, y el que corre en la placa ===
import numpy as np, matplotlib.pyplot as plt
d = np.load("../../clasificador_mnist/comparar_metricas.npz")
F = ["Sobel", "SoC+Sobel", "Canny1", "SoC+Canny1", "Transitivo"]
COL = {"Sobel":"#90a4ae","SoC+Sobel":"#546e7a","Canny1":"#66bb6a",
       "SoC+Canny1":"#1b5e20","Transitivo":"#c62828"}
esc = {n: d[f"{n}_esc"] for n in F}     # acc,f1,cob,prec,nVP,nFP,nFN,nVN

fig = plt.figure(figsize=(13.6, 5.2))
gs = fig.add_gridspec(1, 3, width_ratios=[1.1, 1.4, 1], wspace=.32)

# A · las metricas principales
a = fig.add_subplot(gs[0])
et = ["exactitud", "F1 macro\n(×100)", "precisión\nal hablar"]
x = np.arange(3); w = .16
for k, n in enumerate(F):
    v = [esc[n][0]*100, esc[n][1]*100, esc[n][3]*100]
    a.bar(x + (k-2)*w, v, w, color=COL[n], ec="#333", label=n)
a.set_xticks(x); a.set_xticklabels(et, fontsize=8.5); a.set_ylim(85, 101)
a.grid(axis="y", alpha=.3); a.legend(fontsize=7, loc="lower left")
a.set_title("A · SoC+Canny gana en las tres\n(y es el que corre en la placa)", fontsize=10.5)

# B · F1 por clase
b = fig.add_subplot(gs[1])
xs = np.arange(10); w2 = .16
for k, n in enumerate(F):
    b.bar(xs + (k-2)*w2, d[f"{n}_F"], w2, color=COL[n], ec="#333", lw=.4, label=n)
b.set_xticks(xs); b.set_xlabel("dígito"); b.set_ylabel("F1")
b.set_ylim(.75, 1.0); b.grid(axis="y", alpha=.3); b.legend(fontsize=6.5, ncol=3)
b.add_patch(plt.Rectangle((1.58, .75), .84, .25, fill=False, ec="#f9a825", lw=2.2))
b.text(2.0, 1.007, "el 2", ha="center", fontsize=9, color="#f57f17", weight="bold")
b.set_title("B · F1 por clase · el 2 sube de 0.849 a 0.930", fontsize=10.5)

# C · falsos positivos: habló y se equivocó
c = fig.add_subplot(gs[2])
fp = [int(esc[n][5]) for n in F]
bars = c.barh(range(5), fp, color=[COL[n] for n in F], ec="#333", height=.6)
for r, v in zip(bars, fp):
    c.text(v+2, r.get_y()+r.get_height()/2, str(v), va="center", fontsize=9.5, weight="bold")
c.set_yticks(range(5)); c.set_yticklabels(F, fontsize=8); c.invert_yaxis()
c.set_xlabel("FP: habló y se equivocó  (de 10 000)"); c.set_xlim(0, 160)
c.grid(axis="x", alpha=.3)
c.set_title("C · El error caro\nSoC+Canny: 73 · Transitivo: 139", fontsize=10.5)
plt.savefig("fig_cinco.png", dpi=140, bbox_inches="tight")
plt.show()

print(f"{'front-end':<12}{'exactitud':>11}{'F1':>8}{'prec.habla':>12}{'FP':>6}{'filtra':>9}")
for n in F:
    print(f"{n:<12}{esc[n][0]:>11.2%}{esc[n][1]:>8.3f}{esc[n][3]:>12.2%}"
          f"{int(esc[n][5]):>6}{esc[n][7]/(esc[n][7]+esc[n][5]):>9.1%}")
print(f"\ndigito 2:  Sobel {d['Sobel_F'][2]:.3f}  ->  SoC+Canny1 {d['SoC+Canny1_F'][2]:.3f}"
      f"   ({d['SoC+Canny1_F'][2]-d['Sobel_F'][2]:+.3f}, el salto mas grande)")
