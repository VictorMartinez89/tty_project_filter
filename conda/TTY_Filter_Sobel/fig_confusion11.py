# === Cuaderno 2 · figura 2: la matriz de 11 clases (NADA + 0..9) con front-end Canny ===
import numpy as np, matplotlib.pyplot as plt

d = np.load("../../clasificador_mnist/canny1_completo.npz")
M, y, p, v = d["M11"], d["yte"], d["pte"], d["val"]
cob, prec = float(d["cob"]), float(d["prec"])

fig, (a1, a2) = plt.subplots(1, 2, figsize=(13, 5.2),
                             gridspec_kw={"width_ratios": [1.35, 1]})
Mn = M / M.sum(1, keepdims=True) * 100
im = a1.imshow(Mn, cmap="Blues", vmin=0, vmax=100)
for i in range(10):
    for j in range(11):
        if M[i, j]:
            a1.text(j, i, M[i, j], ha="center", va="center", fontsize=7.6,
                    color="w" if Mn[i, j] > 55 else "#222")
a1.set_xticks(range(11)); a1.set_xticklabels(list("0123456789") + ["NADA"], fontsize=8.5)
a1.set_yticks(range(10)); a1.set_yticklabels(range(10), fontsize=8.5)
a1.set_xlabel("lo que dijo el circuito"); a1.set_ylabel("lo que era")
a1.axvline(9.5, c="#c62828", lw=2)
a1.set_title(f"Matriz de 11 clases · front-end Canny 1-salto\n"
             f"cobertura {cob:.1%} · precisión al hablar {prec:.1%}", fontsize=10.5)
plt.colorbar(im, ax=a1, fraction=.045, label="% de la fila")

# precision / recall por clase, solo sobre lo que el circuito acepta contestar
P, R = np.zeros(10), np.zeros(10)
for c in range(10):
    VP = M[c, c]; FN = M[c, :].sum() - VP; FP = M[:, c].sum() - VP
    P[c] = VP / (VP + FP) if VP + FP else 0
    R[c] = VP / (VP + FN)
a2.scatter(R * 100, P * 100, s=95, c="#1565c0", zorder=3)
for c in range(10):
    a2.annotate(str(c), (R[c] * 100, P[c] * 100), fontsize=12, weight="bold",
                xytext=(7, -4), textcoords="offset points")
a2.set_xlabel("recall  %  (incluye lo que se calló)")
a2.set_ylabel("precisión  %  (de lo que dijo)")
a2.set_title("Cada dígito, con la clase NADA activa\nel recall baja porque callarse cuenta como no encontrar",
             fontsize=10.5)
a2.grid(alpha=.3, zorder=0)
plt.tight_layout()
plt.savefig("fig_confusion11.png", dpi=150)
plt.show()
print(f"aciertos entre los aceptados: {np.trace(M[:, :10])}/{M[:, :10].sum()} = {prec:.2%}")
print(f"cuadros en los que se callo: {M[:, 10].sum()}/{M.sum()} = {M[:,10].sum()/M.sum():.2%}")
