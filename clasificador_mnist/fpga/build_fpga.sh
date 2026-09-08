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
# Dos demos. Se elige con el primer argumento:
#   bash build_fpga.sh uart    -> los 10 digitos de la ROM por el puerto serie
#   bash build_fpga.sh cam     -> la camara: escribi un digito y miralo en el TFT
#   bash build_fpga.sh crudo   -> DIAGNOSTICO: la camara sin invertir, para ver exposicion/foco
#   bash build_fpga.sh bits    -> DIAGNOSTICO DEL BUS: solo los 4 bits altos de cam_d.
#                                 Si con esto la imagen se limpia, los bits bajos estan flojos.
#   bash build_fpga.sh patron  -> DIAGNOSTICO DE PCLK: escribe una RAMPA generada adentro,
#                                 sin tocar cam_d. Si sale limpia el problema son los cables de
#                                 datos; si sale ruidosa, el problema es PCLK.
#   bash build_fpga.sh raw     -> REFERENCIA: cam_display.v, el diseno de camara cruda que YA
#                                 funcionaba antes de todo esto. Si este muestra imagen y el
#                                 'crudo' no, el problema es mio; si tampoco, es de camara/luz.
DEMO="${1:-cam}"
COMUN="linebuf3x3.v mnist_feat.v mnist_clf.v mnist_top.v"
if [ "$DEMO" = "uart" ]; then
    TOP=top; FUENTES="rom_digitos.v uart_tx.v fpga_mnist_top.v $COMUN"; PCF=fpga_mnist.pcf
    SALIDA=mnist_uart
elif [ "$DEMO" = "patron" ]; then
    TOP=top; FUENTES="cam_patron.v"; PCF=cam_display.pcf; SALIDA=cam_patron; PARAM="patron"
elif [ "$DEMO" = "bits" ]; then
    TOP=top; FUENTES="cam_bits.v"; PCF=cam_display.pcf; SALIDA=cam_bits
elif [ "$DEMO" = "raw" ]; then
    TOP=top; FUENTES="cam_display.v"; PCF=cam_display.pcf; SALIDA=cam_raw
elif [ "$DEMO" = "crudo" ]; then
    TOP=top; FUENTES="mnist_cam_display.v cam_win28.v glifo.v $COMUN";  PCF=mnist_cam.pcf
    SALIDA=mnist_crudo; PARAM="-p INVERTIR=0"
else
    TOP=top; FUENTES="mnist_cam_display.v cam_win28.v glifo.v $COMUN";  PCF=mnist_cam.pcf
    SALIDA=mnist_cam
fi
echo "== demo: $DEMO -> $SALIDA.bin"

command -v nextpnr-ice40 >/dev/null || {
    echo "!! nextpnr-ice40 no esta en el PATH."
    echo "   source ~/Documents/UN/oss-cad-suite/environment"; exit 1; }

echo "== 1/3 sintesis (yosys)"
yosys -p "read_verilog $FUENTES; chparam ${PARAM:+$([ "$PARAM" = patron ] && echo "-set FUENTE 1" || echo "-set INVERTIR 0")} $TOP; synth_ice40 -top $TOP -json $SALIDA.json" | tee yosys.log | tail -20

echo
echo "== 2/3 place & route (nextpnr)"
nextpnr-ice40 --up5k --package sg48 --freq 12 \
    --json $SALIDA.json --pcf $PCF --asc $SALIDA.asc 2>&1 | tee nextpnr.log | \
    grep -E "Device utilisation|ICESTORM|SB_RAM|Max frequency|ERROR" || true

echo
echo "== 3/3 bitstream (icepack)"
icepack $SALIDA.asc $SALIDA.bin
ls -la $SALIDA.bin
echo
echo "listo. Copiar $SALIDA.bin al disco iCELink."
[ "$DEMO" = "uart" ] && echo "  y abrir la terminal serie a 115200 8N1."
[ "$DEMO" = "cam" ] && echo "  escribi un digito GRUESO y OSCURO en papel blanco y llena el marco verde."
