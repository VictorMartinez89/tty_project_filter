#!/usr/bin/env python3
"""verifica_canny_rtl.py — el golden de Python del Canny 1-salto contra el VERILOG.

Mismo procedimiento que verifico el front-end Sobel en las Partes 29-35 y 174: se corre el RTL
en iverilog sobre imagenes reales y se compara pixel a pixel. La latencia del pipeline se CALIBRA
barriendo el desplazamiento, igual que se hizo con LAT en mnist_feat.v: no se deduce, se mide.
"""
import os, subprocess, sys
import numpy as np
import frente_golden as fg
from canny1_mnist import frente_canny1

HI, LO = 110, 40
N_IMG = int(sys.argv[1]) if len(sys.argv) > 1 else 20
AQUI = os.path.dirname(os.path.abspath(__file__))
os.makedirs(f"{AQUI}/tmp", exist_ok=True)
_, _, Xte, _ = fg.cargar_mnist(f"{AQUI}/mnist.npz")

def corre_rtl(img):
    with open(f"{AQUI}/tmp/c.hex", "w") as f:
        f.write("".join(f"{v:02x}\n" for v in img.ravel()))
    subprocess.run(["vvp", "/tmp/canny_sim.vvp", f"+IMG={AQUI}/tmp/c.hex",
                    f"+OUT={AQUI}/tmp/c.txt", f"+HI={HI}", f"+LO={LO}"],
                   cwd=AQUI, capture_output=True)
    return np.array([int(x) for x in open(f"{AQUI}/tmp/c.txt").read().split()], dtype=np.int8)

# --- 1) calibrar el desplazamiento con la primera imagen ---
# OJO: el raster DA LA VUELTA cada H*W muestras, asi que el barrido tiene que cubrir TODO el
# rango y usar indices modulo. Buscar solo en 0..200 encuentra un optimo espurio del 92 % y
# hace creer que el golden no coincide con el RTL. Costo de ese error: media hora.
oro = frente_canny1(Xte[0], HI, LO)[0][0].astype(int)
s = corre_rtl(Xte[0]); L = len(s)
print(f"RTL emitio {L} muestras; el golden tiene {oro.size} pixeles validos (22x22)")
mejor = (-1, None)
for off in range(L):
    if off + 21*28 + 22 > L: break
    idx = off + np.arange(22)[:, None] * 28 + np.arange(22)[None, :]
    t = int((s[idx] == oro).sum())
    if t > mejor[0]: mejor = (t, off)
tot, OFF = mejor
print(f"desplazamiento calibrado: OFF = {OFF}   (coincidencia {tot}/{oro.size} = {tot/oro.size:.2%})")

def reconstruye(s):
    idx = OFF + np.arange(22)[:, None] * 28 + np.arange(22)[None, :]
    return s[idx]

# --- 2) verificar sobre N imagenes ---
iguales, total, perfectas = 0, 0, 0
for n in range(N_IMG):
    oro = frente_canny1(Xte[n], HI, LO)[0][0].astype(int)
    rec = reconstruye(corre_rtl(Xte[n]))
    ig = int((rec == oro).sum()); iguales += ig; total += oro.size
    perfectas += (ig == oro.size)
    if ig != oro.size:
        print(f"  imagen {n:3d}: {ig}/{oro.size}   <-- DIFIERE")
print(f"\n{perfectas}/{N_IMG} imagenes IDENTICAS   ·   {iguales}/{total} pixeles = {iguales/total:.4%}")
