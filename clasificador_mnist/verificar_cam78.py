#!/usr/bin/env python3
"""verificar_cam78.py — la camara emulada mostrando los 10 digitos a la cadena del 97,22 %.

Arma 10 escenas como gen_escena.py (el primer ejemplar de cada digito del test, ampliado x16,
tinta oscura sobre papel claro), corre tb_cam78.v y compara CADA veredicto con el golden de
esa imagen. La ventana de 448x448 promediada en bloques de 16x16 devuelve exactamente la
imagen de MNIST, asi que el golden es el de la imagen original.
"""
import numpy as np, subprocess, os, warnings; warnings.filterwarnings("ignore")
import frente_golden as fg
from canny1_mnist import frente_canny1
F = os.path.abspath("fpga"); os.makedirs(f"{F}/tmp", exist_ok=True)
CAM_W, CAM_H, WIN, REP = 640, 480, 448, 2
_, _, Xte, yte = fg.cargar_mnist()
idx = [int(np.where(yte == k)[0][0]) for k in range(10)]
p = np.load("pesos_sel78.npz"); W, b, ix = p["W"], p["b"], p["idx"]
m, o = frente_canny1(Xte[idx], 90, 32); S = fg.piramide(m, o, 2)[:, ix] @ W.T + b
ss = np.sort(S, 1); nb = m.sum((1, 2))
gold = [int(S[k].argmax()) if (174 <= nb[k] <= 376 and ss[k, -1] - ss[k, -2] > 70) else 10
        for k in range(10)]
with open(f"{F}/tmp/esc78.hex", "w") as f:
    for k in range(10):
        esc = np.full((CAM_H, CAM_W), 235, np.uint8)
        x0, y0 = (CAM_W - WIN) // 2, (CAM_H - WIN) // 2
        esc[y0:y0+WIN, x0:x0+WIN] = 255 - np.kron(Xte[idx[k]], np.ones((16, 16), np.uint8))
        f.write("".join(f"{v:02x}\n" for v in esc.ravel()))
src = ["tb_cam78.v", "cam78_cadena.v", "cam_win28.v", "../rtl/mnist_top78.v",
       "../rtl/mnist_feat16_mem.v", "../rtl/mnist_clf78_x2.v", "../rtl/linebuf3x3.v"]
subprocess.run(["iverilog", "-g2012", "-I../rtl", "-o", "tmp/cam78.vvp"] + src, cwd=F, check=True)
subprocess.run(["vvp", "-n", "tmp/cam78.vvp", "+ESC=tmp/esc78.hex", "+OUT=tmp/cam78.out"],
               cwd=F, check=True, stdout=subprocess.DEVNULL)
ver, realin = [], None
for ln in open(f"{F}/tmp/cam78.out"):
    t = ln.split()
    if t[0] == "V": ver.append(int(t[2]))
    elif t[0] == "REALINEO": realin = int(t[1])
esp = [gold[c // REP] for c in range(10 * REP)]
nom = lambda v: "NADA" if v == 10 else str(v)
print(f"camara emulada · 10 digitos x {REP} cuadros · {len(ver)} veredictos (esperados {len(esp)})\n")
ok = 0
for c, e in enumerate(esp):
    v = ver[c] if c < len(ver) else None
    ok += (v == e)
    print(f"  cuadro {c:2d}  muestra un {yte[idx[c // REP]]}  golden {nom(e):>4}  "
          f"placa-sim {nom(v) if v is not None else '-':>4}  {'ok' if v == e else '!! FALLA'}")
print(f"\n  {ok}/{len(esp)} veredictos iguales al golden · realineos: {realin}")
print("  " + ("ALL TESTS PASSED" if ok == len(esp) and realin == 0 else "HAY FALLOS"))
