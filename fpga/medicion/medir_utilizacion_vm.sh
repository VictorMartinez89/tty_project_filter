#!/usr/bin/env bash
# medir_utilizacion_vm.sh — Device Utilisation de nextpnr para la tabla de la 5.2 de la tesis.
#
# Rehace la fila que falta (SoC + Sobel) y RECOMPRUEBA las otras tres contra los informes
# ya guardados, para que la tabla entera quede verificada con la misma herramienta.
# Las ordenes de lectura de fuentes son LAS MISMAS de los build_*.sh originales.
#
# CORRER EN LA VM (nextpnr no esta en el Mac):
#     source ~/oss-cad-suite/environment
#     bash /mnt/share/utm-share/medir_util/medir_utilizacion_vm.sh
#
# Deja los informes en  /mnt/share/utm-share/medir_util/out/  (visibles desde el Mac).
set -u
SH=/mnt/share/utm-share
OUT="$(cd "$(dirname "$0")" && pwd)/out"
mkdir -p "$OUT"

command -v nextpnr-ice40 >/dev/null || { echo "!! falta nextpnr-ice40: source ~/oss-cad-suite/environment"; exit 1; }
echo "yosys:    $(yosys -V 2>/dev/null | head -1)"
echo "nextpnr:  $(nextpnr-ice40 --version 2>&1 | head -1)"
echo

medir () {           # $1=nombre  $2=subdirectorio  $3=orden de lectura para yosys
    local nom=$1 dir=$2 lectura=$3
    echo "=================================================== $nom   ($dir)"
    if ! cd "$SH/$dir" 2>/dev/null; then echo "   !! no existe $SH/$dir"; return; fi

    yosys -p "$lectura synth_ice40 -top top -json $OUT/$nom.json" > "$OUT/$nom.yosys.log" 2>&1
    if [ ! -f "$OUT/$nom.json" ]; then
        echo "   !! fallo la sintesis. Ultimas lineas:"
        tail -6 "$OUT/$nom.yosys.log" | sed 's/^/      /'
        return
    fi
    awk '/Printing statistics/,0' "$OUT/$nom.yosys.log" \
      | grep -iE "SB_LUT4|SB_RAM40_4K|SB_SPRAM" | tail -3 | sed 's/^/   sintesis: /'

    # sin --freq a proposito: queremos la utilizacion y la fmax, no que aborte por timing
    nextpnr-ice40 --up5k --package sg48 --json "$OUT/$nom.json" --asc "$OUT/$nom.asc" \
        > "$OUT/$nom.pnr.log" 2>&1
    if grep -q "ICESTORM_LC:" "$OUT/$nom.pnr.log"; then
        grep -E "ICESTORM_LC:|ICESTORM_RAM:|ICESTORM_SPRAM:|SB_IO:" "$OUT/$nom.pnr.log" \
          | sed 's/Info:[[:space:]]*/   /'
        grep -E "Max frequency" "$OUT/$nom.pnr.log" | tail -2 | sed 's/Info:[[:space:]]*/   /'
    else
        echo "   !! nextpnr no llego a informar utilizacion. Ultimas lineas:"
        tail -6 "$OUT/$nom.pnr.log" | sed 's/^/      /'
    fi
    echo
}

# >>> LA FILA QUE FALTA EN LA TABLA <<<
medir soc_sobel femto_sobel \
  "read_verilog cam_femto_display.v femtorv32_quark.v peripheral_filter.v linebuf3x3.v;"

# >>> las tres que ya tienen informe, para recomprobarlas <<<
medir soc_canny1 femto_canny_streaming \
  "read_verilog cam_femto_multi.v femtorv32_quark.v peripheral_filter.v linebuf3x3.v;"

medir trans_hw femto_canny_transitivo \
  "read_verilog -sv hysteresis_frame_bram_sync.sv; read_verilog cam_trans_display.v filter_multi_wh.v linebuf3x3.v clsfb_spram.v spram_fb.v;"

medir soc_trans_sw femto_canny_transitivo \
  "read_verilog cam_trans_soc.v femtorv32_quark.v linebuf3x3.v;"

cat <<TXT
Informes completos en $OUT/   (en el Mac: /Users/vic/utm-share/medir_util/out/)

Lo esperado, segun los informes ya guardados:
   soc_sobel      LC ~4878 (92 %)   BRAM 20   SPRAM 0     <- ESTA es la que falta confirmar
   soc_canny1     LC  5234 (99 %)   BRAM 24   SPRAM 0
   trans_hw       LC  2426 (45 %)   BRAM 17   SPRAM 2
   soc_trans_sw   LC  5251 (99 %)   BRAM 28   SPRAM 0
TXT
