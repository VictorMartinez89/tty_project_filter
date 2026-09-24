#!/usr/bin/env python3
"""brecha_camara.py — CUANTO le cuesta a la cadena del 97,22 % que el digito no venga como MNIST.

MNIST llega normalizado: el trazo cabe en una caja de 20x20 y el centro de masa cae en el centro
del cuadro de 28x28. La camara no hace nada de eso: el digito entra donde caiga y del tamano que
salga. La Parte 181 lo midio en placa (7/72, nivel de azar) pero con 72 imagenes sin control.

Aqui se mide con las 10 000 del test, perturbando UNA cosa por vez:
  1. desplazamiento: el digito corrido d pixeles (8 direcciones, promedio)
  2. escala: el trazo encogido o agrandado alrededor de su centro de masa
Y para cada perturbacion, lo mismo DESPUES de un normalizador tipo MNIST (caja 20x20 + centro de
masa), que es lo que el marco verde le pide hacer a la persona. La diferencia entre las dos curvas
es lo que valdria meter ese normalizador en el silicio.

Los pesos son los del RTL verificado (pesos_sel78.npz); la cadena es la golden, bit-exacta.
"""
import numpy as np, warnings, json; warnings.filterwarnings("ignore")
from scipy import ndimage
import matplotlib; matplotlib.use("Agg"); import matplotlib.pyplot as plt
import frente_golden as fg
from canny1_mnist import frente_canny1

N = 10000
_, _, Xte, yte = fg.cargar_mnist(); X = Xte[:N].astype(float); y = yte[:N]
p = np.load("pesos_sel78.npz"); W, b, idx = p["W"], p["b"], p["idx"]

def exactitud(A):
    A = np.clip(np.round(A), 0, 255)
    m, o = frente_canny1(A, 90, 32); S = fg.piramide(m, o, 2)[:, idx] @ W.T + b
    ss = np.sort(S, 1); nb = m.sum(axis=(1, 2))
    habla = (nb >= 174) & (nb <= 376) & (ss[:, -1] - ss[:, -2] > 70)
    ok = S.argmax(1) == y
    return float(ok.mean()), float(habla.mean()), float(ok[habla].mean()) if habla.any() else 0.0

def normaliza(a):
    """El preprocesado de MNIST: recorta la caja del trazo, la lleva a 20x20 sin deformar y la
    pega en 28x28 con el centro de masa en el centro. Es lo que la camara NO hace."""
    ys, xs = np.nonzero(a > 30)
    if len(ys) == 0: return a
    c = a[ys.min():ys.max()+1, xs.min():xs.max()+1]
    f = 20.0 / max(c.shape)
    c = np.clip(ndimage.zoom(c, f, order=1), 0, 255)
    out = np.zeros((28, 28)); h, w = c.shape
    out[(28-h)//2:(28-h)//2+h, (28-w)//2:(28-w)//2+w] = c
    cy, cx = ndimage.center_of_mass(out)
    return ndimage.shift(out, (14 - cy, 14 - cx), order=1, mode="constant")

def desplaza(A, d):
    if d == 0: return A
    R = []
    for k, (dy, dx) in enumerate([(d,0),(-d,0),(0,d),(0,-d),(d,d),(-d,-d),(d,-d),(-d,d)]):
        B = A[k::8]
        R.append((np.roll(np.roll(B, dy, 1), dx, 2) * _mascara(dy, dx), k))
    out = np.empty_like(A)
    for B, k in R: out[k::8] = B
    return out

def _mascara(dy, dx):
    """np.roll da la vuelta; lo que sale por un lado NO entra por el otro: se pone a cero."""
    M = np.ones((28, 28))
    if dy > 0: M[:dy] = 0
    if dy < 0: M[dy:] = 0
    if dx > 0: M[:, :dx] = 0
    if dx < 0: M[:, dx:] = 0
    return M

def escala(A, s):
    if s == 1.0: return A
    out = np.empty_like(A)
    for i, a in enumerate(A):
        cy, cx = ndimage.center_of_mass(a)
        # afin alrededor del centro de masa: salida(p) = entrada(c + (p - c)/s)
        out[i] = ndimage.affine_transform(a, np.eye(2) / s, offset=(np.array([cy, cx]) * (1 - 1/s)),
                                          order=1, mode="constant")
    return out

res = {"desplazamiento": [], "escala": []}
print(f"cadena del 97,22 % sobre {N} imagenes del test\n")
print("DESPLAZAMIENTO (pixeles)      sin normalizar            con normalizador")
print("                           acierta  habla  al hablar   acierta  habla")
for d in [0, 1, 2, 3, 4, 6, 8]:
    A = desplaza(X, d); sin = exactitud(A)
    con = exactitud(np.stack([normaliza(a) for a in A]))
    res["desplazamiento"].append((d, sin, con))
    print(f"  {d:2d} px                    {sin[0]:6.2%} {sin[1]:6.1%}  {sin[2]:6.2%}    {con[0]:6.2%} {con[1]:6.1%}", flush=True)
print("\nESCALA del trazo")
for s in [0.5, 0.65, 0.8, 1.0, 1.15, 1.3]:
    A = escala(X, s); sin = exactitud(A)
    con = exactitud(np.stack([normaliza(a) for a in A]))
    res["escala"].append((s, sin, con))
    print(f"  x{s:4.2f}                    {sin[0]:6.2%} {sin[1]:6.1%}  {sin[2]:6.2%}    {con[0]:6.2%} {con[1]:6.1%}", flush=True)
json.dump(res, open("brecha_camara.json", "w"), indent=1)

fig, ax = plt.subplots(1, 2, figsize=(11, 3.8))
for a, k, xl in [(ax[0], "desplazamiento", "desplazamiento del digito (pixeles)"),
                 (ax[1], "escala", "escala del trazo")]:
    xs = [r[0] for r in res[k]]
    a.plot(xs, [100*r[1][0] for r in res[k]], "o-", color="#c0392b", label="tal cual (lo que ve la camara)")
    a.plot(xs, [100*r[2][0] for r in res[k]], "s-", color="#1e7a3c", label="con normalizador tipo MNIST")
    a.axhline(10, color="#999", lw=0.8, ls=":"); a.text(xs[0], 11.5, "azar", fontsize=8, color="#777")
    a.set_xlabel(xl); a.set_ylabel("acierto (%)"); a.set_ylim(0, 100); a.grid(alpha=.3)
    for sp in ("top", "right"): a.spines[sp].set_visible(False)
ax[0].legend(fontsize=8, loc="upper right")
fig.suptitle("La brecha de la camara, medida: la cadena del 97,22 % con el digito corrido o reescalado",
             fontsize=10.5, x=0.01, ha="left")
fig.tight_layout(); fig.savefig("../tesis/figuras/fig_brecha_camara.png", dpi=170, facecolor="white")
print("\n  -> tesis/figuras/fig_brecha_camara.png · brecha_camara.json")
