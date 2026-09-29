#!/usr/bin/env python3
"""canny98_hex.py — de pesos_canny98_H120.npz a los .hex que lee mnist_clf98.v, y el lote de prueba:
rtl/canny98_w.hex (21 504 pesos de 4 bits: W1 en j*168+k, W2 en 20160+c*120+j), canny98_b1.hex, canny98_b2.hex,
rtl/tmp/c98_lote.hex (por imagen: 128 contadores + n_bordes) y rtl/tmp/c98_esperado.txt (digito valido score)."""
import numpy as np, sys, os
import frente_golden as fg
from canny1_mnist import frente_canny1
N = int(sys.argv[1]) if len(sys.argv) > 1 else 10000
p = np.load("pesos_canny98_H120.npz"); W1, b1, S, W2, b2 = p["W1q"], p["b1i"], int(p["S"]), p["W2q"], p["b2i"]
H = W1.shape[0]; assert H == 120 and W1.shape[1] == 168 and S == 2
w = np.zeros(21504, dtype=np.int64); w[:H*168] = W1.reshape(-1); w[H*168:H*168+10*H] = W2.reshape(-1)
assert np.abs(w).max() <= 7 and -256 <= b1.min() and b1.max() <= 255 and -256 <= b2.min() and b2.max() <= 255
open("rtl/canny98_w.hex", "w").write("".join(f"{int(x) & 0xF:x}\n" for x in w))
open("rtl/canny98_b1.hex", "w").write("".join(f"{int(x) & 0x1FF:03x}\n" for x in list(b1) + [0]*(128-len(b1))))
open("rtl/canny98_b2.hex", "w").write("".join(f"{int(x) & 0x1FF:03x}\n" for x in list(b2) + [0]*6))
_, _, Xte, yte = fg.cargar_mnist(); m, o = frente_canny1(Xte[:N], 90, 32); F = fg.piramide(m, o, 2).astype(np.int64)
Fhw = np.concatenate([F[:, 40:168], F[:, 8:40], F[:, 0:8]], axis=1)
nb = m.reshape(N, -1).sum(1)
acc1 = Fhw @ W1.T + b1; h = np.clip(acc1 >> S, 0, 255); s = h @ W2.T + b2
dig = s.argmax(1); ss = np.sort(s, 1); val = ((nb >= 174) & (nb <= 376) & (ss[:, -1] - ss[:, -2] > 0)).astype(int)
os.makedirs("rtl/tmp", exist_ok=True)
with open("rtl/tmp/c98_lote.hex", "w") as f:
    for i in range(N):
        f.write("".join(f"{int(x):x}\n" for x in list(F[i, 40:]) + [int(nb[i])]))
np.savetxt("rtl/tmp/c98_esperado.txt", np.stack([dig, val, s.max(1), yte[:N]], 1), fmt="%d")
print(f"  {N} imágenes · exactitud del modelo {(dig == yte[:N]).mean():.2%} · valido {val.mean():.2%}")
