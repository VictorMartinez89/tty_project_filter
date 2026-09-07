#!/usr/bin/env python3
"""verificar.py — el golden de Python contra el RTL, imagen por imagen.

Compara los 32 contadores del histograma Y el digito. Los contadores tienen que coincidir
EXACTAMENTE: si el hardware y el golden difieren en uno solo, el modelo entrenado no es el que
corre en el chip. Es la verificacion de las Partes 29-35 aplicada al clasificador.

  Uso:  python3 verificar.py [N]        (por defecto 20 imagenes)

OJO con comparar por TOTALES: un desalineamiento del raster deja el total intacto y solo mueve
pixeles entre zonas. Con LAT=58 en vez de 60 el total daba 229 = 229 y el diseno estaba mal.
Por eso se compara contador por contador.
"""
import os, subprocess, sys
import numpy as np
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
import frente_golden as fg

AQUI = os.path.dirname(os.path.abspath(__file__))
N = int(sys.argv[1]) if len(sys.argv) > 1 else 20

_, _, Xte, yte = fg.cargar_mnist(os.path.join(AQUI, "..", "mnist.npz"))
P = np.load(os.path.join(AQUI, "..", "pesos_hw.npz"))
Wq, bq = P["W"], P["b"]

def golden(img):
    m, o = fg.frente(img)
    c = fg.contadores(m[0], o[0])
    return c, int((fg.descriptor(c) @ Wq.T + bq).argmax())

def correr_rtl(img, n):
    hx, ox = f"tmp/d{n}.hex", f"tmp/o{n}.txt"
    with open(os.path.join(AQUI, hx), "w") as f:
        f.write("".join(f"{v:02x}\n" for v in img.ravel()))
    subprocess.run(["vvp", "tmp/sim.vvp", f"+IMG={hx}", f"+OUT={ox}"],
                   cwd=AQUI, capture_output=True)
    L = open(os.path.join(AQUI, ox)).read().split("\n")
    return np.array([int(x) for x in L[:32]]), int(L[32].split()[1])

os.makedirs(os.path.join(AQUI, "tmp"), exist_ok=True)
ok_c = ok_d = ok_y = 0
for n in range(N):
    r_cnt, r_dig = correr_rtl(Xte[n], n)
    g_cnt, g_dig = golden(Xte[n])
    c_ok = np.array_equal(r_cnt, g_cnt)
    ok_c += c_ok; ok_d += (r_dig == g_dig); ok_y += (r_dig == yte[n])
    if not c_ok or r_dig != g_dig:
        df = np.where(r_cnt != g_cnt)[0]
        print(f"  #{n} etiqueta {yte[n]} | contadores {'OK' if c_ok else 'DIFIEREN en '+str(len(df))}"
              f" | digito RTL {r_dig} vs golden {g_dig}")
        if len(df):
            print(f"     primeros distintos {df[:6]}  rtl={r_cnt[df[:6]]} golden={g_cnt[df[:6]]}")

print(f"\nhistograma identico: {ok_c}/{N}   ·   digito identico al golden: {ok_d}/{N}")
print(f"precision del RTL contra la etiqueta real: {ok_y}/{N} = {100*ok_y/N:.1f}%")
