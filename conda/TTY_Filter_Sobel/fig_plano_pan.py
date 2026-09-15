# fig_plano_pan.py — dibuja el plano de pan_sobel y pan_canny desde el DEF.
# No necesita KLayout ni el GDS: el DEF es texto y trae la posicion de cada celda.
# Espera /Users/vic/utm-share/pan_planos/pan_{sobel,canny}.def.gz  (lo trae traer_pan.sh)
import gzip, re, os
import numpy as np, matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle
from matplotlib.collections import PatchCollection

DIR = "/Users/vic/utm-share/pan_planos"

def leer_def(path):
    ab = open if not path.endswith(".gz") else gzip.open
    die, comps, unidades = None, [], 1000
    with ab(path, "rt", errors="ignore") as f:
        en_comp = False
        for ln in f:
            if ln.startswith("UNITS DISTANCE MICRONS"):
                unidades = float(ln.split()[-2])
            elif ln.startswith("DIEAREA"):
                n = [int(x) for x in re.findall(r"-?\d+", ln)]
                die = (n[0], n[1], n[2], n[3])
            elif ln.startswith("COMPONENTS"):
                en_comp = True
            elif ln.startswith("END COMPONENTS"):
                en_comp = False
            elif en_comp and ln.lstrip().startswith("-"):
                m = re.search(r"-\s+(\S+)\s+(\S+)", ln)
                p = re.search(r"\(\s*(-?\d+)\s+(-?\d+)\s*\)", ln)
                if m and p:
                    comps.append((m.group(2), int(p.group(1)), int(p.group(2))))
    return die, comps, unidades

# familia de celda -> color. Lo que importa: biestables vs combinacional.
def familia(t):
    if re.search(r"__(df|dl|sdf|edf)", t): return "biestable"
    if re.search(r"__(buf|clkbuf|clkinv|dlyg|dlymetal)", t): return "reloj/buffer"
    if re.search(r"__(fill|decap|tap|diode|conb)", t): return "relleno"
    return "combinacional"

COL = {"biestable":"#d62728", "reloj/buffer":"#ff7f0e",
       "combinacional":"#4c72b0", "relleno":"#dddddd"}
# tamano tipico de celda sky130 hd: alto 2.72 um, ancho variable; se dibuja un punto por celda
ALTO = 2.72

fig, axes = plt.subplots(1, 2, figsize=(15, 7.6))
resumen = []
for ax, nom, titulo in zip(axes, ["pan_sobel","pan_canny"],
                           ["pan_sobel — Sobel", "pan_canny — Canny 1-salto"]):
    p = os.path.join(DIR, nom + ".def.gz")
    if not os.path.exists(p): p = os.path.join(DIR, nom + ".def")
    if not os.path.exists(p):
        ax.text(.5,.5,f"falta {nom}.def\n\ncorrer en la VM:\nbash /mnt/share/utm-share/traer_pan.sh",
                ha="center", va="center", fontsize=11, family="monospace")
        ax.set_axis_off(); continue
    die, comps, u = leer_def(p)
    x0,y0,x1,y1 = [v/u for v in die]
    ax.add_patch(Rectangle((x0,y0), x1-x0, y1-y0, fill=False, ec="k", lw=1.4))

    cnt = {}
    por_fam = {k: [[],[]] for k in COL}
    for t,x,y in comps:
        f = familia(t); cnt[f] = cnt.get(f,0)+1
        por_fam[f][0].append(x/u); por_fam[f][1].append(y/u)
    orden = ["relleno","combinacional","reloj/buffer","biestable"]
    for f in orden:
        xs,ys = por_fam[f]
        if xs: ax.scatter(xs, ys, s=.35, c=COL[f], marker="s",
                          lw=0, label=f"{f} ({len(xs):,})".replace(","," "))
    ax.set_aspect("equal"); ax.set_xlabel("µm"); ax.set_ylabel("µm")
    ax.set_title(f"{titulo}\n{len(comps):,} instancias · {(x1-x0):.0f}×{(y1-y0):.0f} µm"
                 .replace(","," "), fontsize=11)
    ax.legend(loc="upper center", bbox_to_anchor=(.5,-.10), ncol=2,
              fontsize=8, frameon=False, markerscale=14)
    resumen.append((nom, len(comps), cnt, (x1-x0)*(y1-y0)))

fig.suptitle("Los dos chips «Pan Hablas en MNIST» en sky130 — planos de colocación",
             fontsize=13, y=.99)
plt.tight_layout()
plt.savefig("fig_plano_pan.png", dpi=140, bbox_inches="tight")
for n,tot,c,a in resumen:
    print(f"{n:10s} {tot:7,} inst · {a/1e6:.3f} mm² · " +
          " ".join(f"{k}={v:,}" for k,v in sorted(c.items())))
print("ok")
