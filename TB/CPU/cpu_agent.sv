
`ifndef CPU_ACTIVE_AGENT_SV
`define CPU_ACTIVE_AGENT_SV

`include "uvm_macros.svh"
import uvm_pkg::*;

class cpu_active_agent extends uvm_agent;

  `uvm_component_utils(cpu_active_agent)

  cpu_sequencer seqr;
  cpu_driver    drv;
  cpu_monitor   mon;
  cpu_passive_monitor pmon;
//constructor
  function new(
    string name = "cpu_active_agent",
    uvm_component parent = null
  );
    super.new(name, parent);
  endfunction

//build_phase
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    `uvm_info(get_type_name(),
      $sformatf("BUILD_PHASE STARTED at %0t", $time),
      UVM_LOW)

    seqr = cpu_sequencer::type_id::create("seqr", this);
    drv  = cpu_driver::type_id::create("drv", this);
    mon  = cpu_monitor::type_id::create("mon", this);
    pmon = cpu_passive_monitor::type_id::create("pmon", this);

    `uvm_info(get_type_name(),
      "CPU sequencer, driver and monitor created",
      UVM_LOW)

    `uvm_info(get_type_name(),
      $sformatf("BUILD_PHASE COMPLETED at %0t", $time),
      UVM_LOW)
  endfunction
//connect_phase
  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);

    `uvm_info(get_type_name(),
      $sformatf("CONNECT_PHASE STARTED at %0t", $time),
      UVM_LOW)

    // connect sequencer to driver.
    drv.seq_item_port.connect(seqr.seq_item_export);
    

    `uvm_info(get_type_name(),
      "Sequencer connected to driver",
      UVM_LOW)

    `uvm_info(get_type_name(),
      $sformatf("CONNECT_PHASE COMPLETED at %0t", $time),
      UVM_LOW)
  endfunction

endclass

`endif

