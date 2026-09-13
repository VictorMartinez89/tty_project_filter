#!/usr/bin/env python3
"""gen_escena.py — arma una escena de 640x480 con un digito de MNIST en el centro.

La ventana de cam_win28 toma los 448x448 centrales, asi que el digito se amplia 28 -> 448
(cada pixel de MNIST ocupa 16x16) y se pone justo ahi. El fondo es gris claro, como una hoja.
MNIST es trazo CLARO sobre fondo oscuro y la tinta sobre papel es al reves, asi que se INVIERTE:
cam_win28 vuelve a invertir y el clasificador recibe lo que espera.

  Uso:  python3 gen_escena.py <indice de test | -1 para escena VACIA> [salida.hex]
"""
import sys
import numpy as np
import frente_golden as fg

n = int(sys.argv[1]); sal = sys.argv[2] if len(sys.argv) > 2 else "fpga/escena.hex"
CW, CH, WIN = 640, 480, 448
esc = np.full((CH, CW), 235, np.uint8)                 # hoja blanca
if n >= 0:
    _, _, Xte, yte = fg.cargar_mnist("mnist.npz")
    d = Xte[n]
    grande = np.kron(255 - d, np.ones((WIN//28, WIN//28), np.uint8))   # invertido: tinta oscura
    y0, x0 = (CH-WIN)//2, (CW-WIN)//2
    esc[y0:y0+WIN, x0:x0+WIN] = grande
    print(f"escena con el digito {yte[n]} (test #{n})")
else:
    print("escena VACIA (hoja en blanco) -> deberia dar NADA")
open(sal, "w").write("".join(f"{v:02x}\n" for v in esc.ravel()))
print(f"-> {sal}  ({esc.shape[0]}x{esc.shape[1]})")
