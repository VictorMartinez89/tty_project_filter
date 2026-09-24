#!/usr/bin/env python3
"""fig_simulador_todos.py — la cadena del 97,22 % en marcha sobre las ONCE clases: 0..9 y NADA.

Es la ampliacion de fig_simulador_078.py (que mostraba un 0, un 3 y un 7). Once columnas, una por
clase, y cinco filas, que son las etapas del circuito:
  1. la imagen que entra (28 x 28, 8 bits)
  2. la magnitud |Gx|+|Gy| tras el Gauss, saturada a 255
  3. la mascara del doble umbral (hi=90, lo=32): lo UNICO que el clasificador llega a tocar
  4. las 16 zonas y cuantos pixeles marcados caen en cada una
  5. los diez puntajes, el margen y el veredicto

Criterio de eleccion, para no elegir los bonitos: para cada digito, el PRIMER ejemplar del test.
Para NADA, un cuadro en blanco: lo que ve la camara cuando no hay digito, que es para lo que
existe esa clase. Los pesos son los del RTL verificado (pesos_sel78.npz): esto es lo que hace el
silicio, que dio 10000/10000 contra este mismo golden en la placa (§36.15).
"""
import numpy as np, json, warnings; warnings.filterwarnings("ignore")
import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt
import frente_golden as fg
from canny1_mnist import frente_canny1

HI, LO = 90, 32
B_MIN, B_MAX, MARGEN = 174, 376, 70
p = np.load("pesos_sel78.npz"); W, b, idx = p["W"], p["b"], p["idx"]
_, _, Xte, yte = fg.cargar_mnist()
sel = [int(np.where(yte == d)[0][0]) for d in range(10)]
imgs = np.concatenate([Xte[sel], np.zeros((1, 28, 28), Xte.dtype)])     # + el cuadro en blanco
etiq = [str(d) for d in range(10)] + ["NADA"]
titulos = [f"entra un {d}\n(test #{i})" for d, i in zip(range(10), sel)] + ["cuadro en blanco\n(sin dígito)"]

m, o = frente_canny1(imgs, HI, LO)
F = fg.piramide(m, o, 2)
g = np.floor(fg.conv3(imgs.astype(float), fg.GAUSS) / 16.0)
mag = np.minimum(np.abs(fg.conv3(g, fg.SOBEL_X)) + np.abs(fg.conv3(g, fg.SOBEL_Y)), 255.0)

fig, axs = plt.subplots(5, 11, figsize=(22, 10.8),
                        gridspec_kw={"height_ratios": [1, 1, 1, 1, 1.25], "hspace": .38, "wspace": .12})
filas = ["entra", "|Gx|+|Gy|\ntras el Gauss", "máscara\nhi=90 lo=32", "16 zonas\n(píxeles)", "10 puntajes"]
resumen = []
for c in range(11):
    s = F[c, idx] @ W.T + b
    gan = int(s.argmax()); ss = np.sort(s); margen = int(ss[-1] - ss[-2])
    nb = int(m[c].sum()); habla = (B_MIN <= nb <= B_MAX) and (margen > MARGEN)
    dice = str(gan) if habla else "NADA"
    ok = dice == etiq[c]
    por_que = "" if habla else (f"bordes {nb} < {B_MIN}" if nb < B_MIN else
                                f"bordes {nb} > {B_MAX}" if nb > B_MAX else f"margen {margen} ≤ {MARGEN}")
    resumen.append(dict(clase=etiq[c], test=(sel[c] if c < 10 else None), dice=dice, ok=ok,
                        margen=margen, bordes=nb, sat=float((mag[c] >= 255).mean()),
                        mascara=float(m[c].mean()), por_que=por_que))

    ax = axs[0, c]; ax.imshow(imgs[c], cmap="gray_r", vmin=0, vmax=255); ax.set_xticks([]); ax.set_yticks([])
    ax.set_title(titulos[c], fontsize=8.5)
    ax = axs[1, c]; ax.imshow(mag[c], cmap="inferno", vmin=0, vmax=255, interpolation="nearest"); ax.axis("off")
    ax.text(.5, -.08, f"satura {resumen[-1]['sat']:.0%}", transform=ax.transAxes, ha="center", va="top", fontsize=7.5)
    ax = axs[2, c]; ax.imshow(m[c], cmap="gray_r", interpolation="nearest"); ax.axis("off")
    ax.text(.5, -.08, f"{nb} de 484 ({nb/484:.0%})", transform=ax.transAxes, ha="center", va="top", fontsize=7.5)
    ax = axs[3, c]; H = m[c].shape[0]
    z = np.array([[m[c][zy*H//4:(zy+1)*H//4, zx*H//4:(zx+1)*H//4].sum() for zx in range(4)] for zy in range(4)])
    ax.imshow(z, cmap="Reds", vmin=0, vmax=40, interpolation="nearest"); ax.set_xticks([]); ax.set_yticks([])
    for zy in range(4):
        for zx in range(4):
            ax.text(zx, zy, z[zy, zx], ha="center", va="center", fontsize=6.5,
                    color="w" if z[zy, zx] > 24 else "#333")
    ax = axs[4, c]
    colr = ["#c0392b" if (k == gan and habla) else ("#e0a0a0" if k == gan else "#b8c4cc") for k in range(10)]
    ax.barh(range(10), s, color=colr); ax.invert_yaxis(); ax.axvline(0, color="#555", lw=.6)
    ax.set_yticks(range(10)); ax.set_yticklabels(range(10), fontsize=6.5); ax.tick_params(axis="x", labelsize=6)
    for sp in ("top", "right"): ax.spines[sp].set_visible(False)
    color = "#1e7a3c" if ok else "#c0392b"
    ax.set_title(f"dice {dice}  {'✓' if ok else '✗'}\nmargen {margen}", fontsize=9, color=color, weight="bold")
    if por_que: ax.text(.5, -.2, por_que, transform=ax.transAxes, ha="center", va="top", fontsize=7, color="#7f8c8d")
for r, t in enumerate(filas):
    axs[r, 0].text(-.35, .5, t, transform=axs[r, 0].transAxes, ha="right", va="center", fontsize=9, weight="bold")
n_ok = sum(x["ok"] for x in resumen)
fig.suptitle(f"La cadena del 97,22 % en marcha sobre las once clases · el PRIMER ejemplar de cada dígito del test "
             f"y un cuadro en blanco · {n_ok}/11 como deben · pesos del RTL verificado",
             fontsize=11.5, x=.01, ha="left", y=.995)
fig.savefig("../tesis/figuras/fig_simulador_todos.png", dpi=150, facecolor="white", bbox_inches="tight")
json.dump(resumen, open("fig_simulador_todos.json", "w"), indent=1, ensure_ascii=False)
print("  -> tesis/figuras/fig_simulador_todos.png · fig_simulador_todos.json\n")
for x in resumen:
    print(f"  {x['clase']:>4}  dice {x['dice']:>4} {'ok' if x['ok'] else '!!'}  margen {x['margen']:4d}  "
          f"bordes {x['bordes']:3d}  satura {x['sat']:.0%}  mascara {x['mascara']:.0%}  {x['por_que']}")
