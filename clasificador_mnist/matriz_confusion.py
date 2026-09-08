#!/usr/bin/env python3
"""matriz_confusion.py — la evaluacion completa del clasificador que corre en el chip.

Sobre MNIST ENTERO: 60 000 de entrenamiento y 10 000 de prueba, con los pesos EXACTOS que
lleva la ROM del silicio (4 bits con signo, `pesos_hw.npz`) y el front-end de `frente_golden`,
que es el mismo que implementa `rtl/mnist_feat.v` y se verifico bit a bit contra el.

Produce:
  * precision de entrenamiento y de prueba, y la brecha entre las dos
  * la MATRIZ DE CONFUSION 10x10 sobre las 10 000 de prueba
  * precision y exhaustividad por clase
  * los pares que mas se confunden
"""
import numpy as np
import frente_golden as fg

Xtr, ytr, Xte, yte = fg.cargar_mnist()
P = np.load("pesos_hw.npz"); W, b = P["W"], P["b"]

def predecir(X, bloque=5000):
    """Pasa las imagenes por el MISMO front-end del chip y clasifica."""
    out = []
    for i in range(0, len(X), bloque):
        m, o = fg.frente(X[i:i+bloque])
        F = fg.piramide(m, o, 1)
        out.append((F @ W.T + b).argmax(1))
    return np.concatenate(out)

print("evaluando 60 000 de entrenamiento y 10 000 de prueba con los pesos del chip...\n")
ptr = predecir(Xtr); pte = predecir(Xte)
acc_tr = (ptr == ytr).mean(); acc_te = (pte == yte).mean()
print(f"  entrenamiento (60 000): {acc_tr:.2%}")
print(f"  prueba        (10 000): {acc_te:.2%}")
print(f"  brecha                : {100*(acc_tr-acc_te):+.2f} puntos"
      f"   ->  {'sin sobreajuste apreciable' if abs(acc_tr-acc_te) < 0.02 else 'hay sobreajuste'}")

# --- matriz de confusion sobre las 10 000 de prueba ---
M = np.zeros((10, 10), int)
for v, p in zip(yte, pte):
    M[v, p] += 1

print("\nMATRIZ DE CONFUSION (filas = digito real, columnas = prediccion)\n")
print("      " + "".join(f"{j:>6}" for j in range(10)) + "      total")
for i in range(10):
    fila = "".join(f"{M[i,j]:>6}" if i != j else f"\033[1m{M[i,j]:>6}\033[0m" for j in range(10))
    print(f"  {i} |{fila}   {M[i].sum():>6}")

# --- por clase ---
print("\n            exhaustividad   precision   apoyo")
for i in range(10):
    rec = M[i, i] / M[i].sum()
    pre = M[i, i] / M[:, i].sum() if M[:, i].sum() else 0
    print(f"  digito {i}:      {rec:>7.1%}     {pre:>7.1%}  {M[i].sum():>6}")

# --- los peores pares ---
print("\nlos 8 pares que mas se confunden:")
pares = [(M[i, j], i, j) for i in range(10) for j in range(10) if i != j]
for n, i, j in sorted(pares, reverse=True)[:8]:
    print(f"   {i} leido como {j}: {n:>4}  ({n/M[i].sum():.1%} de los {i})")

np.savez("confusion.npz", M=M, acc_tr=acc_tr, acc_te=acc_te, pte=pte, yte=yte)
print("\n-> confusion.npz")
