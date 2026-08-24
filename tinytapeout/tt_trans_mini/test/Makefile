# Makefile — cocotb (Tiny Tapeout) para tt_um_trans_mini_vic
SIM ?= icarus
TOPLEVEL_LANG ?= verilog
SRC_DIR = $(PWD)/../src
PROJECT_SOURCES = tt_um_trans_mini_vic.v hysteresis_frame_bram_sync.sv
VERILOG_SOURCES += $(addprefix $(SRC_DIR)/,$(PROJECT_SOURCES))
VERILOG_SOURCES += $(PWD)/tb.v
TOPLEVEL = tb
MODULE = test
COMPILE_ARGS += -g2012
include $(shell cocotb-config --makefiles)/Makefile.sim
