# === Cuaderno 2 · figura 11: el SoC RISC-V + clasificador, en silicio ===
import numpy as np, matplotlib.pyplot as plt

P184 = {0:"0",1:"1",2:"0",3:"8",4:"4",5:"5",6:"6",7:"7",8:"8",9:"9"}   # sin CPU, thr=60
SOC  = {0:"0",1:"1",2:"0",3:"2",4:"4",5:"5",6:"6",7:"7",8:"8",9:"9"}   # con CPU, thr=90

fig = plt.figure(figsize=(13.2, 4.7))
gs = fig.add_gridspec(1, 3, width_ratios=[1.5, 1, 1.05], wspace=.3)

# A · los diez digitos, las dos versiones
a = fig.add_subplot(gs[0])
for i in range(10):
    for j, (D, et) in enumerate([(P184, "sin CPU"), (SOC, "con CPU")]):
        ok = D[i] == str(i)
        a.add_patch(plt.Rectangle((i-.44+j*.44, 0), .42, .9,
                    color="#2e7d32" if ok else "#c62828", alpha=.85))
        a.text(i-.23+j*.44, .45, D[i], ha="center", va="center", c="w",
               fontsize=11, weight="bold")
a.add_patch(plt.Rectangle((2.56, -.06), .92, 1.02, fill=False, ec="#f9a825", lw=2.5))
a.text(3.02, 1.06, "el 3 CAMBIÓ\n8 → 2", ha="center", fontsize=8.5, color="#f57f17", weight="bold")
a.set_xticks(range(10)); a.set_xlim(-.7, 9.7); a.set_ylim(-.4, 1.4); a.set_yticks([])
a.text(-.95, .45, "izq: Parte 184 (sin CPU)\nder: hoy (con CPU)", ha="right", va="center", fontsize=8)
a.set_xlabel("dígito embebido en el bitstream")
a.set_title("A · Los diez dígitos en la placa: 8/10 en las dos\ny el umbral del firmware mueve UNA decisión",
            fontsize=10.5)
for s in a.spines.values(): s.set_visible(False)

# B · lo que entra y lo que no
b = fig.add_subplot(gs[1])
comb = ["ROM+clf", "ROM+clf\n+CPU", "cám+clf\n+TFT", "cám+clf\n+CPU"]
lc   = [2879, 4670, 4622, 6656]
col  = ["#546e7a" if v <= 5280 else "#c62828" for v in lc]
bars = b.bar(comb, lc, color=col, ec="#333", width=.6)
b.axhline(5280, c="#c62828", lw=2); b.text(3.5, 5280, " techo", va="center", fontsize=8, color="#c62828")
for r, v in zip(bars, lc):
    b.text(r.get_x()+r.get_width()/2, v+120, f"{v}\n{v/5280:.0%}", ha="center", fontsize=8)
b.set_ylim(0, 7600); b.set_ylabel("ICESTORM_LC"); b.grid(axis="y", alpha=.3)
b.set_xticklabels(comb, fontsize=8)
b.set_title("B · Se puede tener cámara,\no CPU. No los dos.", fontsize=10.5)

# C · el recurso que sobra
c = fig.add_subplot(gs[2])
rec = ["LC", "BRAM", "SPRAM"]
uso = [4670/5280, 20/30, 0/4]
bars = c.barh(rec, [u*100 for u in uso],
              color=["#c62828", "#ef6c00", "#2e7d32"], ec="#333", height=.55)
for r, u in zip(bars, uso):
    c.text(u*100+2, r.get_y()+r.get_height()/2, f"{u:.0%}", va="center", fontsize=10, weight="bold")
c.set_xlim(0, 118); c.set_xlabel("% usado"); c.grid(axis="x", alpha=.3)
c.set_title("C · Falta lógica, sobra memoria\n128 KB de SPRAM sin tocar", fontsize=10.5)
plt.savefig("fig_soc_silicio.png", dpi=140, bbox_inches="tight")
plt.show()

print("placa con CPU :", " ".join(f"{i}->{SOC[i]}" for i in range(10)),
      f"  ->  {sum(SOC[i]==str(i) for i in range(10))}/10")
print("Parte 184     :", " ".join(f"{i}->{P184[i]}" for i in range(10)),
      f"  ->  {sum(P184[i]==str(i) for i in range(10))}/10")
print("difieren en:", [i for i in range(10) if SOC[i] != P184[i]])
