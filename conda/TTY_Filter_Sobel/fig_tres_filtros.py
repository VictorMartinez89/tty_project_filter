# === Cuaderno 2 · figura 8: los TRES filtros de la tesis como front-end ===
# Lo que cuesta cada uno en silicio, contra lo que rinde clasificando.
import numpy as np, matplotlib.pyplot as plt
d = np.load("../../clasificador_mnist/comparar_metricas.npz")
F = ["Sobel", "Canny1", "Transitivo"]
COL = {"Sobel":"#546e7a", "Canny1":"#2e7d32", "Transitivo":"#c62828"}
# celdas sky130 de los chips "completo" SIN CPU (tabla maestra de la tesis)
CEL = {"Sobel":36730, "Canny1":42581, "Transitivo":137092}
esc = {n: d[f"{n}_esc"] for n in F}          # acc, f1, cob, prec, nVP, nFP, nFN, nVN

fig, (a1, a2, a3) = plt.subplots(1, 3, figsize=(13.6, 4.6))

# A · costo vs rendimiento
for n in F:
    a1.scatter(CEL[n]/1000, esc[n][0]*100, s=180, c=COL[n], zorder=3, ec="#333")
    a1.annotate(n, (CEL[n]/1000, esc[n][0]*100), fontsize=9.5, weight="bold",
                xytext=(0, 13), textcoords="offset points", ha="center", color=COL[n])
a1.axvline(45, c="#999", ls="--", lw=1)
a1.text(46, 89.9, "el transitivo\nNO entra en\nTiny Tapeout", fontsize=8, color="#c62828")
a1.set_xlabel("celdas sky130 (miles)"); a1.set_ylabel("exactitud a 4 bits  %")
a1.set_xscale("log"); a1.set_xlim(28, 220); a1.set_ylim(89, 93)
a1.set_title("A · Lo que cuesta vs lo que rinde\nel más caro es el peor", fontsize=10.5)
a1.grid(alpha=.3)

# B · F1 por clase, los tres
x = np.arange(10); w = .27
for k, n in enumerate(F):
    a2.bar(x + (k-1)*w, d[f"{n}_F"], w, color=COL[n], ec="#333", label=n)
a2.set_xticks(x); a2.set_xlabel("dígito"); a2.set_ylabel("F1")
a2.set_ylim(.75, 1.0); a2.grid(axis="y", alpha=.3); a2.legend(fontsize=8)
a2.set_title("B · F1 por clase\n" + " · ".join(f"{n[:5]} {esc[n][1]:.3f}" for n in F), fontsize=10.5)

# C · resumen
et = ["exactitud", "F1 macro", "precisión\nal hablar"]
vals = {n: [esc[n][0]*100, esc[n][1]*100, esc[n][3]*100] for n in F}
x2 = np.arange(3)
for k, n in enumerate(F):
    b = a3.bar(x2 + (k-1)*w, vals[n], w, color=COL[n], ec="#333", label=n)
    for r, v in zip(b, vals[n]):
        a3.text(r.get_x()+r.get_width()/2, v+.25, f"{v:.1f}", ha="center", fontsize=7.5)
a3.set_xticks(x2); a3.set_xticklabels(et, fontsize=9); a3.set_ylim(85, 101)
a3.grid(axis="y", alpha=.3); a3.legend(fontsize=8)
a3.set_title("C · Las tres métricas principales\n(mismo procedimiento para los tres)", fontsize=10.5)
plt.tight_layout()
plt.savefig("fig_tres_filtros.png", dpi=140)
plt.show()

print(f"{'filtro':<12}{'celdas':>9}{'area util':>11}{'exactitud':>11}{'F1':>8}{'prec.NADA':>11}")
for n in F:
    au = 576 if n != "Canny1" else 484
    print(f"{n:<12}{CEL[n]:>9}{au:>11}{esc[n][0]:>11.2%}{esc[n][1]:>8.3f}{esc[n][3]:>11.2%}")
print(f"\npeor clase de cada uno:")
for n in F:
    c = int(np.argmin(d[f"{n}_F"]))
    print(f"  {n:<12} digito {c}: F1 {d[f'{n}_F'][c]:.3f}  "
          f"(P {d[f'{n}_P'][c]:.1%} / R {d[f'{n}_R'][c]:.1%})")
