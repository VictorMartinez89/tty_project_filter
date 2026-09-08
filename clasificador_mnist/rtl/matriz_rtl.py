#!/usr/bin/env python3
"""matriz_rtl.py — la matriz de confusion del VERILOG, no del modelo.

Pasa las 10 000 imagenes de prueba de MNIST por `mnist_top` corriendo en iverilog, una por una,
y arma la matriz con lo que responde EL RTL. Es la diferencia entre decir "el modelo alcanza
91 %" y decir "el circuito alcanza 91 %".

  Uso:  python3 matriz_rtl.py [N]        (por defecto las 10 000)
"""
import os, subprocess, sys, time
import numpy as np
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
import frente_golden as fg

AQUI = os.path.dirname(os.path.abspath(__file__))
N = int(sys.argv[1]) if len(sys.argv) > 1 else 10000

_, _, Xte, yte = fg.cargar_mnist(os.path.join(AQUI, "..", "mnist.npz"))
P = np.load(os.path.join(AQUI, "..", "pesos_hw.npz")); W, b = P["W"], P["b"]
os.makedirs(os.path.join(AQUI, "tmp"), exist_ok=True)

M = np.zeros((10, 10), int)
pred_rtl = np.zeros(N, int)
val_rtl  = np.zeros(N, bool)      # el veredicto de la clase NADA
t0 = time.time()
for n in range(N):
    with open(os.path.join(AQUI, "tmp/e.hex"), "w") as f:
        f.write("".join(f"{v:02x}\n" for v in Xte[n].ravel()))
    subprocess.run(["vvp", "tmp/sim.vvp", "+IMG=tmp/e.hex", "+OUT=tmp/e.txt"],
                   cwd=AQUI, capture_output=True)
    L = open(os.path.join(AQUI, "tmp/e.txt")).read().split("\n")
    d = int(L[32].split()[1])
    val_rtl[n] = (d != 10)                       # 10 = NADA
    pred_rtl[n] = d if d != 10 else -1
    if d != 10: M[yte[n], d] += 1
    if (n+1) % 1000 == 0:
        acc = (pred_rtl[:n+1] == yte[:n+1]).mean()
        print(f"  {n+1:>5}/{N}  acc {acc:.2%}  ({time.time()-t0:.0f}s)", flush=True)

acc = (pred_rtl == yte[:N]).mean()
print(f"\nRTL en iverilog sobre {N} imagenes: {acc:.2%}")
print(f"aceptadas por la clase NADA: {val_rtl.sum()}/{N} = {val_rtl.mean():.1%}")
if val_rtl.sum():
    acc_ac = (pred_rtl[val_rtl] == yte[:N][val_rtl]).mean()
    print(f"precision ENTRE LAS ACEPTADAS: {acc_ac:.2%}")
np.savez(os.path.join(AQUI, "..", "confusion_rtl.npz"),
         M=M, pred=pred_rtl, y=yte[:N], val=val_rtl, acc=acc)
print("-> confusion_rtl.npz")
