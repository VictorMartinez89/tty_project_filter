#!/usr/bin/env python3
"""experimento_luz.py — Sobel vs Canny 1-salto sobre capturas REALES de la placa.

La pregunta de la §6 del cuaderno 2: el doble umbral con histeresis, ¿aguanta mejor los cambios
de iluminacion que un umbral simple? En simulacion el Canny ganaba +17 pp con luz despareja.
Aca se contesta con la camara de verdad.

METODO. No hace falta que la escena sea un digito: alcanza con que sea LA MISMA escena bajo
distintas luces. Se mide la CONSISTENCIA del mapa de bordes entre condiciones:

    un filtro robusto a la iluminacion produce el MISMO mapa de bordes cuando solo cambia la luz.

Se compara con el indice de Jaccard (interseccion sobre union) entre los mapas de dos condiciones.
Los umbrales de cada filtro se eligen para que ambos marquen la MISMA densidad de bordes: sin eso
se estaria comparando un filtro generoso contra uno tacano, no dos filtros.
"""
import numpy as np, warnings; warnings.filterwarnings("ignore")
import frente_golden as fg
from canny1_mnist import frente_canny1

COND = [("pareja", 1), ("lateral", 2), ("penumbra", 3)]

def carga(n, i, k=12):
    A = np.load(f"/Users/vic/luz{i}_{n}.npz")["imgs"].astype(float)
    con = A.std(axis=(1, 2))
    nit = np.array([np.abs(np.diff(a, axis=0)).mean() + np.abs(np.diff(a, axis=1)).mean() for a in A])
    return A[np.argsort(-(con * nit))[:k]]

S = {n: carga(n, i) for n, i in COND}
print("capturas elegidas (las mas nitidas y contrastadas de cada condicion):")
for n, A in S.items():
    print(f"  {n:<10} {len(A)} cuadros · media {A.mean():6.1f} · contraste {A.std(axis=(1,2)).mean():5.1f}")

# --- alinear: la camara se movio un poco entre condiciones ---
def alinea(ref, X, r=4):
    """Desplazamiento entero que maximiza la correlacion (normalizando brillo)."""
    a = (ref - ref.mean()) / (ref.std() + 1e-9)
    mejor = (-9e9, (0, 0))
    for dy in range(-r, r+1):
        for dx in range(-r, r+1):
            b = np.roll(np.roll(X, dy, 0), dx, 1)
            b = (b - b.mean()) / (b.std() + 1e-9)
            c = float((a[r:-r, r:-r] * b[r:-r, r:-r]).mean())
            if c > mejor[0]: mejor = (c, (dy, dx))
    return mejor

ref = S["pareja"].mean(axis=0)
img, corr = {}, {}
for n, A in S.items():
    M = A.mean(axis=0)
    c, (dy, dx) = alinea(ref, M)
    img[n] = np.roll(np.roll(M, dy, 0), dx, 1); corr[n] = c
    print(f"  {n:<10} alineado con desplazamiento ({dy:+d},{dx:+d}) · correlacion {c:.3f}")

# --- umbrales igualados por DENSIDAD de bordes ---
def sobel_mapa(X, thr): return fg.frente(X, thr)[0][0]
def canny_mapa(X, hi, lo): return frente_canny1(X, hi, lo)[0][0]

def densidad_objetivo(X, f, lo_, hi_, obj=.50):
    """Busca el umbral que da la densidad de bordes `obj` en esta imagen."""
    a, b = lo_, hi_
    for _ in range(25):
        m = (a + b) / 2
        if f(X, m).mean() > obj: a = m
        else: b = m
    return (a + b) / 2

print("\numbrales calibrados para densidad 50 % en la condicion de referencia:")
# El techo es 254, no 400: la magnitud SATURA en 255, asi que `mag > 255` no ocurre
# nunca y cualquier umbral >= 255 da un mapa vacio. Con esta escena el percentil 95
# de la magnitud YA es 255: el contraste real es mucho mayor que el de MNIST.
thr_s = densidad_objetivo(img["pareja"], lambda X, t: sobel_mapa(X, t), 5, 254)
# Para el Canny NO se puede mover `hi` y `lo` juntos: aun con hi en el techo (254) la
# densidad se queda en 63 %, y comparar 63 % contra 50 % regala la ventaja al Canny -un mapa
# mas denso solapa mas por construccion-. Se fija hi y se calibra `lo`, que es el que
# realmente controla cuanto borde debil se rescata.
HI_C = 200
lo_c = densidad_objetivo(img["pareja"], lambda X, t: canny_mapa(X, HI_C, t), 5, 254)
thr_c, RAZ = HI_C, lo_c / HI_C
print(f"  Sobel thr={thr_s:.0f}   ·   Canny hi={HI_C} lo={lo_c:.0f}")

mapas = {"Sobel":  {n: sobel_mapa(img[n], thr_s)      for n in img},
         "Canny1": {n: canny_mapa(img[n], HI_C, lo_c) for n in img}}

def jaccard(a, b):
    # OJO: dos mapas VACIOS no son "100 % consistentes". Devolver 1.0 en ese caso hizo que
    # un filtro que no marcaba NADA saliera perfecto. Un conjunto vacio no tiene con que
    # comparar: es NaN, y hay que verlo.
    u = (a | b).sum()
    return (a & b).sum() / u if u else float("nan")

print("\n=== CONSISTENCIA del mapa de bordes entre condiciones (Jaccard) ===")
print(f"{'par':<24}{'Sobel':>9}{'Canny1':>9}{'dif':>9}")
pares = [("pareja","lateral"), ("pareja","penumbra"), ("lateral","penumbra")]
res = {}
for f in mapas:
    res[f] = [jaccard(mapas[f][a], mapas[f][b]) for a, b in pares]
val = []
for k, (a, b) in enumerate(pares):
    d = res["Canny1"][k] - res["Sobel"][k]
    ok = corr[a] > .4 and corr[b] > .4        # la escena tiene que ser la MISMA
    val.append(ok)
    marca = "" if ok else "   <-- ESCENA DISTINTA: no cuenta"
    print(f"{a+' vs '+b:<24}{res['Sobel'][k]:9.1%}{res['Canny1'][k]:9.1%}{d:+9.1%}{marca}")
v = np.array(val)
if v.any():
    ms, mc = np.mean(np.array(res["Sobel"])[v]), np.mean(np.array(res["Canny1"])[v])
    print(f"{'PROMEDIO (validos)':<24}{ms:9.1%}{mc:9.1%}{mc-ms:+9.1%}")
    print(f"\npares validos: {v.sum()} de {len(v)}")
print("\ndensidades de borde por condicion:")
for f in mapas:
    print(f"  {f:<8}", "  ".join(f"{n} {mapas[f][n].mean():.0%}" for n in img))
np.savez("experimento_luz.npz",
         **{f"{f}_{n}": mapas[f][n] for f in mapas for n in img},
         **{f"img_{n}": img[n] for n in img}, thr_s=thr_s, thr_c=thr_c)
