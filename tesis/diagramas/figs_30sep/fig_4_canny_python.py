# fig_4_canny_python.py — copia de la celda 52 de TTY_Filter_Sobel.ipynb con rótulos en español.
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import numpy as np
import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt
from scipy.ndimage import convolve, label
from _base_cuaderno1 import sources, prep_work, Gx, Gy, FIGURAS

GK = np.array([[1, 2, 1], [2, 4, 2], [1, 2, 1]], float) / 16.0

def canny_steps(img_u8, lo_p=70, hi_p=90):
    f = img_u8.astype(float)
    sm  = convolve(f, GK, mode="reflect")
    gx  = convolve(sm, Gx, mode="reflect")
    gy  = convolve(sm, Gy, mode="reflect")
    mag = np.hypot(gx, gy)
    ang = np.rad2deg(np.arctan2(gy, gx)) % 180
    nms = np.zeros_like(mag); M, Nn = mag.shape
    for i in range(1, M-1):
        for j in range(1, Nn-1):
            a = ang[i, j]
            if   a < 22.5 or a >= 157.5: q, r = mag[i, j+1],  mag[i, j-1]
            elif a < 67.5:               q, r = mag[i+1, j-1], mag[i-1, j+1]
            elif a < 112.5:              q, r = mag[i+1, j],   mag[i-1, j]
            else:                        q, r = mag[i-1, j-1], mag[i+1, j+1]
            if mag[i, j] >= q and mag[i, j] >= r:
                nms[i, j] = mag[i, j]
    nz = nms[nms > 0]
    hi, lo = np.percentile(nz, hi_p), np.percentile(nz, lo_p)
    strong = nms >= hi
    weak   = (nms >= lo) & (nms < hi)
    dthr = np.zeros_like(nms); dthr[weak] = 128; dthr[strong] = 255
    lbl, _ = label(weak | strong)
    keep = set(np.unique(lbl[strong])) - {0}
    final = np.isin(lbl, list(keep))
    return {"1 gaussiano 3×3": sm, "2 magnitud del gradiente |G|": mag,
            "3 supresión de no máximos": nms, "4 doble umbral": dthr,
            "5 histéresis (final)": final}

img = prep_work(sources[0])      # flor
panels = [("0 original", img)] + list(canny_steps(img).items())
fig, ax = plt.subplots(2, 3, figsize=(20, 10))
for a, (title, d) in zip(ax.ravel(), panels):
    a.imshow(d, cmap="gray"); a.set_title(title, fontsize=12); a.axis("off")
plt.tight_layout()
fig.savefig(os.path.join(FIGURAS, "fig_4_canny_python.png"), dpi=75, bbox_inches="tight")
