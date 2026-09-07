#!/usr/bin/env python3
"""entrenar_hw.py — entrena el clasificador CON LA ARITMETICA DEL HARDWARE y exporta los pesos.

El front-end vive en `frente_golden.py` y es el mismo que verifica el RTL: no se duplica aca.
Lo unico que hace este script es entrenar el clasificador lineal encima y volcar los pesos
cuantizados a `rtl/mnist_weights.vh`, que el Verilog incluye.

  Uso:  python3 entrenar_hw.py [bits]     (por defecto 4)
"""
import sys
import numpy as np
from sklearn.linear_model import LogisticRegression
import frente_golden as fg

BITS  = int(sys.argv[1]) if len(sys.argv) > 1 else 4
NIVEL = 1                      # piramide 0+1 -> 5 zonas -> 40 caracteristicas
SALIDA = "rtl/mnist_weights.vh"

Xtr, ytr, Xte, yte = fg.cargar_mnist()
mtr, otr = fg.frente(Xtr)
mte, ote = fg.frente(Xte)
Ftr = fg.piramide(mtr, otr, NIVEL)
Fte = fg.piramide(mte, ote, NIVEL)
D = Ftr.shape[1]
print(f"front-end del RTL (octante) · {D} caracteristicas · densidad de borde {mtr.mean():.1%}")

# Se entrena sobre los CONTADORES CRUDOS: en hardware no hay normalizacion, y estandarizar y
# despues plegar la escala a los pesos da PEOR al cuantizar (85.0 % a 4 bits, medido).
clf = LogisticRegression(max_iter=3000, C=0.002).fit(Ftr, ytr)
acc_f = clf.score(Fte, yte)
Wq, esc = fg.cuantizar(clf.coef_, BITS)
bq = np.round(clf.intercept_ / esc).astype(int)
pred = (Fte @ Wq.T + bq).argmax(1)
acc_q = (pred == yte).mean()

print(f"precision  float {acc_f:.1%}   ·   cuantizado a {BITS} bits {acc_q:.1%}")
print(f"pesos: {Wq.shape[0]}x{Wq.shape[1]} = {Wq.size} · rango [{Wq.min()},{Wq.max()}] · escala {esc:.5f}")
print(f"6 leido como 9: {int(((yte==6)&(pred==9)).sum())}/{int((yte==6).sum())}   "
      f"9 leido como 6: {int(((yte==9)&(pred==6)).sum())}/{int((yte==9).sum())}")

def sd(v, w):
    return f"{w}'sd{int(v)}" if v >= 0 else f"-{w}'sd{-int(v)}"

with open(SALIDA, "w") as f:
    f.write("// mnist_weights.vh — GENERADO por entrenar_hw.py. No editar a mano.\n")
    f.write(f"//   {Wq.shape[0]} clases x {Wq.shape[1]} caracteristicas, {BITS} bits con signo.\n")
    f.write(f"//   Entrenado sobre MNIST (60 000) con el front-end de frente_golden.py, que es el\n")
    f.write(f"//   mismo que implementa mnist_feat.v. Precision de test: {acc_q:.1%}.\n")
    f.write(f"//   Escala del cuantizador: {esc:.6f} — no hace falta en el RTL: el argmax es\n")
    f.write(f"//   invariante a una escala positiva comun.\n")
    f.write(f"localparam integer N_CLASE = {Wq.shape[0]};\n")
    f.write(f"localparam integer N_CARAC = {Wq.shape[1]};\n")
    f.write(f"localparam integer WB      = {BITS};\n\n")
    f.write("// w_rom[clase*N_CARAC + carac]\n")
    f.write(f"function signed [{BITS-1}:0] w_rom(input [8:0] a);\n    case (a)\n")
    for c in range(Wq.shape[0]):
        for k in range(Wq.shape[1]):
            f.write(f"        9'd{c*Wq.shape[1]+k}: w_rom = {sd(Wq[c,k], BITS)};\n")
    f.write("        default: w_rom = 0;\n    endcase\nendfunction\n\n")
    f.write("function signed [15:0] b_rom(input [3:0] c);\n    case (c)\n")
    for c in range(len(bq)):
        f.write(f"        4'd{c}: b_rom = {sd(bq[c], 16)};\n")
    f.write("        default: b_rom = 0;\n    endcase\nendfunction\n")
print(f"-> {SALIDA}")
np.savez("pesos_hw.npz", W=Wq, b=bq, esc=esc)
