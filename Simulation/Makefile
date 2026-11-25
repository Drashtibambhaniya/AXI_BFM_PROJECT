#========================================================
# Makefile : FIFO-to-AXI4 UVM Verification
# Simulator: Synopsys VCS     UVM : 1.2
# Run from the Simulation/ folder.
#
#   make             -> same as "make run"
#   make run         -> compile + simulate + show important lines
#   make help        -> list all targets and options
#========================================================

VCS        ?= vcs
SIM        := simv
FILELIST   := filelist.f

TEST       ?= write_read_test
SEED       ?= 1
VERB       ?= UVM_MEDIUM          # UVM_LOW / UVM_MEDIUM / UVM_HIGH
PLUSARGS   ?=                     # extra plusargs, e.g. PLUSARGS=+UVM_TIMEOUT=500000

WAVE       := waveform.fsdb       # VCD data (tb_top uses this name)
PEEK_NS    ?= 300                 # time window for "make peek"

# Lines worth reading in run.log
KEEP       := SCB\|outside of\|UVM_ERROR\|UVM_FATAL\|UVM_WARNING\|cpu_driver\|Running test\|RESET

#========================================================
# Compiler options
#========================================================
VCS_FLAGS  := -full64 \
              -sverilog \
              -ntb_opts uvm-1.2 \
              -debug_access+all \
              -timescale=1ns/1ps \
              -kdb \
              -licqueue

RUN_FLAGS   = +UVM_TESTNAME=$(strip $(TEST)) \
              +ntb_random_seed=$(strip $(SEED)) \
              +UVM_VERBOSITY=$(strip $(VERB)) \
              $(PLUSARGS)

.PHONY: all compile sim run log errors peek wave clean help

all: run

#========================================================
# compile : build simv
#========================================================
compile:
	$(VCS) $(VCS_FLAGS) -top tb_top -f $(FILELIST) -o $(SIM) -l compile.log
	@echo ""
	@echo "---- compile errors (if any) ----"
	@grep -n "Error-" compile.log || echo "none"

#========================================================
# sim : run the already-compiled simv (no recompile)
#========================================================
sim:
	./$(SIM) $(RUN_FLAGS) -l run.log
	@$(MAKE) --no-print-directory log

#========================================================
# run : compile + simulate + show important lines
#========================================================
run: compile sim

#========================================================
# log : show only the important lines of run.log
#========================================================
log:
	@echo ""
	@echo "================ important lines (run.log) ================"
	@grep "$(KEEP)" run.log || true
	@echo "==========================================================="
	@grep -A4 "Report counts by severity" run.log || true

#========================================================
# errors : show only errors
#========================================================
errors:
	@grep -n "UVM_ERROR\|UVM_FATAL\|Error-" run.log compile.log 2>/dev/null || echo "no errors"

#========================================================
# peek : print write-path signal changes from the waveform
#        (no GUI needed)  e.g. make peek PEEK_NS=1500
#========================================================
peek:
	python3 vcd_peek.py $(strip $(WAVE)) $(strip $(PEEK_NS))

#========================================================
# wave : open the waveform in Verdi (needs a display)
#========================================================
wave:
	verdi -vcd $(strip $(WAVE)) &

#========================================================
# clean : remove generated files
#========================================================
clean:
	rm -rf csrc simv simv.daidir ucli.key vc_hdrs.h \
	       compile.log run.log $(strip $(WAVE)) \
	       verdiLog novas.conf novas.rc AN.DB DVEfiles

#========================================================
# help
#========================================================
help:
	@echo ""
	@echo "Targets:"
	@echo "  make run       compile + simulate + show important lines (default)"
	@echo "  make compile   compile only"
	@echo "  make sim       simulate only (uses existing simv)"
	@echo "  make log       show important lines of run.log again"
	@echo "  make errors    show only errors"
	@echo "  make peek      print write-path signals from waveform (no GUI)"
	@echo "  make wave      open waveform in Verdi (needs display)"
	@echo "  make clean     remove generated files"
	@echo ""
	@echo "Options:"
	@echo "  TEST=<name>    default write_read_test"
	@echo "  SEED=<n>       default 1"
	@echo "  VERB=<level>   default UVM_MEDIUM"
	@echo "  PEEK_NS=<ns>   default 300 (for make peek)"
	@echo "  PLUSARGS=...   extra simulator plusargs"
	@echo ""
	@echo "Examples:"
	@echo "  make run TEST=write_read_test"
	@echo "  make sim VERB=UVM_HIGH"
	@echo "  make peek PEEK_NS=1500"
	@echo ""
