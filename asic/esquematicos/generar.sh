#!/bin/sh
# generar.sh — los siete esquematicos RTL, generados DEL RTL con yosys + netlistsvg
# y revestidos con la paleta del RTL Viewer de Xilinx ISE (xilinx.py).
set -e
D="$(cd "$(dirname "$0")" && pwd)"; cd "$D"
R="$HOME/UN/Tesis/Repository/tty_project_filter"
A="$R/asic"; F="$R/clasificador_mnist/fpga"; C="$R/clasificador_mnist/rtl"

uno() {  # uno <top> <titulo> <fuentes...>
    top="$1"; tit="$2"; shift 2
    printf "  %-22s " "$top"
    # `memory -nomap` deja las memorias como bloques legibles en vez de una caja opaca:
    # sin el, trans_engine_top -que ES un framebuffer- salia con UNA sola celda.
    yosys -p "read_verilog -I$C $*; hierarchy -top $top; proc; memory -nomap; opt_clean; write_json $top.json" \
        > "ys_$top.log" 2>&1 || { echo "FALLO yosys (ver ys_$top.log)"; return 0; }
    python3 solo_top.py "$top.json" "$top" || return 0
    node node_modules/.bin/netlistsvg "$top.json" -o "$top.svg" >/dev/null 2>&1 \
        || { echo "FALLO netlistsvg"; return 0; }
    python3 xilinx.py "$top.svg" "${top}_x.svg" "$tit" >/dev/null
    printf "ok  %s\n" "$(python3 -c "import re,sys;s=open('${top}_x.svg').read();m=re.search(r'viewBox=\"0 0 (\d+) (\d+)\"',s);print(m.group(1)+'x'+m.group(2))")"
}

# Vista de BLOQUES: se lee SOLO el fichero del top y los submodulos quedan sin resolver,
# asi que yosys los trata como cajas negras y netlistsvg los dibuja como cajas con sus
# pines -que es la vista de primer nivel del RTL Viewer de ISE-. Hace falta porque el
# nivel de operador de estos disenos da 41 000 px de ancho: correcto pero inservible.
bloque() {
    top="$1"; tit="$2"; fuente="$3"
    printf "  %-22s " "$top (bloques)"
    yosys -p "read_verilog -I$C $fuente; hierarchy -top $top; proc; memory -nomap; opt_clean; write_json $top.json" \
        > "ys_$top.log" 2>&1 || { echo "FALLO yosys"; return 0; }
    python3 solo_top.py "$top.json" "$top" || return 0
    node node_modules/.bin/netlistsvg "$top.json" -o "$top.svg" >/dev/null 2>&1 \
        || { echo "FALLO netlistsvg"; return 0; }
    python3 xilinx.py "$top.svg" "${top}_x.svg" "$tit" >/dev/null
    printf "ok  %s\n" "$(python3 -c "import re;s=open('${top}_x.svg').read();m=re.search(r'viewBox=\"0 0 (\d+) (\d+)\"',s);print(m.group(1)+'x'+m.group(2))")"
}

uno sobel_top          "sobel_top:1"          $A/sobel_top/src/sobel_top.v $A/sobel_top/src/linebuf3x3.v
uno canny1_top         "canny1_top:1"         $A/canny1_top/src/*.v
uno hysteresis_frame_bram_sync "hysteresis_frame_bram_sync:1" $A/trans_engine_top/src/*.v
bloque vision_sobel_mnist "vision_sobel_mnist:1" $A/vision_mnist/src/vision_sobel_mnist.v
bloque vision_canny_mnist "vision_canny_mnist:1" $A/vision_mnist/src/vision_canny_mnist.v
