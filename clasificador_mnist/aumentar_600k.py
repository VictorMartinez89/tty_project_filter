#!/usr/bin/env python3
"""aumentar_600k.py — 60 000 imagenes de train -> 600 000 sinteticas.

El TEST NO SE TOCA. Se aumenta solo el train: las 10 000 de test siguen siendo las
oficiales, que es lo unico que hace el numero comparable con la literatura.

Aumento: 9 desplazamientos enteros (-2,0,+2 en cada eje) + la original = 10x.
Es el aumento clasico de MNIST, y sobre un descriptor de histogramas por zonas
tiene sentido: ensena al modelo que el digito puede no estar centrado, que es
EXACTAMENTE el problema de la camara (el marco verde de la §5.6).
"""
import numpy as np, time, warnings; warnings.filterwarnings("ignore")
from sklearn.linear_model import LogisticRegression
import frente_golden as fg
from canny1_mnist import frente_canny1

t0=time.time(); HI,LO = 90,32
Xtr,ytr,Xte,yte = fg.cargar_mnist()
DES = [(dy,dx) for dy in (-2,0,2) for dx in (-2,0,2)]   # 9
print(f"  original {Xtr.shape[0]} -> aumentado {Xtr.shape[0]*len(DES)}", flush=True)

Fs, ys = [], []
for k,(dy,dx) in enumerate(DES):
    Xd = np.roll(np.roll(Xtr, dy, axis=1), dx, axis=2)
    if dy>0: Xd[:,:dy,:]=0
    elif dy<0: Xd[:,dy:,:]=0
    if dx>0: Xd[:,:,:dx]=0
    elif dx<0: Xd[:,:,dx:]=0
    m,o = frente_canny1(Xd,HI,LO)
    Fs.append(fg.piramide(m,o,2)); ys.append(ytr)
    print(f"  [{time.time()-t0:5.0f}s] desplazamiento {k+1}/{len(DES)} ({dy:+d},{dx:+d})", flush=True)
Ftr = np.concatenate(Fs); Ytr = np.concatenate(ys)
del Fs, ys
mte,ote = frente_canny1(Xte,HI,LO); Fte = fg.piramide(mte,ote,2)
print(f"  [{time.time()-t0:5.0f}s] train {Ftr.shape}  test {Fte.shape} (SIN aumentar)", flush=True)

def calibra(S,y,b):
    b=b.copy().astype(np.int64); mej=((S+b).argmax(1)==y).mean()
    for _ in range(8):
        h=False
        for c in range(10):
            for p in (16,8,4,2,1,-1,-2,-4,-8,-16):
                b2=b.copy(); b2[c]+=p; a=((S+b2).argmax(1)==y).mean()
                if a>mej+1e-9: mej,b,h=a,b2,True
        if not h: break
    return b

for niv,nc in ((1,40),(2,168)):
    for C in (0.0005,):
        t=time.time()
        clf = LogisticRegression(max_iter=300, C=C).fit(Ftr[:,:nc], Ytr)
        W,esc = fg.cuantizar(clf.coef_,4); b=np.round(clf.intercept_/esc).astype(np.int64)
        Str,Ste = Ftr[:,:nc]@W.T, Fte[:,:nc]@W.T
        base = ((Ste+b).argmax(1)==yte).mean()
        bc = calibra(Str,Ytr,b); cal = ((Ste+bc).argmax(1)==yte).mean()
        print(f"  [{time.time()-t0:5.0f}s] nivel {niv} C={C} 600k: "
              f"4 bits {base:.2%}  +calib {cal:.2%}  ({time.time()-t:.0f}s)", flush=True)
        np.savez(f"pesos_600k_n{niv}.npz", W=W, b=bc, esc=esc, b_orig=b)
print(f"  [{time.time()-t0:5.0f}s] fin", flush=True)
