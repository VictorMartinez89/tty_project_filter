# === Cuaderno 2 · figura 14: el instrumento que inventaba ===
import numpy as np, matplotlib.pyplot as plt

fig, (a1, a2, a3) = plt.subplots(1, 3, figsize=(13.4, 4.4))

# A · las tres correcciones, una detrás de la otra
et = ["medición\noriginal", "1· dos\npasadas", "2· flujo\ncompleto", "3· alinear\npor etapas"]
val = [97.31, 97.31, 99.93, 99.93]
sob = [72.92, 100.0, 100.0, 100.0]
x = np.arange(4); w = .38
a1.bar(x-w/2, sob, w, color="#546e7a", ec="#333", label="etapa Sobel (8 bits)")
a1.bar(x+w/2, val, w, color="#2e7d32", ec="#333", label="mapa de bordes")
for i,(s,v) in enumerate(zip(sob,val)):
    a1.text(i-w/2, s+1, f"{s:.0f}", ha="center", fontsize=8)
    a1.text(i+w/2, v+1, f"{v:.1f}", ha="center", fontsize=8)
a1.set_xticks(x); a1.set_xticklabels(et, fontsize=7.5); a1.set_ylim(65, 108)
a1.set_ylabel("coincidencia con el golden  %"); a1.legend(fontsize=7.5); a1.grid(axis="y", alpha=.3)
a1.set_title("A · Tres errores de medición,\nuno detrás del otro", fontsize=10.5)

# B · por que un mapa binario engana
a2.axis("off")
a2.text(.5, .95, "Por qué un mapa BINARIO engaña", ha="center", fontsize=10.5, weight="bold")
np.random.seed(3)
m = (np.random.rand(9,9) > .5).astype(int)
for k,(t,off) in enumerate([("alineación correcta",0), ("alineación EQUIVOCADA",2)]):
    y0 = .62 - k*.34
    a2.text(.06, y0+.17, t, fontsize=8.5, weight="bold")
    mm = np.roll(m, off, axis=1)
    ig = (m == mm)
    for r in range(9):
        for c in range(9):
            a2.add_patch(plt.Rectangle((.08+c*.035, y0-r*.018), .033, .016,
                         color="#2e7d32" if ig[r,c] else "#c62828", alpha=.8))
    a2.text(.44, y0-.07, f"acierta {ig.mean():.0%}\nsolo por los ceros", fontsize=8.5,
            color="#c62828" if off else "#2e7d32")
a2.text(.5, .06, "una señal DENSA (8 bits) no tiene ese problema:\nel óptimo es inequívoco",
        ha="center", fontsize=8.5, style="italic")
a2.set_xlim(0,1); a2.set_ylim(0,1)

# C · el resultado, contra el Canny ya fabricado
nm = ["mnist_feat_canny\n(este módulo)", "canny1_top\n(en los chips sky130)"]
v = [99.93, 99.91]
b = a3.bar(nm, v, color=["#2e7d32","#546e7a"], ec="#333", width=.5)
for r,x_ in zip(b,v):
    a3.text(r.get_x()+r.get_width()/2, x_-.04, f"{x_:.2f} %", ha="center",
            color="w", fontsize=11, weight="bold")
a3.set_ylim(99.7, 100.02); a3.set_ylabel("píxeles coincidentes  %"); a3.grid(axis="y", alpha=.3)
a3.set_xticklabels(nm, fontsize=8)
a3.set_title("C · Y las diferencias, en los dos,\ncaen TODAS en la última fila", fontsize=10.5)
plt.tight_layout()
plt.savefig("fig_verificacion.png", dpi=140)
plt.show()
print("etapa Sobel:   72.92 % -> 100.00 %  (volcar dos pasadas)")
print("mapa de bordes: 97.31 % ->  99.93 %  (flujo completo + alinear por etapas)")
print("imagenes exactas: 32/50 · diferencias en la ultima fila: 18/18")
