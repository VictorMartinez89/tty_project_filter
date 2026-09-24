#!/bin/sh
# placa_vm.sh — el top78 (97,22 %) para la iCESugar, alimentado por el puerto serie.
#   MARCA_PLACA78_23SEP
#
#   sh /mnt/share/utm-share/mnist78_placa/placa_vm.sh          # simula, sintetiza y empaqueta
#   sh /mnt/share/utm-share/mnist78_placa/placa_vm.sh ver      # ademas abre gtkwave
#
# Cuatro pasos, y cada uno PARA si el anterior no paso:
#   1. iverilog + vvp : la placa entera con la UART de verdad, bit a bit, 2 lotes de 4
#                       imagenes, contra el golden. Tiene que decir ALL TESTS PASSED.
#   2. yosys          : tienen que salir 9 SB_RAM40_4K (si salen 7, la BRAM no se infirio).
#   3. nextpnr        : LC, frecuencia, y PASS a 12 MHz.
#   4. icepack        : out/mnist78_placa.bin
#
# Grabar: copiar out/mnist78_placa.bin al disco iCELink (en el Mac aparece como /Volumes/iCELink).
# Probar: en el Mac, `python placa78.py` manda las 10 000 del test y compara con el golden.
set -e
AQUI="$(cd "$(dirname "$0")" && pwd)"; cd "$AQUI"; mkdir -p out
export PATH="$HOME/Documents/UN/oss-cad-suite/bin:$PATH"
RTL="rtl/fpga_mnist78_stream.v rtl/uart_rx.v rtl/uart_tx.v rtl/mnist_top78.v \
     rtl/mnist_feat16_mem.v rtl/mnist_clf78_x2.v rtl/linebuf3x3.v"

echo "=========================================================="
echo "  TOP78 EN LA PLACA · flujo serie · 97,22 %"
echo "=========================================================="
FALTA=0
for f in $RTL rtl/mnist_weights78_x2.vh sim/tb_stream78.v sim/img.hex sim/exp.hex \
         mnist78_placa.pcf; do
    [ -f "$f" ] || { echo "  !! FALTA $f"; FALTA=1; }
done
[ "$FALTA" = 0 ] || { echo "  Copiar lo que falte desde el Mac a utm-share/mnist78_placa/"; exit 1; }
echo "  ficheros completos"

echo; echo "== 1/4 simulacion (iverilog + vvp), la UART bit a bit"
iverilog -g2012 -Irtl -Ptb_stream78.DIV=8 -o out/sim.vvp sim/tb_stream78.v $RTL
( cd out && vvp -n sim.vvp +IN=../sim/img.hex +EXP=../sim/exp.hex +OUT=sim.out \
      +NB=4 +NLOT=2 +VCD ) | tee out/sim.log | grep -vE "^VCD info" | sed 's/^/    /'
grep -q "ALL TESTS PASSED" out/sim.log || { echo "  !! la simulacion NO paso: no se sintetiza"; exit 1; }
echo "    formas de onda: out/stream78.vcd  (gtkwave out/stream78.vcd stream78.gtkw)"

echo; echo "== 2/4 sintesis (yosys)"
yosys -p "read_verilog -sv -Irtl $RTL; synth_ice40 -top top -json out/placa.json" \
    > out/yosys.log 2>&1 || { echo "  !! fallo yosys"; grep -E "ERROR" out/yosys.log; exit 1; }
NRAM=$(awk '/Printing statistics/{f=1} f' out/yosys.log | grep -E "SB_RAM40_4K" | tail -1 | awk '{print $1}')
echo "    SB_RAM40_4K: $NRAM   (tienen que ser 9)"
[ "$NRAM" = 9 ] || { echo "  !! la BRAM no se infirio como se esperaba"; exit 1; }

echo; echo "== 3/4 place & route (nextpnr)"
nextpnr-ice40 --up5k --package sg48 --freq 12 --json out/placa.json \
    --pcf mnist78_placa.pcf --asc out/placa.asc > out/pnr.log 2>&1 \
    || { echo "  !! fallo nextpnr"; grep -E "ERROR" out/pnr.log | head; exit 1; }
grep -E "ICESTORM_LC|ICESTORM_RAM|SB_IO:" out/pnr.log | head -3 | sed 's/^Info: */    /'
grep -E "Max frequency" out/pnr.log | tail -1 | sed 's/^Info: */    /'

echo; echo "== 4/4 bitstream (icepack)"
icepack out/placa.asc out/mnist78_placa.bin
ls -la out/mnist78_placa.bin | awk '{printf "    %s bytes  %s\n",$5,$9}'
md5sum out/mnist78_placa.bin | sed 's/^/    md5 /'
echo
echo "  LISTO. Grabar: copiar out/mnist78_placa.bin al disco iCELink."
echo "  Despues, en el Mac:  cd ~/UN/Tesis/Repository/tty_project_filter/clasificador_mnist"
echo "                       /opt/anaconda3/bin/python placa78.py 20      # prueba corta"
echo "                       /opt/anaconda3/bin/python placa78.py         # las 10 000 (~12 min)"
[ "$1" = "ver" ] && gtkwave out/stream78.vcd stream78.gtkw >/dev/null 2>&1 &
exit 0
