#!/usr/bin/env python3
"""anchos_tablas.py — en una tabla de pipes con alguna fila de mas de 72 caracteres, pandoc reparte el
ancho de las columnas segun los guiones de la fila separadora. Con `|---|---|---|` salen todas iguales
y la columna larga se parte en tres renglones mientras la corta sobra. Este guion escribe los guiones
en proporcion al texto mas largo de cada columna (con un minimo), conservando los ':' de alineacion.
    python3 tesis/maqueta/anchos_tablas.py [--ver]"""
import re, glob, os, sys
T = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SEP = re.compile(r"^\|(\s*:?-+:?\s*\|)+\s*$")

def celdas(l):
    return [c.strip() for c in l.strip().strip("|").split("|")]

def largo(c):
    c = re.sub(r"\*\*|`|\*|\\", "", c)
    # la palabra mas larga no se puede partir: pesa igual que su largo
    return max(len(c), 1)

cambios = 0
for f in sorted(glob.glob(f"{T}/cap*.md")) + sorted(glob.glob(f"{T}/anexo*.md")):
    L = open(f).read().split("\n"); o = list(L); en_codigo = False
    for i, l in enumerate(L):
        if l.startswith("```"): en_codigo = not en_codigo
        if en_codigo or not SEP.match(l) or i == 0 or not L[i - 1].startswith("|"): continue
        j = i + 1
        while j < len(L) and L[j].startswith("|"): j += 1
        filas = [celdas(L[i - 1])] + [celdas(x) for x in L[i + 1:j]]
        n = len(celdas(l))
        if max(len(x) for x in [L[i - 1]] + L[i + 1:j]) <= 72: continue
        if any(len(c) != n for c in filas): continue
        seps = celdas(l)
        if len(set(len(s.strip(":")) for s in seps)) > 1: continue      # ya tiene anchos a mano
        w = [max(largo(fila[k]) for fila in filas) for k in range(n)]
        w = [min(max(x, 6), 60) for x in w]
        nuevo = "|" + "|".join((":" if s.startswith(":") else "") + "-" * x + (":" if s.endswith(":") and len(s) > 1 else "")
                               for s, x in zip(seps, w)) + "|"
        if nuevo != l:
            o[i] = nuevo; cambios += 1
            if "--ver" in sys.argv: print(os.path.basename(f), i + 1, w)
    if "--ver" not in sys.argv and o != L: open(f, "w").write("\n".join(o))
print("  tablas con anchos proporcionales:", cambios)
