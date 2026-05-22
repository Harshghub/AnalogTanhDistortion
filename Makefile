# Cocotb / Verilator simulation for AnalogTanhDistort (no ADC/DAC SPI).
#
# From course root:
#   poetry run make -C Project/AnalogTanhDistortion sim
#   poetry run make -C Project/AnalogTanhDistortion wave

COURSE_ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))/../..)
export PATH := $(COURSE_ROOT)/.venv/bin:$(PATH)

VERILOG_SOURCES = \
	$(PWD)/AnalogTanhDistort.sv \
	$(PWD)/TickGen.sv \
	$(PWD)/cordic_tanh.sv

TOPLEVEL = AnalogTanhDistort
MODULE   = analog_tanh_test

SIM                      = verilator
COCOTB_HDL_TIMEPRECISION = 1ns
EXTRA_ARGS              += --trace --trace-structs -Wno-fatal -Wno-WIDTHEXPAND -Wno-WIDTHTRUNC

include $(shell $(COURSE_ROOT)/.venv/bin/cocotb-config --makefiles)/Makefile.sim

.PHONY: wave help

help:
	@echo "Targets:"
	@echo "  sim   - build and run cocotb simulation"
	@echo "  wave  - run sim then open gtkwave"
	@echo "  clean - remove sim_build, results.xml, dump.vcd"

wave: sim
	@WAVE=$$(ls -1 dump.vcd sim_build/*.fst sim_build/*.vcd 2>/dev/null | head -1); \
	if [ -z "$$WAVE" ]; then \
	  echo "No trace file — run 'make sim' first"; exit 1; \
	fi; \
	echo "Opening gtkwave: $$WAVE"; \
	gtkwave $$WAVE &

clean::
	rm -rf sim_build __pycache__ results.xml dump.vcd
