"""frente_golden.py — el modelo GOLDEN del front-end, en un solo lugar.

Es la referencia contra la que se verifica el RTL (`rtl/mnist_feat.v`), y modela **lo que el
silicio hace**, no la version matematica bonita. Esa es la regla de toda la tesis: si el hardware
trunca, el golden trunca; si el hardware satura a 8 bits, el golden satura.

Las cuatro decisiones que lo atan al RTL, y por que:

* **`/16` del Gaussiano es un `floor`**, no un redondeo: en el RTL es `gsum[11:4]`, un shift.
* **La magnitud es `|Gx|+|Gy|` saturada a 255**, sin raiz cuadrada. Por eso el filtro no lleva
  multiplicadores, que es lo que lo hace caber.
* **La orientacion es el OCTANTE** `{sgn(Gy), sgn(Gx), |Gy|>|Gx|}`: tres comparaciones y cero
  multiplicaciones. Un `atan2` pediria un CORDIC o una tabla. Son los mismos ocho sectores de 45
  grados, con los bordes en 0/45/90... en vez de centrados.
* **La convolucion es `valid`**: sin relleno de bordes. Una imagen de HxW deja (H-4)x(W-4) tras las
  dos etapas 3x3, y esa es exactamente el area que el RTL cuenta.

Antes esto vivia duplicado en cuatro scripts, y dos de ellos lo importaban con un
`exec(open(...).read().split(...))`. Un cambio en el front-end tenia que replicarse a mano en
todos: la receta perfecta para que el golden y el RTL se separen sin que nadie lo note.
"""
import numpy as np

# --- los tres kernels del RTL ---
GAUSS = np.array([[1, 2, 1], [2, 4, 2], [1, 2, 1]], float)      # /16
SOBEL_X = np.array([[-1, 0, 1], [-2, 0, 2], [-1, 0, 1]], float)
SOBEL_Y = np.array([[-1, -2, -1], [0, 0, 0], [1, 2, 1]], float)

UMBRAL = 60          # el mismo `thr` que recibe mnist_feat
N_BINS = 8           # octantes


def conv3(img, k):
    """Convolucion 3x3 'valid' sobre un stack (N,H,W) -> (N,H-2,W-2).

    Es la ventana que produce `linebuf3x3`: la salida (i,j) usa img[i:i+3, j:j+3], o sea el
    vecindario centrado en (i+1, j+1)."""
    N, H, W = img.shape
    out = np.zeros((N, H - 2, W - 2))
    for i in range(3):
        for j in range(3):
            if k[i, j]:
                out += k[i, j] * img[:, i:i + H - 2, j:j + W - 2]
    return out


def frente(img, thr=UMBRAL):
    """El front-end completo. Entra (N,H,W) uint8; salen (mascara, orientacion) de (N,H-4,W-4).

    Gauss/16 (truncado) -> Sobel -> |Gx|+|Gy| saturado a 255 -> umbral -> octante.
    """
    if img.ndim == 2:
        img = img[None]
    g = np.floor(conv3(img.astype(float), GAUSS) / 16.0)        # /16 es un shift: trunca
    gx = conv3(g, SOBEL_X)
    gy = conv3(g, SOBEL_Y)
    mag = np.minimum(np.abs(gx) + np.abs(gy), 255.0)            # saturacion a 8 bits
    sy = (gy >= 0).astype(np.int8)
    sx = (gx >= 0).astype(np.int8)
    d45 = (np.abs(gy) > np.abs(gx)).astype(np.int8)
    return mag > thr, (sy * 4 + sx * 2 + d45).astype(np.int8)


def contadores(mascara, orient):
    """Los 32 contadores del RTL: 4 cuadrantes x 8 orientaciones, para UNA imagen.

    Es lo que `mnist_feat.v` guarda de verdad. El nivel 0 de la piramide no se guarda porque
    es la suma de los cuatro cuadrantes -son una particion-: se deriva."""
    H, W = mascara.shape
    c = np.zeros(32, int)
    for y in range(H):
        for x in range(W):
            if mascara[y, x]:
                z = (1 if y >= H // 2 else 0) * 2 + (1 if x >= W // 2 else 0)
                c[z * N_BINS + orient[y, x]] += 1
    return c


def descriptor(cnt32):
    """Los 32 contadores -> las 40 caracteristicas (piramide nivel 0+1), como hace `mnist_clf.v`.

    k = 0..7  -> nivel 0: suma de los cuatro cuadrantes en esa orientacion
    k = 8..39 -> nivel 1: el contador del cuadrante tal cual"""
    nivel0 = np.array([sum(cnt32[z * N_BINS + k] for z in range(4)) for k in range(N_BINS)])
    return np.concatenate([nivel0, cnt32])


def piramide(mascara, orient, niveles=1):
    """Version vectorizada para entrenar: (N,H,W) -> (N, 8*sum(4^l)) caracteristicas.

    Con niveles=1 da las mismas 40 que `descriptor`, pero para todo el lote de una."""
    N, H, W = mascara.shape
    feats = []
    for L in range(niveles + 1):
        n = 2 ** L
        for zy in range(n):
            for zx in range(n):
                m = mascara[:, zy * H // n:(zy + 1) * H // n, zx * W // n:(zx + 1) * W // n]
                o = orient[:, zy * H // n:(zy + 1) * H // n, zx * W // n:(zx + 1) * W // n]
                for b in range(N_BINS):
                    feats.append(((o == b) & m).sum(axis=(1, 2)))
    return np.stack(feats, axis=1).astype(np.float32)


def cuantizar(W, bits):
    """Cuantizacion simetrica con la escala de MINIMO ERROR CUADRATICO.

    NO se toma la escala del peso maximo: un solo peso grande mandaria el resto a cero y la fila
    de 2 bits saldria peor que la de 1 bit. En hardware la escala no cuesta nada -es un
    desplazamiento- y el argmax es invariante a ella, asi que ni siquiera hay que aplicarla."""
    lim = 2 ** (bits - 1) - 1
    if lim == 0:
        return np.sign(W) * np.abs(W).mean(), 1.0
    mejor, err_min, esc_mejor = None, np.inf, None
    for f in np.linspace(0.05, 1.0, 40):
        esc = np.abs(W).max() * f / lim
        Wq = np.round(W / esc).clip(-lim, lim)
        e = ((Wq * esc - W) ** 2).sum()
        if e < err_min:
            mejor, err_min, esc_mejor = Wq, e, esc
    return mejor.astype(int), esc_mejor


def cargar_mnist(ruta="mnist.npz"):
    """Devuelve (Xtr, ytr, Xte, yte). Si falta el .npz, dice como generarlo."""
    import os
    if not os.path.exists(ruta):
        raise SystemExit(f"falta {ruta} — generalo con:  bash bajar_mnist.sh")
    d = np.load(ruta)
    return d["X"], d["y"], d["Xt"], d["yt"]
