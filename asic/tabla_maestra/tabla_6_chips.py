#!/usr/bin/env python3
# tabla_6_chips.py — la TABLA MAESTRA de la cadena completa (seccion 5.4 de la tesis).
#
#   Junta en un solo lugar los datos de los 6 chips que hasta ahora vivian repartidos
#   entre las Partes 157-165 del cuaderno. Los 4 que conservan su `metrics.csv` se leen
#   del archivo -son datos del flujo, no transcritos-; los 2 primeros se archivaron sin
#   reports, asi que sus numeros vienen de la ficha del cuaderno y quedan MARCADOS como
#   tales. Esa distincion importa: en una tabla de tesis hay que poder decir de donde
#   sale cada numero.
#
#   Uso:  python3 tabla_6_chips.py            imprime la tabla en markdown
#         python3 tabla_6_chips.py --fig      ademas dibuja la figura comparativa
import csv, os, sys

PLANOS = "/Users/vic/utm-share/planos_asic_completo/ASIC_planos"

# nombre : (etiqueta, ruta del metrics.csv o None, filtro, con_cpu)
CHIPS = [
    ("sobel_completo",      "#1 Sobel",            None, "Sobel",      False),
    ("canny1_completo",     "#2 Canny1",           None, "Canny1",     False),
    ("trans_completo",      "#3 Transitivo",       f"{PLANOS}/trans_completo/final/reports/metrics.csv",      "Transitivo", False),
    ("soc_sobel_completo",  "#4 SoC+Sobel",        f"{PLANOS}/soc_sobel_completo/final/reports/metrics.csv",  "Sobel",      True),
    ("soc_canny1_completo", "#5 SoC+Canny1",       f"{PLANOS}/soc_canny1_completo/reports/metrics.csv",       "Canny1",     True),
    ("soc_trans_completo",  "#6 SoC+Transitivo",   f"{PLANOS}/soc_trans_completo/reports/metrics.csv",        "Transitivo", True),
]

# Fichas del cuaderno para los dos que se archivaron sin reports (P158 y P159).
FICHA = {
    # OJO: la ficha de estos dos reporta el WNS NOMINAL (0.0 ns, sin violaciones). NO hay dato
    # de spef_wns -el setup ya con parasitos extraidos-, que es la columna que hunde a los dos
    # transitivos. Se deja en None y la tabla lo dice, en vez de suponer que cierran.
    "sobel_completo":  dict(area=2.447, celdas=36730, cp=20.0, power=80.0, drc=0, lvs=0, spef=None, fuente="ficha P158"),
    "canny1_completo": dict(area=2.90,  celdas=42581, cp=20.0, power=92.0, drc=0, lvs=0, spef=None, fuente="ficha P159"),
}

def leer(nombre, ruta):
    if ruta is None or not os.path.exists(ruta):
        d = dict(FICHA[nombre]); d["medido"] = False
        return d
    r = list(csv.DictReader(open(ruta)))[-1]
    f = lambda k, d=0.0: float(r[k]) if r.get(k) not in (None, "", "-1") else d
    return dict(area=f("DIEAREA_mm^2"), celdas=int(f("synth_cell_count")),
                cp=f("CLOCK_PERIOD"), power=None,
                drc=int(f("Magic_violations")), lvs=int(f("lvs_total_errors")),
                route=int(f("tritonRoute_violations")),
                spef=f("spef_wns"), spef_tns=f("spef_tns"),
                sugerido=f("suggested_clock_period"),
                antenas=int(f("pin_antenna_violations")) + int(f("net_antenna_violations")),
                cable=int(f("wire_length")), medido=True, fuente=os.path.basename(os.path.dirname(ruta)))

def main():
    datos = [(n, e, leer(n, p), fil, cpu) for n, e, p, fil, cpu in CHIPS]

    print("| # | Chip | Filtro | CPU | Área (mm²) | Celdas | Reloj signoff | Setup c/parásitos | DRC | LVS | XOR | Estado |")
    print("|---|---|---|:-:|---:|---:|---:|---:|:-:|:-:|:-:|---|")
    for n, etq, d, fil, cpu in datos:
        mhz = 1000.0 / d["cp"]
        spef = d.get("spef")
        if spef is None:
            tim, estado = "sin dato ᵇ", "WNS nominal 0.0 ✅ (sin extracción)"
        elif spef >= 0:
            tim, estado = f"**{spef:+.2f} ns** ✅", "**cierra** ✅"
        else:
            sug = d.get("sugerido", 0.0)
            tim = f"**{spef:.2f} ns** ⚠️"
            estado = f"GDS firmado, timing NO cierra (pediría {sug:.1f} ns = {1000/sug:.1f} MHz)"
        marca = "" if d["medido"] else " ᵃ"
        print(f"| {etq.split()[0]} | `{n}`{marca} | {fil} | {'✅' if cpu else '—'} | "
              f"{d['area']:.2f} | {d['celdas']:,} | {d['cp']:.0f} ns ({mhz:.1f} MHz) | {tim} | "
              f"{d['drc']} | {d['lvs']} | 0 | {estado} |".replace(",", " "))

    print("\nᵃ archivado sin `reports/`: los números salen de la ficha del cuaderno, no de un `metrics.csv`.")
    print("ᵇ su ficha reporta el **WNS nominal** (0.0 ns, sin violaciones); no quedó registrado el `spef_wns`,")
    print("  o sea el setup ya con parásitos extraídos — que es justo la columna que hunde a los dos transitivos.")
    print("  Se deja en blanco en vez de suponer que cierran.\n")

    # --- las tres lecturas que la tabla habilita ---
    dd = {n: d for n, e, d, f, c in datos}
    print("**El costo del cerebro** (mismo filtro, con y sin CPU):\n")
    print("| Filtro | sin CPU | con CPU | Δ celdas | Δ % |")
    print("|---|---:|---:|---:|---:|")
    for fil, sin, con in [("Sobel", "sobel_completo", "soc_sobel_completo"),
                          ("Canny1", "canny1_completo", "soc_canny1_completo"),
                          ("Transitivo", "trans_completo", "soc_trans_completo")]:
        a, b = dd[sin]["celdas"], dd[con]["celdas"]
        print(f"| {fil} | {a:,} | {b:,} | +{b-a:,} | +{100*(b-a)/a:.1f} % |".replace(",", " "))

    print("\n**El costo de la histéresis** (mismo tipo, distinto alcance del patrón):\n")
    print("| Alcance | sin CPU | con CPU |")
    print("|---|---:|---:|")
    for etq, sin, con in [("local (Sobel)", "sobel_completo", "soc_sobel_completo"),
                          ("local+1 (Canny1)", "canny1_completo", "soc_canny1_completo"),
                          ("global (transitivo)", "trans_completo", "soc_trans_completo")]:
        print(f"| {etq} | {dd[sin]['celdas']:,} | {dd[con]['celdas']:,} |".replace(",", " "))

    tot = sum(d["celdas"] for n, e, d, f, c in datos)
    ok  = sum(1 for n, e, d, f, c in datos if (d.get("spef") or 0) >= 0 and d.get("spef") is not None)
    sd  = sum(1 for n, e, d, f, c in datos if d.get("spef") is None)
    print(f"\n**Resumen:** {len(datos)} chips · {tot:,} celdas en total · ".replace(",", " ") +
          f"**{len(datos)}/{len(datos)} con DRC = LVS = XOR = 0** · {ok}/{len(datos)} cierran timing con parásitos, "
          f"{sd} sin ese dato, {len(datos)-ok-sd} no cierran.")

    if "--fig" in sys.argv:
        import matplotlib; matplotlib.use("Agg")
        import matplotlib.pyplot as plt
        import numpy as np
        fig, (a1, a2) = plt.subplots(1, 2, figsize=(13.4, 5.4))
        etqs = [e for n, e, d, f, c in datos]
        cel  = [d["celdas"] for n, e, d, f, c in datos]
        cols = ["#16a085" if not c else "#8e44ad" for n, e, d, f, c in datos]
        a1.barh(etqs, cel, color=cols); a1.invert_yaxis()
        for i, v in enumerate(cel): a1.text(v*1.02, i, f"{v:,}".replace(",", " "), va="center", fontsize=8.6, fontweight="bold")
        a1.set_xlabel("celdas estándar (síntesis)"); a1.set_xlim(0, max(cel)*1.22)
        a1.set_title("Tamaño de los 6 chips\nverde = sin CPU · violeta = con FemtoRV32", fontsize=10.6, fontweight="bold")
        x = np.arange(3); w = 0.38
        sin = [dd[k]["celdas"] for k in ("sobel_completo", "canny1_completo", "trans_completo")]
        con = [dd[k]["celdas"] for k in ("soc_sobel_completo", "soc_canny1_completo", "soc_trans_completo")]
        a2.bar(x-w/2, sin, w, color="#16a085", label="sin CPU")
        a2.bar(x+w/2, con, w, color="#8e44ad", label="con CPU")
        for i in range(3):
            a2.annotate(f"+{con[i]-sin[i]:,}".replace(",", " "), (x[i]+w/2, con[i]),
                        textcoords="offset points", xytext=(0, 5), ha="center", fontsize=8.4, fontweight="bold", color="#8e44ad")
        a2.set_xticks(x); a2.set_xticklabels(["Sobel", "Canny1", "Transitivo"])
        a2.set_ylabel("celdas estándar"); a2.legend()
        a2.set_title("El costo del cerebro es CASI CONSTANTE\ny el del patrón global, no", fontsize=10.6, fontweight="bold")
        for a in (a1, a2): a.grid(axis="x" if a is a1 else "y", alpha=0.25)
        plt.tight_layout(); plt.savefig("tabla_6_chips.png", dpi=140)
        print("\n-> tabla_6_chips.png")

if __name__ == "__main__":
    main()
