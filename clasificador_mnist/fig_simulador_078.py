#!/usr/bin/env python3
"""fig_simulador_078.py — la cadena del 97,22 % en marcha, sobre un 0, un 3 y un 7.

Cinco columnas por digito, que son las etapas del circuito:
  1. la imagen que entra
  2. la magnitud |Gx|+|Gy| tras el Gauss, saturada a 255
  3. la mascara que sale del doble umbral, que es lo UNICO que el
     clasificador llega a tocar: el original ya no existe a partir de aqui
  4. las 16 zonas y cuantos pixeles marcados caen en cada una
  5. los diez puntajes y el veredicto

OJO CON LA COLUMNA 3, que es lo que esta figura deja ver y conviene no
llamar por el nombre equivocado. Sobre MNIST los trazos van de 0 a 255 en
un pixel: la magnitud SATURA en el 44 % de la imagen y el 55 % pasa el
umbral alto. La mascara no es un contorno sino la silueta engordada del
digito. El clasificador acierta el 97,22 % con ella, asi que funciona,
pero lo que la piramide espacial esta midiendo es DONDE HAY TINTA, no
donde hay borde. Los umbrales 90/32 vienen del firmware del SoC, no de
optimizar esta tarea.

Los pesos son los MISMOS que corren en el RTL verificado (pesos_sel78.npz),
asi que lo que se ve aqui es lo que hace el silicio, no una aproximacion.
"""
import numpy as np, warnings; warnings.filterwarnings("ignore")
import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle
import frente_golden as fg
from canny1_mnist import frente_canny1

def magnitud(img):
    """La magnitud ANTES del umbral, igual que la calcula frente_canny1."""
    g  = np.floor(fg.conv3(img.astype(float), fg.GAUSS) / 16.0)
    return np.minimum(np.abs(fg.conv3(g, fg.SOBEL_X)) + np.abs(fg.conv3(g, fg.SOBEL_Y)), 255.0)

HI, LO = 90, 32
DIGITOS = [0, 3, 7]
p = np.load("pesos_sel78.npz"); W, b, idx = p["W"], p["b"], p["idx"]
B_MIN, B_MAX, MARGEN = 174, 376, 70

_, _, Xte, yte = fg.cargar_mnist()
# el primer ejemplar de cada digito pedido
elegidos = [int(np.where(yte == d)[0][0]) for d in DIGITOS]
m, o = frente_canny1(Xte[elegidos], HI, LO)
F = fg.piramide(m, o, 2)
mg = magnitud(Xte[elegidos])

fig, axes = plt.subplots(len(DIGITOS), 5, figsize=(18, 3.6 * len(DIGITOS)),
                         gridspec_kw={"width_ratios": [1, 1, 1, 1, 1.9]})
for r, (d, i) in enumerate(zip(DIGITOS, elegidos)):
    s = F[r, idx] @ W.T + b
    gan = int(s.argmax()); ss = np.sort(s); margen = ss[-1] - ss[-2]
    nb = int(m[r].sum())
    habla = (B_MIN <= nb <= B_MAX) and (margen > MARGEN)

    ax = axes[r, 0]; ax.imshow(Xte[i], cmap="gray_r"); ax.axis("off")
    ax.set_title(f"entra un {d}\n28 x 28, 8 bits", fontsize=9, loc="left")

    ax = axes[r, 1]
    ax.imshow(mg[r], cmap="inferno", interpolation="nearest", vmin=0, vmax=255); ax.axis("off")
    sat = (mg[r] >= 255).mean()
    ax.set_title(f"|Gx|+|Gy| tras el Gauss\nsatura en el {sat:.0%} de los pixeles",
                 fontsize=9, loc="left")

    ax = axes[r, 2]; ax.imshow(m[r], cmap="gray_r", interpolation="nearest"); ax.axis("off")
    ax.set_title(f"mascara, hi={HI} lo={LO}\n{nb} de {m[r].size} marcados "
                 f"({nb/m[r].size:.0%})", fontsize=9, loc="left")

    ax = axes[r, 3]
    H = m[r].shape[0]
    zona = np.zeros((4, 4), dtype=int)
    for zy in range(4):
        for zx in range(4):
            zona[zy, zx] = m[r][zy*H//4:(zy+1)*H//4, zx*H//4:(zx+1)*H//4].sum()
    ax.imshow(zona, cmap="Reds", interpolation="nearest")
    for zy in range(4):
        for zx in range(4):
            ax.text(zx, zy, zona[zy, zx], ha="center", va="center", fontsize=9,
                    color="white" if zona[zy, zx] > zona.max()*0.6 else "#333333")
    ax.set_xticks([]); ax.set_yticks([])
    ax.set_title("las 16 zonas\npixeles marcados por zona", fontsize=9, loc="left")

    ax = axes[r, 4]
    col = ["#c0392b" if k == gan else "#b8c4cc" for k in range(10)]
    ax.barh(range(10), s, color=col)
    ax.set_yticks(range(10)); ax.set_yticklabels(range(10), fontsize=8)
    ax.invert_yaxis(); ax.axvline(0, color="#555555", lw=0.8)
    ax.set_xlabel("puntaje", fontsize=8); ax.tick_params(labelsize=8)
    for sp in ("top", "right"): ax.spines[sp].set_visible(False)
    ver = f"dice {gan}" if habla else "dice NADA"
    ok = "  ✓" if (habla and gan == d) else ("  (se calla)" if not habla else "  ✗")
    ax.set_title(f"{ver}{ok}    margen {int(margen)}  (umbral {MARGEN})",
                 fontsize=9, loc="left",
                 color="#1e7a3c" if (habla and gan == d) else "#c0392b")

fig.suptitle("La cadena del 97,22 % en marcha  ·  front-end Canny (hi=90, lo=32), 16 zonas, "
             "78 caracteristicas elegidas, pesos de 4 bits con signo",
             fontsize=11, y=0.995, x=0.012, ha="left")
fig.tight_layout(rect=[0, 0, 1, 0.97])
fig.savefig("../tesis/figuras/fig_simulador_078.png", dpi=170, facecolor="white")
print("  -> tesis/figuras/fig_simulador_078.png")
for r, d in enumerate(DIGITOS):
    s = F[r, idx] @ W.T + b; ss = np.sort(s)
    print(f"    {d}: dice {int(s.argmax())}  margen {int(ss[-1]-ss[-2])}  "
          f"bordes {int(m[r].sum())}")
