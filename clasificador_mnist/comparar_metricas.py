#!/usr/bin/env python3
"""comparar_metricas.py — TODAS las metricas, Sobel vs Canny, con el MISMO procedimiento.

Las cifras que andaban sueltas no eran comparables: el NADA del Sobel se calibro mirando test
-fuga de informacion- y el del Canny sobre entrenamiento. Aca los dos se entrenan, calibran y
evaluan igual, asi la comparacion es de igual a igual.

  entrenar (60 000) -> cuantizar a 4 bits -> calibrar NADA sobre TRAIN -> medir sobre los 10 000
"""
import numpy as np, warnings, time; warnings.filterwarnings("ignore")
from sklearn.linear_model import LogisticRegression
import frente_golden as fg
from canny1_mnist import frente_canny1

NIVEL, BITS = 1, 4
# Los dos filtros, CON LOS PARAMETROS DE SUS DISENOS REALES: el Sobel de la tesis usa
# thr=60 (es lo que tiene mnist_feat.v) y el Canny 110/40. Un barrido sobre 20 000 habia
# sugerido thr=110 para el Sobel, pero con las 60 000 ese umbral HUNDE el recall del 9
# de 89.5 % a 40.6 % y cuesta 4.75 puntos: el optimo de la muestra chica no transfiere.
FRENTES = {"Sobel":  lambda X: fg.frente(X, 60),
           "Canny1": lambda X: frente_canny1(X, 110, 40)}

Xtr, ytr, Xte, yte = fg.cargar_mnist()
R = {}
for nom, f in FRENTES.items():
    t0 = time.time()
    mtr, otr = f(Xtr); mte, ote = f(Xte)
    Ftr = fg.piramide(mtr, otr, NIVEL); Fte = fg.piramide(mte, ote, NIVEL)
    ntr = mtr.sum(axis=(1,2)); nte = mte.sum(axis=(1,2))
    clf = LogisticRegression(max_iter=5000, C=0.002).fit(Ftr, ytr)
    Wq, esc = fg.cuantizar(clf.coef_, BITS); bq = np.round(clf.intercept_/esc).astype(int)
    Str, Ste = Ftr @ Wq.T + bq, Fte @ Wq.T + bq
    ptr, pte = Str.argmax(1), Ste.argmax(1)
    mg = lambda S: np.sort(S,1)[:,-1] - np.sort(S,1)[:,-2]
    mgtr, mgte = mg(Str), mg(Ste)
    # NADA calibrada SOLO con entrenamiento, mismo criterio para los dos
    B_MIN, B_MAX = int(np.percentile(ntr,5)), int(np.percentile(ntr,95))
    mejor = (0,0)
    for M in range(0,200,5):
        v = (ntr>=B_MIN)&(ntr<=B_MAX)&(mgtr>M)
        if v.mean() < .60: break
        pr = (ptr[v]==ytr[v]).mean()
        if pr > mejor[0]: mejor = (pr, M)
    MARGEN = mejor[1]
    val = (nte>=B_MIN)&(nte<=B_MAX)&(mgte>MARGEN)
    R[nom] = dict(pte=pte, val=val, area=mte.shape[1]*mte.shape[2],
                  B=(B_MIN,B_MAX,MARGEN), acc_tr=(ptr==ytr).mean())
    print(f"{nom} listo ({time.time()-t0:.0f}s) · area {R[nom]['area']} px · "
          f"NADA {B_MIN}/{B_MAX}/{MARGEN}")

# ---------------- metricas ----------------
def metricas(p, y, val):
    M = np.zeros((10,10),int)
    for a,b in zip(y,p): M[a,b]+=1
    P,Rc,F,VP,FP,FN,VN = (np.zeros(10) for _ in range(7))
    for c in range(10):
        VP[c]=M[c,c]; FN[c]=M[c].sum()-VP[c]; FP[c]=M[:,c].sum()-VP[c]
        VN[c]=M.sum()-VP[c]-FP[c]-FN[c]
        P[c]=VP[c]/(VP[c]+FP[c]); Rc[c]=VP[c]/(VP[c]+FN[c]); F[c]=2*P[c]*Rc[c]/(P[c]+Rc[c])
    ac=(p==y)
    # prefijo n* para el 2x2 de la clase NADA: VP/FP/FN/VN a secas ya son los arreglos
    # POR CLASE del uno-contra-el-resto. Son cuatro conceptos distintos con el mismo nombre.
    b2 = dict(nVP=int((val&ac).sum()), nFP=int((val&~ac).sum()),
              nFN=int((~val&ac).sum()), nVN=int((~val&~ac).sum()))
    return dict(M=M, P=P, R=Rc, F=F, VP=VP, FP=FP, FN=FN, VN=VN,
                acc=ac.mean(), f1=F.mean(), cob=val.mean(),
                prec=(p[val]==y[val]).mean(), **b2)

Z = {n: metricas(R[n]["pte"], yte, R[n]["val"]) for n in R}
print("\n" + "="*74)
print(f"{'':<34}{'Sobel':>18}{'Canny1':>18}")
print("="*74)
fil = [("area util (px)", lambda n: f"{R[n]['area']}", ""),
       ("exactitud (accuracy) test", lambda n: f"{Z[n]['acc']:.2%}", ""),
       ("exactitud train", lambda n: f"{R[n]['acc_tr']:.2%}", ""),
       ("F1 macro", lambda n: f"{Z[n]['f1']:.3f}", ""),
       ("", lambda n: "", ""),
       ("clase NADA:", lambda n: "", ""),
       ("  cobertura", lambda n: f"{Z[n]['cob']:.2%}", ""),
       ("  precision al hablar", lambda n: f"{Z[n]['prec']:.2%}", ""),
       ("  VP / FP", lambda n: f"{Z[n]['nVP']} / {Z[n]['nFP']}", ""),
       ("  FN / VN", lambda n: f"{Z[n]['nFN']} / {Z[n]['nVN']}", ""),
       ("  errores filtrados", lambda n: f"{Z[n]['nVN']/(Z[n]['nVN']+Z[n]['nFP']):.1%}", ""),
       ("  aciertos sacrificados", lambda n: f"{Z[n]['nFN']/(Z[n]['nFN']+Z[n]['nVP']):.1%}", "")]
for et, f, _ in fil:
    print(f"{et:<34}{f('Sobel'):>18}{f('Canny1'):>18}")
print("="*74)
print("\nPOR CLASE  (precision / recall / F1)")
print(f"{'dig':>4}{'Sobel P':>10}{'Sobel R':>10}{'Sobel F1':>10}   {'Canny P':>9}{'Canny R':>9}{'Canny F1':>9}")
for c in range(10):
    s,k = Z["Sobel"], Z["Canny1"]
    print(f"{c:>4}{s['P'][c]:10.2%}{s['R'][c]:10.2%}{s['F'][c]:10.3f}   "
          f"{k['P'][c]:9.2%}{k['R'][c]:9.2%}{k['F'][c]:9.3f}")
np.savez("comparar_metricas.npz",
         **{f"{n}_{k}": v for n in Z for k,v in Z[n].items() if isinstance(v,np.ndarray)},
         **{f"{n}_esc": np.array([Z[n]['acc'],Z[n]['f1'],Z[n]['cob'],Z[n]['prec'],
                                  Z[n]['nVP'],Z[n]['nFP'],Z[n]['nFN'],Z[n]['nVN']]) for n in Z})
print("\n-> comparar_metricas.npz")
