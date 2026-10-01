#!/bin/sh
# compilar_pdflatex.sh — compila la tesis con pdfLaTeX, como Overleaf, dentro de Docker (imagen texlive/texlive).
#   bash tesis/maqueta/compilar_pdflatex.sh            -> ~/UN/Tesis/Tesis_Final_1/pdf_local/0000.pdf
# Trabaja sobre una COPIA del clon de Overleaf: no toca el repositorio. Hace falta Docker Desktop abierto.
set -e
ORIG="$HOME/UN/Tesis/Tesis_Final_1/overleaf"
DEST="$HOME/UN/Tesis/Tesis_Final_1/pdf_local"
mkdir -p "$DEST"
rsync -a --delete --exclude .git --exclude '*.pdf' "$ORIG/" "$DEST/"
docker info >/dev/null 2>&1 || { open -a Docker; for i in $(seq 1 40); do docker info >/dev/null 2>&1 && break; sleep 3; done; }
echo "== pdfLaTeX (latexmk) en texlive/texlive — puede tardar unos minutos"
docker run --rm -v "$DEST":/tesis -w /tesis texlive/texlive:latest \
    latexmk -pdf -f -interaction=nonstopmode 0000.tex > "$DEST/compilar.log" 2>&1 || true
if [ -f "$DEST/0000.pdf" ]; then
    echo "   PDF: $DEST/0000.pdf  ($(ls -la "$DEST/0000.pdf" | awk '{print $5}') bytes)"
else
    echo "   !! no salio el PDF: ver $DEST/compilar.log"
fi
echo "   errores de LaTeX: $(grep -c '^!' "$DEST/0000.log" 2>/dev/null || echo ?)"
grep -A2 '^!' "$DEST/0000.log" 2>/dev/null | head -20
