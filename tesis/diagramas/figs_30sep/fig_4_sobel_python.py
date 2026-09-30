# fig_4_sobel_python.py — copia de la celda 42 de TTY_Filter_Sobel.ipynb con rótulos en español.
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import numpy as np
import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt
from scipy.ndimage import convolve
from _base_cuaderno1 import MU5_IMGS, MU5_NOMBRES, preprocess, Gx, Gy, FIGURAS

def sobel(im_u8):
    f  = im_u8.astype(float)
    gx = convolve(f, Gx, mode="reflect")
    gy = convolve(f, Gy, mode="reflect")
    mag = np.abs(gx) + np.abs(gy)
    mag_sat = np.clip(mag, 0, 255).astype(np.uint8)
    return gx, gy, mag_sat

titles = ["antes (original)", "|Gx| horizontal", "|Gy| vertical", "después: Sobel |Gx|+|Gy|"]
fig, ax = plt.subplots(5, 4, figsize=(20, 4.5*5))
for row, (name, img) in enumerate(zip(MU5_NOMBRES, MU5_IMGS)):
    u8 = preprocess(img, sigma=1.0)
    gx, gy, mag = sobel(u8)
    panels = [(u8, "gray", {}), (np.abs(gx), "magma", {}),
              (np.abs(gy), "magma", {}), (mag, "gray", dict(vmin=0, vmax=255))]
    for col, (d, cm, kw) in enumerate(panels):
        a = ax[row, col]; a.imshow(d, cmap=cm, **kw); a.axis("off")
        a.set_title(f"{name}, {titles[col]}" if col in (0, 3) else titles[col], fontsize=13)
plt.tight_layout()
fig.savefig(os.path.join(FIGURAS, "fig_4_sobel_python.jpg"), dpi=80, bbox_inches="tight")
