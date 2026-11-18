
#========================================================
# Makefile: FIFO-to-AXI4 UVM Verification
# Simulator: Synopsys VCS
# UVM Version: 1.2
#========================================================

VCS_HOME ?= /hwetools/synosys/installed_tools/vcs/Q-2020.03-SP2-8
VCS      := $(VCS_HOME)/bin/vcs

SIM      := simv
TEST     ?= write_test
SEED     ?= 1

FILELIST := filelist.f
WAVEFORM := waveform.fsdb

STOP     ?=
PLUSARGS ?=

RUN_ARGS := +UVM_TESTNAME=$(TEST) \
            +ntb_random_seed=$(SEED) \
            $(if $(STOP),+STOP_AFTER_NS=$(STOP)) \
            $(PLUSARGS)

#========================================================
# VCS Compiler Options
#========================================================

VCS_FLAGS := -full64 \
             -sverilog \
             -ntb_opts uvm-1.2 \
             -debug_access+all \
             -timescale=1ns/1ps \
             -kdb \
             -licqueue

#========================================================
# Targets
#========================================================

.PHONY: all compile run run_test wave clean help

all: compile

#========================================================
# Compile
#========================================================

compile:
	$(VCS) $(VCS_FLAGS) -top tb_top -f $(FILELIST) -o $(SIM) -l compile.log

#========================================================
# Compile and Run
#========================================================

run: compile
	./$(SIM) $(RUN_ARGS) -l run.log

#========================================================
# Run Already Compiled Simulation
#========================================================

run_test:
	./$(SIM) $(RUN_ARGS) -l run.log

#========================================================
# View VCD Waveform in Verdi
#========================================================

wave:
	verdi -vcd $(WAVEFORM) &

#========================================================
# Clean Generated Files
#========================================================

clean:
	rm -rf csrc simv simv.* simv.daidir
	rm -rf DVEfiles AN.DB
	rm -f ucli.key vc_hdrs.h novas.conf novas.ics
	rm -f *.log *.vpd *.fsdb *.vcd

#========================================================
# Help
#========================================================

help:
	@echo "make compile"
	@echo "make run TEST=write_test"
	@echo "make run TEST=read_test"
	@echo "make run TEST=write_read_test"
	@echo "make run_test TEST=write_test"
	@echo "make wave"
	@echo "make clean"

