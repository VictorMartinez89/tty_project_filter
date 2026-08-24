#!/usr/bin/env bash
# correr_experimento.sh — el experimento 5 imagenes x 6 disenos, a 16x12, en iverilog.
#
#   5 imagenes: flower, monarch, butterfly, mano, hi   (las mismas de la tesis)
#   6 disenos:  Sobel, Canny1, transitivo  x  (sin CPU / con SoC femto)
#
# Cada celda es una simulacion RTL completa. Deja en exp/out/<img>_<diseno>.txt el
# mapa de bordes (192 lineas, 1 = borde) y en exp/resultados.csv el resumen.
#
# Uso:  bash correr_experimento.sh        (Mac o VM, solo necesita iverilog)
set -e
AQUI="$(cd "$(dirname "$0")" && pwd)"
cd "$AQUI"
mkdir -p exp/out
S=src
CPU="$S/femtorv32_quark.v $S/peripheral_filter.v"
CSV=exp/resultados.csv
echo "imagen,diseno,bordes,pixeles,densidad_pct" > $CSV

# diseno : banco : flags : fuentes
DISENOS="sobel:stream:-DDISENO=sobel_top:$S/sobel_top.v $S/linebuf3x3.v
canny1:stream:-DDISENO=canny1_top -DDOS_UMBRALES:$S/canny1_top.v $S/linebuf3x3.v
trans:trans::$S/grad_class_top.v $S/linebuf3x3.v $S/trans_engine_top.v $S/hysteresis_frame_bram_sync.sv
soc_sobel:stream:-DDISENO=soc_sobel_top -DCON_CPU:$S/soc_sobel_top.v $S/sobel_top.v $S/linebuf3x3.v $CPU
soc_canny1:stream:-DDISENO=soc_canny1_top -DCON_CPU -DDOS_UMBRALES:$S/soc_canny1_top.v $S/canny1_top.v $S/linebuf3x3.v $CPU
soc_trans:trans:-DCON_CPU:$S/grad_class_top.v $S/linebuf3x3.v $S/soc_trans_top.v $S/trans_engine_top.v $S/hysteresis_frame_bram_sync.sv $CPU"

IMAGENES="flower monarch butterfly mano hi"

printf "%-11s" "IMAGEN"
for d in sobel canny1 trans soc_sobel soc_canny1 soc_trans; do printf "%12s" "$d"; done; echo
printf "%-11s" "-----------"
for d in 1 2 3 4 5 6; do printf "%12s" "-----------"; done; echo

for img in $IMAGENES; do
    printf "%-11s" "$img"
    echo "$DISENOS" | while IFS=: read -r nom banco flags fuentes; do
        [ -z "$nom" ] && continue
        iverilog -g2012 $flags -o exp/out/$nom.vvp -s tb_exp_$banco exp/tb_exp_$banco.v $fuentes 2>/dev/null
        salida=$(vvp exp/out/$nom.vvp +IMG=img/$img.hex +OUT=exp/out/${img}_${nom}.txt | grep bordes)
        n=$(echo "$salida" | grep -oE "^[0-9]+")
        printf "%12s" "$n"
        pct=$(python3 -c "print(f'{100*$n/192:.1f}')")
        echo "$img,$nom,$n,192,$pct" >> $CSV
    done
    echo
done

echo
echo "Mapas de bordes en exp/out/*.txt  |  resumen en $CSV"
echo "Para ver la grilla 5x6:  python3 render_5x6.py"
