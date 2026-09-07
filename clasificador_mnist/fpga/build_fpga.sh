#!/usr/bin/env bash
# build_fpga.sh — bitstream del clasificador de digitos para la iCESugar v1.5 (iCE40UP5K).
#
#   CORRE EN LA VM UBUNTU: nextpnr-ice40 e icepack no estan en el Mac.
#   Antes de correrlo hay que activar la toolchain:
#
#       source ~/Documents/UN/oss-cad-suite/environment      # el prompt muestra ⦗OSS CAD Suite⦘
#       cd /mnt/share/utm-share/fpga_mnist
#       bash build_fpga.sh
#
#   Sale `mnist.bin`. Para grabar: copiarlo al disco iCELink (en el Mac, /Volumes/iCELink).
#   Para ver el resultado: terminal serie a 115200 8N1 en el puerto de la iCESugar.
set -e
AQUI="$(cd "$(dirname "$0")" && pwd)"; cd "$AQUI"
TOP=top
FUENTES="rom_digitos.v uart_tx.v fpga_mnist_top.v linebuf3x3.v mnist_feat.v mnist_clf.v mnist_top.v"

command -v nextpnr-ice40 >/dev/null || {
    echo "!! nextpnr-ice40 no esta en el PATH."
    echo "   source ~/Documents/UN/oss-cad-suite/environment"; exit 1; }

echo "== 1/3 sintesis (yosys)"
yosys -p "read_verilog $FUENTES; synth_ice40 -top $TOP -json mnist.json" | tee yosys.log | tail -20

echo
echo "== 2/3 place & route (nextpnr)"
nextpnr-ice40 --up5k --package sg48 --freq 12 \
    --json mnist.json --pcf fpga_mnist.pcf --asc mnist.asc 2>&1 | tee nextpnr.log | \
    grep -E "Device utilisation|ICESTORM|SB_RAM|Max frequency|ERROR" || true

echo
echo "== 3/3 bitstream (icepack)"
icepack mnist.asc mnist.bin
ls -la mnist.bin
echo
echo "listo. Copiar mnist.bin al disco iCELink y abrir la terminal serie a 115200."
