#!/usr/bin/env python3
# verificar.py — el golden de Python contra el RTL, imagen por imagen.
#   Compara los 32 contadores del histograma Y el digito predicho. Los contadores tienen que
#   coincidir EXACTAMENTE: si el hardware y el golden difieren en uno solo, el modelo entrenado
#   no es el que corre en el chip. Es la verificacion de las Partes 29-35 aplicada al clasificador.
import numpy as np, subprocess, os, sys
ns = {}
exec(open("../entrenar_hw.py").read().split("d = np.load")[0], ns)
frente = ns["frente"]

d = np.load("../mnist.npz"); Xte, yte = d["Xt"], d["yt"]
P = np.load("../pesos_hw.npz"); Wq, bq = P["W"], P["b"]
N = int(sys.argv[1]) if len(sys.argv) > 1 else 20

def golden(img):
    """Los 32 contadores (4 cuadrantes x 8 orientaciones) y el digito, en Python."""
    m, o = frente(img[None, :, :])
    m, o = m[0], o[0]
    HV, WV = m.shape
    cnt = np.zeros(32, int)
    for y in range(HV):
        for x in range(WV):
            if m[y, x]:
                z = (1 if y >= HV//2 else 0)*2 + (1 if x >= WV//2 else 0)
                cnt[z*8 + o[y, x]] += 1
    feat = np.concatenate([[cnt[z*8+k] for z in range(4)] for k in range(8)]).reshape(8,4).sum(1)
    x40 = np.concatenate([feat, cnt])
    return cnt, int((x40 @ Wq.T + bq).argmax())

os.makedirs("tmp", exist_ok=True)
ok_c = ok_d = 0
for n in range(N):
    img = Xte[n]
    with open(f"tmp/d{n}.hex", "w") as f:
        for v in img.ravel(): f.write(f"{v:02x}\n")
    subprocess.run(["vvp", "tmp/sim.vvp", f"+IMG=tmp/d{n}.hex", f"+OUT=tmp/o{n}.txt"],
                   capture_output=True)
    lin = open(f"tmp/o{n}.txt").read().split("\n")
    rtl_cnt = np.array([int(l) for l in lin[:32]])
    rtl_dig = int(lin[32].split()[1])
    g_cnt, g_dig = golden(img)
    c_ok = np.array_equal(rtl_cnt, g_cnt); d_ok = (rtl_dig == g_dig)
    ok_c += c_ok; ok_d += d_ok
    if not c_ok or not d_ok:
        print(f"  #{n} etiqueta {yte[n]} | contadores {'OK' if c_ok else 'DIFIEREN'} "
              f"| digito RTL {rtl_dig} vs golden {g_dig}")
        if not c_ok:
            df = np.where(rtl_cnt != g_cnt)[0]
            print(f"     contadores distintos: {df[:6]}  rtl={rtl_cnt[df[:6]]} golden={g_cnt[df[:6]]}")
print(f"\nhistograma identico: {ok_c}/{N}   ·   digito identico: {ok_d}/{N}")
