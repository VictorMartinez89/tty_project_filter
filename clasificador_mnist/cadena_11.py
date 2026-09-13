#!/usr/bin/env python3
"""cadena_11.py — la cadena completa en iverilog, para las ONCE clases: 0..9 y NADA.

Para cada clase busca una imagen de test de ese digito, arma la escena de 640x480, la pasa por
  camara emulada -> cam_win28 -> mnist_feat_canny -> mnist_clf_canny
y anota que contesto el circuito. La ultima corrida es una hoja en BLANCO: deberia dar NADA.

  Uso:  python3 cadena_11.py
"""
import os, re, subprocess, sys, time
import numpy as np
import frente_golden as fg

A = os.path.dirname(os.path.abspath(__file__))
_, _, Xte, yte = fg.cargar_mnist(f"{A}/mnist.npz")
HI, LO = 110, 40

casos = [(int(np.nonzero(yte == d)[0][0]), d) for d in range(10)] + [(-1, "NADA")]
print(f"{'esperado':>9}{'circuito':>10}{'bordes':>8}{'seg':>6}")
ok = 0
for idx, esperado in casos:
    subprocess.run([sys.executable, f"{A}/gen_escena.py", str(idx), f"{A}/fpga/escena.hex"],
                   capture_output=True)
    t0 = time.time()
    r = subprocess.run(["vvp", "/tmp/cadena.vvp", "+ESC=escena.hex", f"+HI={HI}", f"+LO={LO}"],
                       cwd=f"{A}/fpga", capture_output=True, text=True)
    m = re.search(r">>> RESULTADO: (\S+)", r.stdout)
    b = re.search(r"bordes=(\d+)", r.stdout)
    got = m.group(1) if m else "?"
    acierta = (got == str(esperado)) if esperado != "NADA" else (got == "NADA")
    ok += acierta
    print(f"{str(esperado):>9}{got:>10}{b.group(1) if b else '?':>8}{time.time()-t0:6.0f}"
          f"   {'ok' if acierta else 'X'}")
print(f"\naciertos: {ok}/11")
