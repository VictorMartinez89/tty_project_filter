#!/usr/bin/env python3
"""soc_umbral.py — que compra el CPU: el umbral ADAPTATIVO.

El SoC femto + Sobel produce el MISMO mapa de bordes que el Sobel solo -la tesis lo midio: 45
pares con y sin CPU, identicos pixel a pixel-. El datapath no cambia. Lo unico que el CPU agrega
es poder ESCRIBIR EL UMBRAL en tiempo de ejecucion, por el periferico 0x0045.

Asi que la pregunta medible es: cuanto vale ese umbral adaptativo?

  FIJO      thr = 60 para todas las imagenes        <- lo que hace el diseno SIN CPU
  ADAPTATIVO thr = percentil p de la magnitud       <- lo que solo un CPU puede hacer

Y se mide dos veces: sobre MNIST limpio, y sobre MNIST DEGRADADO como en la §6, que es donde el
umbral fijo deberia sufrir.
"""
import numpy as np, warnings, time; warnings.filterwarnings("ignore")
from sklearn.linear_model import LogisticRegression
import frente_golden as fg

def mag_orient(img):
    if img.ndim == 2: img = img[None]
    g  = np.floor(fg.conv3(img.astype(float), fg.GAUSS) / 16.0)
    gx = fg.conv3(g, fg.SOBEL_X); gy = fg.conv3(g, fg.SOBEL_Y)
    mag = np.minimum(np.abs(gx) + np.abs(gy), 255.0)
    sy = (gy >= 0).astype(np.int8); sx = (gx >= 0).astype(np.int8)
    return mag, (sy*4 + sx*2 + (np.abs(gy) > np.abs(gx))).astype(np.int8)

def frente_fijo(img, thr=60):
    m, o = mag_orient(img); return m > thr, o

def frente_adapt(img, pct=50):
    """El umbral lo elige el CPU por cuadro: percentil `pct` de la magnitud de ESA imagen."""
    m, o = mag_orient(img)
    t = np.percentile(m.reshape(len(m), -1), pct, axis=1)[:, None, None]
    return m > t, o

def degrada(X, modo, s, rng=np.random.default_rng(0)):
    Y = X.astype(float); N, H, W = Y.shape
    if modo == "gradiente":
        Y = Y * (np.linspace(1-s,1,W)[None,None,:] * np.linspace(1-s,1,H)[None,:,None])
    elif modo == "contraste":
        Y = Y*(1-0.75*s) + 255*0.12*s
    elif modo == "ruido":
        Y = Y + rng.normal(0, 40*s, Y.shape)
    return np.clip(Y,0,255).astype(np.uint8)

Xtr, ytr, Xte, yte = fg.cargar_mnist()
def entrena_y_mide(f, Xd_te=None):
    mtr,otr = f(Xtr); Ftr = fg.piramide(mtr,otr,1)
    clf = LogisticRegression(max_iter=5000, C=0.002).fit(Ftr, ytr)
    W,e = fg.cuantizar(clf.coef_,4); b = np.round(clf.intercept_/e).astype(int)
    def acc(X):
        m,o = f(X); return ((fg.piramide(m,o,1)@W.T+b).argmax(1)==yte).mean()
    return acc

print("=== MNIST limpio ===")
t0=time.time()
acc_fijo  = entrena_y_mide(frente_fijo)
acc_adapt = entrena_y_mide(frente_adapt)
print(f"  umbral FIJO (sin CPU)      {acc_fijo(Xte):.2%}")
print(f"  umbral ADAPTATIVO (con CPU) {acc_adapt(Xte):.2%}   ({time.time()-t0:.0f}s)")

RES = []
print("\n=== degradado, como en la §6 (entrenado sobre limpio) ===")
print(f"{'degradacion':<12}{'sev':>5}{'FIJO':>9}{'ADAPT':>9}{'dif':>9}")
for modo in ["gradiente","contraste","ruido"]:
    for s in [0.0, 0.2, 0.4, 0.6, 0.8, 1.0]:
        Xd = degrada(Xte, modo, s)
        a, b_ = acc_fijo(Xd), acc_adapt(Xd)
        print(f"{modo:<12}{s:5.1f}{a:9.2%}{b_:9.2%}{b_-a:+9.2%}"
              f"{chr(32)*3+chr(60)+chr(45)+chr(45)+chr(32)+chr(101)+chr(108)+chr(32)+chr(67)+chr(80)+chr(85)+chr(32)+chr(115)+chr(97)+chr(108)+chr(118)+chr(97) if b_-a > .03 else chr(32)*0}")
        RES.append((modo, s, a, b_))

import numpy as _np
_np.savez("soc_umbral.npz", res=_np.array([(m,s,a,b) for m,s,a,b in RES], dtype=object),
         limpio=_np.array([acc_fijo(Xte), acc_adapt(Xte)]))
print("\n-> soc_umbral.npz")
