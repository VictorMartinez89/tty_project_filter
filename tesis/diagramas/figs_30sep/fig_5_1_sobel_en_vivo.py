# figs_30sep/fig_5_1_sobel_en_vivo.py — copia de la celda «Parte 25.A» de TTY_Filter_Sobel.ipynb
# (filtro Sobel en vivo en la iCESugar, 6 fotos de la pantalla), SIN el título grande interno
# (el pie de la tesis ya lo describe y se montaba sobre los rótulos) y con «mano» en vez de «mano (hand)».
# flower / monarch / butterfly se dejan: son los nombres de las imágenes de prueba que usa el texto.
import os
import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt, matplotlib.image as mpimg
AQUI = os.path.dirname(os.path.abspath(__file__))
IMG = os.path.join(AQUI, "..", "..", "..", "conda", "TTY_Filter_Sobel", "img")
panels = [("hw_sobel_flower.png", "flower"),     ("hw_sobel_monarch.png", "monarch"),
          ("hw_sobel_butterfly.png", "butterfly"), ("hw_sobel_mano.png", "mano"),
          ("hw_sobel_ho.png", "HO"),              ("hw_sobel_la.png", "LA")]
fig, ax = plt.subplots(2, 3, figsize=(12, 10))
for a, (f, t) in zip(ax.ravel(), panels):
    a.imshow(mpimg.imread(os.path.join(IMG, f))); a.set_title(t, fontsize=13); a.axis("off")
plt.tight_layout()
fig.savefig(os.path.join(AQUI, "..", "..", "figuras", "fig_5_1_sobel_en_vivo.jpg"), dpi=85,
            bbox_inches="tight", pil_kwargs={"quality": 92})
print("  -> fig_5_1_sobel_en_vivo.jpg")
