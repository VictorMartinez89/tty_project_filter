# _base_cuaderno1.py — estado mínimo del cuaderno TTY_Filter_Sobel.ipynb (celdas 34, 36, 40,
# 42 y 52) copiado tal cual, para regenerar sus figuras fuera del cuaderno. No lo modifica.
import os, warnings
import numpy as np
from skimage import color, io, transform, util, filters
from scipy.ndimage import convolve
warnings.filterwarnings("ignore")

REPO = "/Users/vic/UN/Tesis/Repository/tty_project_filter"
NB_DIR = os.path.join(REPO, "conda", "TTY_Filter_Sobel")
FIGURAS = os.path.join(REPO, "tesis", "figuras")
DIANA_TEST = "/Users/vic/UN/Tesis/Repository/tt06_grayscale_sobel/test"

def load_gray(src):
    img = io.imread(src) if isinstance(src, str) else src
    if img.ndim == 3 and img.shape[2] >= 3:
        img = color.rgb2gray(img[..., :3])
    return util.img_as_float(img).astype(np.float32)

diana_files = ["flower_RGB.jpg", "monarch_RGB.jpg", "butterfly_640x480.jpg"]
sources = [load_gray(os.path.join(DIANA_TEST, f)) for f in diana_files]
mano_src = load_gray(os.path.join(NB_DIR, "img", "mi_mano.png"))
hi_src = load_gray(os.path.join(NB_DIR, "img", "hi.jpeg"))
MU5_IMGS = sources[:3] + [mano_src, hi_src]
# nombres en español para los rótulos
MU5_NOMBRES = ["flor", "monarca", "mariposa", "mano", "HOLA"]

def to_uint8(im):
    im = (im - im.min()) / (np.ptp(im) + 1e-9)
    return (im * 255.0).astype(np.uint8)

def preprocess(im, sigma=1.0):
    return to_uint8(filters.gaussian(im, sigma=sigma))

Gx = np.array([[-1, 0, 1], [-2, 0, 2], [-1, 0, 1]], dtype=float)
Gy = np.array([[-1, -2, -1], [0, 0, 0], [1, 2, 1]], dtype=float)

WORK = (240, 320)
def prep_work(img):
    return to_uint8(transform.resize(img, WORK, anti_aliasing=True))
