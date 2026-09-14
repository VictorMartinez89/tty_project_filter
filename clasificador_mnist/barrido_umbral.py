#!/usr/bin/env python3
"""barrido_umbral.py — ¿que palanca es mas grande: el filtro o el umbral?

Misma metodologia que comparar_metricas.py: entrenar sobre las 60 000, cuantizar a
4 bits, medir sobre las 10 000. Lo unico que cambia es que ahora se BARRE el umbral
dentro de cada filtro, para comparar ese rango contra la diferencia ENTRE filtros.

La magnitud y la orientacion no dependen del umbral, asi que se calculan UNA vez.
"""
import numpy as np, time, sys
from sklearn.linear_model import LogisticRegression
import frente_golden as fg
from canny1_mnist import frente_canny1   # la MISMA que usa la tabla de la §18

NIVEL, BITS = 1, 4
Xtr, ytr, Xte, yte = fg.cargar_mnist()

def mag_ori(img):
    """El Sobel hasta la magnitud, SIN umbralar. Igual que fg.frente pero sin el corte."""
    g  = np.floor(fg.conv3(img.astype(float), fg.GAUSS) / 16.0)
    gx = fg.conv3(g, fg.SOBEL_X); gy = fg.conv3(g, fg.SOBEL_Y)
    mag = np.minimum(np.abs(gx) + np.abs(gy), 255.0)
    ori = ((gy >= 0).astype(np.int8)*4 + (gx >= 0).astype(np.int8)*2
           + (np.abs(gy) > np.abs(gx)).astype(np.int8))
    return mag, ori

print("calculando magnitud y orientacion una sola vez...", flush=True)
t0 = time.time()
Mtr, Otr = mag_ori(Xtr); Mte, Ote = mag_ori(Xte)
print(f"  listo ({time.time()-t0:.0f}s)\n", flush=True)

# El Canny NO se reimplementa aca: se usa frente_canny1, la misma que la §18.
# Una version rapida con np.roll ENVUELVE por los bordes y deja el area en 24x24
# en vez de 22x22, y la §3 ya midio que el recorte solo ya cambia el resultado.

def evaluar(mtr, otr, mte, ote):
    Ftr = fg.piramide(mtr, otr, NIVEL); Fte = fg.piramide(mte, ote, NIVEL)
    clf = LogisticRegression(max_iter=3000, C=0.002).fit(Ftr, ytr)
    Wq, esc = fg.cuantizar(clf.coef_, BITS); bq = np.round(clf.intercept_/esc).astype(int)
    return ((Fte @ Wq.T + bq).argmax(1) == yte).mean() * 100

R = {"Sobel": [], "Canny1": []}
print(f"{'filtro':<9}{'umbral':>14}{'exactitud':>12}{'t':>7}")
for thr in range(40, 145, 10):
    t0 = time.time(); a = evaluar(Mtr > thr, Otr, Mte > thr, Ote)
    R["Sobel"].append((thr, a)); print(f"{'Sobel':<9}{thr:>14}{a:>11.2f} %{time.time()-t0:>6.0f}s", flush=True)
for hi in range(60, 145, 10):
    lo = int(round(hi * 0.36))
    t0 = time.time()
    a = evaluar(*frente_canny1(Xtr, hi, lo), *frente_canny1(Xte, hi, lo))
    R["Canny1"].append((hi, lo, a))
    print(f"{'Canny1':<9}{f'{hi}/{lo}':>14}{a:>11.2f} %{time.time()-t0:>6.0f}s", flush=True)

print("\n" + "="*58)
s = [a for _, a in R["Sobel"]]; c = [a for _, _, a in R["Canny1"]]
print(f"  Sobel : de {min(s):.2f} % a {max(s):.2f} %   -> rango {max(s)-min(s):.2f} pp")
print(f"  Canny1: de {min(c):.2f} % a {max(c):.2f} %   -> rango {max(c)-min(c):.2f} pp")
print(f"\n  el UMBRAL mueve hasta      {max(max(s)-min(s), max(c)-min(c)):.2f} pp")
print(f"  el FILTRO, en su mejor pto {abs(max(c)-max(s)):.2f} pp")
print(f"  sigma (§19)                1.32 pp")
np.savez("barrido_umbral.npz", sobel=np.array(R["Sobel"]), canny=np.array(R["Canny1"]))
