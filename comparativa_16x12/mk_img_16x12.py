#!/usr/bin/env python3
# mk_img_16x12.py — prepara las 5 imagenes de la tesis a 16 filas x 12 columnas
# para el experimento 5x6 en simulacion Verilog.
#
#   img/<nombre>.hex   -> 192 bytes en hexadecimal (uno por linea), orden raster
#   img/<nombre>.png   -> vista previa ampliada, para el cuaderno
#
# Son las mismas cinco fuentes del experimento original de la tesis (Partes 29-35):
# tres de Diana (flower, monarch, butterfly) y dos propias (la mano y el "hi").
import os
import numpy as np
from PIL import Image

H, W = 16, 12
AQUI = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(AQUI, ".."))

FUENTES = {
    "flower":    "/Users/vic/UN/Tesis_Expermiento/flower_RGB.jpg",
    "monarch":   "/Users/vic/UN/Tesis_Expermiento/monarch_RGB.jpg",
    "butterfly": "/Users/vic/UN/Tesis_Expermiento/butterfly_640x480.jpg",
    "mano":      os.path.join(REPO, "conda/TTY_Filter_Sobel/img/mi_mano.png"),
    "hi":        os.path.join(REPO, "conda/TTY_Filter_Sobel/img/hi.jpeg"),
}

def a_gris_16x12(path):
    im = Image.open(path).convert("L")
    w, h = im.size
    objetivo = W / H
    if w / h > objetivo:
        nw = int(h * objetivo); im = im.crop(((w - nw) // 2, 0, (w + nw) // 2, h))
    else:
        nh = int(w / objetivo); im = im.crop((0, (h - nh) // 2, w, (h + nh) // 2))
    return np.array(im.resize((W, H), Image.LANCZOS), dtype=np.uint8)

os.makedirs(os.path.join(AQUI, "img"), exist_ok=True)
for nombre, path in FUENTES.items():
    if not os.path.exists(path):
        print(f"  !! falta {path}"); continue
    g = a_gris_16x12(path)
    with open(os.path.join(AQUI, "img", f"{nombre}.hex"), "w") as f:
        for fila in g:
            for px in fila:
                f.write(f"{px:02x}\n")
    Image.fromarray(g).resize((W * 24, H * 24), Image.NEAREST) \
         .save(os.path.join(AQUI, "img", f"{nombre}.png"))
    print(f"  {nombre:<10} {g.min():3d}..{g.max():3d}  media {g.mean():5.1f}   -> img/{nombre}.hex")
print(f"\n{H}x{W} = {H*W} pixeles por imagen")
