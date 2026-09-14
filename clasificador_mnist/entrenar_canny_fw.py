#!/usr/bin/env python3
"""entrenar_canny_fw.py — pesos del Canny para LOS UMBRALES QUE PONE EL FIRMWARE.

Los pesos anteriores (mnist_weights_canny.vh) se entrenaron con hi=110 lo=40, pero el firmware
del SoC escribe hi=90 lo=32 (constante 0x5A20, ver §16). Entrenar con unos umbrales y correr con
otros es la desalineacion firmware<->modelo que la §13 estudio: aca se elimina.

  Uso:  python3 entrenar_canny_fw.py [hi] [lo]
"""
import sys, numpy as np, warnings; warnings.filterwarnings("ignore")
from sklearn.linear_model import LogisticRegression
import frente_golden as fg
from canny1_mnist import frente_canny1

HI = int(sys.argv[1]) if len(sys.argv) > 1 else 90
LO = int(sys.argv[2]) if len(sys.argv) > 2 else 32
BITS = 4

Xtr, ytr, Xte, yte = fg.cargar_mnist()
mtr, otr = frente_canny1(Xtr, HI, LO); mte, ote = frente_canny1(Xte, HI, LO)
Ftr = fg.piramide(mtr, otr, 1); Fte = fg.piramide(mte, ote, 1)
ntr = mtr.sum(axis=(1,2)); nte = mte.sum(axis=(1,2))
clf = LogisticRegression(max_iter=5000, C=0.002).fit(Ftr, ytr)
W, esc = fg.cuantizar(clf.coef_, BITS); b = np.round(clf.intercept_/esc).astype(int)
Str, Ste = Ftr @ W.T + b, Fte @ W.T + b
ptr, pte = Str.argmax(1), Ste.argmax(1)
print(f"Canny hi={HI} lo={LO} · densidad {mtr.mean():.1%}")
print(f"  float {clf.score(Fte,yte):.2%}   4 bits {(pte==yte).mean():.2%}   (train {(ptr==ytr).mean():.2%})")

mg = lambda S: np.sort(S,1)[:,-1] - np.sort(S,1)[:,-2]
B_MIN, B_MAX = int(np.percentile(ntr,5)), int(np.percentile(ntr,95))
mejor=(0,0)
for M in range(0,200,5):
    v=(ntr>=B_MIN)&(ntr<=B_MAX)&(mg(Str)>M)
    if v.mean()<.60: break
    pr=(ptr[v]==ytr[v]).mean()
    if pr>mejor[0]: mejor=(pr,M)
MARGEN=mejor[1]
v=(nte>=B_MIN)&(nte<=B_MAX)&(mg(Ste)>MARGEN)
print(f"  NADA: B_MIN={B_MIN} B_MAX={B_MAX} MARGEN={MARGEN}  ->  "
      f"cobertura {v.mean():.2%} precision {(pte[v]==yte[v]).mean():.2%}")

def sd(x,w): return f"{w}'sd{int(x)}" if x>=0 else f"-{w}'sd{-int(x)}"
with open("rtl/mnist_weights_canny_fw.vh","w") as f:
    f.write(f"// mnist_weights_canny_fw.vh — GENERADO. Canny 1-salto con hi={HI} lo={LO},\n")
    f.write(f"//   que son LOS UMBRALES QUE ESCRIBE EL FIRMWARE (constante 0x{(HI<<8)|LO:04X}).\n")
    f.write(f"//   Test a 4 bits: {(pte==yte).mean():.2%}.  NADA: {B_MIN}/{B_MAX}/{MARGEN}.\n")
    f.write(f"localparam integer N_CLASE = {W.shape[0]};\nlocalparam integer N_CARAC = {W.shape[1]};\n")
    f.write("localparam integer WB = 4;\n\n")
    f.write("function signed [3:0] w_rom(input [8:0] a);\n    case (a)\n")
    for c in range(W.shape[0]):
        for k in range(W.shape[1]):
            f.write(f"        9'd{c*W.shape[1]+k}: w_rom = {sd(W[c,k],4)};\n")
    f.write("        default: w_rom = 0;\n    endcase\nendfunction\n\n")
    f.write("function signed [15:0] b_rom(input [3:0] c);\n    case (c)\n")
    for c in range(len(b)): f.write(f"        4'd{c}: b_rom = {sd(b[c],16)};\n")
    f.write("        default: b_rom = 0;\n    endcase\nendfunction\n")
print("-> rtl/mnist_weights_canny_fw.vh")
np.savez("pesos_canny_fw.npz", W=W, b=b, esc=esc, B=(B_MIN,B_MAX,MARGEN))
