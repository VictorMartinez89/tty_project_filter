# fig_plano_pan.py — el plano de colocación de pan_sobel y pan_canny, desde el DEF.
#
# No necesita KLayout ni el GDS: el DEF es texto y trae el tipo y la posición de cada
# instancia. Se dibuja un punto por celda, coloreado por FAMILIA, de modo que el plano
# no sea una mancha sino un dato: dónde puso el colocador los registros, dónde la
# lógica, y cuánto silicio se fue en reparar el temporizado.
#
# Entrada: /Users/vic/utm-share/pan_planos/pan_{sobel,canny}.def.gz   (traer_pan.sh)
import gzip, os, re, collections
import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle

DIR = "/Users/vic/utm-share/pan_planos"

# --- clasificación de celdas de sky130_fd_sc_hd -----------------------------
# CUIDADO: dlygate4sd3 (retardo) empieza igual que dlxtp/dlrtp (latch). Se separan
# explícitamente; confundirlos infla la cuenta de biestables en más de un 80 %.
def familia(t):
    if re.search(r"__(decap|fill)",            t): return "relleno"
    if re.search(r"__tap",                     t): return "tap"
    if re.search(r"__(dly|dlymetal)",          t): return "retardo (hold)"
    if re.search(r"__(dfxtp|dfrtp|dfstp|dfbbn|dfbbp|dfsbp|dfrbp|sdf|edf|dlxt|dlrt|dlclk)", t):
        return "biestable"
    if re.search(r"__(clkbuf|clkinv|clkdly)",  t): return "árbol de reloj"
    if re.search(r"__(buf|inv)",               t): return "buffer / inversor"
    if re.search(r"__(conb|diode)",            t): return "diodo / constante"
    return "combinacional"

COL = {"relleno":"#e8e8e8", "tap":"#c9c9c9", "combinacional":"#4c72b0",
       "buffer / inversor":"#8bb0d8", "árbol de reloj":"#ff7f0e",
       "retardo (hold)":"#9467bd", "biestable":"#d62728",
       "diodo / constante":"#55a868"}
ORDEN = ["relleno","tap","combinacional","buffer / inversor","diodo / constante",
         "árbol de reloj","retardo (hold)","biestable"]

def leer_def(path):
    ab = gzip.open if path.endswith(".gz") else open
    die, comps, u = None, [], 1000.0
    with ab(path, "rt", errors="ignore") as f:
        en = False
        for ln in f:
            if ln.startswith("UNITS DISTANCE MICRONS"): u = float(ln.split()[-2])
            elif ln.startswith("DIEAREA"):
                n = [int(x) for x in re.findall(r"-?\d+", ln)]; die = n[:4]
            elif ln.startswith("COMPONENTS"): en = True
            elif ln.startswith("END COMPONENTS"): en = False
            elif en and ln.lstrip().startswith("-"):
                m = re.search(r"-\s+(\S+)\s+(\S+)", ln)
                p = re.search(r"\(\s*(-?\d+)\s+(-?\d+)\s*\)", ln)
                if m and p: comps.append((m.group(2), int(p.group(1)), int(p.group(2))))
    return die, comps, u

fig, axes = plt.subplots(1, 2, figsize=(16, 8.6))
resumen = {}
for ax, nom, tit in zip(axes, ["pan_sobel", "pan_canny"],
                        ["pan_sobel — cámara + CPU + Sobel + clasificador",
                         "pan_canny — cámara + CPU + Canny 1-salto + clasificador"]):
    p = os.path.join(DIR, nom + ".def.gz")
    if not os.path.exists(p): p = os.path.join(DIR, nom + ".def")
    if not os.path.exists(p):
        ax.text(.5, .5, "falta %s.def\n\nen la VM:\nbash /mnt/share/utm-share/traer_pan.sh" % nom,
                ha="center", va="center", family="monospace", fontsize=11)
        ax.set_axis_off(); continue

    die, comps, u = leer_def(p)
    x0, y0, x1, y1 = [v / u for v in die]
    ax.add_patch(Rectangle((x0, y0), x1 - x0, y1 - y0, fill=False, ec="k", lw=1.5, zorder=5))

    pts = collections.defaultdict(lambda: ([], []))
    cnt = collections.Counter()
    for t, x, y in comps:
        f = familia(t); cnt[f] += 1
        pts[f][0].append(x / u); pts[f][1].append(y / u)
    for f in ORDEN:
        if f not in pts: continue
        xs, ys = pts[f]
        ax.scatter(xs, ys, s=.30, c=COL[f], marker="s", lw=0,
                   label="%s (%s)" % (f, format(len(xs), ",").replace(",", " ")))

    ax.set_aspect("equal"); ax.set_xlabel("µm"); ax.set_ylabel("µm")
    util = 100.0 * (len(comps) - cnt["relleno"] - cnt["tap"]) / max(len(comps), 1)
    ax.set_title("%s\n%s instancias · %.0f×%.0f µm · %.2f mm²"
                 % (tit, format(len(comps), ",").replace(",", " "),
                    x1 - x0, y1 - y0, (x1 - x0) * (y1 - y0) / 1e6), fontsize=11)
    ax.legend(loc="upper center", bbox_to_anchor=(.5, -.09), ncol=3,
              fontsize=8.5, frameon=False, markerscale=16, handletextpad=.4,
              columnspacing=1.1)
    resumen[nom] = cnt

fig.suptitle("Los dos chips «Pan Hablas en MNIST» en sky130 — planos de colocación\n"
             "seis racimos de lógica separados por vacío: con FP_CORE_UTIL = 22 el colocador "
             "no necesitó apretar\ndentro de cada racimo las familias están UNIFORMEMENTE "
             "mezcladas (todas a ±3 % de la densidad media)", fontsize=12.5, y=1.02)
plt.tight_layout()
plt.savefig("fig_plano_pan.png", dpi=140, bbox_inches="tight")

if resumen:
    fams = sorted({f for c in resumen.values() for f in c}, key=lambda f: -resumen["pan_sobel"][f])
    print("%-22s %9s %9s %8s" % ("familia", "sobel", "canny", "factor"))
    for f in fams:
        a, b = resumen["pan_sobel"][f], resumen["pan_canny"][f]
        print("%-22s %9s %9s %8s" % (f, format(a, ","), format(b, ","),
                                     ("%.2fx" % (b / a)) if a else "-"))
    for n, c in resumen.items():
        logi = sum(v for f, v in c.items() if f not in ("relleno", "tap"))
        print("  %s: lógica %s · taps %s · relleno %s"
              % (n, format(logi, ","), format(c["tap"], ","), format(c["relleno"], ",")))
plt.show()
print("ok")
