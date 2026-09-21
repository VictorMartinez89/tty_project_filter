#!/usr/bin/env bash
# armar_zip.sh — empaqueta SOLO lo que Overleaf necesita.
set -e
AQUI="$(cd "$(dirname "$0")" && pwd)"
export PATH=/opt/anaconda3/bin:/opt/homebrew/bin:$PATH
UNIDO="$AQUI/../salida/tesis.md"
[ -f "$UNIDO" ] || { echo "!! falta $UNIDO — corre antes tesis/maqueta/armar.sh"; exit 1; }
rm -rf "$AQUI/figuras"; cp -R "$AQUI/../../figuras" "$AQUI/figuras"
pandoc "$UNIDO" -o "$AQUI/tesis.tex" --standalone --top-level-division=chapter \
       --resource-path="$AQUI/.."
python3 "$AQUI/cuerpo.py" "$AQUI/tesis.tex" "$AQUI/cuerpo.tex"

cd "$AQUI"
rm -f tesis_overleaf.zip
zip -qr tesis_overleaf.zip tesis.tex cuerpo.tex figuras LEEME_OVERLEAF.md
echo "  $AQUI/tesis_overleaf.zip  ($(du -h tesis_overleaf.zip | cut -f1))"
echo "  Overleaf: New Project -> Upload Project -> arrastrar el zip"
