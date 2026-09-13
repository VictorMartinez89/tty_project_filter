# === Cuaderno 2 · figura 10: la cadena con CPU en iverilog, y la tolerancia al umbral ===
import numpy as np, matplotlib.pyplot as plt

# lo medido en iverilog (11 escenas generadas desde MNIST, ver utm-share/mnist_cam_soc_sobel)
CPU  = {0:("0",306), 1:("1",140), 2:("6",289), 3:("3",344), 4:("4",254), 5:("5",292),
        6:("NADA",312), 7:("7",219), 8:("8",303), 9:("NADA",223), "NADA":("NADA",0)}
CAB  = {0:("0",327), 1:("1",149), 2:("6",299), 3:("3",352), 4:("4",267), 5:("5",308),
        6:("NADA",328), 7:("7",229), 8:("8",316), 9:("NADA",234), "NADA":("NADA",0)}

fig, (a1, a2) = plt.subplots(1, 2, figsize=(12.6, 4.6),
                             gridspec_kw={"width_ratios":[1.35, 1]})

# A · las once escenas, las dos fuentes de umbral
ks = list(CPU.keys())
x = np.arange(len(ks))
ok_c = [1 if str(CPU[k][0]) == str(k) else 0 for k in ks]
ok_h = [1 if str(CAB[k][0]) == str(k) else 0 for k in ks]
for i, k in enumerate(ks):
    for j, (d, oc) in enumerate([(CPU, ok_c), (CAB, ok_h)]):
        a1.add_patch(plt.Rectangle((i-.42+j*.42, 0), .40, .9,
                     color="#2e7d32" if oc[i] else "#c62828", alpha=.85))
        a1.text(i-.22+j*.42, .45, str(d[k][0]), ha="center", va="center",
                color="w", fontsize=9, weight="bold")
a1.set_xticks(x); a1.set_xticklabels([str(k) for k in ks], fontsize=9)
a1.set_xlim(-.7, len(ks)-.3); a1.set_ylim(-.35, 1.35); a1.set_yticks([])
a1.text(-.95, .45, "izq: CPU (90)\nder: cableado (60)", ha="right", va="center", fontsize=8)
a1.set_xlabel("escena generada desde MNIST")
a1.set_title(f"A · Las once clases con las dos fuentes de umbral\n"
             f"{sum(ok_c)}/11 y {sum(ok_h)}/11 — mismos aciertos, mismos errores", fontsize=10.5)
for s in a1.spines.values(): s.set_visible(False)

# B · los conteos de bordes: cambian, pero las decisiones no
d10 = [k for k in ks if k != "NADA"]
bc = [CPU[k][1] for k in d10]; bh = [CAB[k][1] for k in d10]
a2.plot(d10, bh, "o-", c="#546e7a", lw=2, ms=6, label="cableado thr=60")
a2.plot(d10, bc, "s-", c="#c62828", lw=2, ms=6, label="CPU thr=90")
a2.fill_between(d10, bc, bh, color="#999", alpha=.2)
for i, k in enumerate(d10):
    a2.annotate(f"−{bh[i]-bc[i]}", (k, (bc[i]+bh[i])/2), fontsize=7,
                ha="center", color="#555")
a2.set_xticks(d10); a2.set_xlabel("dígito"); a2.set_ylabel("bordes contados")
a2.legend(fontsize=8.5); a2.grid(alpha=.3)
a2.set_title("B · El umbral sí cambia los conteos…\n…y aun así ninguna decisión cambia", fontsize=10.5)
plt.tight_layout()
plt.savefig("fig_soc_cadena.png", dpi=140)
plt.show()

print(f"CPU (thr=90)      {sum(ok_c)}/11")
print(f"cableado (thr=60) {sum(ok_h)}/11")
print(f"bordes: el umbral bajo cuenta {np.mean([bh[i]-bc[i] for i in range(10)]):.0f} mas en promedio")
print("errores, en los dos casos:", [k for k in ks if str(CPU[k][0]) != str(k)])
