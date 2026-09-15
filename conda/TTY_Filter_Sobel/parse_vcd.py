#!/usr/bin/env python3
"""parse_vcd.py — extrae las señales de nivel superior de un .vcd a un .pkl liviano."""
import re, sys, pickle
QUIERO = {"pclk","href","py_valid","curY","w_valid","w_pix","w_fin",
          "done","digito","valido","thr_usado","cpu_escribio","reset","resetn"}
f_in = sys.argv[1]; f_out = sys.argv[2]
ID = {}
with open(f_in) as f:
    for ln in f:
        m = re.match(r"\$var \w+ (\d+) (\S+) (\w+)", ln)
        if m and m.group(3) in QUIERO and m.group(2) not in ID:
            ID[m.group(2)] = m.group(3)          # el PRIMER id es el del nivel superior
        if ln.startswith("$enddefinitions"): break
vistos = set()
ID = {k: v for k, v in ID.items() if not (v in vistos or vistos.add(v))}
tr = {v: [] for v in ID.values()}; t = 0
with open(f_in) as f:
    for ln in f:
        ln = ln.rstrip("\n")
        if not ln: continue
        c = ln[0]
        if c == '#': t = int(ln[1:]); continue
        if c in "01xz" and len(ln) > 1:
            i = ln[1:]
            if i in ID: tr[ID[i]].append((t, 0 if c=='0' else (1 if c=='1' else None)))
        elif c in "bB":
            p = ln.split()
            if len(p) > 1 and p[1] in ID:
                v = p[0][1:]
                tr[ID[p[1]]].append((t, int(v,2) if set(v) <= set("01") else None))
pickle.dump((tr, t), open(f_out,"wb"))
print(f"{f_in}: {len(tr)} señales, t_final={t/1e9:.2f} ms")
