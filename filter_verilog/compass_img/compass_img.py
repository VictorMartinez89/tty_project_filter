"""compass_img.py — el Sobel compass (8 direcciones) sobre las cinco imagenes de prueba.

   python compass_img.py golden   -> hex/<img>.hex, hex/<img>_exp.hex y la figura de Python
   python compass_img.py rtl      -> lee out/<img>_rtl.hex (del simulador), compara bit a bit
                                     y arma la figura del RTL

   Dos modelos, a proposito distintos:
   * el de la Parte 12.B del cuaderno 1 (flotante, convolucion con reflejo, raiz real): es la
     figura «Python», 8 direcciones x 5 imagenes x [Compass, sqrt(Gx^2+Gy^2)] = 80 paneles;
   * el ENTERO, que es lo que calcula sobel_compass_core: correlacion en la zona interior,
     |g| saturado a 8 bits, magnitud compass = la mayor de las 8, direccion = la primera que la
     alcanza (0=N .. 7=NW). Es el golden contra el que se compara el RTL bit a bit.
"""
import os, sys
import numpy as np
import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt
from skimage import io, color, util, transform, filters
from scipy.ndimage import convolve

AQUI = os.path.dirname(os.path.abspath(__file__))
NB = os.path.join(AQUI, "..", "..", "conda", "TTY_Filter_Sobel")
DIANA = "/Users/vic/UN/Tesis/Repository/tt06_grayscale_sobel/test"
H, W = 120, 160
IMGS = [("monarch", f"{DIANA}/monarch_RGB.jpg"), ("flower", f"{DIANA}/flower_RGB.jpg"),
        ("butterfly", f"{DIANA}/butterfly_640x480.jpg"), ("hand", f"{NB}/img/mi_mano.png"),
        ("hi", f"{NB}/img/hi.jpeg")]
DIRS = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
KER = {"N": [[1, 2, 1], [0, 0, 0], [-1, -2, -1]], "NE": [[2, 1, 0], [1, 0, -1], [0, -1, -2]],
       "E": [[1, 0, -1], [2, 0, -2], [1, 0, -1]], "SE": [[0, -1, -2], [1, 0, -1], [2, 1, 0]]}
for a, b in (("S", "N"), ("SW", "NE"), ("W", "E"), ("NW", "SE")):
    KER[a] = (-np.array(KER[b])).tolist()
GX = np.array([[-1, 0, 1], [-2, 0, 2], [-1, 0, 1]], float)
GY = np.array([[-1, -2, -1], [0, 0, 0], [1, 2, 1]], float)
FIG = os.path.join(AQUI, "..", "..", "tesis", "figuras")


def cargar(ruta):
    """gris -> recorte central 4:3 -> 160x120 -> gauss sigma=1 -> 8 bits (el preprocess del cuaderno)"""
    im = io.imread(ruta)
    if im.ndim == 3:
        im = color.rgb2gray(im[..., :3])
    im = util.img_as_float(im)
    h, w = im.shape
    if w * 3 > h * 4:                       # demasiado ancha: recortar columnas
        nw = h * 4 // 3; im = im[:, (w - nw) // 2:(w - nw) // 2 + nw]
    else:                                   # demasiado alta (la mano): recortar filas
        nh = w * 3 // 4; im = im[(h - nh) // 2:(h - nh) // 2 + nh, :]
    im = transform.resize(im, (H, W), anti_aliasing=True)
    im = filters.gaussian(im, sigma=1.0)
    im = (im - im.min()) / (np.ptp(im) + 1e-9)
    return (im * 255.0).astype(np.uint8)


def modelo_entero(u8):
    """lo que calcula sobel_compass_core en cada pixel interior (correlacion, sin reflejo)"""
    p = u8.astype(np.int32)
    win = [p[r:r + H - 2, c:c + W - 2] for r in range(3) for c in range(3)]   # p0..p8
    g = {}
    for d in DIRS:
        k = np.array(KER[d]).ravel()
        g[d] = sum(int(k[i]) * win[i] for i in range(9))
    a = np.stack([np.abs(g[d]) for d in DIRS])                 # (8, H-2, W-2)
    mags = np.minimum(a, 255)
    mag = np.minimum(a.max(0), 255)
    drc = a.argmax(0)                                          # primera que alcanza el maximo
    s2 = g["E"].astype(np.int64) ** 2 + g["N"].astype(np.int64) ** 2   # Gx = gE, Gy = gN
    eu = np.floor(np.sqrt(s2)).astype(np.int64)                # floor(sqrt), = isqrt.sv
    eu -= (eu * eu > s2); eu += ((eu + 1) ** 2 <= s2)          # por si el flotante redondea
    return mags, mag, drc, eu


def fig_grid(paneles, titulo_col, nombre, cmaps):
    """8 filas (direcciones) x 10 columnas (5 imagenes x 2 operaciones)"""
    fig, ax = plt.subplots(8, 10, figsize=(20, 12.6))
    for r, d in enumerate(DIRS):
        for c in range(10):
            a = ax[r, c]
            a.imshow(paneles[r][c], cmap=cmaps[c % 2])
            a.set_xticks([]); a.set_yticks([])
            if r == 0:
                a.set_title(titulo_col[c], fontsize=11)
            if c == 0:
                a.set_ylabel(d, fontsize=13, rotation=0, labelpad=18, va="center")
    plt.subplots_adjust(left=0.03, right=0.995, top=0.965, bottom=0.005, wspace=0.04, hspace=0.06)
    fig.savefig(nombre, dpi=90, pil_kwargs={"quality": 88}); plt.close(fig)
    print("  figura:", nombre)


def golden():
    os.makedirs(os.path.join(AQUI, "hex"), exist_ok=True)
    paneles = [[None] * 10 for _ in DIRS]
    tit = []
    for i, (n, ruta) in enumerate(IMGS):
        u8 = cargar(ruta)
        with open(f"{AQUI}/hex/{n}.hex", "w") as f:
            f.write("\n".join(f"{v:02x}" for v in u8.ravel()) + "\n")
        mags, mag, drc, eu = modelo_entero(u8)
        with open(f"{AQUI}/hex/{n}_exp.hex", "w") as f:
            for rr in range(H - 2):
                for cc in range(W - 2):
                    m8 = "".join(f"{mags[k, rr, cc]:02x}" for k in reversed(range(8)))   # NW..N
                    f.write(f"{m8}{mag[rr, cc]:02x}{drc[rr, cc]:01x}{eu[rr, cc]:03x}\n")
        np.save(f"{AQUI}/hex/{n}_u8.npy", u8)
        # figura Python: el modelo del cuaderno (flotante, reflejo, raiz real)
        base = u8.astype(float)
        raiz = np.sqrt(convolve(base, GX, mode="reflect") ** 2 + convolve(base, GY, mode="reflect") ** 2)
        for r, d in enumerate(DIRS):
            paneles[r][2 * i] = np.abs(convolve(base, np.array(KER[d], float), mode="reflect"))
            paneles[r][2 * i + 1] = raiz
        tit += [f"{n}: compass", f"{n}: √(Gx²+Gy²)"]
        print(f"  {n:10s} {W}x{H}  golden: {(H-2)*(W-2)} pixeles interiores")
    fig_grid(paneles, tit, f"{FIG}/fig_4_compass_python.jpg", ["inferno", "gray"])


def rtl():
    paneles = [[None] * 10 for _ in DIRS]
    tit = []; total = 0; iguales = 0
    for i, (n, _) in enumerate(IMGS):
        exp = [l.split()[0] for l in open(f"{AQUI}/hex/{n}_exp.hex")]
        out = [l.split() for l in open(f"{AQUI}/out/{n}_rtl.hex")]
        got = [f"{a}{b}{int(c):01x}{e}" for a, b, c, e in out]
        ok = sum(1 for x, y in zip(exp, got) if x == y) if len(exp) == len(got) else 0
        total += len(exp); iguales += ok
        print(f"  {n:10s} RTL vs golden entero: {ok}/{len(exp)} identicos")
        m8 = np.array([[int(a[2 * k:2 * k + 2], 16) for k in range(8)] for a, _, _, _ in out])  # NW..N
        m8 = m8[:, ::-1].reshape(H - 2, W - 2, 8)                                           # N..NW
        mag = np.array([int(b, 16) for _, b, _, _ in out]).reshape(H - 2, W - 2)
        drc = np.array([int(c) for _, _, c, _ in out]).reshape(H - 2, W - 2)
        eu = np.array([int(e, 16) for _, _, _, e in out]).reshape(H - 2, W - 2)
        np.save(f"{AQUI}/out/{n}_mag.npy", mag)
        np.save(f"{AQUI}/out/{n}_dir.npy", drc)
        for r, d in enumerate(DIRS):
            paneles[r][2 * i] = m8[:, :, r]
            paneles[r][2 * i + 1] = eu
        tit += [f"{n}: compass", f"{n}: √(Gx²+Gy²)"]
    print(f"  TOTAL: {iguales}/{total} pixeles identicos (8 magnitudes + compass + direccion + euclidea)")
    fig_grid(paneles, tit, f"{FIG}/fig_4_compass_rtl.jpg", ["inferno", "gray"])
    # mapa de direccion: la salida dir_o a color, sobre la magnitud
    import matplotlib.colors as mc
    fig, ax = plt.subplots(1, 5, figsize=(20, 3.6))
    # |S|=|N|, |SW|=|NE|, |W|=|E|, |NW|=|SE| y el argmax se queda con la PRIMERA: dir_o solo vale 0..3
    PAL = np.array([[1.0, 0.15, 0.1], [1.0, 0.8, 0.0], [0.1, 0.6, 1.0], [0.9, 0.2, 1.0]])
    hist = np.zeros(8, int)
    for i, (n, _) in enumerate(IMGS):
        drc = np.load(f"{AQUI}/out/{n}_dir.npy"); hist += np.bincount(drc.ravel(), minlength=8)
        mag = np.load(f"{AQUI}/out/{n}_mag.npy").astype(float) / 255.0
        rgb = PAL[np.minimum(drc, 3)] * np.clip(mag * 2.0, 0, 1)[..., None]
        ax[i].imshow(rgb); ax[i].set_title(f"{n}: dir_o", fontsize=13); ax[i].axis("off")
    print("  dir_o, pixeles por valor 0..7:", hist.tolist())
    manejas = [plt.Rectangle((0, 0), 1, 1, color=PAL[k]) for k in range(4)]
    fig.legend(manejas, ["N (y S)", "NE (y SW)", "E (y W)", "SE (y NW)"], loc="lower center", ncol=4,
               fontsize=12, frameon=False)
    plt.subplots_adjust(left=0.005, right=0.995, top=0.9, bottom=0.12, wspace=0.03)
    fig.savefig(f"{FIG}/fig_4_compass_dir.jpg", dpi=90, pil_kwargs={"quality": 88}); plt.close(fig)
    print("  figura:", f"{FIG}/fig_4_compass_dir.jpg")


if __name__ == "__main__":
    golden() if (len(sys.argv) < 2 or sys.argv[1] == "golden") else rtl()
