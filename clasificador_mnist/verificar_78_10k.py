#!/usr/bin/env python3
"""verificar_78_10k.py — el clasificador de 78 caracteristicas sobre las 10 000.

Dos preguntas:
  1. el RTL nuevo (128 contadores, tabla de indices) reproduce el golden?
  2. cuanto acierta de verdad, sobre el test oficial entero?
"""
import numpy as np, subprocess, os, sys, time, warnings; warnings.filterwarnings("ignore")
import frente_golden as fg
from canny1_mnist import frente_canny1
R=os.path.abspath("rtl"); N=int(sys.argv[1]) if len(sys.argv)>1 else 10000
_,_,Xte,yte = fg.cargar_mnist()
m,o = frente_canny1(Xte[:N],90,32); F = fg.piramide(m,o,2)
p = np.load("pesos_sel78.npz"); W,b,idx = p["W"],p["b"],p["idx"]
B_MIN,B_MAX,MARGEN = 174,376,70
t0=time.time(); mal=0; acc=0; nada=0; acc_ok=0
for i in range(N):
    c128 = F[i,40:].astype(int); nb=int(m[i].sum())
    s = F[i,idx]@W.T+b; g=int(s.argmax()); ss=np.sort(s)
    gv = int(B_MIN<=nb<=B_MAX and ss[-1]-ss[-2]>MARGEN)
    with open(f"{R}/tmp/c78.hex","w") as f:
        f.write("".join(f"{int(x):x}\n" for x in list(c128)+[nb]))
    subprocess.run(["vvp","tmp/clf78.vvp","+IN=tmp/c78.hex","+OUT=tmp/c78.out"],
                   cwd=R,capture_output=True)
    d,v,_ = [int(x) for x in open(f"{R}/tmp/c78.out").read().split()]
    mal += (d,v)!=(g,gv); acc += d==yte[i]; nada += v
    if v: acc_ok += d==yte[i]
    if (i+1)%500==0:
        print(f"  [{time.time()-t0:5.0f}s] {i+1:5}/{N}  acierto {acc/(i+1):.2%}  "
              f"discrepancias {mal}", flush=True)
print(f"\n  === EL RTL DE 78 CONTRA EL GOLDEN ({N}) ===")
print(f"    {N-mal}/{N} identicos    {'OK' if mal==0 else 'FALLA'}")
print(f"\n  === ACIERTO ===")
print(f"    78 caracteristicas: {acc}/{N} = {acc/N:.2%}")
print(f"    (referencia: 40 por defecto 92.46 %, calibrado 94.20 %)")
print(f"    NADA acepta {nada}/{N} = {nada/N:.2%}; entre los aceptados {acc_ok}/{nada} = {acc_ok/max(nada,1):.2%}")
print(f"\n  [{time.time()-t0:.0f}s]")
