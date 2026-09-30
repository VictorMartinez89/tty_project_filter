# _base_rtl_montaje.py — copia de ~/utm-share/sim_sobel/render.py y sim_canny/render_{canny,trans}.py
# (sin el título interno y con rótulos en español). Lee los .hex/.png de la share; no los modifica.
import os, re, numpy as np
import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt
from PIL import Image

W, H = 60, 80
SHARE = "/Users/vic/utm-share"
FIGURAS = "/Users/vic/UN/Tesis/Repository/tty_project_filter/tesis/figuras"
NAMES = ["flower", "monarch", "butterfly", "mano", "hi"]
NICE = {"flower": "flor", "monarch": "monarca", "butterfly": "mariposa", "mano": "mano", "hi": "HOLA"}

def load_hex(path):
    v = []
    for line in open(path):
        line = line.split('//')[0]
        for t in line.split():
            if re.fullmatch(r'[0-9a-fA-F]{1,2}', t): v.append(int(t, 16))
            elif re.fullmatch(r'[xXzZ]{1,2}', t):    v.append(0)
    while len(v) < W*H: v.append(0)
    return np.array(v[:W*H], np.uint8).reshape(H, W)

def load_png(path):
    return np.asarray(Image.open(path).convert("L").resize((W, H)), np.uint8)

def montaje(dirsim, gold_fmt, core_fmt, cam_fmt, salida, core_override=None):
    core_override = core_override or {}
    fig, ax = plt.subplots(len(NAMES), 4, figsize=(11, 2.3*len(NAMES)))
    for r, n in enumerate(NAMES):
        inp  = load_png(os.path.join(SHARE, "sim_sobel", "out", f"{n}_in.png"))
        gold = load_hex(os.path.join(SHARE, dirsim, "hex", gold_fmt.format(n)))
        core = load_hex(core_override.get(n, os.path.join(SHARE, dirsim, "out", core_fmt.format(n))))
        cam  = load_hex(os.path.join(SHARE, dirsim, "out", cam_fmt.format(n)))
        print(f"{n:10s} núcleo == modelo: {np.array_equal(core, gold)}")
        for c, (img, ttl) in enumerate([
                (inp, "entrada 60×80"), (gold, "modelo (ref.)"),
                (core, "núcleo RTL"),   (cam, "cámara RTL")]):
            ax[r, c].imshow(img, cmap="gray", vmin=0, vmax=255)
            ax[r, c].set_xticks([]); ax[r, c].set_yticks([])
            if r == 0: ax[r, c].set_title(ttl, fontsize=11)
            if c == 0: ax[r, c].set_ylabel(NICE[n], fontsize=11)
    fig.tight_layout()
    fig.savefig(os.path.join(FIGURAS, salida), dpi=109, bbox_inches="tight")
