`ifndef AXI_FIFO_TEST_PKG_SV
`define AXI_FIFO_TEST_PKG_SV

package axi_fifo_test_pkg;

  `include "uvm_macros.svh"
  import uvm_pkg::*;

  // Type definitions
  `include "typedef_enum.sv"

  // CPU components
  `include "cpu_transaction.sv"
  `include "cpu_sequencer.sv"
  `include "cpu_driver.sv"
  `include "cpu_monitor.sv"
  `include "cpu_agent.sv"

  // Sequence
  `include "test_sequence.sv"

  // Environment
  `include "env.sv"

  // Tests
  `include "test.sv"

endpackage : axi_fifo_test_pkg

`endif
