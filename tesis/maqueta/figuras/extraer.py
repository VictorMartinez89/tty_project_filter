#!/usr/bin/env python3
"""extraer.py — saca a fichero las imagenes elegidas en seleccion.tsv.

seleccion.tsv tiene tres columnas separadas por tabulador, y se comenta con '#':
    cuaderno<TAB>celda:idx<TAB>nombre_del_fichero_sin_extension

    python3 tesis/maqueta/figuras/extraer.py [dir_de_los_cuadernos]
"""
import json, base64, io, os, sys, csv

AQUI = os.path.dirname(os.path.abspath(__file__))
DIR  = sys.argv[1] if len(sys.argv) > 1 else \
       os.path.expanduser("~/UN/Tesis/Repository/tty_project_filter/conda/TTY_Filter_Sobel")
SEL  = os.path.join(AQUI, "seleccion.tsv")
NB   = {"C1": "TTY_Filter_Sobel.ipynb", "C2": "TTY_Filter_Sobel2.ipynb"}

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

if not os.path.exists(SEL):
    print(f"  !! falta {SEL}"); sys.exit(1)

cache = {}
n_ok = n_mal = 0
for ln in io.open(SEL, encoding="utf-8"):
    ln = ln.rstrip("\n")
    if not ln.strip() or ln.lstrip().startswith("#"): continue
    try:
        cuad, pos, nombre = [c.strip() for c in ln.split("\t") if c.strip()][:3]
        celda, idx = (int(x) for x in pos.split(":"))
    except Exception:
        print(f"  !! linea ilegible: {ln}"); n_mal += 1; continue
    if cuad not in cache:
        cache[cuad] = json.load(open(os.path.join(DIR, NB[cuad])))
    cs = cache[cuad]["cells"]
    if celda >= len(cs):
        print(f"  !! {cuad} no tiene celda {celda}"); n_mal += 1; continue
    ims = imagenes(cs[celda])
    if idx >= len(ims):
        print(f"  !! {cuad} celda {celda} no tiene imagen {idx} (tiene {len(ims)})"); n_mal += 1; continue
    k, v = ims[idx]
    ext = "png" if k.endswith("png") else "jpg"
    b = base64.b64decode(v.split(",")[-1])
    dest = os.path.join(AQUI, f"{nombre}.{ext}")
    open(dest, "wb").write(b)
    print(f"  {nombre}.{ext:<4} {len(b)//1024:>5} KB   <- {cuad} celda {celda}")
    n_ok += 1
print(f"\n  {n_ok} extraídas, {n_mal} con problema, en {AQUI}/")
