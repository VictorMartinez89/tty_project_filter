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
#   bash build_fpga.sh fase    -> LA CORRECCION: la luma es el 2do byte del par YUV422.
#                                 Una linea de diferencia con el cam_display probado.
#   bash build_fpga.sh pix     -> LA PLACA IMPRIME PIXELES VECINOS por serie. Si se parecen
#                                 entre si es una imagen; si saltan al azar, el muestreo esta mal.
#   bash build_fpga.sh neg     -> EL SOSPECHOSO ACTUAL: muestrear cam_d en el flanco de BAJADA
#                                 de PCLK. Una linea de diferencia con el cam_display probado.
#   bash build_fpga.sh uartbits-> EL DEFINITIVO: la placa reporta por SERIE que bits estan
#                                 pegados. AND=xx dice cuales valen 1 SIEMPRE. Sin fotos.
#   bash build_fpga.sh swap    -> DE QUE LADO ESTA: franjas verticales con cam_d[7] y cam_d[6]
#                                 intercambiados (42<->31). Si la franja pegada se MUEVE, es del
#                                 lado FPGA/conector; si se QUEDA, es de la camara o su cable.
#   bash build_fpga.sh franjas -> QUE CABLE FALLA, sin ambiguedad: los 8 bits en franjas VERTICALES.
#                                 Las verticales no las corre el OFFSET de lectura; las horizontales si.
#   bash build_fpga.sh bandas  -> QUE CABLE FALLA: los 8 bits de cam_d, uno por banda.
#                                 Tapando y destapando el lente se ve cual responde y cual no.
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
elif [ "$DEMO" = "fase" ]; then
    TOP=top; FUENTES="cam_fase.v"; PCF=cam_display.pcf; SALIDA=cam_fase
    OFS=${2:-2400}; PARAM="ofs"; echo "   OFFSET de encuadre = $OFS"
elif [ "$DEMO" = "pix" ]; then
    TOP=top; FUENTES="cam_uart_pix.v uart_tx.v"; PCF=cam_uart.pcf; SALIDA=cam_pix
elif [ "$DEMO" = "neg" ]; then
    TOP=top; FUENTES="cam_negedge.v"; PCF=cam_display.pcf; SALIDA=cam_neg
elif [ "$DEMO" = "camcanny" ]; then
    # la cadena ENTERA con front-end Canny: camara -> ventana -> Canny -> clasificador -> TFT
    TOP=top; FUENTES="mnist_cam_canny.v cam_win28.v glifo.v ../rtl/mnist_top_canny.v ../rtl/mnist_feat_canny.v ../rtl/mnist_clf_canny.v ../rtl/linebuf3x3.v"
    PCF=mnist_cam.pcf; SALIDA=mnist_cam_canny
elif [ "$DEMO" = "win" ]; then
    # vuelca la ventana de 28x28 por UART, para el experimento de las 3 iluminaciones
    TOP=top; FUENTES="cam_uart_win.v cam_win28.v uart_tx.v"; PCF=cam_uart_win.pcf; SALIDA=cam_win
elif [ "$DEMO" = "uartbits" ]; then
    TOP=top; FUENTES="cam_uart_bits.v uart_tx.v"; PCF=cam_uart.pcf; SALIDA=cam_uartbits
elif [ "$DEMO" = "swap" ]; then
    TOP=top; FUENTES="cam_franjas.v"; PCF=cam_swap.pcf; SALIDA=cam_swap
elif [ "$DEMO" = "franjas" ]; then
    TOP=top; FUENTES="cam_franjas.v"; PCF=cam_display.pcf; SALIDA=cam_franjas
elif [ "$DEMO" = "bandas" ]; then
    TOP=top; FUENTES="cam_bandas.v"; PCF=cam_display.pcf; SALIDA=cam_bandas
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
yosys -p "read_verilog -I../rtl $FUENTES; chparam ${PARAM:+$(case $PARAM in patron) echo "-set FUENTE 1";; ofs) echo "-set OFS $OFS";; *) echo "-set INVERTIR 0";; esac)} $TOP; synth_ice40 -top $TOP -json $SALIDA.json" | tee yosys.log | tail -20

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
