#!/bin/sh
# correr_sim.sh — Canny-98 en simulacion: iverilog -> vvp -> GTKWave.   MARCA_CANNY98_SIM_28SEP
#
#   sh /mnt/share/utm-share/canny98_sim/correr_sim.sh          # compila, simula y saca los 4 PDF
#   sh /mnt/share/utm-share/canny98_sim/correr_sim.sh A        # abre GTKWave en la vista A (B, C o D)
#                                                              #   -> captura con ImprPant
set -e
AQUI="$(cd "$(dirname "$0")" && pwd)"; cd "$AQUI"; mkdir -p out
export PATH="$HOME/Documents/UN/oss-cad-suite/bin:$PATH"
grep -q "MARCA_CANNY98_SIM_28SEP" "$0" || { echo "!! script viejo (la share sirve contenido viejo)"; exit 1; }
if [ -n "$1" ]; then
    [ -f out/canny98.vcd ] || { echo "  !! primero sin argumentos, para generar out/canny98.vcd"; exit 1; }
    echo "  vista $1: $(head -1 vista_$1.tcl | sed 's/^# vista . — //')"
    gtkwave -S vista_$1.tcl out/canny98.vcd canny98.gtkw >/dev/null 2>&1 &
    exit 0
fi
echo "== 1/3 iverilog: compilar"
iverilog -g2012 -o out/c98.vvp sim/tb_canny98.v rtl/mnist_top98.v rtl/mnist_feat16_mem.v \
    rtl/mnist_clf98.v rtl/linebuf3x3.v rtl/sim_spram256ka.v
echo "== 2/3 vvp: simular (4 imagenes: un 7, un 2, un 1 y un 0; un pixel cada 32 ciclos)"
cp canny98_w.hex canny98_b1.hex canny98_b2.hex out/
( cd out && vvp -n c98.vvp +IMG=../sim/img4.hex +EXP=../sim/exp4.hex ) | grep -v "VCD info" | tee out/sim.log | sed 's/^/    /'
grep -q "ALL TESTS PASSED" out/sim.log || { echo "  !! la simulacion no paso"; exit 1; }
ls -la out/canny98.vcd | awk '{printf "    VCD: %s bytes\n", $5}'
echo "== 3/3 GTKWave: las 4 vistas a PDF apaisado"
gtkwave -S foto_pdf.tcl out/canny98.vcd canny98.gtkw >out/gtkwave.log 2>&1 || true
if ls out/vista_*.pdf >/dev/null 2>&1; then ls -la out/vista_*.pdf | awk '{printf "    %8s  %s\n",$5,$9}'
else echo "    (no salieron los PDF: usar las vistas a mano)"; fi
echo
echo "  Fotos a mano (las mejores): sh $AQUI/correr_sim.sh A   ... B, C, D   y ImprPant en cada una."
echo "  Luego copiar las capturas a la share:  cp ~/Pictures/Screenshots/*.png $AQUI/out/"
