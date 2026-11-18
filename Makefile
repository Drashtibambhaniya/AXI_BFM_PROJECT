#========================================================
# Makefile: FIFO-to-AXI4 UVM Verification
# Simulator: Synopsys VCS
# UVM Version: 1.2
#========================================================

VCS       ?= vcs
SIM       := simv
TEST      ?= write_test
SEED      ?= 1
AVIP_DIR := axi4_avip
FILELIST := files.f
WAVEFORM  := waveform.fsdb

# Optional run-time switches (both empty by default = normal run, no time limit)
#   STOP=<ns>       end the run at <ns> and print the scoreboard / UVM summary
#                   (debug aid for a test that never finishes; a normal test ends before it)
#   PLUSARGS=...    any extra plusargs, e.g. PLUSARGS=+DUMP to write the waveform
STOP      ?=
PLUSARGS  ?=

# plusargs shared by run and run_test
RUN_ARGS  := +UVM_TESTNAME=$(TEST) +ntb_random_seed=$(SEED) \
        $(if $(STOP),+STOP_AFTER_NS=$(STOP)) $(PLUSARGS)

#========================================================
# Compiler options (includes KDB and debug flags for waveforms)
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

compile: $(FILELIST)
  $(VCS) $(VCS_FLAGS) -f $(FILELIST) -o $(SIM) -l compile.log

#========================================================
# Compile and run
#========================================================

run: compile
  ./$(SIM) $(RUN_ARGS) -l run.log

#========================================================
# Run already compiled simulation
#========================================================

run_test:
  ./$(SIM) $(RUN_ARGS) -l run.log

#========================================================
# View Waveforms (Verdi)
#========================================================

wave:
  verdi -fsdb $(WAVEFORM) &

#========================================================
# Clean generated files
#========================================================

clean:
  rm -rf csrc simv simv.daidir
  rm -rf DVEfiles
  rm -f ucli.key vc_hdrs.h novas.conf novas.ics
  rm -f *.log *.vpd *.fsdb *.vcd
  rm -rf AN.DB

#========================================================
# Help
#========================================================

help:
  @echo "make compile"
  @echo "make run TEST=write_test"
  @echo "make run TEST=read_test"
  @echo "make run TEST=write_read_test"
  @echo "make run_test TEST=directed_write_test"
  @echo "make run_test TEST=directed_wr_rd_test STOP=20000   (end at 20000 ns, print summary)"
  @echo "make run_test TEST=directed_write_test PLUSARGS=+DUMP   (write waveform.vcd)"
  @echo "make wave"
  @echo "make clean"
 
