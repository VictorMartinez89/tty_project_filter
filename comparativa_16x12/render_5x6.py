#!/usr/bin/env python3
# render_5x6.py — dibuja la grilla del experimento: 5 imagenes x 6 disenos, a 16x12,
# todo salido de simulacion RTL con iverilog (nada de modelos en Python).
import os
import numpy as np
import matplotlib.pyplot as plt

H, W = 16, 12
AQUI = os.path.dirname(os.path.abspath(__file__))
IMGS = ["flower", "monarch", "butterfly", "mano", "hi"]
DIS  = [("sobel", "Sobel"), ("canny1", "Canny1"), ("trans", "Transitivo"),
        ("soc_sobel", "SoC+Sobel"), ("soc_canny1", "SoC+Canny1"), ("soc_trans", "SoC+Transit")]

def leer_gris(n):
    v = [int(l, 16) for l in open(f"{AQUI}/img/{n}.hex") if l.strip()]
    return np.array(v, dtype=np.uint8).reshape(H, W)

def leer_bordes(img, dis):
    p = f"{AQUI}/exp/out/{img}_{dis}.txt"
    v = [int(l) for l in open(p) if l.strip()]
    return np.array(v, dtype=np.uint8).reshape(H, W)

fig, ejes = plt.subplots(len(IMGS), 1 + len(DIS), figsize=(13.6, 10.4))
for r, nom in enumerate(IMGS):
    ejes[r, 0].imshow(leer_gris(nom), cmap="gray", vmin=0, vmax=255, interpolation="nearest")
    ejes[r, 0].set_ylabel(nom, fontsize=11, fontweight="bold", rotation=0,
                          ha="right", va="center", labelpad=12)
    if r == 0:
        ejes[r, 0].set_title("entrada\n(16x12 gris)", fontsize=9.5, fontweight="bold")
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

fig.suptitle("Experimento 5x6 a 16x12 — 30 simulaciones RTL (iverilog): 5 imagenes x 6 disenos\n"
             "verde = sin CPU   ·   violeta = con SoC femto   ·   el numero es la cuenta de bordes",
             fontsize=12.2, fontweight="bold", y=0.985)
plt.tight_layout(rect=[0, 0, 1, 0.955])
plt.savefig(f"{AQUI}/exp/grilla_5x6.png", dpi=130, bbox_inches="tight")
print("-> exp/grilla_5x6.png")

# comprobacion: con CPU vs sin CPU, pixel a pixel
iguales = 0
for nom in IMGS:
    for a, b in [("sobel", "soc_sobel"), ("canny1", "soc_canny1"), ("trans", "soc_trans")]:
        if np.array_equal(leer_bordes(nom, a), leer_bordes(nom, b)):
            iguales += 1
print(f"pares con CPU / sin CPU identicos pixel a pixel: {iguales} de 15")
