# Makefile — cocotb (Tiny Tapeout) para tt_um_soc_canny1_vic
SIM ?= icarus
TOPLEVEL_LANG ?= verilog
SRC_DIR = $(PWD)/../src
PROJECT_SOURCES = tt_um_soc_canny1_vic.v soc_canny1_top.v canny1_top.v femtorv32_quark.v peripheral_filter.v linebuf3x3.v
VERILOG_SOURCES += $(addprefix $(SRC_DIR)/,$(PROJECT_SOURCES))
VERILOG_SOURCES += $(PWD)/tb.v
TOPLEVEL = tb
MODULE = test
include $(shell cocotb-config --makefiles)/Makefile.sim
