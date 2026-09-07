#!/usr/bin/env python3
"""figura_pantalla.py — como se va a ver el TFT, dibujado desde los datos de la SIMULACION.

No es un mockup inventado: las 28x28 salen del stream real de `cam_win28` en `tb_cam_mnist.v`,
y el glifo se dibuja con la MISMA regla de siete segmentos que `glifo.v`. Es lo que la iCESugar
va a pintar, calculado en Python.
"""
import subprocess, sys, os
import numpy as np
import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle

SEG = {0:0b0111111, 1:0b0000110, 2:0b1011011, 3:0b1001111, 4:0b1100110,
       5:0b1101101, 6:0b1111101, 7:0b0000111, 8:0b1111111, 9:0b1101111}

def glifo(dig, W=60, H=80, G=11):
    """La misma aritmetica que glifo.v, para dibujar lo que el hardware dibuja."""
    s = SEG.get(dig, 0); img = np.zeros((H, W), bool); MED = H//2
    for y in range(H):
        for x in range(W):
            hx = G <= x < W-G
            va = G <= y < MED-G//2
            vb = MED+G//2 <= y < H-G
            on = ((s>>0 & 1 and hx and y < G) or (s>>1 & 1 and va and x >= W-G) or
                  (s>>2 & 1 and vb and x >= W-G) or (s>>3 & 1 and hx and y >= H-G) or
                  (s>>4 & 1 and vb and x < G)    or (s>>5 & 1 and va and x < G) or
                  (s>>6 & 1 and hx and MED-G//2 <= y < MED+G//2))
            img[y, x] = on
    return img

DIGITOS = [int(x) for x in (sys.argv[1:] or ["7", "1", "4"])]
fig, ejes = plt.subplots(1, len(DIGITOS), figsize=(3.4*len(DIGITOS), 5.6))
if len(DIGITOS) == 1: ejes = [ejes]

for ax, k in zip(ejes, DIGITOS):
    subprocess.run(["python3", "gen_escena.py", str(k)], capture_output=True)
    r = subprocess.run(["vvp", "/tmp/cm.vvp"], capture_output=True, text=True).stdout
    pred = int([l for l in r.split("\n") if "DIGITO RECON" in l][0].split(":")[1].split()[0])
    v = np.array([int(l) for l in open("vista28.txt")]).reshape(28, 28)

    # el TFT es 240x320; se arma tal cual lo pinta mnist_cam_display.v
    scr = np.zeros((320, 240, 3))
    img8 = np.kron(v, np.ones((8, 8)))                      # 28x28 -> 224x224
    scr[:224, :224, :] = (img8/255.0)[:, :, None]
    for b in range(3):                                      # marco verde de 3 px
        scr[b, :224] = scr[223-b, :224] = [0, 1, 0]
        scr[:224, b] = scr[:224, 223-b] = [0, 1, 0]
    g = glifo(pred)
    y0, x0 = 232, (240-60)//2
    scr[y0:y0+80, x0:x0+60][g] = [1.0, 0.72, 0.0]           # ambar

    ax.imshow(scr, interpolation="nearest")
    ax.set_xticks([]); ax.set_yticks([])
    ok = (pred == k)
    ax.set_title(f"papel: «{k}»   →   TFT: «{pred}»", fontsize=11.5, fontweight="bold",
                 color="#16a085" if ok else "#c0392b")
    ax.add_patch(Rectangle((0,0), 239, 319, fill=False, edgecolor="#444", lw=2))

fig.suptitle("Lo que va a pintar la iCESugar, calculado desde la simulación\n"
             "las 28×28 son el stream real de `cam_win28`; el glifo, la misma regla de `glifo.v`",
             fontsize=12.4, fontweight="bold", y=0.99)
plt.tight_layout(rect=[0,0,1,0.93])
plt.savefig("pantalla_mnist.png", dpi=140, bbox_inches="tight")
print("-> pantalla_mnist.png")
