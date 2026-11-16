VCS_HOME ?= /hwetools/synosys/installed_tools/vcs/Q-2020.03-SP2-8
VCS      := $(VCS_HOME)/bin/vcs
SIMV     := ./simv
FILELIST := filelist.f
TOP      := tb_top

VCS_FLAGS := -full64 \
             -sverilog \
             -ntb_opts uvm-1.2 \
             -timescale=1ns/1ps \
             -debug_access+all \
             -kdb \
             -cm line+cond+tgl+fsm+assert \
             -top $(TOP) \
             -o simv

.PHONY: all compile run clean help

all: compile

compile:
	@test -f "$(FILELIST)" || { echo "ERROR: $(FILELIST) not found. Run make from the Simulation directory."; exit 1; }
	@test -x "$(VCS)" || { echo "ERROR: VCS executable not found: $(VCS)"; echo "Check VCS_HOME."; exit 1; }
	$(VCS) $(VCS_FLAGS) -f $(FILELIST) -l compile.log

run: compile
	./simv +UVM_TESTNAME=write_test +UVM_VERBOSITY=UVM_HIGH -l sim.log

clean:
	rm -rf simv simv.daidir simv.vdb csrc DVEfiles verdiLog novas.conf ucli.key
	rm -f compile.log sim.log

help:
	@echo "Targets:"
	@echo "  make compile  - Compile the testbench with VCS"
	@echo "  make run      - Compile and run the simulation"
	@echo "  make clean    - Remove generated simulation files and logs"
	@echo "  make help     - Show this help"


