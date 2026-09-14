#!/usr/bin/env python3
"""ruido_emparejado.py — ¿la histeresis amplifica el ruido, o era el umbral?

La §6 concluyo que "la histeresis amplifica el ruido" comparando Sobel thr=110 (86.2 %) contra
Canny 110/40 (70.3 %). Pero esos dos NO producen la misma densidad de bordes: el Canny con lo=40
y un salto de histeresis deja pasar mucho mas. Un umbral ALTO es intrinsecamente resistente al
ruido -el ruido suma magnitud, y con la vara alta esos pixeles igual no pasan-, asi que la
comparacion puede estar midiendo el UMBRAL y atribuyendoselo a la HISTERESIS.

Es el mismo error que la §3 aprendio a evitar ("a igual area"), aplicado al umbral.

Esto barre los dos filtros sobre el mismo rango y registra la DENSIDAD de bordes, para poder
compararlos emparejados. Entrena sobre limpio, mide sobre limpio y sobre ruido.
"""
import numpy as np, warnings, time; warnings.filterwarnings("ignore")
from sklearn.linear_model import LogisticRegression
import frente_golden as fg
from canny1_mnist import frente_canny1

def mag_orient(img):
    g  = np.floor(fg.conv3(img.astype(float), fg.GAUSS) / 16.0)
    gx = fg.conv3(g, fg.SOBEL_X); gy = fg.conv3(g, fg.SOBEL_Y)
    mag = np.minimum(np.abs(gx) + np.abs(gy), 255.0)
    sy = (gy >= 0).astype(np.int8); sx = (gx >= 0).astype(np.int8)
    return mag, (sy*4 + sx*2 + (np.abs(gy) > np.abs(gx))).astype(np.int8)

def ruido(X, s, rng=np.random.default_rng(0)):
    return np.clip(X.astype(float) + rng.normal(0, 40*s, X.shape), 0, 255).astype(np.uint8)

Xtr, ytr, Xte, yte = fg.cargar_mnist()
Xn6, Xn10 = ruido(Xte, 0.6), ruido(Xte, 1.0)

def corre(nom, f):
    mtr, otr = f(Xtr); Ftr = fg.piramide(mtr, otr, 1)
    clf = LogisticRegression(max_iter=4000, C=0.002).fit(Ftr, ytr)
    Wq, esc = fg.cuantizar(clf.coef_, 4); bq = np.round(clf.intercept_/esc).astype(int)
    out = []
    for X in (Xte, Xn6, Xn10):
        m, o = f(X)
        out.append((((fg.piramide(m,o,1) @ Wq.T + bq).argmax(1) == yte).mean()*100, m.mean()*100))
    print(f"{nom:<16}{mtr.mean()*100:8.1f}%"
          + "".join(f"{a:9.2f}{d:7.1f}%" for a, d in out), flush=True)
    return (nom, mtr.mean()*100, *[v for p in out for v in p])

print(f"{'config':<16}{'dens tr':>9}"
      f"{'limpio':>9}{'dens':>7} {'ruido.6':>8}{'dens':>7} {'ruido 1':>8}{'dens':>7}")
R = []
for thr in (60, 80, 110, 140, 170):
    R.append(corre(f"Sobel {thr}", lambda X, t=thr: (lambda mo: (mo[0] > t, mo[1]))(mag_orient(X))))
for hi in (60, 80, 110, 140, 170, 200):
    R.append(corre(f"Canny {hi}/{int(hi*.36)}", lambda X, h=hi: frente_canny1(X, h, int(h*.36))))

A = np.array([r[1:] for r in R], float)
nom = [r[0] for r in R]
S = [i for i,n in enumerate(nom) if n.startswith("Sobel")]
C = [i for i,n in enumerate(nom) if n.startswith("Canny")]
print("\n" + "="*74)
print("  A DENSIDAD DE ENTRENAMIENTO EMPAREJADA, con ruido severo (s=1.0):")
for i in S:
    j = C[int(np.argmin([abs(A[k,0]-A[i,0]) for k in C]))]
    print(f"    {nom[i]:<12} dens {A[i,0]:5.1f}%  ->{A[i,5]:7.2f} %   |   "
          f"{nom[j]:<12} dens {A[j,0]:5.1f}%  ->{A[j,5]:7.2f} %   "
          f"Canny {A[j,5]-A[i,5]:+6.2f}")
print(f"\n  el mejor Sobel con ruido 1.0: {nom[S[int(A[S,5].argmax())]]:<12} {A[S,5].max():.2f} %")
print(f"  el mejor Canny con ruido 1.0: {nom[C[int(A[C,5].argmax())]]:<12} {A[C,5].max():.2f} %")
np.savez("ruido_emparejado.npz", A=A, nom=np.array(nom))
