#!/usr/bin/env python3
"""contar_celdas.py — recuenta las celdas de cada chip con UNA sola definicion,
leyendo el netlist post-ruteo (.nl.v) archivado. Contrasta con el DEF."""
import re, glob, os, sys

RAIZ = sys.argv[1] if len(sys.argv) > 1 else os.path.expanduser("~/ASIC_planos")
# celdas que NO hacen logica: relleno, taps de pozo, desacoplo y diodos de antena
FISICAS = re.compile(r"_(fill|tapvpwrvgnd|decap|diode|tap)\w*$")
INST = re.compile(r"^\s*((?:sky130_fd_sc_hd|sg13g2)\w*)\s+(\S+)\s*\(")

filas = []
for d in sorted(os.listdir(RAIZ)):
    dir_ = os.path.join(RAIZ, d)
    if not os.path.isdir(dir_): continue
    nls = glob.glob(os.path.join(dir_, "*.nl.v"))
    if not nls: continue
    total, fis = 0, 0
    for l in open(nls[0], errors="ignore"):
        m = INST.match(l)
        if m:
            total += 1
            if FISICAS.search(m.group(1)): fis += 1
    # el DEF como contraste independiente
    defs = glob.glob(os.path.join(dir_, "*.def"))
    ncomp = None
    if defs:
        for l in open(defs[0], errors="ignore"):
            mm = re.match(r"^COMPONENTS\s+(\d+)", l)
            if mm: ncomp = int(mm.group(1)); break
    filas.append((d, total, fis, total - fis, ncomp))

anch = max(len(f[0]) for f in filas)
print(f"{'chip':<{anch}} {'instancias':>11} {'fisicas':>8} {'LOGICAS':>9} {'DEF':>9}  coincide")
print("-" * (anch + 52))
for d, t, f, log, nc in filas:
    ok = "si" if nc == t else (f"NO ({nc-t:+d})" if nc is not None else "—")
    print(f"{d:<{anch}} {t:>11,} {f:>8,} {log:>9,} {(nc if nc is not None else 0):>9,}  {ok}")
