# === Cuaderno 2 · figura 1: Sobel y Canny 1-salto sobre el mismo dígito ===
import sys; sys.path.insert(0, "../../clasificador_mnist")
import numpy as np, matplotlib.pyplot as plt
import frente_golden as fg
from canny1_mnist import frente_canny1

_, _, Xte, yte = fg.cargar_mnist("../../clasificador_mnist/mnist.npz")
n = 0
img = Xte[n]
g  = np.floor(fg.conv3(img[None].astype(float), fg.GAUSS) / 16.0)
gx = fg.conv3(g, fg.SOBEL_X); gy = fg.conv3(g, fg.SOBEL_Y)
mag = np.minimum(np.abs(gx) + np.abs(gy), 255.0)[0]
cls = np.where(mag > 110, 2, np.where(mag > 40, 1, 0))
sob = fg.frente(img, 110)[0][0]
can = frente_canny1(img, 110, 40)[0][0]

fig, ax = plt.subplots(1, 5, figsize=(13, 3.1))
for a, (im, t, cm) in zip(ax, [
        (img,  f"entrada 28×28\n(dígito {yte[n]})", "gray"),
        (mag,  "magnitud |Gx|+|Gy|\n24×24", "magma"),
        (cls,  "clases del doble umbral\n2=fuerte 1=débil 0=plano", "viridis"),
        (sob,  "Sobel  thr=110\n24×24 · un umbral", "gray"),
        (can,  "Canny 1-salto  110/40\n22×22 · + histéresis", "gray")]):
    a.imshow(im, cmap=cm); a.set_title(t, fontsize=8.6); a.axis("off")
fig.suptitle("El mismo dígito por los dos front-ends: el Canny recupera trazo débil que continúa "
             "a uno fuerte,\ny paga con una fila y una columna menos por cada lado (tercera ventana 3×3)",
             fontsize=9.5, y=1.06)
plt.tight_layout()
plt.savefig("fig_filtros.png", dpi=150, bbox_inches="tight")
plt.show()
print(f"bordes marcados — Sobel: {sob.sum():4d}/{sob.size}  ({sob.mean():.1%})")
print(f"                  Canny: {can.sum():4d}/{can.size}  ({can.mean():.1%})")
