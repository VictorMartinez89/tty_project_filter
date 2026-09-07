#!/usr/bin/env python3
# figura_jerarquia.py — pixel -> bordes -> formas -> digito, para los diez digitos.
#
#   Las cuatro capas de 3Blue1Brown, pero con las dos primeras ESCRITAS A MANO (Sobel de 1968)
#   en vez de aprendidas. Cada fila es una capa; cada columna, un digito. La ultima fila muestra
#   lo que el clasificador ve de verdad: 40 numeros, no una imagen.
#
#   El digito predicho sale del RTL corriendo en iverilog, no del modelo de Python.
import numpy as np, subprocess, os
import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.colors import ListedColormap

import frente_golden as fg
_, _, Xte, yte = fg.cargar_mnist()

# un ejemplar de cada digito
ejemplos = [int(np.where(yte == k)[0][0]) for k in range(10)]

def rtl(img):
    """Corre el Verilog de verdad y devuelve (32 contadores, digito)."""
    os.makedirs("rtl/tmp", exist_ok=True)
    open("rtl/tmp/f.hex", "w").write("".join(f"{v:02x}\n" for v in img.ravel()))
    subprocess.run(["vvp", "tmp/sim.vvp", "+IMG=tmp/f.hex", "+OUT=tmp/f.txt"],
                   cwd="rtl", capture_output=True)
    L = open("rtl/tmp/f.txt").read().split("\n")
    return np.array([int(x) for x in L[:32]]), int(L[32].split()[1])

# 8 colores para las 8 orientaciones (ciclico: la direccion es angular)
COL8 = ListedColormap(plt.cm.hsv(np.linspace(0, 0.92, 8)))

fig, ejes = plt.subplots(4, 10, figsize=(17.2, 8.0))
aciertos = 0
for c, idx in enumerate(ejemplos):
    img = Xte[idx]
    m, o = fg.frente(img); m, o = m[0], o[0]
    cnt, dig = rtl(img)
    aciertos += (dig == yte[idx])

    # --- capa 1: PIXELES ---
    ejes[0, c].imshow(img, cmap="gray", vmin=0, vmax=255, interpolation="nearest")
    ejes[0, c].set_title(f"«{yte[idx]}»", fontsize=13, fontweight="bold", pad=4)

    # --- capa 2: BORDES (que pixel pasa el umbral) ---
    ejes[1, c].imshow(m, cmap="gray", vmin=0, vmax=1, interpolation="nearest")
    ejes[1, c].set_xlabel(f"{int(m.sum())} px", fontsize=8.2, labelpad=1)

    # --- capa 3: FORMAS (la orientacion de cada borde, en color) ---
    vis = np.where(m, o, np.nan)
    ejes[2, c].imshow(vis, cmap=COL8, vmin=-0.5, vmax=7.5, interpolation="nearest")
    ejes[2, c].set_facecolor("#111")
    for q in (1, 2):   # las lineas de la piramide: 4 cuadrantes
        ejes[2, c].axhline(m.shape[0]/2-0.5, color="w", lw=0.9, alpha=0.65)
        ejes[2, c].axvline(m.shape[1]/2-0.5, color="w", lw=0.9, alpha=0.65)

    # --- capa 4: EL DESCRIPTOR (4 zonas x 8 orientaciones) + el veredicto ---
    ejes[3, c].imshow(cnt.reshape(4, 8), cmap="magma", aspect="auto", interpolation="nearest")
    ok = (dig == yte[idx])
    ejes[3, c].set_xlabel(f"RTL → {dig}", fontsize=11, fontweight="bold",
                          color="#16a085" if ok else "#c0392b", labelpad=3)

for a in ejes.ravel():
    a.set_xticks([]); a.set_yticks([])
    for s in a.spines.values(): s.set_edgecolor("#999")

filas = ["1 · PÍXELES\n(lo que entra)", "2 · BORDES\n(Sobel + umbral)",
         "3 · FORMAS\n(orientación, 8 colores)", "4 · DESCRIPTOR\n(4 zonas × 8 orient.)"]
for r, t in enumerate(filas):
    ejes[r, 0].set_ylabel(t, fontsize=9.6, fontweight="bold", rotation=0,
                          ha="right", va="center", labelpad=52)

fig.suptitle("pixel → bordes → formas → dígito, en el hardware de la tesis\n"
             f"las dos primeras capas son Sobel (1968), escrito a mano; solo la última se entrenó   ·   "
             f"aciertos del RTL: {aciertos}/10",
             fontsize=13.2, fontweight="bold", y=0.985)
plt.tight_layout(rect=[0.045, 0, 1, 0.93])
plt.savefig("jerarquia_mnist.png", dpi=135, bbox_inches="tight")
print(f"-> jerarquia_mnist.png   (RTL acerto {aciertos}/10)")
