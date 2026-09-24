#!/bin/sh
# preparar_canny78.sh — el chip 17: Canny-78 (la cadena del 97,22 %) en sky130 con OpenLane.
#   MARCA_CANNY78_ASIC_24SEP
#
#   sh /mnt/share/utm-share/canny78_asic/preparar_canny78.sh
#
# Es EXACTAMENTE el RTL que dio 10 000/10 000 en la iCESugar (md5 comprobados contra el paquete de
# la placa en el Mac). Tope: mnist_top78 — entra un pixel por ciclo, sale el digito y la decision
# de rechazo. Un solo reloj, reset sincrono explicito, sin `initial`, sin primitivas de Lattice.
#
# Lo que hace este guion, y lo que NO hace:
#   1. comprueba los md5 de las fuentes YA EN LA SHARE (la virtiofs sirve contenido viejo a veces)
#   2. mira el disco de la VM (cada run pesa varios G)
#   3. copia el diseno a $OL/designs/canny78 y crea runs/ (sin runs/ OpenLane muere con un error
#      que tapa el de verdad: «couldn't write .../openlane.log»)
#   4. verifica los parametros YA EN EL DESTINO
#   NO borra nada: si designs/canny78 ya tiene runs, se niega (un guion que prepara no destruye la
#   evidencia de un fallo anterior). NO lanza OpenLane: imprime los comandos.
set -e
AQUI="$(cd "$(dirname "$0")" && pwd)"
OL="${OL:-$HOME/Documents/UN/OpenLane}"
DST="$OL/designs/canny78"

echo "=========================================================="
echo "  CHIP 17 · Canny-78 · sky130_fd_sc_hd · OpenLane"
echo "=========================================================="

echo; echo "== 1/4 md5 de las fuentes, leidos desde la share"
( cd "$AQUI/canny78/src" && md5sum -c "$AQUI/md5_fuentes.txt" ) | sed 's/^/    /' \
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
cp "$AQUI/canny78/config.json" "$DST/"
cp "$AQUI/canny78/src/"* "$DST/src/"
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
    ./flow.tcl -design canny78 -tag c78 -ignore_mismatches

  Esperado: ~35 000 celdas sky130 (estimado con yosys x 1,383), ~30-60 min.
  Al terminar, pegarle a Claude:
    tail -5 designs/canny78/runs/c78/openlane.log
    ls designs/canny78/runs/c78/results/final/gds/
  y NO archivar todavia: archivar_chip.sh canny78 c78 es seguro (nombre nuevo), pero antes se
  revisan las metricas juntos.
EOF
