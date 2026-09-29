# ================================================================
# AXI_FIFO_BFM Verification Makefile
# ================================================================

.DEFAULT_GOAL := usage

# ================================================================
# VCS CONFIGURATION
# ================================================================

VCS = vcs

VCS_CMD = $(VCS) -full64 -sverilog +v2k \
          -debug_access+all \
          -ntb_opts uvm-1.1 \
          +ntb_random_seed_automatic \
          +vcs+fsdbon+all \
          -timescale=1ns/1ps

# ================================================================
# SIMULATION CONFIGURATION
# ================================================================

TEST ?= write_test
UVM_VERBOSITY ?= UVM_HIGH

SIMV = simv
COMPILE_LOG = VcsCompile.log
SIM_LOG = $(TEST).log
FSDB = novas.fsdb

# ================================================================
# ALL
# ================================================================

all:
	@$(MAKE) clean
	@$(MAKE) compile
	@$(MAKE) simulate TEST=$(TEST) UVM_VERBOSITY=$(UVM_VERBOSITY)

# ================================================================
# COMPILE
# ================================================================

compile:
	@echo ""
	@echo "================================================================"
	@echo "                    COMPILATION"
	@echo "================================================================"
	@echo ""
	@echo "Testbench      : AXI_FIFO_BFM"
	@echo "Top            : tb_top"
	@echo "Test           : $(TEST)"
	@echo ""

	$(VCS_CMD) \
	-l $(COMPILE_LOG) \
	-f filelist.f \
	-top tb_top \
	-o $(SIMV)

	@echo ""
	@echo "Compilation completed."
	@echo "Compile log    : $(COMPILE_LOG)"
	@echo ""

# ================================================================
# SIMULATE
# ================================================================

simulate:
	@echo ""
	@echo "================================================================"
	@echo "                    SIMULATION"
	@echo "================================================================"
	@echo ""
	@echo "Test           : $(TEST)"
	@echo "UVM Verbosity  : $(UVM_VERBOSITY)"
	@echo ""

	./$(SIMV) \
	+UVM_TESTNAME=$(TEST) \
	+UVM_VERBOSITY=$(UVM_VERBOSITY) \
	-l $(SIM_LOG)

	@echo ""
	@echo "Simulation completed."
	@echo "Simulation log : $(SIM_LOG)"
	@echo "Waveform       : $(FSDB)"
	@echo ""

# ================================================================
# WAVEFORM
# ================================================================

wave:
	@echo ""
	@echo "================================================================"
	@echo "                    VERDI WAVEFORM"
	@echo "================================================================"
	@echo ""

	verdi -ssf $(FSDB) &

# ================================================================
# CLEAN
# ================================================================

clean:
	@echo ""
	@echo "Cleaning AXI_FIFO_BFM simulation files..."
	@echo ""

	rm -rf csrc \
	       $(SIMV) \
	       simv.daidir \
	       simv.vdb \
	       verdiLog \
	       nWaveLog \
	       $(COMPILE_LOG) \
	       *.log \
	       *.fsdb \
	       *.vpd \
	       *.key \
	       *.conf \
	       novas.rc \
	       ucli.key \
	       vc_hdrs.h

	@echo ""
	@echo "Clean completed."
	@echo ""

# ================================================================
# USAGE
# ================================================================

usage:
	@echo ""
	@echo "================================================================"
	@echo "                    AXI_FIFO_BFM"
	@echo "================================================================"
	@echo ""
	@echo "Usage:"
	@echo ""
	@echo "  make compile"
	@echo "      Compile the verification environment"
	@echo ""
	@echo "  make simulate"
	@echo "      Run the default test: $(TEST)"
	@echo ""
	@echo "  make simulate TEST=write_test"
	@echo "      Run a specific test"
	@echo ""
	@echo "  make simulate TEST=write_test UVM_VERBOSITY=UVM_HIGH"
	@echo "      Run with detailed UVM messages"
	@echo ""
	@echo "  make all"
	@echo "      Clean + compile + simulate"
	@echo ""
	@echo "  make wave"
	@echo "      Open FSDB waveform in Verdi"
	@echo ""
	@echo "  make clean"
	@echo "      Remove generated simulation files"
	@echo ""
	@echo "================================================================"
	@echo ""

.SILENT:
