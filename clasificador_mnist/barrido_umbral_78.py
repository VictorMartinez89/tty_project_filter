#!/usr/bin/env python3
"""barrido_umbral_78.py — ¿son 90/32 los umbrales buenos para MNIST?

Vienen del firmware del SoC, no de optimizar esta tarea, y la figura del
simulador enseño que a 90 la mascara no es un contorno sino la silueta
engordada del digito: la magnitud satura en el 44 % de los pixeles.

Se barre hi manteniendo la proporcion hi/lo ~ 2.8, y para cada punto se
mide lo que importa: cuanto satura, que densidad deja, y que exactitud da
-con las 168 y con las 78 elegidas, las dos a 4 bits y calibradas-.
"""
import numpy as np, time, warnings; warnings.filterwarnings("ignore")
from sklearn.linear_model import LogisticRegression
import frente_golden as fg
from canny1_mnist import frente_canny1

PARES = [(90,32), (130,46), (170,61), (210,75), (250,89)]
t0=time.time()
Xtr,ytr,Xte,yte = fg.cargar_mnist()

def magnitud(img):
    g = np.floor(fg.conv3(img.astype(float), fg.GAUSS)/16.0)
    return np.minimum(np.abs(fg.conv3(g, fg.SOBEL_X))+np.abs(fg.conv3(g, fg.SOBEL_Y)), 255.0)

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

def evalua(Ftr,ytr,Fte,yte,idx):
    clf=LogisticRegression(max_iter=2000,C=0.0005).fit(Ftr[:,idx],ytr)
    W,esc=fg.cuantizar(clf.coef_,4); b=np.round(clf.intercept_/esc).astype(np.int64)
    Str,Ste=Ftr[:,idx]@W.T, Fte[:,idx]@W.T
    bc=calibra(Str,ytr,b)
    return ((Ste+bc).argmax(1)==yte).mean()

mg = magnitud(Xte[:2000])
print(f"  {'hi/lo':>9} {'satura':>7} {'densidad':>9} {'168 caracs':>11} {'78 elegidas':>12}", flush=True)
print("  " + "-"*54, flush=True)
for HI,LO in PARES:
    t=time.time()
    mtr,otr = frente_canny1(Xtr,HI,LO); mte,ote = frente_canny1(Xte,HI,LO)
    Ftr=fg.piramide(mtr,otr,2); Fte=fg.piramide(mte,ote,2)
    sat = (mg>=255).mean(); dens = mte.mean()
    a168 = evalua(Ftr,ytr,Fte,yte,np.arange(168))
    clf=LogisticRegression(max_iter=2000,C=0.0005).fit(Ftr,ytr)
    idx=np.sort(np.argsort(-np.abs(clf.coef_).sum(0))[:78])
    a78 = evalua(Ftr,ytr,Fte,yte,idx)
    print(f"  {HI:4}/{LO:<4} {sat:>6.0%} {dens:>9.0%} {a168:>11.2%} {a78:>12.2%}"
          f"   ({time.time()-t:.0f}s)", flush=True)
    np.savez(f"pesos_hi{HI}.npz", idx=idx)
print(f"\n  referencia actual: hi=90 lo=32, 78 caracs -> 97.22 %", flush=True)
print(f"  [{time.time()-t0:.0f}s]", flush=True)
