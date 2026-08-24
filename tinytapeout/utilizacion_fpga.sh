#!/usr/bin/env bash
# utilizacion_fpga.sh — Device Utilisation real (nextpnr) de los 6 proyectos de Tiny Tapeout.
# Correr EN LA VM, con el oss-cad-suite activado (nextpnr no esta en el Mac).
#   bash /mnt/share/utm-share/utilizacion_fpga.sh  ó  bash tinytapeout/utilizacion_fpga.sh
set -e
AQUI="$(cd "$(dirname "$0")" && pwd)"
OUT=${OUT:-/tmp/tt_util}
mkdir -p "$OUT"

PROYECTOS="tt_sobel:tt_um_sobel_vic
tt_canny1:tt_um_canny1_vic
tt_soc_sobel:tt_um_soc_sobel_vic
tt_soc_sobel_flash:tt_um_soc_sobel_flash_vic
tt_trans_mini:tt_um_trans_mini_vic
tt_soc_canny1:tt_um_soc_canny1_vic"

echo "$PROYECTOS" | while IFS=: read -r d t; do
    [ -d "$AQUI/$d" ] || continue
    echo "================= $d  ($t)"
    srcs=$(find "$AQUI/$d/src" -name "*.v" -o -name "*.sv" | tr '\n' ' ')
    yosys -p "read_verilog -sv $srcs; synth_ice40 -top $t -json $OUT/$d.json" > "$OUT/$d.yosys.log" 2>&1
    # sin .pcf: nextpnr coloca los pines libremente; alcanza para medir utilizacion
    nextpnr-ice40 --up5k --package sg48 --json "$OUT/$d.json" --asc "$OUT/$d.asc" \
        > "$OUT/$d.pnr.log" 2>&1 || true
    # la tabla de Device utilisation la imprime nextpnr en stderr
    sed -n '/Device utilisation/,/^$/p' "$OUT/$d.pnr.log" | grep -E "ICESTORM|SB_|TRELLIS" || \
        echo "   (no se pudo leer la tabla; ver $OUT/$d.pnr.log)"
    grep -E "Max frequency" "$OUT/$d.pnr.log" | tail -1 || true
    echo
done
echo "Logs completos en $OUT/"
