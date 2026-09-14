#!/usr/bin/env python3
"""soc_umbral_canny.py — la prediccion de la §25.4, puesta a prueba.

La §12 midio cuanto vale el umbral adaptativo (= lo unico que agrega el CPU) SOBRE EL SOBEL:
+27.27 pp con ruido severo. La §25 encontro que el Canny vive en una MESETA de 0.90 pp, mientras
el Sobel vive en un pico de 5.79 pp. De ahi sale una prediccion:

    si el Canny ya es insensible al umbral, el CPU deberia aportarle MUCHO MENOS que al Sobel.

Esto la mide. Metodologia identica a la de la §12 (soc_umbral.py): mismo degradador, mismo
percentil, mismo entrenamiento sobre limpio, misma cuantizacion a 4 bits. Lo unico que se agrega
son las dos columnas del Canny.

    Sobel  FIJO   thr = 60                      <- lo grabado en mnist_feat.v
    Sobel  ADAPT  thr = percentil p de ESA imagen
    Canny  FIJO   hi = 110, lo = 40             <- lo grabado en mnist_feat_canny.v
    Canny  ADAPT  hi = percentil p de ESA imagen,  lo = 0.36*hi   (la proporcion del firmware)
"""
import numpy as np, warnings, time; warnings.filterwarnings("ignore")
from sklearn.linear_model import LogisticRegression
import frente_golden as fg
from canny1_mnist import frente_canny1     # LA MISMA que la §18 y la §25

PCT = 50            # el mismo percentil que uso la §12
RAZON = 0.36        # lo/hi, la proporcion que escribe el firmware (90/32)

def mag_orient(img):
    if img.ndim == 2: img = img[None]
    g  = np.floor(fg.conv3(img.astype(float), fg.GAUSS) / 16.0)
    gx = fg.conv3(g, fg.SOBEL_X); gy = fg.conv3(g, fg.SOBEL_Y)
    mag = np.minimum(np.abs(gx) + np.abs(gy), 255.0)
    sy = (gy >= 0).astype(np.int8); sx = (gx >= 0).astype(np.int8)
    return mag, (sy*4 + sx*2 + (np.abs(gy) > np.abs(gx))).astype(np.int8)

def umbral_por_imagen(img):
    m, _ = mag_orient(img)
    return np.percentile(m.reshape(len(m), -1), PCT, axis=1)[:, None, None]

FRENTES = {
 "Sobel FIJO":  lambda X: (lambda mo: (mo[0] > 60, mo[1]))(mag_orient(X)),
 "Sobel ADAPT": lambda X: (lambda mo, t: (mo[0] > t, mo[1]))(mag_orient(X), umbral_por_imagen(X)),
 "Canny FIJO":  lambda X: frente_canny1(X, 110, 40),
 "Canny ADAPT": lambda X: (lambda t: frente_canny1(X, t, RAZON*t))(umbral_por_imagen(X)),
}

def degrada(X, modo, s, rng=np.random.default_rng(0)):
    """IDENTICO a soc_umbral.py, para que los numeros sean comparables con la §12."""
    Y = X.astype(float); N, H, W = Y.shape
    if modo == "gradiente":
        Y = Y * (np.linspace(1-s,1,W)[None,None,:] * np.linspace(1-s,1,H)[None,:,None])
    elif modo == "contraste":
        Y = Y*(1-0.75*s) + 255*0.12*s
    elif modo == "ruido":
        Y = Y + rng.normal(0, 40*s, Y.shape)
    return np.clip(Y,0,255).astype(np.uint8)

Xtr, ytr, Xte, yte = fg.cargar_mnist()
ACC = {}
for nom, f in FRENTES.items():
    t0 = time.time()
    mtr, otr = f(Xtr); Ftr = fg.piramide(mtr, otr, 1)
    clf = LogisticRegression(max_iter=5000, C=0.002).fit(Ftr, ytr)
    Wq, esc = fg.cuantizar(clf.coef_, 4); bq = np.round(clf.intercept_/esc).astype(int)
    def acc(X, f=f, Wq=Wq, bq=bq):
        m, o = f(X); return ((fg.piramide(m,o,1) @ Wq.T + bq).argmax(1) == yte).mean()*100
    ACC[nom] = acc
    print(f"  {nom:<12} entrenado ({time.time()-t0:.0f}s) · limpio {acc(Xte):6.2f} %", flush=True)

print(f"\n{'degradacion':<11}{'sev':>4}"
      f"{'Sob FIJO':>10}{'Sob ADAPT':>11}{'gana':>8}   "
      f"{'Can FIJO':>10}{'Can ADAPT':>11}{'gana':>8}")
R = []
for modo in ["gradiente","contraste","ruido"]:
    for s in [0.0, 0.2, 0.4, 0.6, 0.8, 1.0]:
        Xd = degrada(Xte, modo, s)
        v = [ACC[n](Xd) for n in FRENTES]
        R.append((modo, s, *v))
        print(f"{modo:<11}{s:4.1f}{v[0]:10.2f}{v[1]:11.2f}{v[1]-v[0]:+8.2f}   "
              f"{v[2]:10.2f}{v[3]:11.2f}{v[3]-v[2]:+8.2f}", flush=True)

A = np.array([r[2:] for r in R])
gS, gC = A[:,1]-A[:,0], A[:,3]-A[:,2]
print("\n" + "="*72)
print(f"  lo que el CPU le aporta al SOBEL:  peor {gS.min():+6.2f}   mejor {gS.max():+6.2f}   "
      f"rango {gS.max()-gS.min():5.2f} pp")
print(f"  lo que el CPU le aporta al CANNY:  peor {gC.min():+6.2f}   mejor {gC.max():+6.2f}   "
      f"rango {gC.max()-gC.min():5.2f} pp")
print(f"\n  en la peor condicion medida el CPU salva {gS.max():.2f} pp al Sobel "
      f"y {gC[gS.argmax()]:.2f} pp al Canny")
print(f"  el Canny SIN CPU, en esa misma condicion: {A[gS.argmax(),2]:.2f} % "
      f"contra {A[gS.argmax(),0]:.2f} % del Sobel sin CPU")
np.savez("soc_umbral_canny.npz", R=np.array([(m,s,*v) for m,s,*v in R], dtype=object),
         A=A, modos=[r[0] for r in R], sev=[r[1] for r in R])
