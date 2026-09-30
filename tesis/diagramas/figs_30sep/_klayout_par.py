# Utilidad común: dos capturas de KLayout lado a lado, cada una con su título corto.
# Las capturas base están en conda/TTY_Filter_Sobel/img/ (las mismas que usan las celdas del cuaderno).
import os
import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt, matplotlib.image as mpimg

AQUI = os.path.dirname(os.path.abspath(__file__))
IMG = os.path.join(AQUI, "..", "..", "..", "conda", "TTY_Filter_Sobel", "img")
FIG = os.path.join(AQUI, "..", "..", "figuras")


def par(izq, der, tit_izq, tit_der, salida, ancho_px=1600, dpi=100, fs=9.5):
    a, b = mpimg.imread(os.path.join(IMG, izq)), mpimg.imread(os.path.join(IMG, der))
    h, w = a.shape[:2]
    alto_px = ancho_px / 2 * h / w + 30
    fig, ax = plt.subplots(1, 2, figsize=(ancho_px / dpi, alto_px / dpi), dpi=dpi)
    for x, im, t in zip(ax, (a, b), (tit_izq, tit_der)):
        x.imshow(im); x.axis("off"); x.set_title(t, fontsize=fs, fontweight="bold", pad=4)
    fig.subplots_adjust(left=0.003, right=0.997, bottom=0.003, top=1 - 26 / alto_px, wspace=0.02)
    fig.savefig(os.path.join(FIG, salida), dpi=dpi, pil_kwargs={"quality": 92})
    print("  ->", salida)


def una(img, titulo, salida, figsize, dpi=None, fs=11):
    fig, ax = plt.subplots(figsize=figsize)
    ax.imshow(mpimg.imread(os.path.join(IMG, img))); ax.axis("off")
    ax.set_title(titulo, fontsize=fs, fontweight="bold")
    plt.tight_layout()
    fig.savefig(os.path.join(FIG, salida), dpi=dpi or fig.dpi, bbox_inches="tight",
                pil_kwargs={"quality": 92})
    print("  ->", salida)
