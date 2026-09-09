#!/usr/bin/env python3
"""canny1_camara.py — ¿el doble umbral aguanta lo que la camara le hace a la imagen?

La Parte 188 midio sobre MNIST limpio y el Canny no gano: MNIST es trazo blanco sobre negro,
sin bordes debiles que rescatar, y la histeresis existe justamente para rescatarlos. Este
experimento pone a prueba la hipotesis que quedo abierta: **el Canny deberia degradarse mas
despacio que el Sobel cuando la imagen se parece a lo que ve una OV7670**.

Se entrena SOBRE MNIST LIMPIO -que es lo que pasa de verdad: los pesos se calculan una vez y
se graban en la ROM- y se evalua sobre imagenes degradadas. Es el desplazamiento de dominio de
la Parte 181, pero controlado y graduable.

Cuatro degradaciones, cada una con una razon fisica:
  * GRADIENTE  — iluminacion despareja: una rampa multiplicativa. Es LO QUE MAS deberia
                 favorecer al doble umbral, porque un umbral unico no puede servir a los dos
                 lados de la imagen a la vez.
  * CONTRASTE  — el trazo no llega a blanco ni el fondo a negro: comprime el rango.
  * DESENFOQUE — la lente no enfoca a 10 cm: suaviza los bordes.
  * RUIDO      — el sensor a poca luz.
"""
import sys, warnings
warnings.filterwarnings("ignore")
import numpy as np
from sklearn.linear_model import LogisticRegression
import frente_golden as fg
from canny1_mnist import frente_canny1

N_TR, NIVEL, BITS = 20000, 1, 4
THR_S, HI, LO = 110, 110, 40
rng = np.random.default_rng(0)


def degrada(X, modo, s):
    """s = 0 -> imagen intacta;  s = 1 -> degradacion fuerte."""
    Y = X.astype(float)
    N, H, W = Y.shape
    if modo == "gradiente":
        # rampa multiplicativa diagonal: de (1-s) a 1 a lo ancho de la imagen
        r = np.linspace(1 - s, 1.0, W)[None, None, :] * np.linspace(1 - s, 1.0, H)[None, :, None]
        Y = Y * r
    elif modo == "contraste":
        Y = Y * (1 - 0.75 * s) + 255 * 0.12 * s          # comprime hacia el gris
    elif modo == "desenfoque":
        # gaussiana separable con sigma CONTINUO. La primera version aplicaba
        # `int(round(s*3))` pasadas de un 3x3, asi que s=0.2 y s=0.4 daban la MISMA
        # imagen: la curva salia plana de a pares y eso era un artefacto de
        # discretizacion, no un resultado. Un eje que no es continuo no es un eje.
        sig = 1.6 * s
        if sig > 0.01:
            r = int(np.ceil(3 * sig))
            k = np.exp(-np.arange(-r, r + 1) ** 2 / (2 * sig * sig)); k /= k.sum()
            P = np.pad(Y, ((0, 0), (0, 0), (r, r)), mode="edge")
            Y = sum(k[t] * P[:, :, t:t + W] for t in range(2 * r + 1))
            P = np.pad(Y, ((0, 0), (r, r), (0, 0)), mode="edge")
            Y = sum(k[t] * P[:, t:t + H, :] for t in range(2 * r + 1))
    elif modo == "ruido":
        Y = Y + rng.normal(0, 40 * s, Y.shape)
    return np.clip(Y, 0, 255).astype(np.uint8)


def entrena(F, y):
    clf = LogisticRegression(max_iter=3000, C=0.002).fit(F, y)
    Wq, esc = fg.cuantizar(clf.coef_, BITS)
    return Wq, np.round(clf.intercept_ / esc).astype(int)


Xtr, ytr, Xte, yte = fg.cargar_mnist()
Xtr, ytr = Xtr[:N_TR], ytr[:N_TR]

# --- entrenar UNA vez, sobre limpio, con cada front-end ---
FR = {"Sobel": lambda X: fg.frente(X, THR_S),
      "Canny1": lambda X: frente_canny1(X, HI, LO)}
modelo = {}
for nom, f in FR.items():
    m, o = f(Xtr)
    modelo[nom] = entrena(fg.piramide(m, o, NIVEL), ytr)
    print(f"{nom:<7} entrenado sobre limpio")

SEV = [0.0, 0.2, 0.4, 0.6, 0.8, 1.0]
res = {}
print(f"\n{'degradacion':<12} {'sev':>4} {'Sobel':>8} {'Canny1':>8} {'dif':>8}")
for modo in ["gradiente", "contraste", "desenfoque", "ruido"]:
    for s in SEV:
        Xd = degrada(Xte, modo, s)
        fila = {}
        for nom, f in FR.items():
            m, o = f(Xd)
            W, b = modelo[nom]
            fila[nom] = ((fg.piramide(m, o, NIVEL) @ W.T + b).argmax(1) == yte).mean()
        res[(modo, s)] = fila
        d = fila["Canny1"] - fila["Sobel"]
        print(f"{modo:<12} {s:4.1f} {fila['Sobel']:8.2%} {fila['Canny1']:8.2%} {d:+8.2%}"
              f"{'  <-- Canny aguanta mejor' if d > 0.02 else ''}")
np.savez("canny1_camara.npz",
         claves=np.array([f"{m}|{s}" for (m, s) in res]),
         sobel=np.array([res[k]["Sobel"] for k in res]),
         canny=np.array([res[k]["Canny1"] for k in res]))
print("\n-> canny1_camara.npz")
