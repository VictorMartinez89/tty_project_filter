# openXC7 flow para Colorlight i9+ (XC7A50T-FGG484) -- REFERENCIA.
# Si las rutas no calzan, lo mas seguro: copia blinky.v y colorlight_i9plus.xdc
# dentro de  demo-projects/blinky-colorlight-i9plus/  (de wuxx) y corre su 'make',
# que ya esta configurado para esta placa.  Luego programa con ch347prog-*.
TOP     = top
SRCS    = blinky.v
XDC     = colorlight_i9plus.xdc
DEVICE  = xc7a50t
# Ajusta CHIPDB a tu instalacion de openXC7 (chipdb del xc7a50t):
CHIPDB ?= $(HOME)/.local/share/openXC7/xc7a50t.bin

all: $(TOP).bit

$(TOP).json: $(SRCS)
	yosys -p "synth_xilinx -flatten -family xc7 -top $(TOP); write_json $@" $(SRCS)

$(TOP).fasm: $(TOP).json $(XDC)
	nextpnr-xilinx --chipdb $(CHIPDB) --xdc $(XDC) \
	  --json $(TOP).json --fasm $@ --write $(TOP)_routed.json

$(TOP).bit: $(TOP).fasm
	# parte de prjxray/openXC7: convierte FASM -> bitstream
	xc7frames2bit --part_name xc7a50tfgg484 --frm_file $(TOP).frames --output_file $@ || \
	  echo ">> usa el flujo fasm2bit de tu openXC7 (ver demo-projects)"

clean:
	rm -f $(TOP).json $(TOP).fasm $(TOP)_routed.json $(TOP).bit $(TOP).frames

# Programar (desde Linux x86-64 con la CH347 conectada por USB):
#   $ ch347prog-sram  top.bit     # a SRAM (volatil, rapido para probar)
#   $ ch347prog-flash top.bit     # a SPI-Flash (persistente)
.PHONY: all clean
