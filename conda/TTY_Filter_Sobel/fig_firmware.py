# === Cuaderno 2 · figura 13: el firmware del Sobel rompe el Canny ===
import numpy as np, matplotlib.pyplot as plt

CFG = [("referencia\n110/40", 110, 40, 57.9, 92.03, "#2e7d32"),
       ("firmware del SOBEL\n90/0", 90, 0, 64.7, 89.93, "#c62828"),
       ("firmware del CANNY\n90/32", 90, 32, 58.8, 92.46, "#1565c0"),
       ("firmware alt.\n90/58", 90, 58, 56.2, 91.43, "#546e7a")]

fig, (a1, a2, a3) = plt.subplots(1, 3, figsize=(13.4, 4.5))

# A · exactitud
et = [c[0] for c in CFG]; acc = [c[4] for c in CFG]; col = [c[5] for c in CFG]
b = a1.bar(range(4), acc, color=col, ec="#333", width=.62)
for r, v in zip(b, acc):
    a1.text(r.get_x()+r.get_width()/2, v+.1, f"{v:.2f}", ha="center", fontsize=9, weight="bold")
a1.set_xticks(range(4)); a1.set_xticklabels(et, fontsize=7.5)
a1.set_ylim(88.5, 93.2); a1.set_ylabel("exactitud a 4 bits  %"); a1.grid(axis="y", alpha=.3)
a1.set_title("A · El firmware del Sobel le cuesta\nal Canny 2.10 puntos", fontsize=10.5)

# B · el mecanismo: la densidad
den = [c[3] for c in CFG]
b = a2.bar(range(4), den, color=col, ec="#333", width=.62)
for r, v in zip(b, den):
    a2.text(r.get_x()+r.get_width()/2, v+.4, f"{v:.1f}%", ha="center", fontsize=9)
a2.set_xticks(range(4)); a2.set_xticklabels(et, fontsize=7.5)
a2.set_ylim(50, 69); a2.set_ylabel("densidad de bordes  %"); a2.grid(axis="y", alpha=.3)
a2.set_title("B · El mecanismo: con thr_lo=0\nla histéresis promueve de más", fontsize=10.5)

# C · lo que cambia en la ROM
a3.axis("off")
a3.text(.5, .95, "Lo que hay que cambiar en el chip", ha="center", fontsize=11, weight="bold")
txt = [
 ("#c62828", "firmware original (Sobel)", [
    "lui  x3,0x6",
    "addi x3,x3,-1536      # x3 = 0x5A00",
    "sw   x3,4(x1)         # thr_hi=90  thr_lo=0"]),
 ("#1565c0", "firmware del Canny", [
    "lui  x3,0x6",
    "addi x3,x3,-1504      # x3 = 0x5A20",
    "sw   x3,4(x1)         # thr_hi=90  thr_lo=32"])]
y = .80
for c, tit, ls in txt:
    a3.text(.03, y, tit, fontsize=9.5, weight="bold", color=c); y -= .09
    for l in ls:
        a3.text(.06, y, l, fontsize=8.6, family="monospace"); y -= .075
    y -= .06
a3.add_patch(plt.Rectangle((.02, .06), .96, .16, fc="#fff8e1", ec="#f9a825", lw=1.6))
a3.text(.5, .155, "UNA constante: −1536 → −1504", ha="center", fontsize=10, weight="bold", color="#f57f17")
a3.text(.5, .095, "el mismo silicio, sin resintetizar", ha="center", fontsize=8.5, style="italic")
a3.set_title("C · Dos instrucciones de diferencia", fontsize=10.5)
plt.tight_layout()
plt.savefig("fig_firmware.png", dpi=140)
plt.show()
print(f"firmware del Sobel sobre el Canny: {89.93-92.03:+.2f} pp")
print(f"firmware propio del Canny:         {92.46-89.93:+.2f} pp de recuperacion")
print(f"y el mejor resultado del cuaderno:  92.46 %")
