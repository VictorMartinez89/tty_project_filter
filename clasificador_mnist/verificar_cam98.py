#!/usr/bin/env python3
"""verificar_cam98.py — la camara emulada mostrando los 10 digitos a Canny-98 (98,45 %).

Es verificar_cam78.py con el clasificador cambiado: las mismas 10 escenas (el primer ejemplar de
cada digito del test, ampliado x16, tinta oscura sobre papel claro), el banco tb_cam98.v con
cam98_cadena -el MISMO modulo que va a la placa- y, como golden, el modelo ENTERO de
canny98_golden.py con la regla de rechazo del circuito (n_bordes en [174, 376] y margen > 0).
La ventana de 448x448 promediada en bloques de 16x16 devuelve exactamente la imagen de MNIST.
Escribe tambien sim/exp98.hex (un veredicto por cuadro) para que la VM se juzgue sola.
    /opt/anaconda3/bin/python verificar_cam98.py <dir_de_trabajo>
"""
import numpy as np, subprocess, os, sys, warnings; warnings.filterwarnings("ignore")
D = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else "fpga/cam98")
sys.argv = sys.argv[:1]                # canny1_mnist lee sys.argv[1] al importarse
import frente_golden as fg
from canny1_mnist import frente_canny1
CAM_W, CAM_H, WIN, REP = 640, 480, 448, 2
_, _, Xte, yte = fg.cargar_mnist()
idx = [int(np.where(yte == k)[0][0]) for k in range(10)]
p = np.load("pesos_canny98_H120.npz")
m, o = frente_canny1(Xte[idx], 90, 32)
F = fg.piramide(m, o, 2); F = np.concatenate([F[:, 40:168], F[:, 8:40], F[:, 0:8]], axis=1).astype(np.int64)
h = np.clip((F @ p["W1q"].T + p["b1i"]) >> int(p["S"]), 0, 255)
S = h @ p["W2q"].T + p["b2i"]
ss = np.sort(S, 1); nb = m.sum((1, 2))
gold = [int(S[k].argmax()) if (174 <= nb[k] <= 376 and ss[k, -1] - ss[k, -2] > 0) else 10 for k in range(10)]
esp = [gold[c // REP] for c in range(10 * REP)]
os.makedirs(f"{D}/sim", exist_ok=True)
with open(f"{D}/sim/exp98.hex", "w") as f:
    f.write("".join(f"{v:x}\n" for v in esp))
if not os.path.exists(f"{D}/sim/esc78.hex"):
    with open(f"{D}/sim/esc78.hex", "w") as f:
        for k in range(10):
            esc = np.full((CAM_H, CAM_W), 235, np.uint8)
            x0, y0 = (CAM_W - WIN) // 2, (CAM_H - WIN) // 2
            esc[y0:y0+WIN, x0:x0+WIN] = 255 - np.kron(Xte[idx[k]], np.ones((16, 16), np.uint8))
            f.write("".join(f"{v:02x}\n" for v in esc.ravel()))
print("golden por escena:", ["NADA" if g == 10 else g for g in gold], "  (etiquetas", list(yte[idx]), ")")
