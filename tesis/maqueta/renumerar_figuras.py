#!/usr/bin/env python3
"""renumerar_figuras.py — numera las figuras de cada capitulo en el orden en que aparecen
(«Figura 4.1», «4.2»…) y actualiza sus citas en la prosa de TODOS los ficheros.
Las etiquetas viejas pueden ser cualquier cosa unica («4.0t1», «5.9t»…): sirven de marcador
para insertar figuras nuevas sin calcular numeros a mano.
    python3 tesis/maqueta/renumerar_figuras.py        (desde la raiz del repo o desde tesis/)"""
import re, os, glob
T = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CAP = re.compile(r"!\[\*\*Figura ([0-9]+\.[0-9]+[a-z0-9]*)\.\*\*")
caps = sorted(glob.glob(f"{T}/cap*.md"))
mapa = {}
for f in caps:
    s = open(f).read()
    m = re.search(r"^# (\d+)\. ", s, re.M)
    if not m: continue
    n = m.group(1)
    for k, viejo in enumerate(CAP.findall(s), 1):
        assert viejo not in mapa, f"etiqueta repetida: {viejo}"
        mapa[viejo] = f"{n}.{k}"
todos = caps + sorted(glob.glob(f"{T}/anexo*.md"))
cambios = 0
for f in todos:
    s = open(f).read(); o = s
    s = CAP.sub(lambda m: "![**Figura @" + mapa[m.group(1)] + ".**", s)
    s = re.sub(r"(?<!\[\*\*)Figura ([0-9]+\.[0-9]+[a-z0-9]*)\b",
               lambda m: "Figura @" + mapa[m.group(1)] if m.group(1) in mapa else m.group(0), s)
    s = s.replace("Figura @", "Figura ")
    if s != o: open(f, "w").write(s); cambios += 1
print("  figuras:", len(mapa), "· cambiadas:", sum(1 for k, v in mapa.items() if k != v), "· ficheros tocados:", cambios)
