# fig_4_trans_python.py — copia de la celda 67 de TTY_Filter_Sobel.ipynb con rótulos en español.
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import numpy as np
import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt
from scipy.ndimage import convolve, label, binary_dilation
from _base_cuaderno1 import sources, prep_work, Gx, Gy, FIGURAS

def binomial2d(coeffs):
    v = np.array(coeffs, float); K = np.outer(v, v); return K / K.sum()
GK3 = binomial2d([1, 2, 1])

def nms_strong_weak(work, lo_p=70, hi_p=90):
    f = work.astype(float); sm = convolve(f, GK3, mode="reflect")
    gx = convolve(sm, Gx, mode="reflect"); gy = convolve(sm, Gy, mode="reflect")
    mag = np.hypot(gx, gy); ang = np.rad2deg(np.arctan2(gy, gx)) % 180
    nms = np.zeros_like(mag); M, Nn = mag.shape
    for i in range(1, M-1):
        for j in range(1, Nn-1):
            a = ang[i, j]
            if   a < 22.5 or a >= 157.5: q, r = mag[i, j+1],  mag[i, j-1]
            elif a < 67.5:               q, r = mag[i+1, j-1], mag[i-1, j+1]
            elif a < 112.5:              q, r = mag[i+1, j],   mag[i-1, j]
            else:                        q, r = mag[i-1, j-1], mag[i+1, j+1]
            if mag[i, j] >= q and mag[i, j] >= r: nms[i, j] = mag[i, j]
    nz = nms[nms > 0]; hi, lo = np.percentile(nz, hi_p), np.percentile(nz, lo_p)
    return nms >= hi, (nms >= lo) & (nms < hi)

def hyst_full(strong, weak):
    lbl, _ = label(weak | strong); keep = set(np.unique(lbl[strong])) - {0}
    return np.isin(lbl, list(keep))

def hyst_1hop(strong, weak):
    return strong | (weak & binary_dilation(strong, iterations=1))

work = prep_work(sources[1]); s, w = nms_strong_weak(work)     # monarca
f1, h1 = hyst_full(s, w), hyst_1hop(s, w); diff = f1 ^ h1
print(f"concordancia un salto vs completa: {100*(f1==h1).mean():.2f} %")
fig, ax = plt.subplots(1, 4, figsize=(22, 6))
panels = [("supresión de no máximos: fuertes + débiles", s.astype(int)+w.astype(int)),
          ("histéresis completa (transitiva)", f1),
          ("histéresis de un salto", h1), ("diferencia", diff)]
for a, (t, im) in zip(ax, panels):
    a.imshow(im, cmap="gray"); a.set_title(t, fontsize=13); a.axis("off")
plt.tight_layout()
fig.savefig(os.path.join(FIGURAS, "fig_4_trans_python.png"), dpi=68, bbox_inches="tight")
