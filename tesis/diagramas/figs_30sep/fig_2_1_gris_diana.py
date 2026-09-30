# fig_2_1_gris_diana.py — copia de la celda 60 de TTY_Filter_Sobel.ipynb con rótulos en español.
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import numpy as np
import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt
from skimage import io, transform
from _base_cuaderno1 import DIANA_TEST, FIGURAS

def gray_hw(rgb):    # = (red>>2)+(red>>5)+(green>>1)+(green>>4)+(blue>>4)+(blue>>5)
    R, G, B = rgb[...,0].astype(int), rgb[...,1].astype(int), rgb[...,2].astype(int)
    return np.clip((R>>2)+(R>>5)+(G>>1)+(G>>4)+(B>>4)+(B>>5), 0, 255)

rgb = (transform.resize(io.imread(DIANA_TEST + "/flower_RGB.jpg")[..., :3], (240, 320),
                        anti_aliasing=True) * 255).astype(int)
g_hw    = gray_hw(rgb)
g_exact = np.clip(0.299*rgb[...,0] + 0.587*rgb[...,1] + 0.114*rgb[...,2], 0, 255)

fig, ax = plt.subplots(1, 3, figsize=(18, 6))
ax[0].imshow(rgb.astype(np.uint8));                   ax[0].set_title("RGB original");                        ax[0].axis("off")
ax[1].imshow(g_hw,    cmap="gray", vmin=0, vmax=255); ax[1].set_title("gris del hardware (>> y +)");          ax[1].axis("off")
ax[2].imshow(g_exact, cmap="gray", vmin=0, vmax=255); ax[2].set_title("gris exacto (con multiplicaciones)");  ax[2].axis("off")
plt.suptitle("Gris de Maldonado: solo desplazamientos y sumas, sin multiplicador", fontsize=14)
plt.tight_layout()
fig.savefig(os.path.join(FIGURAS, "fig_2_1_gris_diana.jpg"), dpi=89, bbox_inches="tight")
