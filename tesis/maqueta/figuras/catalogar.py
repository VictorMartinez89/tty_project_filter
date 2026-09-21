#!/usr/bin/env python3
"""catalogar.py — lista TODAS las imagenes de los dos cuadernos con su seccion,
tipo, dimensiones y peso.  Salida: catalogo_figuras.tsv

    python3 tesis/maqueta/figuras/catalogar.py [dir_de_los_cuadernos]
"""
import json, base64, re, struct, io, sys, os
from collections import defaultdict

DIR = sys.argv[1] if len(sys.argv) > 1 else \
      os.path.expanduser("~/UN/Tesis/Repository/tty_project_filter/conda/TTY_Filter_Sobel")
SAL = os.path.join(os.path.dirname(os.path.abspath(__file__)), "catalogo_figuras.tsv")

def dim(b):
    try:
        if b[:8] == b'\x89PNG\r\n\x1a\n': return struct.unpack('>II', b[16:24])
        if b[:2] == b'\xff\xd8':
            i = 2
            while i < len(b) - 9:
                if b[i] != 0xFF: i += 1; continue
                if b[i+1] in (0xC0, 0xC1, 0xC2, 0xC3):
                    h, w = struct.unpack('>HH', b[i+5:i+9]); return (w, h)
                i += 2 + struct.unpack('>H', b[i+2:i+4])[0]
    except Exception: pass
    return (0, 0)

def limpia(t):
    t = re.sub(r'[\U0001F000-\U0001FAFF☀-➿️]', '', t)
    return re.sub(r'\s+', ' ', t).strip(" —-·*#")

def imagenes(celda):
    vistas = []
    for o in celda.get("outputs", []):
        for k, v in (o.get("data") or {}).items():
            if k.startswith("image/"):
                vistas.append((k, v if isinstance(v, str) else "".join(v)))
    for _, att in (celda.get("attachments") or {}).items():
        for k, v in att.items():
            if k.startswith("image/"): vistas.append((k, v))
    return vistas

filas = []
for nb, eti in (("TTY_Filter_Sobel.ipynb", "C1"), ("TTY_Filter_Sobel2.ipynb", "C2")):
    ruta = os.path.join(DIR, nb)
    if not os.path.exists(ruta): print("  !! no está", ruta); continue
    d = json.load(open(ruta)); sec = "(antes del primer título)"
    for i, c in enumerate(d["cells"]):
        if c["cell_type"] == "markdown":
            for ln in "".join(c["source"]).splitlines():
                if re.match(r'^#{1,3}\s+\S', ln): sec = limpia(ln)[:70]
        for n, (k, v) in enumerate(imagenes(c)):
            b = base64.b64decode(v.split(",")[-1]); w, h = dim(b)
            filas.append((eti, i, n, sec, k.split("/")[-1], w, h, len(b)//1024))

with io.open(SAL, "w", encoding="utf-8") as f:
    f.write("cuaderno\tcelda\tidx\tseccion\ttipo\tancho\talto\tKB\n")
    for r in filas: f.write("\t".join(str(x) for x in r) + "\n")

por = defaultdict(int)
for r in filas: por[r[0]] += 1
print(f"  {len(filas)} imágenes  ({', '.join(f'{k}: {v}' for k,v in sorted(por.items()))})")
print(f"  -> {SAL}")
