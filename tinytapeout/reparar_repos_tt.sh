#!/usr/bin/env bash
# reparar_repos_tt.sh — arregla los repos de Tiny Tapeout que se crearon pisando la plantilla.
#
# El error: al volcar el proyecto se borraron carpetas enteras (src/, test/) y con ellas
# archivos que la plantilla necesita:
#   src/config.json        -> config de OpenLane   ("Could not find configuration file")
#   test/requirements.txt  -> pytest + cocotb      ("Could not open requirements file")
#   test/Makefile          -> maneja RTL Y gate-level (GATES=yes) con las rutas del PDK
#   test/tb.v              -> trae los pines de potencia (VPWR/VGND) para el gl_test
#
# Lo correcto es PARCHEAR la plantilla, no reemplazarla:
#   - se restauran esos 4 archivos del commit inicial
#   - al Makefile se le cambia PROJECT_SOURCES por los fuentes del proyecto
#   - al tb.v se le cambia tt_um_example por el top real
#   - se dejan nuestros src/*.v, test/test.py, docs/info.md e info.yaml
#
# Uso:  bash reparar_repos_tt.sh          (muestra el plan)
#       bash reparar_repos_tt.sh --arreglar
set -e
AQUI="$(cd "$(dirname "$0")" && pwd)"
DESTINO="${DESTINO:-$HOME/UN/Tesis/tt_repos}"
ARREGLAR=0; [ "$1" = "--arreglar" ] && ARREGLAR=1
SOLO="${SOLO:-}"   # SOLO=tt_sobel para arreglar uno solo

PROYECTOS="tt_sobel:tt_sobel_vic
tt_canny1:tt_canny1_vic
tt_soc_sobel:tt_soc_sobel_vic
tt_soc_sobel_flash:tt_soc_sobel_flash_vic
tt_trans_mini:tt_trans_mini_vic
tt_soc_canny1:tt_soc_canny1_vic"

[ $ARREGLAR -eq 0 ] && echo "== MODO PRUEBA: no toco nada. Agrega --arreglar para hacerlo de verdad."

echo "$PROYECTOS" | while IFS=: read -r carpeta repo; do
    [ -z "$carpeta" ] && continue
    if [ -n "$SOLO" ] && [ "$carpeta" != "$SOLO" ]; then continue; fi
    src="$AQUI/$carpeta"; clone="$DESTINO/$repo"
    [ -d "$clone" ] || { echo "!! no esta clonado: $clone"; continue; }

    top=$(grep -E "^ *top_module:" "$src/info.yaml" | sed 's/.*"\(.*\)".*/\1/')
    fuentes=$(cd "$src/src" && ls *.v *.sv 2>/dev/null | tr '\n' ' ')

    echo "-------- $repo   (top: $top)"
    echo "         fuentes: $fuentes"
    [ $ARREGLAR -eq 0 ] && continue

    cd "$clone"
    C=$(git rev-list --max-parents=0 HEAD)
    git checkout "$C" -- src/config.json test/requirements.txt test/Makefile test/tb.v

    # el Makefile de la plantilla, con nuestros fuentes
    sed -i.bak "s|^PROJECT_SOURCES = .*|PROJECT_SOURCES = $fuentes|" test/Makefile && rm -f test/Makefile.bak
    # el tb.v de la plantilla, con nuestro top
    sed -i.bak "s/tt_um_example/$top/" test/tb.v && rm -f test/tb.v.bak

    # nuestros archivos
    cp "$src/test/test.py" test/test.py
    cp "$src/docs/info.md" docs/info.md
    cp "$src/info.yaml" info.yaml
    rm -f src/project.v
    cp "$src/src/"*.v src/ 2>/dev/null || true
    cp "$src/src/"*.sv src/ 2>/dev/null || true
    rm -rf test/__pycache__ test/sim_build test/*.vcd test/results.xml

    git add -A
    if [ -z "$(git status --porcelain)" ]; then
        echo "         sin cambios"
    else
        git commit -q -m "Arreglar el volcado: conservar los archivos de la plantilla

src/config.json, test/requirements.txt, test/Makefile y test/tb.v son de la
plantilla de Tiny Tapeout y hacen falta para que corran las acciones gds y
test (esta ultima incluye el gate-level). Se parchean en vez de reemplazarse:
PROJECT_SOURCES con los fuentes del proyecto y el tb.v con el top real."
        git push -q origin HEAD
        echo "         arreglado y pusheado"
    fi
    cd "$AQUI"
done

if [ $ARREGLAR -eq 1 ]; then echo; echo "Mira el estado en un rato:  bash $AQUI/estado_repos.sh"; fi
