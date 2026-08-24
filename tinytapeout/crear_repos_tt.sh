#!/usr/bin/env bash
# crear_repos_tt.sh — crea los 6 repos de Tiny Tapeout desde la plantilla y vuelca cada proyecto.
#
#   Por defecto SOLO MUESTRA el plan (dry-run).  Para crear de verdad:
#       bash crear_repos_tt.sh --crear
#
#   ANTES de correrlo: mirar en https://tinytapeout.com cual shuttle esta ABIERTO y cual es su
#   plantilla, y pasarla por variable si no es la de abajo:
#       TEMPLATE=TinyTapeout/ttXX-verilog-template bash crear_repos_tt.sh --crear
#
#   Requiere la CLI de GitHub autenticada:  gh auth login
set -e
AQUI="$(cd "$(dirname "$0")" && pwd)"
USER_GH="${USER_GH:-VictorMartinez89}"
TEMPLATE="${TEMPLATE:-TinyTapeout/tt10-verilog-template}"
DESTINO="${DESTINO:-$HOME/UN/Tesis/tt_repos}"
CREAR=0; [ "$1" = "--crear" ] && CREAR=1

# carpeta_en_el_monorepo : nombre_del_repo : descripcion
PROYECTOS="tt_sobel:tt_sobel:Sobel 3x3 edge filter (MSc thesis, UNAL)
tt_canny1:tt_canny1:Streaming Canny 1-hop edge filter (MSc thesis, UNAL)
tt_soc_sobel:tt_soc_sobel:RISC-V SoC (FemtoRV32) + Sobel filter, ROM on chip
tt_soc_sobel_flash:tt_soc_sobel_flash:RISC-V SoC + Sobel, boots from external SPI flash
tt_trans_mini:tt_trans_mini:Transitive hysteresis engine 32x24 (morphological reconstruction)
tt_soc_canny1:tt_soc_canny1:RISC-V SoC (FemtoRV32) + streaming Canny filter"

echo "== plantilla: $TEMPLATE"
echo "== cuenta:    $USER_GH"
echo "== clones en: $DESTINO"
[ $CREAR -eq 0 ] && echo "== MODO PRUEBA: no se crea nada. Agrega --crear para hacerlo de verdad."
echo

gh auth status >/dev/null 2>&1 || { echo "!! gh no esta autenticado: corre  gh auth login"; exit 1; }

mkdir -p "$DESTINO"
echo "$PROYECTOS" | while IFS=: read -r carpeta repo desc; do
    [ -z "$carpeta" ] && continue
    src="$AQUI/$carpeta"
    [ -d "$src" ] || { echo "!! falta $src"; continue; }
    top=$(grep -E "^ *top_module:" "$src/info.yaml" | sed 's/.*"\(.*\)".*/\1/')

    echo "-------- $repo   (top: $top)"
    if [ $CREAR -eq 0 ]; then
        echo "   gh repo create $USER_GH/$repo --template $TEMPLATE --public --clone"
        echo "   volcar: $(ls "$src" | tr '\n' ' ')"
        continue
    fi

    if gh repo view "$USER_GH/$repo" >/dev/null 2>&1; then
        echo "   ya existe, no lo toco"
        continue
    fi

    gh repo create "$USER_GH/$repo" --template "$TEMPLATE" --public --description "$desc"
    sleep 3                                    # GitHub tarda un instante en materializar la plantilla
    git clone "git@github.com:$USER_GH/$repo.git" "$DESTINO/$repo"

    cd "$DESTINO/$repo"
    rm -rf src docs test info.yaml
    cp -r "$src/src" "$src/docs" "$src/test" "$src/info.yaml" .
    rm -rf test/__pycache__ test/sim_build test/*.vcd test/results.xml 2>/dev/null || true

    git add -A
    git commit -q -m "$desc

Tomado de la tesis de maestria: SoC RISC-V con filtros de deteccion de
bordes, de FPGA (iCE40UP5K) a ASIC (sky130). Verificado con cocotb.
https://github.com/$USER_GH/tty_project_filter"
    git push -q origin HEAD
    echo "   creado y pusheado -> https://github.com/$USER_GH/$repo/actions"

    # habilitar Pages por Actions (para que salga la ficha del proyecto)
    gh api -X POST "repos/$USER_GH/$repo/pages" -f build_type=workflow >/dev/null 2>&1 \
        && echo "   Pages habilitado" || echo "   (Pages: habilitalo a mano en Settings -> Pages)"
    cd "$AQUI"
done

cat <<TXT

Siguiente paso:
  bash $AQUI/estado_repos.sh          # las 3 acciones de los 6, en una tabla
La accion gds tarda ~20-30 min por repo. Empeza mirando tt_sobel, que es el mas simple.
TXT
