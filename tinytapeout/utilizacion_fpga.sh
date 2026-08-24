#!/usr/bin/env bash
# utilizacion_fpga.sh — Device Utilisation y frecuencia maxima (nextpnr) de los proyectos de Tiny Tapeout.
# Correr EN LA VM, con el oss-cad-suite activado (nextpnr no esta en el Mac).
#   bash /mnt/share/utm-share/tinytapeout/utilizacion_fpga.sh
#
# Envuelve cada tt_um_* en fpga/top_fpga.v, que junta uio_in/uio_out/uio_oe en 8 pines INOUT reales
# (como hace el anillo de pads del shuttle). Sin ese adaptador son 43 senales y no caben en el sg48.
set -e
AQUI="$(cd "$(dirname "$0")" && pwd)"
OUT=${OUT:-/tmp/tt_util}
mkdir -p "$OUT"

PROYECTOS="tt_sobel:tt_um_sobel_vic
tt_canny1:tt_um_canny1_vic
tt_soc_sobel:tt_um_soc_sobel_vic
tt_soc_sobel_flash:tt_um_soc_sobel_flash_vic
tt_trans_mini:tt_um_trans_mini_vic
tt_soc_canny1:tt_um_soc_canny1_vic"

echo "$PROYECTOS" | while IFS=: read -r d t; do
    [ -d "$AQUI/$d" ] || continue
    echo "================= $d  ($t)"

    # shim: mapea el nombre concreto del proyecto al tt_um_dut que espera el adaptador
    cat > "$OUT/shim_$d.v" <<SHIM
\`default_nettype none
module tt_um_dut (
    input wire [7:0] ui_in, output wire [7:0] uo_out,
    input wire [7:0] uio_in, output wire [7:0] uio_out, output wire [7:0] uio_oe,
    input wire ena, input wire clk, input wire rst_n);
    $t u (.ui_in(ui_in), .uo_out(uo_out), .uio_in(uio_in),
        .uio_out(uio_out), .uio_oe(uio_oe), .ena(ena), .clk(clk), .rst_n(rst_n));
endmodule
\`default_nettype wire
SHIM

    srcs=$(find "$AQUI/$d/src" -name "*.v" -o -name "*.sv" | tr '\n' ' ')
    yosys -p "read_verilog -sv $AQUI/fpga/top_fpga.v $OUT/shim_$d.v $srcs; \
              synth_ice40 -top top_fpga -json $OUT/$d.json" > "$OUT/$d.yosys.log" 2>&1
    nextpnr-ice40 --up5k --package sg48 --json "$OUT/$d.json" --asc "$OUT/$d.asc" \
        --freq 12 > "$OUT/$d.pnr.log" 2>&1 || echo "   (nextpnr devolvio error; ver $OUT/$d.pnr.log)"

    grep -E "ICESTORM_LC:|ICESTORM_RAM:|SB_IO:|SB_GB:|ICESTORM_SPRAM:" "$OUT/$d.pnr.log" || true
    grep -E "Max frequency for clock" "$OUT/$d.pnr.log" | tail -1 || true
    echo
done
echo "Logs completos en $OUT/"
