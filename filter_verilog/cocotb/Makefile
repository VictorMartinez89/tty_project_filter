# cocotb + Icarus para sobel_compass_control
SIM ?= icarus
TOPLEVEL_LANG ?= verilog
PWD = $(shell pwd)
VERILOG_SOURCES += $(PWD)/../sobel_compass_control.sv
VERILOG_SOURCES += $(PWD)/../sobel_compass_core.sv
TOPLEVEL = sobel_compass_control
MODULE   = test_sobel_compass
COMPILE_ARGS += -g2012 -Psobel_compass_control.IMG_W=8
include $(shell cocotb-config --makefiles)/Makefile.sim
