#!/usr/bin/env python3
"""verificar_top78.py — la CADENA COMPLETA en flujo continuo, contra el golden.

No basta con preguntar si el digito sale bien: si sale mal hay que saber si la culpa es del
extractor, del trasvase o del clasificador. El banco vuelca los tres y aca se comparan por
separado. Y se encadenan varias imagenes sin pausa, porque lo que falla es el segundo cuadro.

  Uso:  python3 verificar_top78.py [n_imagenes] [gap]
"""
import numpy as np, subprocess, os, sys, time, warnings; warnings.filterwarnings("ignore")
import frente_golden as fg
from canny1_mnist import frente_canny1

R = os.path.abspath("rtl")
N   = int(sys.argv[1]) if len(sys.argv) > 1 else 8
GAP = int(sys.argv[2]) if len(sys.argv) > 2 else 0
LOTE = 32                                     # imagenes por corrida de vvp
# Nombre de temporal PROPIO de cada corrida. Sin esto, dos corridas en paralelo -una en fondo
# sobre las 10 000 y una de GAP en primer plano- se pisan el .hex y el .out, y la que pierde
# informa fallos que no existen. Costo de averiguarlo: media hora de perseguir un fantasma.
TAG = os.environ.get("TAG", str(os.getpid()))

_, _, Xte, yte = fg.cargar_mnist()
p = np.load("pesos_sel78.npz"); W, b, idx = p["W"], p["b"], p["idx"]

def golden(lo, hi):
    m, o = frente_canny1(Xte[lo:hi], 90, 32)
    F = fg.piramide(m, o, 2)
    out = []
    for i in range(hi - lo):
        nb = int(m[i].sum()); s = F[i, idx] @ W.T + b; ss = np.sort(s)
        out.append((F[i, 40:].astype(int), nb, int(s.argmax()),
                    int(174 <= nb <= 376 and ss[-1] - ss[-2] > 70)))
    return out

def patron(g, q):
    g, q = np.asarray(g, int), np.asarray(q, int)
    if np.array_equal(g, q): return None
    for s in range(1, 4):
        if np.array_equal(g[s:], q[:-s]): return f"CORRIDO {s}"
        if np.array_equal(g[:-s], q[s:]): return f"CORRIDO -{s}"
    d = np.nonzero(g != q)[0]
    return f"{len(d)} casillas (suma {g.sum()} vs {q.sum()}, 1a en {d[0]})"

print(f"cadena completa en flujo continuo · {N} imagenes · GAP={GAP}\n")
t0 = time.time()
# LA COMPROBACION QUE MANDA es golden -> fmem: es lo que el clasificador consume de verdad.
# El volcado de cnt[] es solo diagnostico, y con tiempo muerto entre pixeles CORRE CARRERA con
# el vaciado al leer: el trasvase avanza a ritmo de reloj y el desague del ultimo incremento
# espera una muestra valida, asi que con GAP grande la instantanea sale con las primeras
# casillas ya en cero. No es un fallo del diseno; es que no se puede fotografiar una memoria
# mientras alguien la vacia. Se informa aparte y no cuenta como fallo.
malc = malf = maln = mald = malg = 0; acc = 0; vistos = 0; fallos = []
for lo in range(0, N, LOTE):
    hi = min(lo + LOTE, N); G = golden(lo, hi)
    with open(f"{R}/tmp/t78_{TAG}.hex", "w") as f:
        for i in range(lo, hi):
            f.write("".join(f"{int(x):02x}\n" for x in Xte[i].ravel()))
    subprocess.run(["vvp", "tmp/top78.vvp", f"+IN=tmp/t78_{TAG}.hex",
                    f"+OUT=tmp/t78_{TAG}.out", f"+NIMG={hi-lo}", f"+GAP={GAP}"],
                   cwd=R, capture_output=True)
    cnt, fmem, ver = {}, {}, {}
    L = open(f"{R}/tmp/t78_{TAG}.out").read().split("\n")
    j = 0
    while j < len(L):
        t = L[j].split()
        if not t: j += 1; continue
        if t[0] == "CNT":
            cnt[int(t[1])] = ([int(x) if x != "x" else -1 for x in L[j+1:j+129]], int(t[2])); j += 129
        elif t[0] == "FMEM":
            fmem[int(t[1])] = [int(x) if x != "x" else -1 for x in L[j+1:j+129]]; j += 129
        elif t[0] == "VER":
            ver[int(t[1])] = (int(t[2]), int(t[3])); j += 1
        else: j += 1
    for k in range(hi - lo):
        g128, gnb, gd, gv = G[k]
        if k not in ver:
            print(f"  img {lo+k}: SIN VEREDICTO (done no llego)"); mald += 1; continue
        vistos += 1
        pg = patron(g128, fmem[k]) if k in fmem else "sin volcado"
        pc = patron(g128, cnt[k][0]) if k in cnt else "sin volcado"
        d, v = ver[k]
        malg += pg is not None; malc += pc is not None
        maln += cnt[k][1] != gnb; mald += (d, v) != (gd, gv); acc += d == yte[lo+k]
        if pg or (d, v) != (gd, gv) or cnt[k][1] != gnb:
            fallos.append(f"  img {lo+k} (etiq {yte[lo+k]}): golden->fmem={pg or 'ok'}"
                          f" · n_bordes {cnt[k][1]}/{gnb} · veredicto ({d},{v})/({gd},{gv})"
                          f"  [cnt: {pc or 'ok'}]")
    print(f"  [{time.time()-t0:5.0f}s] {hi}/{N}  caracteristicas {hi-malg}/{hi}"
          f"  n_bordes {hi-maln}/{hi}  veredicto {hi-mald}/{hi}"
          f"  acierto {acc/max(vistos,1):.2%}", flush=True)

for l in fallos[:12]: print(l)
print(f"\n  === CADENA COMPLETA, FLUJO CONTINUO ({N} imagenes, GAP={GAP}) ===")
print(f"    caracteristicas que recibe el clasificador vs Python : {N-malg}/{N} "
      f"{'OK' if malg==0 else 'FALLA'}")
print(f"    (diagnostico) instantanea de cnt[] : {N-malc}/{N}"
      + ("" if malc == 0 else "  <- corre carrera con el vaciado si GAP>2, ver nota"))
print(f"    n_bordes            : {N-maln}/{N} {'OK' if maln==0 else 'FALLA'}")
print(f"    veredicto vs golden : {N-mald}/{N} {'OK' if mald==0 else 'FALLA'}")
print(f"    acierto {acc}/{vistos} = {acc/max(vistos,1):.2%}")
print(f"  [{time.time()-t0:.0f}s]")
