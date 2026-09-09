#!/usr/bin/env python3
"""canny1_mnist.py — ¿sirve el Canny 1-salto como front-end del clasificador?

Reemplaza el umbral simple de `frente_golden.frente()` por el Canny 1-salto en streaming que
implementa `comparativa_*/src/canny1_top.v`, y mide si el clasificador mejora o empeora.

El Canny 1-salto del RTL es, exactamente:
    cls = 2 si mag > thr_hi ;  1 si mag > thr_lo ;  0 si no       (doble umbral)
    borde = (cls == 2) o (cls == 1 y algun VECINO de los 8 tiene cls == 2)   (histeresis 1 salto)

OJO con el area valida: el Canny lleva TRES ventanas 3x3 encadenadas (Gauss, Sobel, clase) contra
DOS del Sobel. Sobre 28x28 eso deja 22x22 en vez de 24x24: 484 pixeles contra 576, un 16 % menos
de area util. Es una diferencia real, no un detalle de implementacion.

  Uso:  python3 canny1_mnist.py [n_entrenamiento]
"""
import sys, time
import numpy as np
from sklearn.linear_model import LogisticRegression
import frente_golden as fg

N_TR = int(sys.argv[1]) if len(sys.argv) > 1 else 20000
BITS, NIVEL = 4, 1


def frente_canny1(img, thr_hi, thr_lo):
    """El front-end con Canny 1-salto. (N,H,W) -> (mascara, orientacion) de (N,H-6,W-6)."""
    if img.ndim == 2:
        img = img[None]
    g  = np.floor(fg.conv3(img.astype(float), fg.GAUSS) / 16.0)     # igual que el Sobel
    gx = fg.conv3(g, fg.SOBEL_X)
    gy = fg.conv3(g, fg.SOBEL_Y)
    mag = np.minimum(np.abs(gx) + np.abs(gy), 255.0)
    sy = (gy >= 0).astype(np.int8); sx = (gx >= 0).astype(np.int8)
    d45 = (np.abs(gy) > np.abs(gx)).astype(np.int8)
    orient = (sy * 4 + sx * 2 + d45).astype(np.int8)

    cls = np.where(mag > thr_hi, 2, np.where(mag > thr_lo, 1, 0)).astype(np.int8)
    # tercera ventana 3x3 sobre el mapa de clases: ¿algun vecino (de los 8) es fuerte?
    fuerte = (cls == 2)
    any_s = np.zeros_like(fuerte[:, 1:-1, 1:-1])
    for i in range(3):
        for j in range(3):
            if (i, j) != (1, 1):
                any_s |= fuerte[:, i:i + fuerte.shape[1] - 2, j:j + fuerte.shape[2] - 2]
    c = cls[:, 1:-1, 1:-1]
    borde = (c == 2) | ((c == 1) & any_s)
    return borde, orient[:, 1:-1, 1:-1]      # la orientacion se recorta igual


def evalua(mtr, otr, mte, ote, ytr, yte, etiqueta):
    Ftr = fg.piramide(mtr, otr, NIVEL); Fte = fg.piramide(mte, ote, NIVEL)
    clf = LogisticRegression(max_iter=3000, C=0.002).fit(Ftr, ytr)
    Wq, esc = fg.cuantizar(clf.coef_, BITS)
    bq = np.round(clf.intercept_ / esc).astype(int)
    acc_f = clf.score(Fte, yte)
    acc_q = ((Fte @ Wq.T + bq).argmax(1) == yte).mean()
    print(f"  {etiqueta:<34} densidad {mtr.mean():6.1%}   float {acc_f:6.2%}   4 bits {acc_q:6.2%}")
    return acc_q, acc_f, mtr.mean()


if __name__ == "__main__":       # sin este guard, importar el modulo re-corre el barrido
    Xtr, ytr, Xte, yte = fg.cargar_mnist()
    Xtr, ytr = Xtr[:N_TR], ytr[:N_TR]
    print(f"entrenando con {N_TR} imagenes, evaluando sobre las 10 000 de test\n")

    print("REFERENCIA — Sobel con umbral simple (el front-end actual de la tesis)")
    t0 = time.time()
    mtr, otr = fg.frente(Xtr); mte, ote = fg.frente(Xte)
    base = evalua(mtr, otr, mte, ote, ytr, yte, f"Sobel  thr={fg.UMBRAL}  ({mtr.shape[1]}x{mtr.shape[2]})")

    print("\nCANNY 1-SALTO — barrido de (thr_hi, thr_lo)")
    res = []
    for hi, lo in [(90, 30), (90, 45), (75, 25), (75, 40), (60, 20), (60, 30),
                   (60, 45), (45, 15), (45, 25), (110, 40)]:
        mtr, otr = frente_canny1(Xtr, hi, lo); mte, ote = frente_canny1(Xte, hi, lo)
        a = evalua(mtr, otr, mte, ote, ytr, yte, f"Canny1 hi={hi:3d} lo={lo:3d} ({mtr.shape[1]}x{mtr.shape[2]})")
        res.append(((hi, lo), a))

    print(f"\n({time.time()-t0:.0f}s)")
    mejor = max(res, key=lambda r: r[1][0])
    print(f"\nMEJOR Canny1: hi={mejor[0][0]} lo={mejor[0][1]}  ->  {mejor[1][0]:.2%} a 4 bits")
    print(f"Sobel de referencia:                    {base[0]:.2%} a 4 bits")
    d = mejor[1][0] - base[0]
    print(f"DIFERENCIA: {d:+.2%}  ->  {'el Canny GANA' if d > 0.002 else 'el Canny NO mejora' if d > -0.002 else 'el Canny PIERDE'}")
    np.savez("canny1_barrido.npz", res=np.array([[*k, v[0], v[1], v[2]] for k, v in res]),
             base=np.array(base))
