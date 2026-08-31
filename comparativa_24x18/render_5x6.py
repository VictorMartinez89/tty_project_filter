#!/usr/bin/env python3
# render_5x6.py — dibuja la grilla del experimento: 5 imagenes x 6 disenos, a 24x18,
# todo salido de simulacion RTL con iverilog (nada de modelos en Python).
import os
import sys
import numpy as np
import matplotlib.pyplot as plt

H, W = 24, 18
AQUI = os.path.dirname(os.path.abspath(__file__))
SUF  = sys.argv[1] if len(sys.argv) > 1 else ""          # p.ej. "250_210" -> exp/out_250_210/
DIR  = f"out_{SUF}" if SUF else "out"
PNG  = f"grilla_5x6_{SUF}.png" if SUF else "grilla_5x6.png"
UMB  = f"  ·  umbrales {SUF.replace('_', '/')}" if SUF else ""
IMGS = ["flower", "monarch", "butterfly", "mano", "hi"]
DIS  = [("sobel", "Sobel"), ("canny1", "Canny1"), ("trans", "Transitivo"),
        ("soc_sobel", "SoC+Sobel"), ("soc_canny1", "SoC+Canny1"), ("soc_trans", "SoC+Transit")]

def leer_gris(n):
    v = [int(l, 16) for l in open(f"{AQUI}/img/{n}.hex") if l.strip()]
    return np.array(v, dtype=np.uint8).reshape(H, W)

# Cada etapa 3x3 del pipeline retrasa la salida exactamente W+1 pixeles (la ventana
# centrada en (r,c) recien esta cuando entro (r+1,c+1)). Los tres filtros NO tienen las
# mismas etapas: Sobel 1 (Sobel), transitivo 2 (Gauss+Sobel), Canny1 3 (Gauss+Sobel+
# linebuffer de clase). Sin descontarlo, las columnas de la grilla salen corridas entre
# si -medido: 27 y 54 pixeles a 36x26- y se estarian comparando imagenes desplazadas.
ETAPAS = {"sobel": 1, "canny1": 3, "trans": 2,
          "soc_sobel": 1, "soc_canny1": 3, "soc_trans": 2}

def leer_bordes(img, dis):
    p = f"{AQUI}/exp/{DIR}/{img}_{dis}.txt"
    v = [int(l) for l in open(p) if l.strip()]
    v = np.roll(np.array(v, dtype=np.uint8), -ETAPAS[dis] * (W + 1))   # alinear con la entrada
    return v.reshape(H, W)

fig, ejes = plt.subplots(len(IMGS), 1 + len(DIS), figsize=(13.6, 10.4))
for r, nom in enumerate(IMGS):
    ejes[r, 0].imshow(leer_gris(nom), cmap="gray", vmin=0, vmax=255, interpolation="nearest")
    ejes[r, 0].set_ylabel(nom, fontsize=11, fontweight="bold", rotation=0,
                          ha="right", va="center", labelpad=12)
    if r == 0:
        ejes[r, 0].set_title("entrada\n(24x18 gris)", fontsize=9.5, fontweight="bold")
    for c, (dis, etq) in enumerate(DIS, start=1):
        b = leer_bordes(nom, dis)
        color = "#16a085" if c <= 3 else "#8e44ad"      # sin CPU / con CPU
        ejes[r, c].imshow(b, cmap="gray", vmin=0, vmax=1, interpolation="nearest")
        ejes[r, c].text(0.5, -0.13, f"{int(b.sum())}", transform=ejes[r, c].transAxes,
                        ha="center", fontsize=8.6, fontweight="bold", color=color)
        if r == 0:
            ejes[r, c].set_title(etq, fontsize=9.5, fontweight="bold", color=color)
for e in ejes.ravel():
    e.set_xticks([]); e.set_yticks([])
    for s in e.spines.values(): s.set_edgecolor("#999")

fig.suptitle(f"Experimento 5x6 a 24x18 — 30 simulaciones RTL (iverilog): 5 imagenes x 6 disenos{UMB}\n"
             "verde = sin CPU   ·   violeta = con SoC femto   ·   el numero es la cuenta de bordes\n"
             "columnas alineadas a la entrada descontando la latencia de cada pipeline",
             fontsize=12.2, fontweight="bold", y=0.985)
plt.tight_layout(rect=[0, 0, 1, 0.955])
plt.savefig(f"{AQUI}/exp/{PNG}", dpi=130, bbox_inches="tight")
print(f"-> exp/{PNG}")

# comprobacion: con CPU vs sin CPU, pixel a pixel
iguales = 0
for nom in IMGS:
    for a, b in [("sobel", "soc_sobel"), ("canny1", "soc_canny1"), ("trans", "soc_trans")]:
        if np.array_equal(leer_bordes(nom, a), leer_bordes(nom, b)):
            iguales += 1
print(f"pares con CPU / sin CPU identicos pixel a pixel: {iguales} de 15")
