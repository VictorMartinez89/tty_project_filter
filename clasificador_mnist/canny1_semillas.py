import sys; sys.path.insert(0, "/Users/vic/UN/Tesis/Repository/tty_project_filter/clasificador_mnist")
import numpy as np, warnings
warnings.filterwarnings("ignore")
from sklearn.linear_model import LogisticRegression
import frente_golden as fg
exec(open("canny1_mnist.py").read().split("def evalua")[0].split('import frente_golden as fg')[1])

def fit(Ftr, ytr, Fte, yte):
    clf = LogisticRegression(max_iter=3000, C=0.002).fit(Ftr, ytr)
    Wq, esc = fg.cuantizar(clf.coef_, 4)
    bq = np.round(clf.intercept_/esc).astype(int)
    return clf.score(Fte, yte), ((Fte@Wq.T+bq).argmax(1)==yte).mean()

X, y, Xte, yte = fg.cargar_mnist()
# los frentes se calculan UNA vez sobre todo, despues se submuestrea
frentes = {}
ms, os_ = fg.frente(X, 110);  mt, ot = fg.frente(Xte, 110)
frentes["Sobel thr=110  24x24"] = (fg.piramide(ms,os_,1), fg.piramide(mt,ot,1))
frentes["Sobel thr=110  22x22*"] = (fg.piramide(ms[:,1:-1,1:-1],os_[:,1:-1,1:-1],1),
                                    fg.piramide(mt[:,1:-1,1:-1],ot[:,1:-1,1:-1],1))
for hi,lo in [(110,40),(75,25)]:
    ms,os_ = frente_canny1(X,hi,lo); mt,ot = frente_canny1(Xte,hi,lo)
    frentes[f"Canny1 hi={hi} lo={lo} 22x22"] = (fg.piramide(ms,os_,1), fg.piramide(mt,ot,1))

print("5 semillas x 20 000 imagenes de entrenamiento, test = las 10 000\n")
print(f"{'front-end':<26} {'float':>16}   {'4 bits':>16}")
res={}
for nom,(Ftr_all,Fte_) in frentes.items():
    a_f,a_q=[],[]
    for s in range(5):
        rng=np.random.default_rng(s); idx=rng.choice(len(y),20000,replace=False)
        f,q = fit(Ftr_all[idx], y[idx], Fte_, yte); a_f.append(f); a_q.append(q)
    res[nom]=(np.mean(a_f),np.std(a_f),np.mean(a_q),np.std(a_q))
    print(f"{nom:<26} {np.mean(a_f):6.2%} ± {np.std(a_f):.2%}   {np.mean(a_q):6.2%} ± {np.std(a_q):.2%}")
np.savez("canny1_semillas.npz", **{k:np.array(v) for k,v in res.items()})
b=res["Sobel thr=110  24x24"]; c=res["Canny1 hi=110 lo=40 22x22"]
d=c[2]-b[2]; sd=np.hypot(b[3],c[3])
print(f"\nCanny1 - Sobel  (4 bits) = {d:+.2%}   desviacion combinada = {sd:.2%}")
print("VEREDICTO:", "diferencia REAL (>2 sigma)" if abs(d)>2*sd else "DENTRO DEL RUIDO: no se puede afirmar que uno gane")
