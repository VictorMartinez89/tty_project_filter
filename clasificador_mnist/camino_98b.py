#!/usr/bin/env python3
"""camino_98b.py — la prueba honesta de camino_98.py: pesos Y activaciones en 8 bits (como en un DSP), y una capa
oculta más grande. Entrada: los 168 rasgos de Canny-78 (hi=90 lo=32). Test: las 10 000 oficiales. -> camino_98b.json"""
import json, time, numpy as np, warnings; warnings.filterwarnings("ignore")
from sklearn.neural_network import MLPClassifier
import frente_golden as fg
from canny1_mnist import frente_canny1
t0=time.time()
Xtr,ytr,Xte,yte = fg.cargar_mnist()
mtr,otr = frente_canny1(Xtr,90,32); mte,ote = frente_canny1(Xte,90,32)
Ftr = fg.piramide(mtr,otr,2).astype(float); Fte = fg.piramide(mte,ote,2).astype(float)
esc = Ftr.max(0)+1e-9; Ftr/=esc; Fte/=esc
def q(W,b=8):
    s=np.abs(W).max()/(2**(b-1)-1); return np.round(W/s)*s
def qa(h,hmax,b=8):                       # activación ReLU en 8 bits sin signo, escala fija sacada del TRAIN
    s=hmax/(2**b-1); return np.clip(np.round(h/s),0,2**b-1)*s
filas=[]
for H in (128,256):
    t=time.time()
    m=MLPClassifier(hidden_layer_sizes=(H,),activation="relu",alpha=1e-4,batch_size=256,max_iter=60,
                    early_stopping=True,n_iter_no_change=6,random_state=0).fit(Ftr,ytr)
    W1,W2=m.coefs_; b1,b2=m.intercepts_
    hmax=np.percentile(np.maximum(Ftr@q(W1)+b1,0),99.9)
    xq=np.round(Fte*255)/255                                     # la entrada también en 8 bits
    h=qa(np.maximum(xq@q(W1)+b1,0),hmax)
    acc=((h@q(W2)+b2).argmax(1)==yte).mean()
    pesos=168*H+H*10
    f={"oculta":H,"float":float(m.score(Fte,yte)),"q8_pesos_y_activaciones":float(acc),"pesos":pesos,
       "spram_pct":round(100*pesos*8/(4*256*1024),1),"ciclos_8dsp":int(np.ceil(pesos/8))}
    filas.append(f); print(f, round(time.time()-t,1),"s", flush=True)
json.dump(filas,open("camino_98b.json","w"),indent=1)
