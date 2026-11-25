
`ifndef CPU_SEQUENCER_SV
`define CPU_SEQUENCER_SV

`include "uvm_macros.svh"
import uvm_pkg::*;

class cpu_sequencer extends uvm_sequencer #(cpu_sequence_item);

  `uvm_component_utils(cpu_sequencer)

  function new(
    string name = "cpu_sequencer",
    uvm_component parent = null
  );
    super.new(name, parent);
  endfunction

endclass

`endif

