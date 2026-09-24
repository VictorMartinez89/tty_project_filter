#!/usr/bin/env python3
"""placa78.py — las 10 000 imagenes del test, por el puerto serie, a la iCESugar con el top78.

    /opt/anaconda3/bin/python placa78.py [N] [puerto]

  N       cuantas imagenes (10000 por defecto; 20 para una prueba corta)
  puerto  /dev/cu.usbmodem... (por defecto, el primero que aparezca)

La placa contesta un byte por imagen: 0x40 | valido<<4 | digito ('@'..'I' calla, 'P'..'Y' habla).
Se compara con el golden (los mismos pesos que el RTL verificado) digito Y valido, imagen por
imagen. Se manda en lotes de LOTE con 8 bytes de cola y una pausa: si la placa contesta '!' o
faltan respuestas, ese lote se repite. Un byte perdido cuesta un lote, no la corrida.

Lo que interesa NO es la exactitud (eso ya lo dice el golden: 97,22 %) sino CUANTAS IMAGENES
DICE LA PLACA LO MISMO QUE LA SIMULACION. El objetivo es 10 000 / 10 000.
La evidencia se guarda en fpga/evidencia/placa78_<fecha>.txt.
"""
import numpy as np, serial, glob, sys, time, os, datetime, warnings; warnings.filterwarnings("ignore")
import frente_golden as fg
from canny1_mnist import frente_canny1

N      = int(sys.argv[1]) if len(sys.argv) > 1 else 10000
PUERTO = sys.argv[2] if len(sys.argv) > 2 else (sorted(glob.glob("/dev/cu.usbmodem*")) or [None])[0]
LOTE   = 100
PAUSA  = 0.15          # > 50 ms de IDLE en la placa: el silencio realinea la cadena
if PUERTO is None:
    sys.exit("!! no hay /dev/cu.usbmodem*: la placa no esta conectada al Mac (o esta en la VM)")

print(f"golden de {N} imagenes...", flush=True)
_, _, Xte, yte = fg.cargar_mnist()
p = np.load("pesos_sel78.npz"); W, b, idx = p["W"], p["b"], p["idx"]
gold = np.zeros(N, int)
for lo in range(0, N, 1000):
    hi = min(lo + 1000, N)
    m, o = frente_canny1(Xte[lo:hi], 90, 32); S = fg.piramide(m, o, 2)[:, idx] @ W.T + b
    ss = np.sort(S, 1); nb = m.sum(axis=(1, 2))
    val = (nb >= 174) & (nb <= 376) & (ss[:, -1] - ss[:, -2] > 70)
    gold[lo:hi] = 0x40 | (val.astype(int) << 4) | S.argmax(1)

sp = serial.Serial(PUERTO, 115200, timeout=0.05)
time.sleep(0.3); sp.reset_input_buffer()
print(f"puerto {PUERTO} · lotes de {LOTE} · ~{N*784/11520/60:.1f} min\n", flush=True)

placa = np.full(N, -1)
repetidos = 0; t0 = time.time()
for lo in range(0, N, LOTE):
    hi = min(lo + LOTE, N)
    datos = Xte[lo:hi].astype(np.uint8).tobytes() + bytes(8)       # la cola de 8
    for intento in range(4):
        sp.reset_input_buffer()
        sp.write(datos); sp.flush()
        # esperar el tiempo de envio + la pausa de realineo, leyendo lo que llegue
        fin = time.time() + len(datos) / 11520 * 1.3 + PAUSA + 0.5
        r = b""
        while time.time() < fin and len(r) < hi - lo:
            r += sp.read(hi - lo - len(r))
        time.sleep(PAUSA); r += sp.read(64)
        if b"!" not in r and len(r) == hi - lo:
            placa[lo:hi] = list(r); break
        repetidos += 1
        print(f"  lote {lo//LOTE}: {len(r)} respuestas{' y un !' if b'!' in r else ''} -> se repite",
              flush=True)
        if len(r) == 0 and lo == 0:
            sys.exit("!! la placa no contesta NADA: revisar el pin RX (4) del pcf y el bitstream")
    igual = (placa[:hi] == gold[:hi]).sum()
    print(f"\r  {hi:5d}/{N}  iguales al golden {igual:5d}/{hi}  "
          f"({time.time()-t0:4.0f} s)", end="", flush=True)
print()

igual = int((placa == gold).sum())
dig_p = placa & 0xF; val_p = (placa >> 4) & 1
acc = float((dig_p == yte[:N]).mean())
habla = val_p == 1
lineas = [
    f"placa78 · {datetime.datetime.now():%Y-%m-%d %H:%M} · {PUERTO}",
    f"bitstream: mnist78_placa.bin (fpga_mnist78_stream.v + mnist_top78)",
    f"imagenes: {N}   lotes repetidos: {repetidos}",
    "",
    f"PLACA == SIMULACION (digito y valido): {igual} / {N}",
    f"exactitud de la placa (digito):        {acc:.2%}",
    f"habla: {habla.mean():.2%}   y acierta al hablar: {(dig_p[habla] == yte[:N][habla]).mean():.2%}",
]
dif = np.nonzero(placa != gold)[0]
if len(dif):
    lineas += ["", "DISCREPANCIAS (imagen: placa / golden):"]
    lineas += [f"  {i}: {chr(placa[i]) if placa[i] >= 0 else '-'} / {chr(gold[i])}" for i in dif[:50]]
print("\n" + "\n".join(lineas))
os.makedirs("fpga/evidencia", exist_ok=True)
ruta = f"fpga/evidencia/placa78_{datetime.datetime.now():%Y%m%d_%H%M}.txt"
with open(ruta, "w") as f:
    f.write("\n".join(lineas) + "\n\nrespuestas crudas:\n" + bytes(int(x) & 0xFF for x in placa).decode("latin1") + "\n")
print(f"\nevidencia -> {ruta}")
