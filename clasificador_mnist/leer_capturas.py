#!/usr/bin/env python3
"""leer_capturas.py — reconstruye las ventanas de 28x28 que volco la placa por UART.

Formato que emite cam_uart_win.v:   IMG \n  28 lineas de 28 bytes hex  \n END
Se descartan los bloques incompletos (el `cat` puede cortar a mitad de una captura).
"""
import re, sys
import numpy as np

def leer(ruta):
    t = open(ruta, encoding="ascii", errors="replace").read()
    imgs = []
    for blq in re.findall(r"IMG\n(.*?)END", t, re.S):
        fil = [l.split() for l in blq.strip().split("\n")]
        fil = [f for f in fil if len(f) == 28]
        if len(fil) == 28:
            try:
                imgs.append(np.array([[int(v, 16) for v in f] for f in fil], dtype=np.uint8))
            except ValueError:
                pass
    return imgs

if __name__ == "__main__":
    for r in sys.argv[1:]:
        im = leer(r)
        if im:
            A = np.stack(im)
            print(f"{r.split('/')[-1]:<22} {len(im):3d} capturas completas · "
                  f"media {A.mean():5.1f} · rango {A.min():3d}..{A.max():3d} · "
                  f"desv entre capturas {A.std(axis=0).mean():5.2f}")
        else:
            print(f"{r.split('/')[-1]:<22} sin capturas completas")
