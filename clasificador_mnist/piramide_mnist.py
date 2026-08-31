#!/usr/bin/env python3
# piramide_mnist.py — el clasificador de digitos que SI cabe en silicio.
#
#   Front-end IDENTICO al RTL de la tesis: Gaussiano 3x3 -> Sobel -> |Gx|+|Gy| saturado
#   a 8 bits -> umbral. De ahi salen las orientaciones (el compass de 8 direcciones).
#   Encima: histograma por zonas en PIRAMIDE ESPACIAL (Lazebnik 2006) y un clasificador
#   LINEAL cuyos pesos se cuantizan a 1/2/4/8 bits, que es lo que costaria en flip-flops.
#
#   Barrido: nivel de piramide x bits por peso -> precision vs flip-flops.
import numpy as np, sys
from sklearn.linear_model import LogisticRegression

rng = np.random.default_rng(0)
d = np.load(sys.argv[1] if len(sys.argv) > 1 else "mnist.npz")
Xtr, ytr, Xte, yte = d["X"], d["y"], d["Xt"], d["yt"]

GAUSS = np.array([[1,2,1],[2,4,2],[1,2,1]], float)          # /16, el del RTL
GX    = np.array([[-1,0,1],[-2,0,2],[-1,0,1]], float)       # Sobel estandar
GY    = np.array([[-1,-2,-1],[0,0,0],[1,2,1]], float)

def conv3(img, k):
    """3x3 valida sobre el stack (N,H,W), como la ventana del linebuf3x3."""
    N,H,W = img.shape
    out = np.zeros((N,H-2,W-2))
    for i in range(3):
        for j in range(3):
            if k[i,j]: out += k[i,j]*img[:, i:i+H-2, j:j+W-2]
    return out

def frente(img, thr):
    """El front-end del chip: Gauss -> Sobel -> magnitud saturada -> umbral -> orientacion."""
    g  = conv3(img.astype(float), GAUSS)/16.0
    gx = conv3(g, GX); gy = conv3(g, GY)
    mag = np.minimum(np.abs(gx)+np.abs(gy), 255.0)           # |Gx|+|Gy| saturado a 8 bits
    ori = (np.round(np.arctan2(gy, gx)/(2*np.pi)*8) % 8).astype(np.int8)   # 8 direcciones
    return mag > thr, ori                                    # mascara de borde + orientacion

def piramide(mask, ori, niveles):
    """Histograma de orientaciones por zona, concatenando los niveles 0..niveles."""
    N,H,W = mask.shape
    feats = []
    for L in range(niveles+1):
        n = 2**L                                             # n x n zonas
        for zy in range(n):
            for zx in range(n):
                ys, ye = zy*H//n, (zy+1)*H//n
                xs, xe = zx*W//n, (zx+1)*W//n
                m = mask[:, ys:ye, xs:xe]; o = ori[:, ys:ye, xs:xe]
                for b in range(8):
                    feats.append(((o == b) & m).sum(axis=(1,2)))
    return np.stack(feats, axis=1).astype(np.float32)

def cuantizar(W, bits):
    """Cuantizacion simetrica. La escala NO se toma del maximo -un solo peso grande
    mandaria el resto a cero, que es justo lo que arruinaba la fila de 2 bits-, sino
    buscando la que menos error cuadratico deja. Es lo que haria un buen flujo de
    cuantizacion, y en hardware cuesta lo mismo: la escala es un desplazamiento."""
    if bits is None: return W
    lim = 2**(bits-1) - 1
    if lim == 0: return np.sign(W)*np.abs(W).mean()          # 1 bit = solo el signo
    mejor, mejor_err = None, np.inf
    for f in np.linspace(0.05, 1.0, 40):
        esc = np.abs(W).max()*f/lim
        Wq  = np.round(W/esc).clip(-lim, lim)*esc
        err = ((Wq-W)**2).sum()
        if err < mejor_err: mejor, mejor_err = Wq, err
    return mejor

THR = 60
print(f"front-end: Gauss 3x3 -> Sobel -> |Gx|+|Gy| sat 255 -> umbral {THR} -> 8 orientaciones\n")
mtr, otr = frente(Xtr, THR); mte, ote = frente(Xte, THR)
print(f"densidad de borde: train {mtr.mean():.1%}  test {mte.mean():.1%}\n")

print(f"{'piramide':<12}{'zonas':>6}{'carac':>7}{'pesos':>7} | " + "".join(f"{b if b else 'float':>8}" for b in [None,8,4,2,1]))
print("-"*12 + "-"*20 + "-+-" + "-"*40)
resultados = {}
for niv, etq in [(0,"nivel 0"), (1,"nivel 0+1"), (2,"nivel 0+1+2")]:
    Ftr = piramide(mtr, otr, niv); Fte = piramide(mte, ote, niv)
    zonas = sum(4**L for L in range(niv+1)); nf = Ftr.shape[1]
    mu, sd = Ftr.mean(0), Ftr.std(0)+1e-6
    clf = LogisticRegression(max_iter=2000, C=0.05, multi_class="multinomial")
    clf.fit((Ftr-mu)/sd, ytr)
    fila = f"{etq:<12}{zonas:>6}{nf:>7}{nf*10:>7} | "
    for bits in [None,8,4,2,1]:
        Wq = cuantizar(clf.coef_, bits)
        pred = (((Fte-mu)/sd) @ Wq.T + clf.intercept_).argmax(1)
        acc = (pred == yte).mean()
        fila += f"{acc:>7.1%} "
        resultados[(niv,bits)] = (acc, nf, pred)
    print(fila)

# la prueba del 6 vs 9: es lo que la bolsa pura no puede separar
print("\nconfusion 6<->9 (test):")
for niv, etq in [(0,"nivel 0 (bolsa pura)"), (1,"nivel 0+1 (con piramide)")]:
    pred = resultados[(niv,4)][2]
    n69 = int(((yte==6)&(pred==9)).sum()); n96 = int(((yte==9)&(pred==6)).sum())
    tot6 = int((yte==6).sum()); tot9 = int((yte==9).sum())
    print(f"  {etq:<26} 6 leido como 9: {n69:4d}/{tot6}   9 leido como 6: {n96:4d}/{tot9}")

# linea de base: los pixeles crudos
clf = LogisticRegression(max_iter=400, C=0.01)
clf.fit(Xtr.reshape(len(Xtr),-1)/255.0, ytr)
acc = clf.score(Xte.reshape(len(Xte),-1)/255.0, yte)
print(f"\nlinea de base — 784 pixeles crudos + lineal: {acc:.1%}  ({784*10} pesos)")
