#!/usr/bin/env python3
"""verificar_bram_10k.py — el clasificador CON MEMORIA sobre las 10 000."""
import numpy as np, subprocess, os, sys, time, warnings; warnings.filterwarnings("ignore")
import frente_golden as fg
from canny1_mnist import frente_canny1
R=os.path.abspath("rtl"); N=int(sys.argv[1]) if len(sys.argv)>1 else 10000
_,_,Xte,yte=fg.cargar_mnist(); m,o=frente_canny1(Xte[:N],90,32); F=fg.piramide(m,o,2)
p=np.load("pesos_sel78.npz"); W,b,idx=p["W"],p["b"],p["idx"]
t0=time.time(); mal=0; acc=0; nada=0; cic=0
for i in range(N):
    c128=F[i,40:].astype(int); nb=int(m[i].sum())
    s=F[i,idx]@W.T+b; g=int(s.argmax()); ss=np.sort(s)
    gv=int(174<=nb<=376 and ss[-1]-ss[-2]>70)
    open(f"{R}/tmp/cb.hex","w").write("".join(f"{int(x):x}\n" for x in list(c128)+[nb]))
    subprocess.run(["vvp","tmp/clf78bram.vvp","+IN=tmp/cb.hex","+OUT=tmp/cb.out"],
                   cwd=R,capture_output=True)
    d,v,sc,n=[int(x) for x in open(f"{R}/tmp/cb.out").read().split()]; cic=n
    mal += (d,v)!=(g,gv); acc += d==yte[i]; nada += v
    if (i+1)%1000==0:
        print(f"  [{time.time()-t0:5.0f}s] {i+1:5}/{N}  acierto {acc/(i+1):.2%}  discrepancias {mal}", flush=True)
print(f"\n  === CLASIFICADOR CON MEMORIA vs GOLDEN ({N}) ===")
print(f"    {N-mal}/{N} identicos   {'OK' if mal==0 else 'FALLA'}")
print(f"    acierto {acc}/{N} = {acc/N:.2%}   ·  NADA acepta {nada/N:.2%}")
print(f"    {cic} ciclos por imagen (presupuesto de un cuadro: 784)")
print(f"  [{time.time()-t0:.0f}s]")
