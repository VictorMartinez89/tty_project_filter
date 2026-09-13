# === Cuaderno 2 · figura 5: Sobel vs Canny sobre capturas REALES de la placa ===
import numpy as np, matplotlib.pyplot as plt
d = np.load("../../clasificador_mnist/experimento_luz.npz")
cond = ["pareja", "lateral", "penumbra"]

fig, ax = plt.subplots(3, 3, figsize=(9.5, 9.2))
for c, n in enumerate(cond):
    ax[0, c].imshow(d[f"img_{n}"], cmap="gray", vmin=0, vmax=255)
    ax[0, c].set_title(f"{n}\ncaptura de la placa", fontsize=9)
    ax[1, c].imshow(d[f"Sobel_{n}"], cmap="gray")
    ax[1, c].set_title(f"Sobel · {d[f'Sobel_{n}'].mean():.0%} bordes", fontsize=9)
    ax[2, c].imshow(d[f"Canny1_{n}"], cmap="gray")
    ax[2, c].set_title(f"Canny1 · {d[f'Canny1_{n}'].mean():.0%} bordes", fontsize=9)
for a in ax.ravel(): a.axis("off")
ax[0, 0].text(-4, 14, "imagen", rotation=90, va="center", ha="center", fontsize=10)
ax[1, 0].text(-4, 11, "Sobel", rotation=90, va="center", ha="center", fontsize=10)
ax[2, 0].text(-4, 11, "Canny1", rotation=90, va="center", ha="center", fontsize=10)
fig.suptitle("La misma escena bajo tres luces, y lo que ve cada filtro\n"
             "(umbrales calibrados para la MISMA densidad de bordes en la referencia)",
             fontsize=11, y=.985)
plt.tight_layout(rect=[0, 0, 1, .96])
plt.savefig("fig_luz_real.png", dpi=140)
plt.show()

def jac(a, b):
    u = (a | b).sum()
    return (a & b).sum()/u if u else float("nan")
print("consistencia del mapa de bordes entre condiciones (Jaccard):")
for a, b in [("pareja","lateral"), ("pareja","penumbra"), ("lateral","penumbra")]:
    s = jac(d[f"Sobel_{a}"], d[f"Sobel_{b}"]); c = jac(d[f"Canny1_{a}"], d[f"Canny1_{b}"])
    val = "" if a == "pareja" and b == "lateral" else "   (escena distinta: no cuenta)"
    print(f"  {a:>8} vs {b:<9} Sobel {s:6.1%}   Canny {c:6.1%}   dif {c-s:+6.1%}{val}")
