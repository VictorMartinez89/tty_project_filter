# Makefile — cocotb (Tiny Tapeout) para tt_um_mnist_canny_vic
SIM ?= icarus
TOPLEVEL_LANG ?= verilog
SRC_DIR = $(PWD)/../src
PROJECT_SOURCES = tt_um_canny78_vic.v mnist_top78.v mnist_feat16_mem.v mnist_clf78_x2.v linebuf3x3.v
VERILOG_SOURCES += $(addprefix $(SRC_DIR)/,$(PROJECT_SOURCES))
VERILOG_SOURCES += $(PWD)/tb.v
COMPILE_ARGS += -I$(SRC_DIR)
TOPLEVEL = tb
MODULE = test
include $(shell cocotb-config --makefiles)/Makefile.sim
