# fig_celdas_ihp.py — de que esta hecho cada reconocedor, celda por celda.
# Datos: resumen de LibreLane 3.0.5 en la accion de Tiny Tapeout (lanza IHP26b, SG13G2).
import numpy as np, matplotlib
import matplotlib.pyplot as plt

CAT = ["Combo Logic","NOR","Misc (dlygate4sd3)","Flip-Flops (dfrbpq)",
       "Buffer","NAND","Inversor","OR / XOR","AND","Multiplexor"]
SOB = [3373, 1823, 1654, 1527, 1289,  779, 765, 284, 211,  69]
CAN = [3708, 1977, 1880, 1776, 1497, 1184, 570, 253, 189, 142]
assert sum(SOB) == 11774 and sum(CAN) == 13176

fig = plt.figure(figsize=(15.5, 9.2))
gs = fig.add_gridspec(2, 3, height_ratios=[1.35, 1], hspace=.42, wspace=.34)

# ---- A: barras por categoria --------------------------------------------
ax = fig.add_subplot(gs[0, :2])
y = np.arange(len(CAT))[::-1]
h = .38
ax.barh(y+h/2, SOB, h, color="#4c72b0", label="Sobel · 11 774 celdas")
ax.barh(y-h/2, CAN, h, color="#c44e52", label="Canny 1-salto · 13 176")
for i,(s,c) in enumerate(zip(SOB,CAN)):
    yy = y[i]
    ax.text(s+60, yy+h/2, f"{s:,}".replace(",", " "), va="center", fontsize=8.5, color="#2c4470")
    ax.text(c+60, yy-h/2, f"{c:,}".replace(",", " "), va="center", fontsize=8.5, color="#8a2f33")
    d = c-s
    ax.text(max(s,c)+660, yy, f"{d:+,}".replace(",", " "),
            va="center", fontsize=8.5, weight="bold",
            color="#c44e52" if d>0 else "#55a868")
ax.set_yticks(y); ax.set_yticklabels(CAT, fontsize=10)
ax.set_xlim(0, 4750); ax.set_xlabel("celdas (sin relleno ni taps)")
ax.set_title("A · De qué está hecho cada reconocedor\n"
             "el Canny cuesta 1 402 celdas más (+11.9 %)",
             fontsize=11.5, loc="left")
ax.legend(fontsize=9.5, frameon=False, loc="lower right")
ax.grid(axis="x", alpha=.25); ax.set_axisbelow(True)
for s_ in ("top","right"): ax.spines[s_].set_visible(False)

# ---- B: de donde sale el sobrecosto -------------------------------------
ax = fig.add_subplot(gs[0, 2])
dif  = [c-s for s,c in zip(SOB,CAN)]
orden = np.argsort(dif)[::-1]
lab = [CAT[i].split(" (")[0] for i in orden]
val = [dif[i] for i in orden]
col = ["#c44e52" if v>0 else "#55a868" for v in val]
ax.barh(range(len(val))[::-1], val, .62, color=col)
for i,v in enumerate(val):
    ax.text(v + (25 if v>0 else -25), len(val)-1-i, f"{v:+}",
            va="center", ha="left" if v>0 else "right", fontsize=8.5)
ax.set_yticks(range(len(val))[::-1]); ax.set_yticklabels(lab, fontsize=9)
ax.axvline(0, color="k", lw=.8)
ax.set_xlim(-320, 560); ax.set_xlabel("celdas de diferencia")
ax.set_title("B · El sobrecosto del Canny\n"
             "+405 NAND · +335 combinacional · +249 biestables\n"
             "y −195 inversores: el sintetizador CAMBIÓ de estilo",
             fontsize=11, loc="left")
ax.grid(axis="x", alpha=.25); ax.set_axisbelow(True)
for s_ in ("top","right"): ax.spines[s_].set_visible(False)

# ---- C: las DOS cuentas de celdas, otra vez -----------------------------
ax = fig.add_subplot(gs[1, 0])
ax.axis("off")
ax.set_title("C · Las dos cuentas de celdas, por tercera vez", fontsize=11, loc="left")
txt = (
"                      Sobel     Canny\n"
"instancias totales   46 019    46 476\n"
"  − relleno/decap    32 700    31 506\n"
"  ─────────────────────────────────\n"
"  LibreLane dice     13 319    14 970   ← §31 v1\n"
"  − taps              1 545     1 794\n"
"  ─────────────────────────────────\n"
"  Tiny Tapeout dice  11 774    13 176   ← real\n"
"\n"
"Los taps implícitos dan 14.94 y 15.03 µm²\n"
"cada uno: el MISMO número en los dos chips.\n"
"Queda probado que la diferencia son taps,\n"
"no un error de nadie.\n"
"\n"
"El factor Canny/Sobel NO cambia:  1.12×")
ax.text(0, .96, txt, va="top", family="monospace", fontsize=9.1, linespacing=1.5)

# ---- D: la fraccion de biestables ---------------------------------------
ax = fig.add_subplot(gs[1, 1])
nom = ["Sobel","Canny"]
ff  = [48.84, 50.08]
ax.bar(nom, ff, .5, color=["#4c72b0","#c44e52"])
ax.bar(nom, [100-v for v in ff], .5, bottom=ff, color="#dcdcdc")
for i,v in enumerate(ff):
    ax.text(i, v/2, f"{v:.1f} %", ha="center", va="center",
            color="w", weight="bold", fontsize=12)
    ax.text(i, v+(100-v)/2, "lógica\ncombinacional", ha="center", va="center", fontsize=9)
ax.axhline(50, color="k", ls="--", lw=1)
ax.set_ylim(0,100); ax.set_ylabel("% del área funcional")
ax.set_title("D · Área ocupada por biestables\n"
             "en el Canny ya pasa la mitad", fontsize=11, loc="left")
for s_ in ("top","right"): ax.spines[s_].set_visible(False)

# ---- E: los transistores y el presupuesto de SPICE ----------------------
ax = fig.add_subplot(gs[1, 2])
ax.axis("off")
ax.set_title("E · 116 314 FET — y qué habilita eso", fontsize=11, loc="left")
txt = (
"El visor de TT cuenta, en el Sobel:\n"
"   FET       116 314\n"
"   inversores 18 522\n"
"   segmentos 200 417\n"
"\n"
"femto, ya simulado en SPICE en esta tesis:\n"
"   FET       121 310   →  200 µs de transitorio\n"
"\n"
"Son el MISMO tamaño. La prueba de NGSpice\n"
"no está limitada por el número de\n"
"transistores, sino por cuántos ciclos hay\n"
"que simular.")
ax.text(0, .93, txt, va="top", family="monospace", fontsize=9.1, linespacing=1.5)

fig.suptitle("Los dos reconocedores MNIST en Tiny Tapeout · IHP SG13G2 · LibreLane 3.0.5",
             fontsize=13.5, y=.985)
plt.savefig("fig_celdas_ihp.png", dpi=140, bbox_inches="tight")
plt.show()
print("ok")
