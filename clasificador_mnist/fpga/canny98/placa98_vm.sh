#!/bin/sh
# placa98_vm.sh — Canny-98 (98,45 %, capa oculta de 120) para la iCESugar, alimentado por el puerto serie.
#   MARCA_CANNY98_PLACA_28SEP
#   sh /mnt/share/utm-share/canny98_placa/placa98_vm.sh
# Cuatro pasos; cada uno PARA si el anterior no paso:
#   1. iverilog: el RTL con la UART bit a bit, 8 imagenes, contra el modelo entero -> ALL TESTS PASSED
#   2. yosys   : tienen que salir 30 SB_RAM40_4K y 1 SB_SPRAM256KA
#   3. nextpnr : LC, frecuencia y PASS a 12 MHz
#   4. icepack : out/canny98_placa.bin   -> copiar al disco iCELink DESDE EL MAC
set -e
AQUI="$(cd "$(dirname "$0")" && pwd)"; cd "$AQUI"; mkdir -p out
export PATH="$HOME/Documents/UN/oss-cad-suite/bin:$PATH"
RTL="rtl/fpga_mnist98_stream.v rtl/uart_rx.v rtl/uart_tx.v rtl/mnist_top98.v rtl/mnist_feat16_mem.v rtl/mnist_clf98.v rtl/linebuf3x3.v"
grep -q "MARCA_CANNY98_PLACA_28SEP" "$0" || { echo "!! el script no es el nuevo (la share sirve contenido viejo)"; exit 1; }
for f in $RTL canny98_w.hex canny98_b1.hex canny98_b2.hex canny98_placa.pcf sim/tb_stream78.v sim/img.hex sim/exp98.hex sim/sim_spram256ka.v; do
    [ -f "$f" ] || { echo "  !! FALTA $f"; exit 1; }
done
echo "== 1/4 simulacion con la UART (8 imagenes)"
iverilog -g2012 -Ptb_stream78.DIV=8 -Ptb_stream78.IDLE=40000 -o out/sim.vvp sim/tb_stream78.v $RTL sim/sim_spram256ka.v
vvp -n out/sim.vvp +IN=sim/img.hex +EXP=sim/exp98.hex +OUT=out/sim.out | grep -v WARNING | tail -3 | tee out/sim.log
grep -q "ALL TESTS PASSED" out/sim.log || { echo "  !! la simulacion no paso: NO seguir"; exit 1; }
echo "== 2/4 sintesis (yosys)"
yosys -p "read_verilog $RTL; synth_ice40 -top top -json out/placa.json; tee -o out/stat.txt stat" > out/yosys.log 2>&1 \
    || { echo "  !! fallo yosys"; grep ERROR out/yosys.log; exit 1; }
grep -E "SB_RAM40_4K|SB_SPRAM256KA|SB_LUT4" out/stat.txt
echo "    avisos 'no driver': $(grep -c 'no driver' out/yosys.log)   (tiene que ser 0)"
echo "== 3/4 place & route (nextpnr)"
nextpnr-ice40 --up5k --package sg48 --freq 12 --json out/placa.json --pcf canny98_placa.pcf --asc out/placa.asc \
    > out/pnr.log 2>&1 || { echo "  !! fallo nextpnr"; grep ERROR out/pnr.log | head; exit 1; }
grep -A3 "Device utilisation" out/pnr.log | sed 's/^Info: */    /'
grep -E "ICESTORM_RAM|ICESTORM_SPRAM|Max frequency" out/pnr.log | tail -3 | sed 's/^Info: */    /'
echo "== 4/4 bitstream"
icepack out/placa.asc out/canny98_placa.bin && md5sum out/canny98_placa.bin
echo "LISTO. En el Mac: cp -X out/canny98_placa.bin /Volumes/iCELink/  (esperar a que el .bin desaparezca)"
