#!/usr/bin/env python3
"""verificar_calib_10k.py — el RTL calibrado sobre las 10 000, contra el golden.

Dos preguntas distintas, que conviene no mezclar:
  1. ¿el RTL hace lo mismo que el golden?  -> imagen por imagen, tiene que ser identico
  2. ¿la calibracion gana?                 -> hace falta el test entero: con 200 imagenes
     una diferencia de 1.7 puntos queda dentro del ruido de muestreo
"""
import numpy as np, subprocess, os, sys, time, warnings; warnings.filterwarnings("ignore")
import frente_golden as fg
from canny1_mnist import frente_canny1

R = os.path.abspath("rtl")
N = int(sys.argv[1]) if len(sys.argv) > 1 else 10000
_,_,Xte,yte = fg.cargar_mnist()
m,o = frente_canny1(Xte[:N], 90, 32)
pc = np.load("pesos_canny_fw_calib.npz"); W,bC,bO = pc["W"], pc["b"], pc["b_orig"]
B_MIN,B_MAX,MARGEN = [int(x) for x in pc["B"]]

def rtl(vvp, cnt, nb):
    with open(f"{R}/tmp/c.hex","w") as f:
        f.write("".join(f"{int(x):x}\n" for x in list(cnt)+[nb]))
    subprocess.run(["vvp", f"tmp/{vvp}", "+IN=tmp/c.hex", "+OUT=tmp/c.out"],
                   cwd=R, capture_output=True)
    return [int(x) for x in open(f"{R}/tmp/c.out").read().split()]

t0=time.time(); malC=malO=0; accC=accO=0; gaccC=gaccO=0; nadaC=0
for i in range(N):
    cnt = fg.contadores(m[i], o[i]); nb = int(m[i].sum()); F = fg.descriptor(cnt)
    sC = F@W.T+bC; gC = int(sC.argmax()); ss=np.sort(sC)
    gvC = int(B_MIN <= nb <= B_MAX and ss[-1]-ss[-2] > MARGEN)
    gO  = int((F@W.T+bO).argmax())
    dC,vC,_ = rtl("clf_calib.vvp", cnt, nb)
    dO,_,_  = rtl("clf_orig.vvp",  cnt, nb)
    malC += (dC,vC)!=(gC,gvC); malO += dO!=gO
    accC += dC==yte[i]; accO += dO==yte[i]
    gaccC += gC==yte[i]; gaccO += gO==yte[i]; nadaC += vC
    if (i+1) % 500 == 0:
        print(f"  [{time.time()-t0:5.0f}s] {i+1:5}/{N}  calib {accC/(i+1):.2%}  "
              f"orig {accO/(i+1):.2%}  discrepancias {malC}/{malO}", flush=True)

print(f"\n  === 1. EL RTL CONTRA EL GOLDEN, imagen por imagen ({N}) ===")
print(f"    calibrado: {N-malC}/{N} identicos   {'OK' if malC==0 else 'FALLA'}")
print(f"    original:  {N-malO}/{N} identicos   {'OK' if malO==0 else 'FALLA'}")
print(f"\n  === 2. ¿GANA LA CALIBRACION? ===")
print(f"    RTL original:  {accO}/{N} = {accO/N:.2%}")
print(f"    RTL calibrado: {accC}/{N} = {accC/N:.2%}   ({(accC-accO)/N:+.2%})")
print(f"    (golden: {gaccO/N:.2%} -> {gaccC/N:.2%})")
n=accC-accO; print(f"    diferencia: {n:+d} imagenes de {N}")
print(f"\n    NADA acepta {nadaC}/{N} = {nadaC/N:.2%}")
print(f"\n  [{time.time()-t0:.0f}s]")
