#!/usr/bin/env python3
"""transitivo_mnist.py — el TERCER filtro de la tesis como front-end del clasificador.

El Canny TRANSITIVO es la histeresis completa: reconstruccion morfologica. Un pixel debil
sobrevive si esta conectado a uno fuerte **transitivamente**, siguiendo la cadena tan lejos como
haga falta. Es el punto fijo de:

    sobreviven <- (cls >= 1)  AND  dilatar(sobreviven)      hasta que no cambie

El Canny 1-salto (§1) es la version truncada a UN paso de esa iteracion. El transitivo es el
filtro "optimo pero lento" de la tesis: mejor calidad de borde, y el unico que NO entra en Tiny
Tapeout -el frame buffer se vuelve flip-flops cuando no hay SPRAM-.

DIFERENCIA IMPORTANTE de area util: el transitivo itera sobre el mapa ENTERO, asi que no pierde
el anillo extra que el Canny 1-salto pierde por su tercera ventana 3x3.
    Sobel      24x24 = 576 px
    Canny1     22x22 = 484 px   (tercera ventana)
    Transitivo 24x24 = 576 px   (la reconstruccion no achica)
"""
import numpy as np, warnings; warnings.filterwarnings("ignore")
import frente_golden as fg


def frente_transitivo(img, thr_hi, thr_lo, max_it=64):
    """(N,H,W) -> (mascara, orientacion) de (N,H-4,W-4), con histeresis TRANSITIVA."""
    if img.ndim == 2:
        img = img[None]
    g  = np.floor(fg.conv3(img.astype(float), fg.GAUSS) / 16.0)
    gx = fg.conv3(g, fg.SOBEL_X); gy = fg.conv3(g, fg.SOBEL_Y)
    mag = np.minimum(np.abs(gx) + np.abs(gy), 255.0)
    sy = (gy >= 0).astype(np.int8); sx = (gx >= 0).astype(np.int8)
    orient = (sy*4 + sx*2 + (np.abs(gy) > np.abs(gx))).astype(np.int8)

    fuerte = mag > thr_hi
    debil  = mag > thr_lo                      # incluye a los fuertes
    viven  = fuerte.copy()
    for _ in range(max_it):                    # punto fijo
        P = np.pad(viven, ((0,0),(1,1),(1,1)))
        crece = np.zeros_like(viven)
        for i in range(3):
            for j in range(3):
                crece |= P[:, i:i+viven.shape[1], j:j+viven.shape[2]]
        nuevo = debil & crece
        if np.array_equal(nuevo, viven): break
        viven = nuevo
    return viven, orient


if __name__ == "__main__":
    import time
    from sklearn.linear_model import LogisticRegression
    Xtr, ytr, Xte, yte = fg.cargar_mnist()
    print("cuantas iteraciones tarda en llegar al punto fijo (10 imagenes):")
    for n in range(3):
        x = Xte[n:n+1]
        g = np.floor(fg.conv3(x.astype(float), fg.GAUSS)/16.0)
        mag = np.minimum(np.abs(fg.conv3(g, fg.SOBEL_X)) + np.abs(fg.conv3(g, fg.SOBEL_Y)), 255.)
        f, d = mag > 110, mag > 40
        v = f.copy(); k = 0
        while True:
            P = np.pad(v, ((0,0),(1,1),(1,1)))
            c = np.zeros_like(v)
            for i in range(3):
                for j in range(3): c |= P[:, i:i+v.shape[1], j:j+v.shape[2]]
            nv = d & c; k += 1
            if np.array_equal(nv, v): break
            v = nv
        print(f"   imagen {n}: K = {k} barridos")
    t0 = time.time()
    mtr, otr = frente_transitivo(Xtr, 110, 40); mte, ote = frente_transitivo(Xte, 110, 40)
    print(f"\narea util {mtr.shape[1]}x{mtr.shape[2]} = {mtr.shape[1]*mtr.shape[2]} px  ·  "
          f"densidad {mtr.mean():.1%}  ·  ({time.time()-t0:.0f}s)")
    Ftr = fg.piramide(mtr, otr, 1); Fte = fg.piramide(mte, ote, 1)
    clf = LogisticRegression(max_iter=5000, C=0.002).fit(Ftr, ytr)
    W, e = fg.cuantizar(clf.coef_, 4); b = np.round(clf.intercept_/e).astype(int)
    print(f"float {clf.score(Fte,yte):.2%}  ·  4 bits {((Fte@W.T+b).argmax(1)==yte).mean():.2%}")
