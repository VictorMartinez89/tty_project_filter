#!/usr/bin/env bash
# estado_repos.sh — estado de las GitHub Actions de los 6 repos de Tiny Tapeout, de un vistazo.
# Necesita la CLI de GitHub autenticada:  gh auth login
# Uso:  bash tinytapeout/estado_repos.sh  [usuario]
USER_GH="${1:-VictorMartinez89}"

REPOS="tt_sobel_vic
tt_canny1_vic
tt_soc_sobel_vic
tt_soc_sobel_flash_vic
tt_trans_mini_vic
tt_soc_canny1_vic
tt_soc_trans_mini_vic
tt_mnist_sobel_vic
tt_mnist_canny_vic"

printf "%-26s %-10s %-10s %-10s  %s\n" "REPO" "gds" "test" "docs" "ultimo commit"
printf "%-26s %-10s %-10s %-10s  %s\n" "--------------------------" "----------" "----------" "----------" "-------------"

echo "$REPOS" | while read -r r; do
    [ -z "$r" ] && continue
    if ! gh repo view "$USER_GH/$r" >/dev/null 2>&1; then
        printf "%-26s %s\n" "$r" "(no existe todavia)"
        continue
    fi
    linea=""
    for wf in gds test docs; do
        est=$(gh run list --repo "$USER_GH/$r" --workflow "$wf" --limit 1 \
              --json conclusion,status --jq '.[0] | (.conclusion // .status) // "-"' 2>/dev/null)
        case "$est" in
            success)      icono="OK" ;;
            failure)      icono="FALLA" ;;
            in_progress)  icono="corriendo" ;;
            queued)       icono="en cola" ;;
            *)            icono="${est:--}" ;;
        esac
        linea="$linea$(printf '%-10s ' "$icono")"
    done
    msg=$(gh run list --repo "$USER_GH/$r" --limit 1 --json displayTitle --jq '.[0].displayTitle' 2>/dev/null | cut -c1-40)
    printf "%-26s %s %s\n" "$r" "$linea" "$msg"
done

cat <<'TXT'

Para ver el detalle de uno:
  gh run list  --repo VictorMartinez89/tt_sobel_vic
  gh run view  --repo VictorMartinez89/tt_sobel_vic --log-failed
  gh run download --repo VictorMartinez89/tt_sobel_vic -n tt_submission   # el GDS y compania
TXT
