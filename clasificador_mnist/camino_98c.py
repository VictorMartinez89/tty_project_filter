#!/usr/bin/env python3
"""camino_98c.py — el ancho de los pesos: 8, 4, 2 y 1 bit, con activaciones y entrada en 8 bits.
Red de una capa oculta sobre los 168 rasgos de Canny-78 (hi=90 lo=32); test: las 10 000 oficiales.
Cuantización DESPUÉS de entrenar (post-training), por capa y con escala simétrica; 1 bit = signo × escala media.
-> camino_98c.json"""
import json, numpy as np, warnings; warnings.filterwarnings("ignore")
from sklearn.neural_network import MLPClassifier
import frente_golden as fg
from canny1_mnist import frente_canny1
Xtr,ytr,Xte,yte = fg.cargar_mnist()
mtr,otr = frente_canny1(Xtr,90,32); mte,ote = frente_canny1(Xte,90,32)
Ftr = fg.piramide(mtr,otr,2).astype(float); Fte = fg.piramide(mte,ote,2).astype(float)
esc = Ftr.max(0)+1e-9; Ftr/=esc; Fte/=esc
def qw(W,b):
    if b==1: return np.sign(W)*np.abs(W).mean()
    n=2**(b-1)-1; s=np.abs(W).max()/n; return np.clip(np.round(W/s),-n,n)*s
def qa(h,hmax): s=hmax/255; return np.clip(np.round(h/s),0,255)*s
filas=[]
for H in (32,128):
    m=MLPClassifier(hidden_layer_sizes=(H,),activation="relu",alpha=1e-4,batch_size=256,max_iter=60,
                    early_stopping=True,n_iter_no_change=6,random_state=0).fit(Ftr,ytr)
    W1,W2=m.coefs_; b1,b2=m.intercepts_
    hmax=np.percentile(np.maximum(Ftr@W1+b1,0),99.9); xq=np.round(Fte*255)/255
    for b in (8,4,2,1):
        h=qa(np.maximum(xq@qw(W1,b)+b1,0),hmax)
        acc=((h@qw(W2,b)+b2).argmax(1)==yte).mean()
        pesos=168*H+H*10
        f={"oculta":H,"bits":b,"exactitud":float(acc),"pesos":pesos,"kbit":round(pesos*b/1024,1)}
        filas.append(f); print(f,flush=True)
json.dump(filas,open("camino_98c.json","w"),indent=1)
