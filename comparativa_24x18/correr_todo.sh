#!/usr/bin/env bash
# correr_todo.sh — la tanda completa de los 6 disenos a 16x12, en un solo comando.
#   1) SIMULACION  (iverilog + vvp)  -> un .vcd por diseno, listo para GTKWave
#   2) SINTESIS    (yosys synth_ice40)
#   3) P&R         (nextpnr-ice40)   -> Device Utilisation + frecuencia maxima
#   4) TABLA final comparativa
#
# Correr EN LA VM con el oss-cad-suite activado:
#   bash /mnt/share/utm-share/comparativa_16x12/correr_todo.sh
#
# Los seis usan EL MISMO cuadro de 16 filas x 12 columnas, para que sus tamanos sean comparables:
# asi se separa "que tan complejo es el filtro" de "que tan grande es la imagen".
set -e
AQUI="$(cd "$(dirname "$0")" && pwd)"
OUT="${OUT:-$AQUI/out}"
mkdir -p "$OUT"
cd "$OUT"

S="$AQUI/src"
LB="$S/linebuf3x3.v"
CPU="$S/femtorv32_quark.v $S/peripheral_filter.v"

#      nombre : top : fuentes
DISENOS="sobel:sobel_top:$S/sobel_top.v $LB
canny1:canny1_top:$S/canny1_top.v $LB
trans:trans_engine_top:$S/trans_engine_top.v $S/hysteresis_frame_bram_sync.sv
soc_sobel:soc_sobel_top:$S/soc_sobel_top.v $S/sobel_top.v $LB $CPU
soc_canny1:soc_canny1_top:$S/soc_canny1_top.v $S/canny1_top.v $LB $CPU
soc_trans:soc_trans_top:$S/soc_trans_top.v $S/trans_engine_top.v $S/hysteresis_frame_bram_sync.sv $CPU"

echo "=================== 1) SIMULACION (iverilog) ==================="
echo "$DISENOS" | while IFS=: read -r nom top fuentes; do
    [ -z "$nom" ] && continue
    iverilog -g2012 -o "$OUT/$nom.vvp" -s "tb_$nom" "$AQUI/tb/tb_$nom.v" $fuentes 2>"$OUT/$nom.iv.log"
    vvp "$OUT/$nom.vvp" | grep -v '\$finish' | sed 's/^/  /'
done

echo
echo "=================== 2) SINTESIS + P&R (yosys + nextpnr) ==================="
printf "%-12s %8s %8s %8s %10s\n" "DISENO" "LC" "BRAM" "SB_IO" "Fmax"
printf "%-12s %8s %8s %8s %10s\n" "------------" "--------" "--------" "--------" "----------"
echo "$DISENOS" | while IFS=: read -r nom top fuentes; do
    [ -z "$nom" ] && continue
    yosys -p "read_verilog -sv $fuentes; synth_ice40 -top $top -json $OUT/$nom.json" \
          > "$OUT/$nom.yosys.log" 2>&1
    nextpnr-ice40 --up5k --package sg48 --json "$OUT/$nom.json" --asc "$OUT/$nom.asc" --freq 12 \
          > "$OUT/$nom.pnr.log" 2>&1 || true
    lc=$(grep -oE "ICESTORM_LC: +[0-9]+" "$OUT/$nom.pnr.log" | head -1 | grep -oE "[0-9]+")
    ram=$(grep -oE "ICESTORM_RAM: +[0-9]+" "$OUT/$nom.pnr.log" | head -1 | grep -oE "[0-9]+")
    io=$(grep -oE "SB_IO: +[0-9]+" "$OUT/$nom.pnr.log" | head -1 | grep -oE "[0-9]+")
    fm=$(grep -oE "Max frequency for clock[^:]*: [0-9.]+ MHz" "$OUT/$nom.pnr.log" | tail -1 | grep -oE "[0-9.]+ MHz")
    printf "%-12s %8s %8s %8s %10s\n" "$nom" "${lc:--}" "${ram:--}" "${io:--}" "${fm:--}"
done

cat <<TXT

=================== 3) LAS ONDAS ===================
Los .vcd quedaron en $OUT/. Para verlos con las senales ya elegidas:

  gtkwave $OUT/sobel.vcd      $AQUI/gtkw/sobel.gtkw
  gtkwave $OUT/canny1.vcd     $AQUI/gtkw/canny1.gtkw
  gtkwave $OUT/trans.vcd      $AQUI/gtkw/trans.gtkw
  gtkwave $OUT/soc_sobel.vcd  $AQUI/gtkw/soc_sobel.gtkw
  gtkwave $OUT/soc_canny1.vcd $AQUI/gtkw/soc_canny1.gtkw
  gtkwave $OUT/soc_trans.vcd  $AQUI/gtkw/soc_trans.gtkw

Que mirar en cada foto:
  sobel / canny1        el escalon de brillo entrando por in_pix y los 0xFF saliendo por out_pix
  trans                 load_ready -> la carga -> el barrido (silencio) -> out_valid con la cadena
  soc_*                 cpu_wrote_filter subiendo y el umbral apareciendo ANTES del primer pixel
TXT
