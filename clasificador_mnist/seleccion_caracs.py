#!/usr/bin/env python3
"""seleccion_caracs.py — la mejor exactitud que CABE en el presupuesto real.

El nivel 2 da 97.56 % pero necesita 1680 multiplicaciones-acumulacion, y entre
cuadro y cuadro solo hay 28x28 = 784 ciclos. En vez de pedir mas ciclos, se
pregunta al reves: **de las 168 caracteristicas, cuales 78 valen mas?**

78 x 10 clases = 780 MAC  ->  cabe en los 784 ciclos, sin tocar el reloj ni
poner multiplicadores en paralelo.

La seleccion se hace SOLO con train, y se mide en el test oficial.
"""
import numpy as np, time, warnings; warnings.filterwarnings("ignore")
from sklearn.linear_model import LogisticRegression
import frente_golden as fg

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

def evalua(Ftr,ytr,Fte,yte,idx,C=0.0005,bits=4):
    clf = LogisticRegression(max_iter=2000,C=C).fit(Ftr[:,idx],ytr)
    W,esc = fg.cuantizar(clf.coef_,bits); b=np.round(clf.intercept_/esc).astype(np.int64)
    Str,Ste = Ftr[:,idx]@W.T, Fte[:,idx]@W.T
    base=((Ste+b).argmax(1)==yte).mean()
    bc=calibra(Str,ytr,b); cal=((Ste+bc).argmax(1)==yte).mean()
    return base,cal,W,bc

t0=time.time()
d=np.load("/Users/vic/.claude/jobs/3eada066/tmp/feats_n2.npz")
Ftr,ytr,Fte,yte = d["Ftr"],d["ytr"],d["Fte"],d["yte"]

# importancia: cuanto pesa cada caracteristica en el modelo completo, en train
clf = LogisticRegression(max_iter=2000,C=0.0005).fit(Ftr,ytr)
imp = np.abs(clf.coef_).sum(0)
orden = np.argsort(-imp)
print(f"  [{time.time()-t0:5.0f}s] importancias calculadas", flush=True)

print(f"\n  {'caracs':>7} {'MAC':>6} {'cabe?':>6} {'4 bits':>9} {'+calib':>9}", flush=True)
print("  " + "-"*44, flush=True)
res=[]
for n in (40, 60, 78, 100, 128, 168):
    idx = np.sort(orden[:n])
    base,cal,W,b = evalua(Ftr,ytr,Fte,yte,idx)
    mac = n*10
    print(f"  {n:>7} {mac:>6} {'SI' if mac<=784 else 'no':>6} {base:>8.2%} {cal:>9.2%}", flush=True)
    res.append((n,mac,base,cal))
    if n==78: np.savez("pesos_sel78.npz", W=W, b=b, idx=idx)
print(f"\n  [{time.time()-t0:5.0f}s] fin", flush=True)
