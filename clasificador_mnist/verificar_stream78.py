#!/usr/bin/env python3
"""verificar_stream78.py — la placa del flujo serie, simulada con la UART real, contra el golden.

    python3 verificar_stream78.py [NB] [NLOT] [PERDER] [DIV]

  NB     imagenes por lote            (4)
  NLOT   lotes                        (3)
  PERDER lote en que se omite un byte (-1 = ninguno)
  DIV    ciclos por bit de la UART    (8; el de la placa es 104 y es lento de simular)

Cada respuesta es 0x40 | valido<<4 | digito. Se compara digito Y valido, imagen por imagen.
Si PERDER >= 0, ese lote tiene derecho a salir mal; lo que se exige es que el LED rojo se
encienda y que los lotes DESPUES salgan perfectos.
"""
import numpy as np, subprocess, os, sys, warnings; warnings.filterwarnings("ignore")
import frente_golden as fg
from canny1_mnist import frente_canny1

NB     = int(sys.argv[1]) if len(sys.argv) > 1 else 4
NLOT   = int(sys.argv[2]) if len(sys.argv) > 2 else 3
PERDER = int(sys.argv[3]) if len(sys.argv) > 3 else -1
DIV    = int(sys.argv[4]) if len(sys.argv) > 4 else 8
N = NB * NLOT
F = os.path.abspath("fpga"); TAG = str(os.getpid())
os.makedirs(f"{F}/tmp", exist_ok=True)

_, _, Xte, yte = fg.cargar_mnist()
p = np.load("pesos_sel78.npz"); W, b, idx = p["W"], p["b"], p["idx"]
m, o = frente_canny1(Xte[:N], 90, 32); Fe = fg.piramide(m, o, 2)
gold = []
for i in range(N):
    nb = int(m[i].sum()); s = Fe[i, idx] @ W.T + b; ss = np.sort(s)
    gold.append(0x40 | (int(174 <= nb <= 376 and ss[-1] - ss[-2] > 70) << 4) | int(s.argmax()))

with open(f"{F}/tmp/s78_{TAG}.hex", "w") as f:
    for i in range(N): f.write("".join(f"{int(x):02x}\n" for x in Xte[i].ravel()))
src = ["tb_stream78.v", "fpga_mnist78_stream.v", "uart_rx.v", "uart_tx.v",
       "../rtl/mnist_top78.v", "../rtl/mnist_feat16_mem.v", "../rtl/mnist_clf78_x2.v",
       "../rtl/linebuf3x3.v"]
# se recompila SIEMPRE: un .vvp viejo ya dio una vez 26/40 con el diseno correcto (§36.9)
subprocess.run(["iverilog", "-g2012", "-I../rtl", f"-Ptb_stream78.DIV={DIV}",
                "-o", f"tmp/s78_{TAG}.vvp"] + src, cwd=F, check=True)
subprocess.run(["vvp", "-n", f"tmp/s78_{TAG}.vvp", f"+IN=tmp/s78_{TAG}.hex",
                f"+OUT=tmp/s78_{TAG}.out", f"+NB={NB}", f"+NLOT={NLOT}", f"+PERDER={PERDER}"],
               cwd=F, check=True, stdout=subprocess.DEVNULL)

lotes, perdido, excl = [], None, []
for ln in open(f"{F}/tmp/s78_{TAG}.out"):
    t = ln.split()
    if t[0] == "LOTE": lotes.append([])
    elif t[0] == "R":
        # el '!' llega DURANTE la pausa del lote roto, antes del marcador del siguiente
        if int(t[1]) == 0x21: excl.append(len(lotes) - 1)
        else: lotes[-1].append(int(t[1]))
    elif t[0] == "PERDIDO": perdido = int(t[1])

print(f"flujo serie · {NLOT} lotes de {NB} · DIV={DIV} · byte perdido en el lote {PERDER}\n")
todo_ok = True
for l, r in enumerate(lotes):
    g = gold[l * NB:(l + 1) * NB]
    ok = sum(a == c for a, c in zip(r, g))
    esperado_mal = (l == PERDER)
    bien = (len(r) == NB and ok == NB)
    marca = "OK" if bien else ("roto, y debia" if esperado_mal else "!! FALLA")
    if not bien and not esperado_mal: todo_ok = False
    print(f"  lote {l}: {len(r)} respuestas, {ok}/{NB} iguales al golden   {marca}")
    if not bien and not esperado_mal:
        print("     placa :", " ".join(chr(x) for x in r))
        print("     golden:", " ".join(chr(x) for x in g))
esp_led = 1 if PERDER >= 0 else 0
print(f"\n  LED rojo (byte perdido): {perdido}   esperado {esp_led}   "
      f"{'OK' if perdido == esp_led else '!! FALLA'}")
todo_ok &= (perdido == esp_led)
esp_excl = [PERDER] if PERDER >= 0 else []
print(f"  '!' recibidos tras el lote: {excl}   esperado {esp_excl}   "
      f"{'OK' if excl == esp_excl else '!! FALLA'}")
todo_ok &= (excl == esp_excl)
print("\n  " + ("TODO OK" if todo_ok else "HAY FALLOS"))
for x in ("hex", "out", "vvp"):
    try: os.remove(f"{F}/tmp/s78_{TAG}.{x}")
    except OSError: pass
sys.exit(0 if todo_ok else 1)
