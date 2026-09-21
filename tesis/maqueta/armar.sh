#!/usr/bin/env bash
# armar.sh — junta los capitulos en un solo documento y lo pasa por pandoc.
#   bash tesis/maqueta/armar.sh
# Sale en tesis/maqueta/salida/: tesis.md (el fuente unido), tesis.docx y tesis.html
#
# NO toca los .md de tesis/: el arreglo del capitulo 5 se hace aqui, al vuelo.
set -e
AQUI="$(cd "$(dirname "$0")" && pwd)"
T="$(dirname "$AQUI")"
OUT="$AQUI/salida"; mkdir -p "$OUT"
UNIDO="$OUT/tesis.md"

export PATH=/opt/homebrew/bin:/opt/anaconda3/bin:$PATH
command -v pandoc >/dev/null || { echo "!! falta pandoc"; exit 1; }

cat "$AQUI/00_portada.md" > "$UNIDO"
echo >> "$UNIDO"

agregar () {            # $1 = fichero   $2 = "bajar" para degradar un nivel
    echo >> "$UNIDO"
    if [ "${2:-}" = "bajar" ]; then
        sed 's/^#/##/' "$T/$1" >> "$UNIDO"      # '# 5.2' -> '## 5.2'
    else
        cat "$T/$1" >> "$UNIDO"
    fi
    echo >> "$UNIDO"
}

agregar cap1_introduccion.md
agregar cap2_marco.md
agregar cap3_metodologia.md
agregar cap4_diseno.md

# El capitulo 5 vive en seis ficheros que usan '#' para lo que son SECCIONES y no
# tienen encabezado de capitulo. Se le pone uno y se degradan los seis.
printf '\n# 5. Resultados\n' >> "$UNIDO"
for n in 1 2 3 4 5 6 7; do agregar "cap5_seccion$n.md" bajar; done

agregar cap6_discusion.md
agregar cap7_conclusiones.md

printf '\n\\newpage\n\n# Anexos\n' >> "$UNIDO"
for a in anexo_entorno anexo_registros anexo_pinout anexo_openlane; do agregar "$a.md" bajar; done

agregar bibliografia.md

echo "  unido:  $UNIDO  ($(wc -w < "$UNIDO" | tr -d ' ') palabras)"

pandoc "$UNIDO" -o "$OUT/tesis.docx" --toc --toc-depth=3 --standalone \
       --resource-path="$T" 2>&1 | head -5
pandoc "$UNIDO" -o "$OUT/tesis.html" --toc --toc-depth=3 --standalone --embed-resources \
       --resource-path="$T" --metadata title="Tesis" 2>&1 | head -5

echo "  docx:   $OUT/tesis.docx"
echo "  html:   $OUT/tesis.html"
echo
echo "  Para el PDF hace falta LaTeX, que no esta en este Mac. Dos caminos:"
echo "    a) abrir el .docx en Word/LibreOffice y aplicar la plantilla de la Facultad"
echo "    b) instalar BasicTeX y anadir:  -o tesis.pdf --pdf-engine=xelatex"
