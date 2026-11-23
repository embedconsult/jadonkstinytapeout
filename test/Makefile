# Makefile
# See https://docs.cocotb.org/en/stable/quickstart.html for more info

# defaults
SIM ?= icarus
FST ?= -fst # Use more efficient FST format
TOPLEVEL_LANG ?= verilog
SRC_DIR = $(PWD)/../src
PROJECT_SOURCES = project.v vga_sync.v minsky_machine.v demo_program.v scene.v font.v

ifneq ($(GATES),yes)

# RTL simulation:
SIM_BUILD				= sim_build/rtl
VERILOG_SOURCES += $(addprefix $(SRC_DIR)/,$(PROJECT_SOURCES))

else

# Gate level simulation:
SIM_BUILD				= sim_build/gl
COMPILE_ARGS    += -DGL_TEST
COMPILE_ARGS    += -DFUNCTIONAL
COMPILE_ARGS    += -DUSE_POWER_PINS
COMPILE_ARGS    += -DSIM
COMPILE_ARGS    += -DUNIT_DELAY=\#1
VERILOG_SOURCES += $(PDK_ROOT)/sky130A/libs.ref/sky130_fd_sc_hd/verilog/primitives.v
VERILOG_SOURCES += $(PDK_ROOT)/sky130A/libs.ref/sky130_fd_sc_hd/verilog/sky130_fd_sc_hd.v

# this gets copied in by the GDS action workflow
VERILOG_SOURCES += $(PWD)/gate_level_netlist.v

endif

# Allow sharing configuration between design and testbench via `include`:
COMPILE_ARGS 		+= -I$(SRC_DIR)

# Include the testbench sources:
VERILOG_SOURCES += $(PWD)/tb.v
TOPLEVEL = tb

# List test modules to run, separated by commas and without the .py suffix:
COCOTB_TEST_MODULES = test

# include cocotb's make rules to take care of the simulator setup
include $(shell cocotb-config --makefiles)/Makefile.sim

# The counting machine's program, one instruction at a time, checked against
# a reference model (plain Icarus Verilog, no cocotb). Writes program_trace.txt.
.PHONY: program_trace
program_trace:
	iverilog -g2012 -o program_trace.vvp program_trace.v $(SRC_DIR)/minsky_machine.v $(SRC_DIR)/demo_program.v
	vvp program_trace.vvp > program_trace.txt; status=$$?; sed -i '/\$$finish called/d' program_trace.txt; exit $$status
	tail -1 program_trace.txt

# The whole chip at its real pace: when each instruction runs, and the state
# after it, which must match program_trace.txt. Takes about an hour for all
# 99 instructions at RTL (pass INSTRUCTIONS=2 for a quick look), much longer
# at gate level (GATES=yes, with PDK_ROOT and gate_level_netlist.v as above).
INSTRUCTIONS ?= 99
ifneq ($(GATES),yes)
CHIP_SOURCES = $(addprefix $(SRC_DIR)/,$(PROJECT_SOURCES))
CHIP_TRACE = chip_trace.txt
else
CHIP_SOURCES = -DGL_TEST -DFUNCTIONAL -DUSE_POWER_PINS -DSIM -DUNIT_DELAY=\#1 \
  $(PDK_ROOT)/sky130A/libs.ref/sky130_fd_sc_hd/verilog/primitives.v \
  $(PDK_ROOT)/sky130A/libs.ref/sky130_fd_sc_hd/verilog/sky130_fd_sc_hd.v \
  $(PWD)/gate_level_netlist.v
CHIP_TRACE = chip_trace_gl.txt
endif
STATES = awk -v n=$(INSTRUCTIONS) '/->/ && $$1+0 >= 1 && $$1+0 <= n { print $$1, $$(NF-5), $$(NF-4), $$(NF-3), $$(NF-2), $$(NF-1), $$NF }'

.PHONY: chip_trace
chip_trace: program_trace
	iverilog -g2012 -o $(CHIP_TRACE:.txt=.vvp) $(CHIP_SOURCES) chip_trace.v
	vvp $(CHIP_TRACE:.txt=.vvp) +instructions=$(INSTRUCTIONS) > $(CHIP_TRACE); status=$$?; sed -i '/\$$finish called/d' $(CHIP_TRACE); exit $$status
	$(STATES) program_trace.txt > $(CHIP_TRACE:.txt=.expect.tmp)
	$(STATES) $(CHIP_TRACE) > $(CHIP_TRACE:.txt=.got.tmp)
	diff $(CHIP_TRACE:.txt=.expect.tmp) $(CHIP_TRACE:.txt=.got.tmp) && echo "SAME: the chip's $(INSTRUCTIONS) instructions match program_trace.txt"
	tail -1 $(CHIP_TRACE)
