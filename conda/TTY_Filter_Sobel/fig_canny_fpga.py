# === Cuaderno 2 · figura 6: el Canny en FPGA, y los 54 intentos en la placa ===
# Dos mitades: lo que cuesta el filtro en cada tecnologia, y lo que contesto el silicio.
from collections import Counter
import numpy as np, matplotlib.pyplot as plt

# --- lo anotado del video canny_prueba_1.mp4 ('-' = NADA) ---
D = {0:[0,'-',0], 1:[0,6,9,7,0,'-'], 2:[7,9,0,7,0,6], 3:['-',2,0,4,3,6,0,4],
     4:[5,0,'-',6,0,4,9,7], 5:[0,'-',5,6,4], 6:[0,'-',7,9,5,6],
     7:[0,6,4,7,7,0,0,6,7], 9:[0,7,6]}

fig = plt.figure(figsize=(13.2, 4.9))
gs = fig.add_gridspec(1, 3, width_ratios=[1, 1.15, 1.25], wspace=.34)

# A · el mismo filtro en dos tecnologias
a = fig.add_subplot(gs[0])
x = np.arange(2); w = .36
sob = [49112/49112, 2942/2942]          # normalizado al Sobel de cada tecnologia
can = [109172/49112, 2956/2942]
a.bar(x-w/2, sob, w, label="Sobel", color="#546e7a", ec="#333")
a.bar(x+w/2, can, w, label="Canny1", color="#2e7d32", ec="#333")
for i,(s,c) in enumerate(zip(sob,can)):
    a.text(i+w/2, c+.04, f"×{c:.2f}", ha="center", fontsize=11, weight="bold",
           color="#c62828" if c>1.5 else "#2e7d32")
a.set_xticks(x); a.set_xticklabels(["sky130\n(ASIC)", "iCE40\n(FPGA)"], fontsize=9.5)
a.set_ylabel("costo relativo al Sobel"); a.set_ylim(0, 2.6)
a.axhline(1, c="#333", lw=.8, ls="--")
a.set_title("A · El mismo filtro,\ndos tecnologías, dos conclusiones", fontsize=10.5)
a.legend(fontsize=8.5); a.grid(axis="y", alpha=.3)

# B · utilizacion real medida por nextpnr
b = fig.add_subplot(gs[1])
et = ["Sobel\n+cámara+TFT", "Canny1\n+cámara+TFT"]
lc = [4453, 4622]
bars = b.bar(et, lc, color=["#546e7a", "#2e7d32"], ec="#333", width=.55)
b.axhline(5280, c="#c62828", lw=2)
b.text(1.45, 5280, " 5 280 LC\n (el techo)", va="center", fontsize=8.5, color="#c62828")
for r, v in zip(bars, lc):
    b.text(r.get_x()+r.get_width()/2, v-420, f"{v}\n{v/5280:.0%}", ha="center",
           fontsize=10, color="w", weight="bold")
b.set_ylim(0, 5900); b.set_ylabel("ICESTORM_LC"); b.grid(axis="y", alpha=.3)
b.set_title("B · Y entra: 87 % de la iCE40UP5K\n(estimado 4 611, medido 4 622)", fontsize=10.5)

# C · que contesto la placa en 54 intentos
c = fig.add_subplot(gs[2])
pred = Counter(x for g in D.values() for x in g if x != '-')
ks = sorted(pred, key=lambda k: -pred[k])
col = ["#c62828" if pred[k]/48 > .15 else "#546e7a" for k in ks]
c.bar([str(k) for k in ks], [pred[k] for k in ks], color=col, ec="#333")
c.set_xlabel("lo que contestó el circuito"); c.set_ylabel("veces (de 48 respuestas)")
c.set_title("C · 54 intentos con la cámara:\nel 0 se lleva el 33 %", fontsize=10.5)
c.grid(axis="y", alpha=.3)
c.text(.5, .92, "1, 2 y 9: cero veces", transform=c.transAxes, ha="center",
       fontsize=8.5, style="italic", color="#c62828")
plt.savefig("fig_canny_fpga.png", dpi=140, bbox_inches="tight")
plt.show()

tot=sum(len(g) for g in D.values()); hit=sum(1 for d,g in D.items() for x in g if x==d)
nada=sum(1 for g in D.values() for x in g if x=='-')
print(f"aciertos {hit}/{tot} = {hit/tot:.1%} · NADA {nada}/{tot} = {nada/tot:.0%}")
print(f"Sobel (Parte 181): 7/72 = {7/72:.1%}   ·   diferencia {hit/tot-7/72:+.1%}  (z = 1.16, NO significativa)")
