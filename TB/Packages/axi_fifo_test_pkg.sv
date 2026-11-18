package axi_fifo_test_pkg;

  `include "uvm_macros.svh"
  `include "define.sv"
  import uvm_pkg::*;
  import axi4_slave_pkg::*;

  `include "typedef_enum.sv"

  `include "cpu_transaction.sv"
  `include "cpu_sequencer.sv"
  `include "cpu_driver.sv"
  `include "cpu_monitor.sv"
  `include "cpu_agent.sv"

  `include "test_sequence.sv"

  `include "Scoreboard.sv"
  `include "env.sv"
  `include "test.sv"

endpackage : axi_fifo_test_pkg
