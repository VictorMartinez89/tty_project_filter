#!/usr/bin/env python3
# entrenar_hw.py — entrena el clasificador CON LA ARITMETICA DEL HARDWARE y exporta los pesos a Verilog.
#
#   Diferencia clave con piramide_mnist.py: alli la orientacion se cuantizaba con atan2 redondeado,
#   que en silicio costaria un CORDIC o una tabla. Aca se usa el OCTANTE:
#
#       bin = { sgn(Gy), sgn(Gx), |Gy| > |Gx| }        <- 3 bits, 3 comparaciones, CERO multiplicaciones
#
#   Son ocho sectores de 45 grados igual que antes, solo que con los bordes en 0/45/90... en vez de
#   centrados. Para un histograma da lo mismo, y en hardware es gratis. Esta es la regla que sigue
#   toda la tesis: el golden modela lo que el silicio puede hacer, no al reves.
#
#   Salida: mnist_weights.vh  (pesos de 4 bits con signo, listos para el `case` del RTL)
import numpy as np, sys
from sklearn.linear_model import LogisticRegression

H_IMG, W_IMG = 28, 28
THR   = 60          # el mismo umbral del front-end
BITS  = 4           # bits por peso
NIVEL = 1           # piramide 0+1 -> 5 zonas

G  = np.array([[1,2,1],[2,4,2],[1,2,1]], float)
GX = np.array([[-1,0,1],[-2,0,2],[-1,0,1]], float)
GY = np.array([[-1,-2,-1],[0,0,0],[1,2,1]], float)

def conv3(img, k):
    N,H,W = img.shape; out = np.zeros((N,H-2,W-2))
    for i in range(3):
        for j in range(3):
            if k[i,j]: out += k[i,j]*img[:, i:i+H-2, j:j+W-2]
    return out

def frente(img):
    """El front-end tal cual lo hace el RTL: Gauss/16 -> Sobel -> |Gx|+|Gy| sat 255 -> umbral -> octante."""
    g  = np.floor(conv3(img.astype(float), G)/16.0)          # /16 es un shift: se trunca, no se redondea
    gx = conv3(g, GX); gy = conv3(g, GY)
    mag = np.minimum(np.abs(gx)+np.abs(gy), 255.0)
    sy  = (gy >= 0).astype(np.int8); sx = (gx >= 0).astype(np.int8)
    d45 = (np.abs(gy) > np.abs(gx)).astype(np.int8)
    return mag > THR, (sy*4 + sx*2 + d45).astype(np.int8)

def piramide(mask, ori, niveles=NIVEL):
    N,H,W = mask.shape; feats = []
    for L in range(niveles+1):
        n = 2**L
        for zy in range(n):
            for zx in range(n):
                m = mask[:, zy*H//n:(zy+1)*H//n, zx*W//n:(zx+1)*W//n]
                o = ori [:, zy*H//n:(zy+1)*H//n, zx*W//n:(zx+1)*W//n]
                for b in range(8):
                    feats.append(((o == b) & m).sum(axis=(1,2)))
    return np.stack(feats, axis=1).astype(np.float32)

def cuantizar(W, bits):
    lim = 2**(bits-1) - 1
    mejor, err_min = None, np.inf
    for f in np.linspace(0.05, 1.0, 40):
        esc = np.abs(W).max()*f/lim
        Wq  = np.round(W/esc).clip(-lim, lim)
        e   = ((Wq*esc - W)**2).sum()
        if e < err_min: mejor, err_min, mejor_esc = Wq, e, esc
    return mejor.astype(int), mejor_esc

d = np.load("mnist.npz")
Xtr, ytr, Xte, yte = d["X"], d["y"], d["Xt"], d["yt"]
mtr, otr = frente(Xtr); mte, ote = frente(Xte)
Ftr = piramide(mtr, otr); Fte = piramide(mte, ote)
D = Ftr.shape[1]
print(f"front-end del RTL (octante) · {D} caracteristicas · densidad de borde {mtr.mean():.1%}")

# El clasificador trabaja sobre los CONTADORES CRUDOS: en hardware no hay normalizacion.
# Se entrena con las cuentas tal cual y se deja que los pesos absorban la escala.
clf = LogisticRegression(max_iter=3000, C=0.002, multi_class="multinomial")
clf.fit(Ftr, ytr)
acc_f = clf.score(Fte, yte)
Wq, esc = cuantizar(clf.coef_, BITS)
bq = np.round(clf.intercept_/esc).astype(int)
pred = (Fte @ Wq.T + bq).argmax(1)
acc_q = (pred == yte).mean()
print(f"precision  float {acc_f:.1%}   ·   cuantizado a {BITS} bits {acc_q:.1%}")
print(f"pesos: {Wq.shape[0]}x{Wq.shape[1]} = {Wq.size} · rango [{Wq.min()},{Wq.max()}] · escala {esc:.5f}")
n69 = int(((yte==6)&(pred==9)).sum()); n96 = int(((yte==9)&(pred==6)).sum())
print(f"6 leido como 9: {n69}/{int((yte==6).sum())}   9 leido como 6: {n96}/{int((yte==9).sum())}")

with open("mnist_weights.vh", "w") as f:
    f.write("// mnist_weights.vh — GENERADO por entrenar_hw.py. No editar a mano.\n")
    f.write(f"//   {Wq.shape[0]} clases x {Wq.shape[1]} caracteristicas, {BITS} bits con signo.\n")
    f.write(f"//   Entrenado sobre MNIST (60 000) con el front-end del RTL: Gauss/16 -> Sobel ->\n")
    f.write(f"//   |Gx|+|Gy| sat 255 -> umbral {THR} -> octante. Precision de test: {acc_q:.1%}.\n")
    f.write(f"//   Escala del cuantizador: {esc:.6f} (no hace falta en el RTL: el argmax es invariante a escala).\n")
    f.write(f"localparam integer N_CLASE = {Wq.shape[0]};\n")
    f.write(f"localparam integer N_CARAC = {Wq.shape[1]};\n")
    f.write(f"localparam integer WB      = {BITS};\n\n")
    f.write("// w_rom[clase*N_CARAC + carac]\n")
    f.write(f"function signed [{BITS-1}:0] w_rom(input [8:0] a);\n    case (a)\n")
    for c in range(Wq.shape[0]):
        for k in range(Wq.shape[1]):
            v = int(Wq[c,k]) & ((1<<BITS)-1)
            f.write(f"        9'd{c*Wq.shape[1]+k}: w_rom = {BITS}'sd{int(Wq[c,k])};\n" if Wq[c,k]>=0
                    else f"        9'd{c*Wq.shape[1]+k}: w_rom = -{BITS}'sd{-int(Wq[c,k])};\n")
    f.write("        default: w_rom = 0;\n    endcase\nendfunction\n\n")
    f.write(f"function signed [15:0] b_rom(input [3:0] c);\n    case (c)\n")
    for c in range(len(bq)):
        f.write(f"        4'd{c}: b_rom = 16'sd{int(bq[c])};\n" if bq[c]>=0 else f"        4'd{c}: b_rom = -16'sd{-int(bq[c])};\n")
    f.write("        default: b_rom = 0;\n    endcase\nendfunction\n")
print("-> mnist_weights.vh")
np.savez("pesos_hw.npz", W=Wq, b=bq, esc=esc)
