#!/usr/bin/env python3
"""revisar_significancia.py — dos tareas, en orden.

TAREA 1 — ¿alguna diferencia que descartamos por ruido resulta REAL?
    Todo el cuaderno uso sigma ~ 0.74 pp, estimado con CINCO semillas sobre 20 000 imagenes.
    Cinco muestras dan una sigma con ~32 % de incertidumbre propia: ese 0.74 podia ser 0.5 o 1.0.
    Con 10 pliegues sobre las 60 000 la estimacion es mucho mejor, y los pliegues son DISJUNTOS
    (cinco submuestras del mismo conjunto comparten informacion; los pliegues no).
    Si el ruido real es menor, algunas diferencias declaradas "no significativas" lo eran por
    falta de resolucion, no por ausencia de efecto.

TAREA 2 — con la sigma nueva, rehacer las afirmaciones que YA teniamos.
    Las que sobrevivan quedan mas firmes; las que no, hay que corregirlas.
"""
import numpy as np, warnings; warnings.filterwarnings("ignore")
d = np.load("metricas_avanzadas.npz")
F = ["Sobel", "SoC+Sobel", "Canny1", "SoC+Canny1", "Transitivo"]
CV = {n: d[f"{n}_cv"] for n in F}

print("=== TAREA 1: la sigma nueva, y si devuelve resultados ===\n")
print(f"{'front-end':<12}{'mediana R2':>12}{'sigma':>9}{'IQR':>9}{'min':>9}{'max':>9}")
for n in F:
    v = CV[n]
    print(f"{n:<12}{np.median(v):>12.4f}{v.std():>9.4f}"
          f"{np.percentile(v,75)-np.percentile(v,25):>9.4f}{v.min():>9.4f}{v.max():>9.4f}")

s_viejo = 0.0074       # 0.74 pp, las cinco semillas de la §3
s_nuevo = np.mean([CV[n].std() for n in F])
print(f"\n  sigma del cuaderno (5 semillas, 20 000):  {s_viejo:.4f}")
print(f"  sigma de 10 pliegues (60 000):           {s_nuevo:.4f}")
print(f"  -> el ruido real es {s_viejo/s_nuevo:.1f}x {'MENOR' if s_nuevo<s_viejo else 'MAYOR'} de lo que suponiamos")

print("\n  ¿se separan las cajas? (prueba de Mann-Whitney entre pares)")
from itertools import combinations
from scipy.stats import mannwhitneyu
for a, b in combinations(F, 2):
    u, p = mannwhitneyu(CV[a], CV[b])
    dif = np.median(CV[b]) - np.median(CV[a])
    if p < .05:
        print(f"     {a:>11} vs {b:<11} dif {dif:+.4f}  p={p:.4f}  <-- SEPARADAS")

print("\n=== TAREA 2: rehacer las afirmaciones con la sigma nueva ===\n")
AFIRM = [("§3  Canny vs Sobel, igual area", 0.0075),
         ("§3  Canny vs Sobel, umbral barrido", 0.0144),
         ("§8  Canny vs Sobel en la camara", 0.0024),
         ("§9  placa: Canny vs Sobel", 0.0690),
         ("§18 SoC+Canny vs Sobel", 0.0142),
         ("§18 SoC+Canny vs Transitivo", 0.0270)]
print(f"{'afirmacion':<38}{'dif':>8}{'con 0.74':>11}{'con la nueva':>14}")
for t, dif in AFIRM:
    v1 = "si" if dif > 2*s_viejo else "NO"
    v2 = "si" if dif > 2*s_nuevo else "NO"
    m = "  <-- CAMBIA" if v1 != v2 else ""
    print(f"{t:<38}{dif:>8.2%}{v1:>11}{v2:>14}{m}")
print("\n  'si' = la diferencia supera 2 sigma y se puede afirmar")
