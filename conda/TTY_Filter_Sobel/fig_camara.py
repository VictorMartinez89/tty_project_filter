# === Cuaderno 2 · figura 3: ¿el doble umbral aguanta lo que hace la cámara? ===
# Entrenado UNA vez sobre MNIST limpio (como los pesos grabados en la ROM), evaluado sobre
# imágenes degradadas. Si la histéresis sirve para algo, tiene que notarse acá y no en el limpio.
import numpy as np, matplotlib.pyplot as plt

d = np.load("../../clasificador_mnist/canny1_camara.npz")
cl = [k.split("|") for k in d["claves"]]
modos = ["gradiente", "contraste", "desenfoque", "ruido"]
tit = {"gradiente": "Iluminación despareja\n(rampa multiplicativa)",
       "contraste": "Contraste bajo\n(el trazo no llega a blanco)",
       "desenfoque": "Desenfoque\n(la lente a 10 cm)",
       "ruido": "Ruido del sensor\n(poca luz)"}

fig, ax = plt.subplots(1, 4, figsize=(14.5, 3.9), sharey=True)
for a, m in zip(ax, modos):
    i = [k for k, (mm, _) in enumerate(cl) if mm == m]
    s = np.array([float(cl[k][1]) for k in i])
    so, ca = d["sobel"][i] * 100, d["canny"][i] * 100
    o = np.argsort(s); s, so, ca = s[o], so[o], ca[o]
    a.plot(s, so, "o-", c="#546e7a", lw=2, ms=6, label="Sobel  thr=110")
    a.plot(s, ca, "s-", c="#2e7d32", lw=2, ms=6, label="Canny1  110/40")
    a.fill_between(s, so, ca, where=(ca >= so), color="#2e7d32", alpha=.15)
    a.fill_between(s, so, ca, where=(ca < so), color="#c62828", alpha=.15)
    dmax = (ca - so).max()
    a.set_title(f"{tit[m]}\nmáx. ventaja del Canny: {dmax:+.1f} pp",
                fontsize=9, color="#2e7d32" if dmax > 2 else "#444")
    a.set_xlabel("severidad de la degradación"); a.grid(alpha=.3)
ax[0].set_ylabel("precisión sobre las 10 000 de test  %")
ax[0].legend(fontsize=8.5, loc="lower left")
fig.suptitle("Entrenado sobre MNIST limpio, evaluado sobre imágenes degradadas: "
             "el desplazamiento de dominio de la Parte 181, graduado",
             fontsize=10.5, y=1.04)
plt.tight_layout()
plt.savefig("fig_camara.png", dpi=150, bbox_inches="tight")
plt.show()
for m in modos:
    i = [k for k, (mm, _) in enumerate(cl) if mm == m]
    print(f"  {m:<11} Sobel {d['sobel'][i].min():.1%}..{d['sobel'][i].max():.1%}   "
          f"Canny {d['canny'][i].min():.1%}..{d['canny'][i].max():.1%}   "
          f"ventaja max {(d['canny'][i]-d['sobel'][i]).max():+.2%}")
