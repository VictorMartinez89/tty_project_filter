#!/bin/sh
# preparar_canny78_f9.sh — Canny-78 con fmem RECORTADA (168x9 en vez de 256x13), para medir en sky130
#   cuanto ahorra el recorte. Misma receta que el chip 17 (run c78): 30 ns, util 30, densidad 0,40.
#   MARCA_CANNY78_F9_ASIC_24SEP
#
#   sh /mnt/share/utm-share/canny78_f9_asic/preparar_canny78_f9.sh
#
# OJO: NO es el RTL de la placa. Es una VARIANTE (mnist_top78_f9 + mnist_clf78_x2_f168): 7 lineas
# cambiadas respecto al verificado, re-verificada contra el golden en iverilog sobre las 10 000 antes de
# armar este paquete. Tope: mnist_top78_f9. Un reloj, reset sincrono, sin `initial`, sin Lattice.
#
# Lo que hace este guion, y lo que NO hace:
#   1. comprueba los md5 de las fuentes YA EN LA SHARE (la virtiofs sirve contenido viejo a veces)
#   2. mira el disco de la VM (cada run pesa varios G)
#   3. copia el diseno a $OL/designs/canny78_f9 y crea runs/ (sin runs/ OpenLane muere con un error
#      que tapa el de verdad: «couldn't write .../openlane.log»)
#   4. verifica los parametros YA EN EL DESTINO
#   NO borra nada: si designs/canny78_f9 ya tiene runs, se niega (un guion que prepara no destruye la
#   evidencia de un fallo anterior). NO lanza OpenLane: imprime los comandos.
set -e
AQUI="$(cd "$(dirname "$0")" && pwd)"
OL="${OL:-$HOME/Documents/UN/OpenLane}"
DST="$OL/designs/canny78_f9"

echo "=========================================================="
echo "  Canny-78 f9 (fmem 168x9) · sky130 · OpenLane · misma receta que c78"
echo "=========================================================="

echo; echo "== 1/4 md5 de las fuentes, leidos desde la share"
( cd "$AQUI/canny78_f9/src" && md5sum -c "$AQUI/md5_fuentes.txt" ) | sed 's/^/    /' \
    || { echo "  !! alguna fuente no coincide: la share sirve una version vieja. No seguir."; exit 1; }

echo; echo "== 2/4 disco de la VM"
LIBRE=$(df -BG --output=avail "$HOME" | tail -1 | tr -dc '0-9')
echo "    libres: ${LIBRE} G"
[ "$LIBRE" -ge 12 ] || echo "  !! menos de 12 G libres: un run de ~35 000 celdas puede no terminar. Liberar antes (u35_lanzar/espacio_vm.sh)."

echo; echo "== 3/4 copiar a $DST"
[ -d "$OL/designs" ] || { echo "  !! no existe $OL/designs (exportar OL=... si OpenLane esta en otro sitio)"; exit 1; }
if [ -d "$DST/runs" ] && [ -n "$(ls -A "$DST/runs" 2>/dev/null)" ]; then
    echo "  !! $DST/runs ya tiene corridas. No se toca nada. Si es a proposito, usar otro -tag o moverlas a mano."
    exit 1
fi
mkdir -p "$DST/src" "$DST/runs"
cp "$AQUI/canny78_f9/config.json" "$DST/"
cp "$AQUI/canny78_f9/src/"* "$DST/src/"
echo "    copiado; runs/ creado"

echo; echo "== 4/4 verificar EN EL DESTINO"
( cd "$DST/src" && md5sum -c "$AQUI/md5_fuentes.txt" ) | sed 's/^/    /'
grep -E '"(DESIGN_NAME|CLOCK_PERIOD|FP_CORE_UTIL|PL_TARGET_DENSITY)"' "$DST/config.json" | sed 's/^/    /'
[ "$(wc -c < "$DST/config.json")" -gt 100 ] || { echo "  !! config.json vacio o truncado"; exit 1; }

cat <<EOF

  LISTO. Ahora, a mano:
    cd $OL && make mount
    # dentro del contenedor:
    export PDK_ROOT=/home/vic/.ciel
    ./flow.tcl -design canny78_f9 -tag f9 -ignore_mismatches

  Esperado: ~22 200 celdas sky130 (19 076 genericas x 1,162, el factor MEDIDO en c78), ~30-60 min.
  Al terminar, pegarle a Claude:
    tail -5 designs/canny78_f9/runs/f9/openlane.log
    ls designs/canny78_f9/runs/f9/results/final/gds/
  y NO archivar todavia: archivar_chip.sh canny78_f9 f9 es seguro (nombre nuevo), pero antes se
  revisan las metricas juntos.
EOF
