#!/usr/bin/env python3
"""verifica_canny_feat.py — los 32 contadores del RTL con Canny contra el golden de Python."""
import os, subprocess, sys
import numpy as np
import frente_golden as fg
from canny1_mnist import frente_canny1

HI, LO = 110, 40
N = int(sys.argv[1]) if len(sys.argv) > 1 else 20
A = os.path.dirname(os.path.abspath(__file__))
os.makedirs(f"{A}/tmp", exist_ok=True)
_, _, Xte, _ = fg.cargar_mnist(f"{A}/mnist.npz")

ok = 0
for n in range(N):
    open(f"{A}/tmp/f.hex", "w").write("".join(f"{v:02x}\n" for v in Xte[n].ravel()))
    subprocess.run(["vvp", "/tmp/cf.vvp", f"+IMG={A}/tmp/f.hex", f"+OUT={A}/tmp/f.txt",
                    f"+HI={HI}", f"+LO={LO}"], cwd=A, capture_output=True)
    L = open(f"{A}/tmp/f.txt").read().split("\n")
    rtl = np.array([int(x) for x in L[:32]])
    m, o = frente_canny1(Xte[n], HI, LO)
    oro = fg.contadores(m[0], o[0])
    if np.array_equal(rtl, oro): ok += 1
    elif n < 5:
        print(f"  img {n}: difieren  rtl={rtl[:8]}  oro={oro[:8]}")
        print(f"          suma rtl={rtl.sum()} oro={oro.sum()}  bordes RTL={L[32]}")
print(f"\n{ok}/{N} imagenes con los 32 contadores IDENTICOS")
