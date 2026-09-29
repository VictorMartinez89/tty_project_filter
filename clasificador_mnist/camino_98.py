#!/usr/bin/env python3
"""camino_98.py — ¿cuánto más reconoce la MISMA iCE40UP5K si se usan los recursos que Canny-78 deja quietos?

Canny-78 (97,22 %) es lineal y no toca los 8 DSP (16x16 + acumulador de 32) ni la SPRAM (4 x 256 kbit = 1 Mbit).
Aquí se mide, en Python y sobre las 10 000 imágenes oficiales de test (el train no se aumenta), un clasificador
de UNA capa oculta con ReLU, con los pesos cuantizados a 8 bits con signo (lo que multiplica un DSP), en dos
entradas:
   - los 168 rasgos de la pirámide de Canny-78 (el mismo front-end, hi=90 lo=32)
   - los 784 píxeles crudos (sin front-end)
Para cada modelo se anota: exactitud en coma flotante y con pesos de 8 bits, número de pesos, bits de memoria
(¿cabe en la SPRAM?), multiplicaciones-acumulaciones por imagen y ciclos con los 8 DSP en paralelo.
No es un circuito: es la cota de lo que el presupuesto de la tarjeta permitiría. Se escribe en camino_98.json.

  /opt/anaconda3/bin/python camino_98.py
"""
import json, time, numpy as np, warnings; warnings.filterwarnings("ignore")
from sklearn.neural_network import MLPClassifier
import frente_golden as fg
from canny1_mnist import frente_canny1

SPRAM_BITS = 4 * 256 * 1024          # 1 Mbit
NDSP, F_MHZ, FPS = 8, 12.0, 30       # 8 DSP, reloj de la tarjeta, cuadros por segundo de la cámara

t0 = time.time()
Xtr, ytr, Xte, yte = fg.cargar_mnist()
mtr, otr = frente_canny1(Xtr, 90, 32); mte, ote = frente_canny1(Xte, 90, 32)
Ftr = fg.piramide(mtr, otr, 2).astype(np.float64); Fte = fg.piramide(mte, ote, 2).astype(np.float64)
Ptr = Xtr.reshape(len(Xtr), -1) / 255.0; Pte = Xte.reshape(len(Xte), -1) / 255.0
esc = Ftr.max(0) + 1e-9                       # normalización fija (una división por constante = un desplazamiento)
Ftr, Fte = Ftr / esc, Fte / esc
print(f"[{time.time()-t0:6.1f}s] entradas listas: rasgos {Ftr.shape[1]}, píxeles {Ptr.shape[1]}", flush=True)


def q8(W):
    s = np.abs(W).max() / 127.0
    return np.round(W / s) * s


def prueba_q8(mlp, X):
    h = X
    for i, (W, b) in enumerate(zip(mlp.coefs_, mlp.intercepts_)):
        h = h @ q8(W) + b
        if i < len(mlp.coefs_) - 1:
            h = np.maximum(h, 0)
    return (h.argmax(1) == yte).mean()


filas = []
for nombre, Xa, Xb in [("168 rasgos", Ftr, Fte), ("784 píxeles", Ptr, Pte)]:
    for H in (32, 64, 128):
        t = time.time()
        mlp = MLPClassifier(hidden_layer_sizes=(H,), activation="relu", alpha=1e-4, batch_size=256,
                            max_iter=60, early_stopping=True, n_iter_no_change=6, random_state=0).fit(Xa, ytr)
        n_in = Xa.shape[1]
        pesos = n_in * H + H * 10
        mac = pesos
        fila = {"entrada": nombre, "oculta": H, "float": float(mlp.score(Xb, yte)), "q8": float(prueba_q8(mlp, Xb)),
                "pesos": pesos, "bits": pesos * 8, "spram_pct": round(100 * pesos * 8 / SPRAM_BITS, 1),
                "mac_por_imagen": mac, "ciclos_8dsp": int(np.ceil(mac / NDSP)),
                "imagenes_por_s": round(F_MHZ * 1e6 / np.ceil(mac / NDSP)), "segundos": round(time.time() - t, 1)}
        filas.append(fila)
        print(f"  {nombre:12} H={H:4}  float {fila['float']:.2%}  8b {fila['q8']:.2%}  pesos {pesos:7}  "
              f"SPRAM {fila['spram_pct']:5}%  ciclos {fila['ciclos_8dsp']:6}  ({fila['imagenes_por_s']} img/s)", flush=True)

json.dump({"referencia_canny78": 0.9722, "cuadros_por_s_camara": FPS, "filas": filas},
          open("camino_98.json", "w"), indent=1, ensure_ascii=False)
print(f"[{time.time()-t0:6.1f}s] fin -> camino_98.json", flush=True)
