
#========================================================
# Makefile: FIFO-to-AXI4 UVM Verification
# Simulator: Synopsys VCS
# UVM Version: 1.2
#========================================================

VCS       ?= vcs
SIM       := simv
TEST      ?= write_test
SEED      ?= 1
FILELIST  := filelist.f
WAVEFORM  := wave.vcd

#========================================================
# Compiler options
#========================================================

VCS_FLAGS := -full64 \
             -sverilog \
             -ntb_opts uvm-1.2 \
             -debug_access+all \
             -timescale=1ns/1ps \
             -kdb \
             -licqueue

#========================================================
# Default target
#========================================================

.PHONY: all compile run run_test wave clean help

all: compile

#========================================================
# Compile
#========================================================

compile:
	$(VCS) $(VCS_FLAGS) -top tb_top -f $(FILELIST) -o $(SIM) -l compile.log

#========================================================
# Compile and run
#========================================================

run: compile
	./$(SIM) +UVM_TESTNAME=$(TEST) +ntb_random_seed=$(SEED) -l run.log

#========================================================
# Run already compiled simulation
#========================================================

run_test:
	./$(SIM) +UVM_TESTNAME=$(TEST) +ntb_random_seed=$(SEED) -l run.log

#========================================================
# View Waveforms (Verdi)
#========================================================

wave:
	verdi -vcd $(WAVEFORM) &

#========================================================
# Clean generated files
#========================================================

clean:
	rm -rf csrc simv simv.* simv.daidir
	rm -rf DVEfiles AN.DB
	rm -f ucli.key vc_hdrs.h
	rm -f *.log *.vcd *.vpd *.fsdb
	rm -f novas.conf novas.ics

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

