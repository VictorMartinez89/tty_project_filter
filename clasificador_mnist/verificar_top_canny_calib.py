#!/usr/bin/env python3
"""verificar_top_canny_calib.py — la cadena del SoC y de los chips 13/14, contra el golden.

Es la hermana de `verificar_top78.py` para la OTRA cadena: la de cuatro cuadrantes y 40
caracteristicas, que es la que esta en el SoC de camara y en los chips `vision_*_mnist`. Su
cabecera confesaba que el extractor no estaba verificado bit a bit y que la mejor coincidencia
medida era del 97,3 % del mapa de bordes. Ese 97,3 % era la latencia mal puesta.

Se copia la forma en que el chip mueve `clr` -un pulso un ciclo despues de `done`- y se
encadenan las imagenes sin pausa, porque lo que falla no es el primer cuadro.

  Uso:  python3 verificar_top_canny_calib.py [n_imagenes] [gap]
"""
import numpy as np, subprocess, os, sys, time, warnings; warnings.filterwarnings("ignore")
import frente_golden as fg
from canny1_mnist import frente_canny1

R = os.path.abspath("rtl")
N   = int(sys.argv[1]) if len(sys.argv) > 1 else 32
GAP = int(sys.argv[2]) if len(sys.argv) > 2 else 0
LOTE = 32
TAG = os.environ.get("TAG", str(os.getpid()))

_, _, Xte, yte = fg.cargar_mnist()
p = np.load("pesos_canny_fw_calib.npz")
W, b, B = p["W"], p["b"], p["B"]
B_MIN, B_MAX, MARGEN = (int(x) for x in B)

def golden(lo, hi):
    m, o = frente_canny1(Xte[lo:hi], 90, 32)
    F = fg.piramide(m, o, 1)                       # 40 = 8 del nivel 0 + 32 del nivel 1
    out = []
    for i in range(hi - lo):
        nb = int(m[i].sum()); s = F[i] @ W.T + b; ss = np.sort(s)
        out.append((F[i, 8:40].astype(int), nb, int(s.argmax()),
                    int(B_MIN <= nb <= B_MAX and ss[-1] - ss[-2] > MARGEN)))
    return out

def patron(g, q):
    g, q = np.asarray(g, int), np.asarray(q, int)
    if np.array_equal(g, q): return None
    d = np.nonzero(g != q)[0]
    return f"{len(d)} casillas (suma {g.sum()} vs {q.sum()}, 1a en {d[0]})"

print(f"cadena de 4 cuadrantes (SoC y chips 13/14) · {N} imagenes · GAP={GAP}\n")
t0 = time.time(); malc = maln = mald = 0; acc = 0; vistos = 0; fallos = []
for lo in range(0, N, LOTE):
    hi = min(lo + LOTE, N); G = golden(lo, hi)
    with open(f"{R}/tmp/tc_{TAG}.hex", "w") as f:
        for i in range(lo, hi):
            f.write("".join(f"{int(x):02x}\n" for x in Xte[i].ravel()))
    subprocess.run(["vvp", "tmp/topccal.vvp", f"+IN=tmp/tc_{TAG}.hex",
                    f"+OUT=tmp/tc_{TAG}.out", f"+NIMG={hi-lo}", f"+GAP={GAP}"],
                   cwd=R, capture_output=True)
    cnt, ver = {}, {}
    L = open(f"{R}/tmp/tc_{TAG}.out").read().split("\n"); j = 0
    while j < len(L):
        t = L[j].split()
        if not t: j += 1; continue
        if t[0] == "CNT":
            cnt[int(t[1])] = ([int(x) if x != "x" else -1 for x in L[j+1:j+33]], int(t[2])); j += 33
        elif t[0] == "VER":
            ver[int(t[1])] = (int(t[2]), int(t[3])); j += 1
        else: j += 1
    for k in range(hi - lo):
        g32, gnb, gd, gv = G[k]
        if k not in ver:
            fallos.append(f"  img {lo+k}: SIN VEREDICTO"); mald += 1; continue
        vistos += 1
        pc = patron(g32, cnt[k][0]) if k in cnt else "sin volcado"
        d, v = ver[k]
        malc += pc is not None; maln += (k in cnt and cnt[k][1] != gnb)
        mald += (d, v) != (gd, gv); acc += d == yte[lo+k]
        if pc or (d, v) != (gd, gv):
            fallos.append(f"  img {lo+k} (etiq {yte[lo+k]}): contadores={pc or 'ok'}"
                          f" · n_bordes {cnt[k][1] if k in cnt else '?'}/{gnb}"
                          f" · veredicto ({d},{v})/({gd},{gv})")
    print(f"  [{time.time()-t0:5.0f}s] {hi}/{N}  contadores {hi-malc}/{hi}"
          f"  n_bordes {hi-maln}/{hi}  veredicto {hi-mald}/{hi}"
          f"  acierto {acc/max(vistos,1):.2%}", flush=True)

for l in fallos[:10]: print(l)
print(f"\n  === CADENA DE 4 CUADRANTES ({N} imagenes, GAP={GAP}) ===")
print(f"    contadores vs Python : {N-malc}/{N} {'OK' if malc==0 else 'FALLA'}")
print(f"    n_bordes             : {N-maln}/{N} {'OK' if maln==0 else 'FALLA'}")
print(f"    veredicto vs golden  : {N-mald}/{N} {'OK' if mald==0 else 'FALLA'}")
print(f"    acierto {acc}/{vistos} = {acc/max(vistos,1):.2%}   (con sesgos calibrados: 94,20 % esperado)")
print(f"  [{time.time()-t0:.0f}s]")
