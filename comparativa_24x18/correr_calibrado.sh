#!/usr/bin/env bash
# correr_calibrado.sh — el experimento 5x6 con umbrales RECALIBRADOS para esta resolucion.
#
#   Los 90/40 (y 110/70 del transitivo) estan calibrados para 60x80 y a estas escalas
#   saturan. Este script corre las mismas 30 simulaciones con el par que se le pase.
#
#   Los filtros sueltos reciben los umbrales por plusargs del banco; los tres SoC los
#   llevan grabados en la ROM, asi que fw_thr.py recompila su firmware en src_cal/.
#   src/ NO se toca.
#
#   Uso:  bash correr_calibrado.sh 250 210
set -e
HI=${1:?falta thr_hi}; LO=${2:?falta thr_lo}
AQUI="$(cd "$(dirname "$0")" && pwd)"; cd "$AQUI"
N=$(grep -oE "localparam H = [0-9]+, W = [0-9]+" exp/tb_exp_stream.v | grep -oE "[0-9]+" | paste -sd* - | bc)

OUT=exp/out_${HI}_${LO}; CSV=exp/resultados_${HI}_${LO}.csv
rm -rf "$OUT" src_cal; mkdir -p "$OUT"; cp -r src src_cal
echo "== firmware recompilado para $HI/$LO =="
python3 fw_thr.py "$HI" "$LO" --patch src_cal
echo

S=src_cal
CPU="$S/femtorv32_quark.v $S/peripheral_filter.v"
echo "imagen,diseno,bordes,pixeles,densidad_pct" > $CSV
DISENOS="sobel:stream:-DDISENO=sobel_top:$S/sobel_top.v $S/linebuf3x3.v
canny1:stream:-DDISENO=canny1_top -DDOS_UMBRALES:$S/canny1_top.v $S/linebuf3x3.v
trans:trans::$S/grad_class_top.v $S/linebuf3x3.v $S/trans_engine_top.v $S/hysteresis_frame_bram_sync.sv
soc_sobel:stream:-DDISENO=soc_sobel_top -DCON_CPU:$S/soc_sobel_top.v $S/sobel_top.v $S/linebuf3x3.v $CPU
soc_canny1:stream:-DDISENO=soc_canny1_top -DCON_CPU -DDOS_UMBRALES:$S/soc_canny1_top.v $S/canny1_top.v $S/linebuf3x3.v $CPU
soc_trans:trans:-DCON_CPU:$S/grad_class_top.v $S/linebuf3x3.v $S/soc_trans_top.v $S/trans_engine_top.v $S/hysteresis_frame_bram_sync.sv $CPU"

printf "%-11s" "IMAGEN"
for d in sobel canny1 trans soc_sobel soc_canny1 soc_trans; do printf "%12s" "$d"; done; echo
printf "%-11s" "-----------"; for d in 1 2 3 4 5 6; do printf "%12s" "-----------"; done; echo

for img in flower monarch butterfly mano hi; do
    printf "%-11s" "$img"
    echo "$DISENOS" | while IFS=: read -r nom banco flags fuentes; do
        [ -z "$nom" ] && continue
        iverilog -g2012 $flags -o $OUT/$nom.vvp -s tb_exp_$banco exp/tb_exp_$banco.v $fuentes 2>/dev/null
        # los sueltos toman el umbral del banco; los SoC, de su ROM (por eso no lo reciben)
        case "$nom" in
          sobel)      arg="+THR=$HI" ;;
          canny1)     arg="+THR=$HI +TLO=$LO" ;;
          trans)      arg="+THI=$HI +TLO=$LO" ;;
          soc_trans)  arg="+THI=$HI +TLO=$LO" ;;   # la clase la genera el banco, no el DUT
          *)          arg="" ;;
        esac
        n=$(vvp $OUT/$nom.vvp +IMG=img/$img.hex +OUT=$OUT/${img}_${nom}.txt $arg | grep bordes | grep -oE "^[0-9]+")
        printf "%12s" "$n"
        echo "$img,$nom,$n,$N,$(python3 -c "print(f'{100*$n/$N:.1f}')")" >> $CSV
    done
    echo
done
echo
echo "Mapas en $OUT/  |  resumen en $CSV"
echo "Grilla:  python3 render_5x6.py ${HI}_${LO}"
