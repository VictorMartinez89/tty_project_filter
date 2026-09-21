#!/usr/bin/env python3
"""integrar.py — vuelca la tesis en la plantilla oficial de la UNAL.

La plantilla ya trae UN FICHERO POR CAPITULO, asi que no se usa \\input{cuerpo}:
se escribe cada capitulo en el fichero que la plantilla espera.

    python3 tesis/maqueta/unal/integrar.py [ruta_de_la_plantilla]

Deja intacto 0000.tex (el preambulo de la plantilla manda) salvo por los
\\include del andamiaje, que se comentan. Escribe una copia .bak de cada fichero
que sobrescribe, la primera vez.
"""
import io, os, re, shutil, subprocess, sys

TESIS = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
DEST  = sys.argv[1] if len(sys.argv) > 1 else os.path.expanduser(
    "~/UN/Tesis_Final_1/Plantilla_Tesis_Trabajo_Final_UNAL_2023")
os.environ["PATH"] = "/opt/anaconda3/bin:/opt/homebrew/bin:" + os.environ["PATH"]

# capitulo -> fichero de la plantilla.  El 5 son siete ficheros que se funden.
MAPA = [
    (["cap1_introduccion.md"],                       "01Seccion01.tex"),
    (["cap2_marco.md"],                              "02Seccion02.tex"),
    (["cap3_metodologia.md"],                        "03Seccion03.tex"),
    (["cap4_diseno.md"],                             "04Seccion04.tex"),
    ([f"cap5_seccion{n}.md" for n in range(1, 8)],   "05Seccion05.tex"),
    (["cap6_discusion.md"],                          "06Seccion06.tex"),
    (["cap7_conclusiones.md"],                       "07Seccion07.tex"),
    (["anexo_entorno.md", "anexo_registros.md",
      "anexo_pinout.md",  "anexo_openlane.md"],      "08Apendice01.tex"),
]
TITULO_CAP5 = "Resultados"

def sin_numero(linea):
    """'## 5.6.1 Arquitectura' -> '## Arquitectura'.  Deja que numere LaTeX."""
    return re.sub(r'^(#{1,6})\s+(?:Anexo\s+[A-D]\.\s*|\d+(?:\.\d+)*\.?\s+)', r'\1 ', linea)

def preparar(ruta, bajar):
    out = []
    for l in io.open(ruta, encoding="utf-8").read().splitlines():
        if l.startswith("#"):
            if bajar: l = "#" + l
            l = sin_numero(l)
        out.append(l)
    return "\n".join(out)

# La plantilla usa natbib con dtvstyle.bst, que es AUTOR-ANO. Las citas del
# texto ya estan en ese formato: se convierten a \citep para que enlacen con
# Referencias.bib en vez de quedar como corchetes sueltos.
CITAS = {
    "Sobel y Feldman 1968": "Sobel1968",   "Prewitt 1970": "Prewitt1970",
    "Kirsch 1971": "Kirsch1971",           "Otsu 1979": "Otsu1979",
    "Mead y Conway 1980": "Mead1980",      "Canny 1986": "Canny1986",
    "Vincent 1993": "Vincent1993",         "LeCun *et al.* 1998": "LeCun1998",
    "Lowe 2004": "Lowe2004",               "Lazebnik *et al.* 2006": "Lazebnik2006",
    "Chen *et al.* 2016": "Chen2016",      "Sze *et al.* 2017": "Sze2017",
    "Waterman y Asanović 2017": "Waterman2017",
    "SkyWater 2020": "Technology2020",     "Shalan y Edwards 2020": "Shalan2020",
    "Camargo (2025, §1.2.1)": "Bareno2025",
}

def citar(md):
    n = 0
    for texto, clave in CITAS.items():
        for patron in ("[" + texto + "]", "[" + texto.replace("*et al.*", "et al.") + "]"):
            if patron in md:
                md = md.replace(patron, "\\citep{" + clave + "}")
                n += md.count("")
    return md

def a_tex(md):
    r = subprocess.run(["pandoc", "-f", "markdown", "-t", "latex",
                        "--top-level-division=chapter", "--wrap=preserve"],
                       input=md, capture_output=True, text=True)
    if r.returncode: sys.exit("!! pandoc: " + r.stderr[:400])
    # las figuras viven en 00Figuras/ dentro de la plantilla
    return r.stdout.replace("{figuras/", "{00Figuras/")

def respaldar(p):
    if os.path.exists(p) and not os.path.exists(p + ".bak"):
        shutil.copy2(p, p + ".bak")

if not os.path.isdir(DEST): sys.exit("!! no existe " + DEST)

# --- figuras -------------------------------------------------------------
figdir = os.path.join(DEST, "00Figuras")
os.makedirs(figdir, exist_ok=True)
n_fig = 0
for f in sorted(os.listdir(os.path.join(TESIS, "figuras"))):
    if f.lower().endswith((".png", ".jpg", ".jpeg", ".pdf")):
        shutil.copy2(os.path.join(TESIS, "figuras", f), os.path.join(figdir, f))
        n_fig += 1
print(f"  figuras -> 00Figuras/ : {n_fig}")

# --- capitulos -----------------------------------------------------------
for fuentes, destino in MAPA:
    partes = []
    if destino == "05Seccion05.tex":
        partes.append("# " + TITULO_CAP5)
    for k, f in enumerate(fuentes):
        ruta = os.path.join(TESIS, f)
        if not os.path.exists(ruta): print("  !! falta", f); continue
        bajar = destino == "05Seccion05.tex"
        partes.append(preparar(ruta, bajar))
    md = citar("\n\n".join(partes))
    tex = a_tex(md)
    p = os.path.join(DEST, destino)
    respaldar(p)
    io.open(p, "w", encoding="utf-8").write(tex)
    print(f"  {destino:<20} {len(tex.split()):>6,} palabras   <- {', '.join(fuentes)[:52]}")

# --- resumen y abstract --------------------------------------------------
port = io.open(os.path.join(TESIS, "maqueta", "00_portada.md"), encoding="utf-8").read()
cuerpo = port[port.index("# Resumen"):]
cuerpo = cuerpo.replace("\\newpage", "").replace("# Resumen", "## Resumen").replace("# Abstract", "## Abstract")
tex = a_tex("# Resumen y Abstract\n\n" + cuerpo)
p = os.path.join(DEST, "00ResumenAbstract.tex"); respaldar(p)
io.open(p, "w", encoding="utf-8").write(tex)
print(f"  00ResumenAbstract.tex  {len(tex.split()):>6,} palabras")
print("\n  Copias de seguridad: *.bak junto a cada fichero sobrescrito.")
