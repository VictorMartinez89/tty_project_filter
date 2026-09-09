#!/usr/bin/env python3
"""canny1_completo.py — el sistema COMPLETO con front-end Canny 1-salto:
   11 clases (NADA, 0..9), 60 000 de entrenamiento, 10 000 de test, matriz de confusion.

Repite sobre el Canny todo lo que las Partes 182-183 hicieron sobre el Sobel, para que la
comparacion sea de igual a igual. Dos diferencias metodologicas, ambas a favor de la limpieza:

  * Los umbrales de la clase NADA se calibran sobre ENTRENAMIENTO, no sobre test. La calibracion
    original (Parte 174) uso 3 000 imagenes de test: eso es fuga de informacion. Aca no.
  * El area valida del Canny es 22x22 = 484 px (tres ventanas 3x3), contra 576 del Sobel, asi que
    los umbrales de densidad de borde NO son los mismos numeros y hay que recalibrarlos.
"""
import numpy as np, warnings, time
warnings.filterwarnings("ignore")
from sklearn.linear_model import LogisticRegression
import frente_golden as fg
from canny1_mnist import frente_canny1

HI, LO, BITS, NIVEL = 110, 40, 4, 1
t0 = time.time()
Xtr, ytr, Xte, yte = fg.cargar_mnist()
print(f"front-end Canny 1-salto  hi={HI} lo={LO}   ({len(Xtr)} train / {len(Xte)} test)")

mtr, otr = frente_canny1(Xtr, HI, LO);  mte, ote = frente_canny1(Xte, HI, LO)
Ftr = fg.piramide(mtr, otr, NIVEL);     Fte = fg.piramide(mte, ote, NIVEL)
ntr = mtr.sum(axis=(1, 2));             nte = mte.sum(axis=(1, 2))    # bordes por imagen
print(f"area valida {mtr.shape[1]}x{mtr.shape[2]} = {mtr.shape[1]*mtr.shape[2]} px   "
      f"densidad {mtr.mean():.1%}   bordes/imagen: mediana {np.median(ntr):.0f}  ({time.time()-t0:.0f}s)")

clf = LogisticRegression(max_iter=5000, C=0.002).fit(Ftr, ytr)
Wq, esc = fg.cuantizar(clf.coef_, BITS)
bq = np.round(clf.intercept_ / esc).astype(int)

def puntajes(F): return F @ Wq.T + bq
Str, Ste = puntajes(Ftr), puntajes(Fte)
ptr, pte = Str.argmax(1), Ste.argmax(1)
acc_tr, acc_te = (ptr == ytr).mean(), (pte == yte).mean()
print(f"\nSIN clase NADA:  train {acc_tr:.2%}   test {acc_te:.2%}   (brecha {acc_te-acc_tr:+.2f} pp)")

# --- margen entre el mejor y el segundo puntaje ---
def margen(S):
    o = np.sort(S, axis=1)
    return o[:, -1] - o[:, -2]
mgtr, mgte = margen(Str), margen(Ste)

# --- calibrar la clase NADA SOLO con entrenamiento ---
B_MIN, B_MAX = int(np.percentile(ntr, 5)), int(np.percentile(ntr, 95))
mejor = (0, 0)
for M in range(0, 200, 5):
    v = (ntr >= B_MIN) & (ntr <= B_MAX) & (mgtr > M)
    if v.mean() < 0.60: break
    prec = (ptr[v] == ytr[v]).mean()
    if prec > mejor[0]: mejor = (prec, M)
MARGEN = mejor[1]
print(f"calibrado en TRAIN:  B_MIN={B_MIN}  B_MAX={B_MAX}  MARGEN={MARGEN}")

v = (nte >= B_MIN) & (nte <= B_MAX) & (mgte > MARGEN)
cob, prec = v.mean(), (pte[v] == yte[v]).mean()
VP = int((v & (pte == yte)).sum()); FP = int((v & (pte != yte)).sum())
FN = int((~v & (pte == yte)).sum()); VN = int((~v & (pte != yte)).sum())
print(f"\nCON clase NADA:  cobertura {cob:.2%}   precision al hablar {prec:.2%}")
print(f"  VP {VP}   FP {FP}   FN {FN}   VN {VN}")
print(f"  filtra {VN/(VN+FP):.1%} de los errores sacrificando {FN/(FN+VP):.1%} de los aciertos")

# --- matriz 11x11: fila = verdad, columna = prediccion (10 = NADA) ---
M11 = np.zeros((10, 11), int)
for t, p, ok in zip(yte, pte, v):
    M11[t, p if ok else 10] += 1
np.savez("canny1_completo.npz", M11=M11, pte=pte, yte=yte, val=v, nte=nte, mgte=mgte,
         W=Wq, b=bq, esc=esc, acc_tr=acc_tr, acc_te=acc_te,
         B_MIN=B_MIN, B_MAX=B_MAX, MARGEN=MARGEN, cob=cob, prec=prec)
print(f"\n-> canny1_completo.npz   ({time.time()-t0:.0f}s)")
