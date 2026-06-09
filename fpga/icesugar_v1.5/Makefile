# iCESugar v1.5 (iCE40UP5K-SG48) -- flujo icestorm (corre nativo en arm64).
# Instala el toolchain con oss-cad-suite (build arm64 de YosysHQ):
#   https://github.com/YosysHQ/oss-cad-suite-build/releases  (linux-arm64)
#   y luego:  source <oss-cad-suite>/environment
TOP  = top
SRCS = blinky.v
PCF  = icesugar.pcf

all: $(TOP).bin

$(TOP).json: $(SRCS)
	yosys -p "synth_ice40 -top $(TOP) -json $@" $(SRCS)

$(TOP).asc: $(TOP).json $(PCF)
	nextpnr-ice40 --up5k --package sg48 --pcf $(PCF) --json $(TOP).json --asc $@

$(TOP).bin: $(TOP).asc
	icepack $(TOP).asc $@

# Programar la iCESugar (se monta como USB drive 'iCELink'):
#   copia top.bin al drive,  o:
prog: $(TOP).bin
	icesprog $(TOP).bin

clean:
	rm -f $(TOP).json $(TOP).asc $(TOP).bin
.PHONY: all prog clean
