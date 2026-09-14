# === Cuaderno 2 · figura 12: los CUATRO front-ends con el mismo procedimiento ===
import numpy as np, matplotlib.pyplot as plt
d = np.load("../../clasificador_mnist/comparar_metricas.npz")
F = ["Sobel", "SoC+Sobel", "Canny1", "Transitivo"]
COL = {"Sobel":"#546e7a", "SoC+Sobel":"#1565c0", "Canny1":"#2e7d32", "Transitivo":"#c62828"}
esc = {n: d[f"{n}_esc"] for n in F}     # acc,f1,cob,prec,nVP,nFP,nFN,nVN

fig = plt.figure(figsize=(13.6, 5.0))
gs = fig.add_gridspec(1, 3, width_ratios=[1.05, 1.35, 1], wspace=.3)

# A · las tres metricas principales
a = fig.add_subplot(gs[0])
et = ["exactitud", "F1 macro\n(×100)", "precisión\nal hablar"]
x = np.arange(3); w = .2
for k, n in enumerate(F):
    v = [esc[n][0]*100, esc[n][1]*100, esc[n][3]*100]
    a.bar(x + (k-1.5)*w, v, w, color=COL[n], ec="#333", label=n)
a.set_xticks(x); a.set_xticklabels(et, fontsize=8.5); a.set_ylim(85, 101)
a.grid(axis="y", alpha=.3); a.legend(fontsize=7.5)
a.set_title("A · Las tres métricas\nSobel y SoC+Sobel: idénticos", fontsize=10.5)

# B · F1 por clase, los cuatro
b = fig.add_subplot(gs[1])
xs = np.arange(10); w2 = .2
for k, n in enumerate(F):
    b.bar(xs + (k-1.5)*w2, d[f"{n}_F"], w2, color=COL[n], ec="#333", label=n)
b.set_xticks(xs); b.set_xlabel("dígito"); b.set_ylabel("F1")
b.set_ylim(.75, 1.0); b.grid(axis="y", alpha=.3); b.legend(fontsize=7.5, ncol=2)
b.set_title("B · F1 por clase", fontsize=10.5)
b.add_patch(plt.Rectangle((2.6, .75), .8, .25, fill=False, ec="#f9a825", lw=2.2))
b.text(3.0, 1.005, "el 3", ha="center", fontsize=8.5, color="#f57f17", weight="bold")

# C · lo que el umbral SI mueve: Sobel(60) -> SoC(90), por clase
c = fig.add_subplot(gs[2])
dif = d["SoC+Sobel_F"] - d["Sobel_F"]
col = ["#2e7d32" if v > 0 else "#c62828" for v in dif]
c.barh(np.arange(10), dif, color=col, ec="#333", height=.6)
c.set_yticks(np.arange(10)); c.set_ylabel("dígito"); c.invert_yaxis()
c.axvline(0, c="#333", lw=1)
c.set_xlabel("Δ F1 al pasar el umbral de 60 a 90")
c.grid(axis="x", alpha=.3)
for i, v in enumerate(dif):
    if abs(v) > .02:
        c.text(v + (.003 if v > 0 else -.003), i, f"{v:+.3f}", va="center",
               ha="left" if v > 0 else "right", fontsize=8, weight="bold")
c.set_title(f"C · El umbral no cambia el total\n…pero mueve las clases", fontsize=10.5)
plt.savefig("fig_cuatro.png", dpi=140, bbox_inches="tight")
plt.show()

print(f"{'front-end':<12}{'exactitud':>11}{'F1 macro':>10}{'cobertura':>11}{'prec. hablar':>13}")
for n in F:
    print(f"{n:<12}{esc[n][0]:>11.2%}{esc[n][1]:>10.3f}{esc[n][2]:>11.2%}{esc[n][3]:>13.2%}")
print(f"\nSobel -> SoC+Sobel: exactitud {esc['Sobel'][0]:.2%} -> {esc['SoC+Sobel'][0]:.2%}"
      f"  ({esc['SoC+Sobel'][0]-esc['Sobel'][0]:+.2%})")
print("pero por clase SI se mueve:")
for i in np.argsort(-np.abs(dif))[:3]:
    print(f"   digito {i}: F1 {d['Sobel_F'][i]:.3f} -> {d['SoC+Sobel_F'][i]:.3f}  ({dif[i]:+.3f})")
