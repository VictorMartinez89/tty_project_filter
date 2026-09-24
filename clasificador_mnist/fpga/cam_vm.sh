#!/bin/sh
# cam_vm.sh — la CAMARA y la PANTALLA con la cadena del 97,22 % (pasos 2 + 1 del plan del 23-sep).
#   MARCA_CAM78_23SEP
#
#   sh /mnt/share/utm-share/mnist78_cam/cam_vm.sh
#
#   1. iverilog + vvp : la camara emulada muestra los 10 digitos, 2 cuadros cada uno, sin reset
#                       entre escenas, a cam78_cadena (el MISMO modulo que va en la placa).
#                       20/20 contra el golden -> ALL TESTS PASSED. (~1 min)
#   2. yosys          : 11 SB_RAM40_4K (9 de la cadena + el framebuffer de la ventana)
#   3. nextpnr        : LC, frecuencia de los dos relojes (clk 12 MHz y cam_pclk)
#   4. icepack        : out/mnist_cam78.bin
#
# Grabar desde el Mac: cp .../out/mnist_cam78.bin /Volumes/iCELink/  y ESPERAR a que el .bin
# DESAPAREZCA del disco (la grabacion no termina con el cp).
set -e
AQUI="$(cd "$(dirname "$0")" && pwd)"; cd "$AQUI"; mkdir -p out
export PATH="$HOME/Documents/UN/oss-cad-suite/bin:$PATH"
RTL="rtl/mnist_cam78.v rtl/cam78_cadena.v rtl/cam_win28.v rtl/glifo.v rtl/mnist_top78.v \
     rtl/mnist_feat16_mem.v rtl/mnist_clf78_x2.v rtl/linebuf3x3.v"
SIM="sim/tb_cam78.v rtl/cam78_cadena.v rtl/cam_win28.v rtl/mnist_top78.v \
     rtl/mnist_feat16_mem.v rtl/mnist_clf78_x2.v rtl/linebuf3x3.v"

echo "=========================================================="
echo "  CAMARA + PANTALLA + la cadena del 97,22 %"
echo "=========================================================="
FALTA=0
for f in $RTL rtl/mnist_weights78_x2.vh sim/tb_cam78.v sim/esc78.hex sim/exp.hex mnist_cam.pcf; do
    [ -f "$f" ] || { echo "  !! FALTA $f"; FALTA=1; }
done
[ "$FALTA" = 0 ] || exit 1
echo "  ficheros completos"

echo; echo "== 1/4 simulacion: la camara emulada muestra los 10 digitos (~1 min)"
iverilog -g2012 -Irtl -o out/cam.vvp $SIM
( cd out && vvp -n cam.vvp +ESC=../sim/esc78.hex +EXP=../sim/exp.hex +OUT=cam.out ) \
    | tee out/sim.log | grep -vE "^VCD info" | sed 's/^/    /'
grep -q "ALL TESTS PASSED" out/sim.log || { echo "  !! la simulacion NO paso: no se sintetiza"; exit 1; }

echo; echo "== 2/4 sintesis (yosys)"
yosys -p "read_verilog -sv -Irtl $RTL; synth_ice40 -top top -json out/cam.json" \
    > out/yosys.log 2>&1 || { echo "  !! fallo yosys"; grep -E "ERROR" out/yosys.log; exit 1; }
NRAM=$(awk '/Printing statistics/{f=1} f' out/yosys.log | grep -E "SB_RAM40_4K" | tail -1 | awk '{print $1}')
echo "    SB_RAM40_4K: $NRAM   (tienen que ser 11)"
[ "$NRAM" = 11 ] || { echo "  !! la BRAM no se infirio como se esperaba"; exit 1; }

echo; echo "== 3/4 place & route (nextpnr)"
nextpnr-ice40 --up5k --package sg48 --freq 12 --json out/cam.json \
    --pcf mnist_cam.pcf --asc out/cam.asc > out/pnr.log 2>&1 \
    || { echo "  !! fallo nextpnr"; grep -E "ERROR" out/pnr.log | head; exit 1; }
grep -E "ICESTORM_LC|ICESTORM_RAM|SB_IO:" out/pnr.log | head -3 | sed 's/^Info: */    /'
grep -E "Max frequency" out/pnr.log | tail -2 | sed 's/^Info: */    /'

echo; echo "== 4/4 bitstream (icepack)"
icepack out/cam.asc out/mnist_cam78.bin
ls -la out/mnist_cam78.bin | awk '{printf "    %s bytes  %s\n",$5,$9}'
md5sum out/mnist_cam78.bin | sed 's/^/    md5 /'
echo
echo "  LISTO. Desde el Mac (o que lo haga Claude):"
echo "    cp ~/utm-share/mnist78_cam/out/mnist_cam78.bin /Volumes/iCELink/"
echo "  Digito GRUESO y OSCURO en papel blanco, llenando el marco verde. El 1 fino sale NADA (raya)."
