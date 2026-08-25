#!/usr/bin/env bash
# bajar_resultados_tt.sh — baja los resultados de los 7 proyectos desde GitHub Actions
# y deja lo util a mano: el render del layout, el precheck y las metricas de OpenLane.
#
#   resultados_tt/<proyecto>/gds_render.png    la foto del chip (la que TT publica)
#   resultados_tt/<proyecto>/precheck.md       los 14 chequeos de admision del shuttle
#   resultados_tt/<proyecto>/metrics.csv       utilizacion, celdas por clase, wirelength, power
#   resultados_tt/<proyecto>/synthesis.txt     el conteo celda por celda de yosys
#
# Necesita la CLI gh autenticada.  Uso:  bash bajar_resultados_tt.sh
set -e
AQUI="$(cd "$(dirname "$0")" && pwd)"
USER_GH="${USER_GH:-VictorMartinez89}"
OUT="$AQUI/resultados_tt"
TMP=$(mktemp -d)
mkdir -p "$OUT"

REPOS="tt_sobel_vic tt_canny1_vic tt_trans_mini_vic tt_soc_sobel_vic tt_soc_sobel_flash_vic tt_soc_canny1_vic tt_soc_trans_mini_vic"

for r in $REPOS; do
    echo "== $r"
    id=$(gh run list --repo "$USER_GH/$r" --workflow gds --limit 1 \
         --json databaseId,conclusion --jq '.[0] | select(.conclusion=="success") | .databaseId')
    if [ -z "$id" ]; then echo "   (el ultimo gds no fue exitoso, lo salteo)"; continue; fi
    d="$OUT/$r"; mkdir -p "$d"
    rm -rf "$TMP/$r"; mkdir -p "$TMP/$r"
    (cd "$TMP/$r" && gh run download "$id" --repo "$USER_GH/$r" \
        -n gds_render -n precheck_reports -n tt_submission >/dev/null 2>&1) || true
    cp "$TMP/$r/gds_render/gds_render.png"                     "$d/gds_render.png"     2>/dev/null || true
    cp "$TMP/$r/precheck_reports/results.md"                   "$d/precheck.md"        2>/dev/null || true
    cp "$TMP/$r"/tt_submission/tt_submission/stats/metrics.csv "$d/metrics.csv"        2>/dev/null || true
    cp "$TMP/$r"/tt_submission/tt_submission/stats/synthesis-stats.txt "$d/synthesis.txt" 2>/dev/null || true
    rm -rf "$TMP/$r"                                  # el GDS pesa 20+ MB: no se guarda
    echo "   -> $(ls "$d" | tr '\n' ' ')"
done
rm -rf "$TMP"
echo
echo "Listo. Para la tabla comparativa:  python3 tabla_resultados_tt.py"
