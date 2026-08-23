#!/usr/bin/env python3
"""optimize_nb.py — achica un .ipynb re-comprimiendo las imagenes embebidas.

Regla acordada:  FOTO -> JPEG q85   ·   DIBUJO/GRAFICA -> PNG con paleta.
Decide por el numero de colores unicos. No toca las que ya son JPEG.
Uso:  python3 tmp/optimize_nb.py entrada.ipynb salida.ipynb
"""
import base64, io, json, re, sys
from PIL import Image

Q_JPEG   = 85
MAX_W    = 1500          # ancho maximo; mas que esto no aporta en pantalla
UMBRAL_COLORES = 4096    # mas colores que esto = foto

def recomprimir(png_b64):
    """Devuelve (nuevo_b64, mime, ahorro_bytes) o None si no conviene tocarla."""
    crudo = base64.b64decode(png_b64)
    try:
        im = Image.open(io.BytesIO(crudo))
    except Exception:
        return None
    im.load()
    if im.width > MAX_W:
        im = im.copy(); im.thumbnail((MAX_W, MAX_W * 4))
    colores = im.convert("RGB").getcolors(maxcolors=UMBRAL_COLORES)
    buf = io.BytesIO()
    if colores is None:                       # muchos colores -> foto
        im.convert("RGB").save(buf, "JPEG", quality=Q_JPEG, optimize=True)
        mime = "jpeg"
    else:                                     # pocos colores -> grafica
        im.convert("RGB").convert("P", palette=Image.ADAPTIVE, colors=256) \
          .save(buf, "PNG", optimize=True)
        mime = "png"
    nuevo = buf.getvalue()
    if len(nuevo) >= len(crudo):
        return None
    return base64.b64encode(nuevo).decode(), mime, len(crudo) - len(nuevo)

def main(ent, sal):
    nb = json.load(open(ent))
    ahorro = total = tocadas = 0

    for c in nb["cells"]:
        # 1) salidas de celdas de codigo
        for out in c.get("outputs", []):
            data = out.get("data", {})
            if "image/png" in data:
                total += 1
                b64 = data["image/png"]
                if isinstance(b64, list): b64 = "".join(b64)
                r = recomprimir(b64)
                if r:
                    nuevo, mime, gan = r
                    del data["image/png"]
                    data[f"image/{mime}"] = nuevo
                    ahorro += gan; tocadas += 1

        # 2) imagenes embebidas como data-URI dentro del markdown
        if c["cell_type"] == "markdown":
            src = "".join(c["source"])
            cambios = []
            for m in re.finditer(r"data:image/png;base64,([A-Za-z0-9+/=]+)", src):
                total += 1
                r = recomprimir(m.group(1))
                if r:
                    nuevo, mime, gan = r
                    cambios.append((m.span(), f"data:image/{mime};base64,{nuevo}"))
                    ahorro += gan; tocadas += 1
            for (ini, fin), rep in reversed(cambios):
                src = src[:ini] + rep + src[fin:]
            if cambios:
                c["source"] = src.splitlines(keepends=True)

    json.dump(nb, open(sal, "w"), ensure_ascii=False, indent=1)
    print(f"imagenes: {total} encontradas, {tocadas} recomprimidas")
    print(f"ahorro en imagenes: {ahorro/1048576:.1f} MB")

if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
