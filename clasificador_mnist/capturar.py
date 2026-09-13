#!/usr/bin/env python3
"""capturar.py — lee las ventanas de 28x28 que vuelca la placa, SIN stty.

En macOS, abrir /dev/cu.* reinicia la configuracion del puerto, asi que el clasico
    stty -f $D 38400 ... ; cat $D
puede terminar leyendo a otra velocidad que la fijada: llegan algunos bytes buenos al
principio y despues basura. Este script abre el puerto Y fija los baudios en el MISMO
proceso, que es la unica forma de garantizar que coincidan.

  Uso:  python3 capturar.py salida.npz [segundos] [baudios]
"""
import glob, re, sys, time
import numpy as np
import serial

SAL = sys.argv[1] if len(sys.argv) > 1 else "captura.npz"
SEG = float(sys.argv[2]) if len(sys.argv) > 2 else 15
BAUD = int(sys.argv[3]) if len(sys.argv) > 3 else 38400

p = sorted(glob.glob("/dev/cu.usbmodem*"))
if not p:
    raise SystemExit("no encuentro /dev/cu.usbmodem* — esta enchufada la placa?")
print(f"puerto {p[0]} a {BAUD} baudios, {SEG:.0f} s")

buf = b""
with serial.Serial(p[0], BAUD, timeout=0.5) as s:
    s.reset_input_buffer()
    t0 = time.time()
    while time.time() - t0 < SEG:
        buf += s.read(4096)
        print(f"\r  {len(buf):7d} bytes  ·  {time.time()-t0:4.1f} s", end="", flush=True)
print()

txt = buf.decode("ascii", errors="replace")
imgs = []
for blq in re.findall(r"IMG\n(.*?)END", txt, re.S):
    fil = [l.split() for l in blq.strip().split("\n")]
    fil = [f for f in fil if len(f) == 28 and all(re.fullmatch(r"[0-9a-f]{2}", v) for v in f)]
    if len(fil) == 28:
        imgs.append(np.array([[int(v, 16) for v in f] for f in fil], dtype=np.uint8))

val = sum(1 for c in txt if c in "0123456789abcdef \n")
print(f"\nASCII valido: {val}/{len(txt)} = {val/max(1,len(txt)):.1%}")
print(f"bloques IMG..END: {txt.count('IMG')}  ·  capturas COMPLETAS: {len(imgs)}")
if imgs:
    A = np.stack(imgs)
    print(f"media {A.mean():.1f} · rango {A.min()}..{A.max()} · "
          f"desv entre capturas {A.std(axis=0).mean():.2f}")
    np.savez(SAL, imgs=A)
    print(f"-> {SAL}")
else:
    open(SAL + ".crudo.txt", "w").write(txt)
    print(f"ninguna captura completa; el flujo crudo quedo en {SAL}.crudo.txt")
