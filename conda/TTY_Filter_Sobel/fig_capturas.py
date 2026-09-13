# === Cuaderno 2 · figura 4: lo que la placa capturo de verdad, y la costura ===
import numpy as np, matplotlib.pyplot as plt

cond = [("pareja", 1), ("lateral", 2), ("penumbra", 3)]
S = {n: np.load(f"/Users/vic/luz{i}_{n}.npz")["imgs"].astype(float) for n, i in cond}

fig = plt.figure(figsize=(13, 6.4))
gs = fig.add_gridspec(3, 7, width_ratios=[1]*5 + [0.25, 1.6], hspace=.35, wspace=.25)
for r, (n, _) in enumerate(cond):
    A = S[n]
    for c, k in enumerate(np.linspace(0, len(A)-1, 5).astype(int)):
        a = fig.add_subplot(gs[r, c])
        a.imshow(A[k], cmap="gray", vmin=0, vmax=255); a.axis("off")
        if c == 0:
            a.text(-6, 14, n, rotation=90, va="center", ha="center", fontsize=9.5)
        a.set_title(f"#{k}", fontsize=7)

# la costura: donde salta el brillo entre filas consecutivas
a = fig.add_subplot(gs[:, 6])
for n, _ in cond:
    A = S[n]
    filas = [int(np.abs(np.diff(A[k].mean(axis=1))).argmax()) for k in range(len(A))]
    a.plot(filas, np.arange(len(filas)), "o", ms=3.5, alpha=.65, label=n)
a.set_xlabel("fila donde cae la costura"); a.set_ylabel("nº de captura")
a.set_xlim(-1, 28); a.grid(alpha=.3); a.legend(fontsize=8)
a.set_title("La costura SE MUEVE\ncaptura a captura", fontsize=10)
fig.suptitle("169 capturas reales de la iCE40 · el cuadro no está enganchado al sensor",
             fontsize=11.5, y=.99)
plt.savefig("fig_capturas.png", dpi=140, bbox_inches="tight")
plt.show()
for n, _ in cond:
    A = S[n]
    f = [int(np.abs(np.diff(A[k].mean(axis=1))).argmax()) for k in range(len(A))]
    print(f"  {n:<9} {len(A):3d} capturas · media {A.mean():5.1f} · "
          f"costura en {len(set(f)):2d} filas distintas: {sorted(set(f))[:8]}...")
