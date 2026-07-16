# cocotb + Icarus para canny_modular_top (cadena compass->NMS->umbral)
#   correr:  make -f Makefile.mod
SIM ?= icarus
TOPLEVEL_LANG ?= verilog
PWD = $(shell pwd)
VERILOG_SOURCES += $(PWD)/../canny_modular_top.sv
VERILOG_SOURCES += $(PWD)/../sobel_compass_control.sv
VERILOG_SOURCES += $(PWD)/../sobel_compass_core.sv
VERILOG_SOURCES += $(PWD)/../nms_control.sv
VERILOG_SOURCES += $(PWD)/../nms_core.sv
VERILOG_SOURCES += $(PWD)/../canny_grad_threshold_core.sv
VERILOG_SOURCES += $(PWD)/../isqrt.sv
TOPLEVEL = canny_modular_top
MODULE   = test_modular_top
COMPILE_ARGS += -g2012
include $(shell cocotb-config --makefiles)/Makefile.sim
