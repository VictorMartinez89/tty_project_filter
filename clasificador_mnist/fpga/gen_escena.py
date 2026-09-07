#!/usr/bin/env python3
"""gen_escena.py — arma la ESCENA que ve la camara en simulacion: un digito de MNIST
   ampliado y puesto dentro de la ventana de encuadre, como si alguien lo hubiera escrito
   en papel y lo sostuviera frente a la OV7670.

   Simula lo que hace la realidad y el modelo golden NO: tinta oscura sobre papel claro,
   el digito ocupando la ventana, y el resto del cuadro con fondo claro.
"""
import sys, os
import numpy as np
sys.path.insert(0, "..")
import frente_golden as fg

CAM_W, CAM_H, WIN = 640, 480, 448
k = int(sys.argv[1]) if len(sys.argv) > 1 else 7      # que digito poner
_, _, Xte, yte = fg.cargar_mnist("../mnist.npz")
idx = int(np.where(yte == k)[0][0])
d = Xte[idx]                                           # 28x28, trazo CLARO sobre fondo oscuro

# ampliar x16 -> 448x448, e INVERTIR: tinta oscura sobre papel claro
grande = np.kron(d, np.ones((16, 16), np.uint8))
papel = 255 - grande

escena = np.full((CAM_H, CAM_W), 235, np.uint8)        # papel blanco, no saturado
x0, y0 = (CAM_W-WIN)//2, (CAM_H-WIN)//2
escena[y0:y0+WIN, x0:x0+WIN] = papel

with open("escena.hex", "w") as f:
    for v in escena.ravel():
        f.write(f"{v:02x}\n")
print(f"-> escena.hex   digito {k} (test #{idx}) · {CAM_W}x{CAM_H} · tinta oscura sobre papel")
