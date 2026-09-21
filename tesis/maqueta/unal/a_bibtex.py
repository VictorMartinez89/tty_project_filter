#!/usr/bin/env python3
"""a_bibtex.py — convierte bibliografia.md a Referencias.bib para la plantilla.

La plantilla usa BibTeX con dtvstyle.bst y \\nocite{*}, de modo que imprime TODAS
las entradas del .bib aunque el texto no las cite con \\cite. Se emiten como
@misc con autor, titulo, ano y una nota, que es lo que el estilo sabe componer.

    python3 a_bibtex.py bibliografia.md Referencias.bib
"""
import io, re, sys, unicodedata

src = sys.argv[1]; dst = sys.argv[2]
texto = io.open(src, encoding="utf-8").read()

def limpia(t):
    t = re.sub(r'\*\*(.+?)\*\*', r'\1', t)          # negrita
    t = re.sub(r'`(.+?)`', r'\1', t)                # codigo
    t = re.sub(r'\[(.+?)\]\((.+?)\)', r'\1', t)     # enlaces
    return t.strip()

def clave(autor, ano, n):
    a = unicodedata.normalize("NFKD", autor).encode("ascii", "ignore").decode()
    a = re.sub(r'[^A-Za-z]', '', a.split(",")[0].split(" y ")[0].split()[-1] if a.strip() else "ref")
    return f"{a or 'ref'}{ano or n}"

entradas, usadas = [], set()
for m in re.finditer(r'^(\d+)\.\s+(.+?)(?=^\d+\.\s|\Z)', texto, re.M | re.S):
    n = m.group(1)
    # la marca de verificada y los encabezados de seccion estorban a los patrones
    crudo = re.sub(r'\*\*✓\*\*\s*', '', " ".join(m.group(2).split()))
    crudo = re.split(r'\s*##\s', crudo)[0]
    cuerpo = crudo
    cuerpo = re.sub(r'▸.*$', '', cuerpo).strip()     # las notas sobre la fuente
    nota = ""
    if " — " in cuerpo:
        cuerpo, nota = cuerpo.split(" — ", 1)
    cuerpo = limpia(cuerpo); nota = limpia(nota)

    tit = re.search(r'\*(.+?)\*|«(.+?)»', crudo)
    titulo = limpia(tit.group(1) or tit.group(2)) if tit else cuerpo[:80]
    autor = limpia(cuerpo.split(",")[0]) if "," in cuerpo else ""
    if tit:
        autor = limpia(crudo[:tit.start()].rstrip(", "))
    anos = re.findall(r'\b(19|20)\d{2}\b', cuerpo)
    ano = re.search(r'\b((?:19|20)\d{2})\b', cuerpo)
    ano = ano.group(1) if ano else ""

    k = clave(autor, ano, n)
    while k in usadas: k += "a"
    usadas.add(k)
    campos = [f"  author  = {{{autor}}}" if autor else None,
              f"  title   = {{{titulo}}}",
              f"  year    = {{{ano}}}" if ano else None,
              f"  note    = {{{nota}}}" if nota else None]
    entradas.append("@misc{%s,\n%s\n}" % (k, ",\n".join(c for c in campos if c)))

cab = ("% Referencias.bib — generado por a_bibtex.py desde tesis/bibliografia.md\n"
       "% REVISAR: la conversion de prosa a BibTeX es aproximada. El tipo de cada\n"
       "% entrada es @misc; para las que son articulo o libro conviene cambiarlo a\n"
       "% @article / @book y separar revista, volumen y paginas, que aqui quedan\n"
       "% dentro del titulo o de la nota.\n\n")
io.open(dst, "w", encoding="utf-8").write(cab + "\n\n".join(entradas) + "\n")
print(f"  {len(entradas)} entradas -> {dst}")
