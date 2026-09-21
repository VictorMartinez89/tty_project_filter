#!/usr/bin/env python3
"""solo_top.py — deja en el JSON de yosys UNICAMENTE el modulo top.

netlistsvg dibuja un modulo del fichero, y con varios presentes elige el que no es:
en `canny1_top` habia tres -el top y dos instancias parametrizadas de linebuf3x3- y
dibujaba uno vacio. Tambien limpia el `$paramod$<sha1>\\` de los nombres.
"""
import json, re, sys
p, top = sys.argv[1], sys.argv[2]
d = json.load(open(p))
lim = lambda n: re.sub(r'\$paramod\$?[0-9a-f]*\\?', '', n)
mods = {lim(k): v for k, v in d["modules"].items()}
if top not in mods:
    sys.exit("no esta '%s'; hay: %s" % (top, list(mods)))
json.dump({"modules": {top: mods[top]}}, open(p, "w"))
print("  %-22s %d celdas, %d puertos" % (top, len(mods[top].get("cells", {})), len(mods[top].get("ports", {}))))
