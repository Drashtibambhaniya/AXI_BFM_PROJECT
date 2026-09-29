`ifndef CPU_ACTIVE_AGENT_SV
`define CPU_ACTIVE_AGENT_SV

`include "uvm_macros.svh"
import uvm_pkg::*;

class cpu_active_agent extends uvm_agent;

  `uvm_component_utils(cpu_active_agent)

  cpu_sequencer seqr;
  cpu_driver drv;
  cpu_monitor mon;


  function new(string name = "cpu_active_agent", uvm_component parent = null);
    super.new(name, parent);
  endfunction


  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    `uvm_info(get_type_name(), $sformatf("[%0t] BUILD_PHASE STARTED", $time), UVM_LOW)

    seqr = cpu_sequencer::type_id::create("seqr", this);
    drv = cpu_driver::type_id::create("drv", this);
    mon = cpu_monitor::type_id::create("mon", this);

    `uvm_info(get_type_name(), $sformatf("[%0t] CPU sequencer, driver and monitor created", $time), UVM_LOW)

    `uvm_info(get_type_name(), $sformatf("[%0t] BUILD_PHASE COMPLETED", $time),UVM_LOW)

  endfunction


  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);

    `uvm_info(get_type_name(), $sformatf("[%0t] CONNECT_PHASE STARTED", $time), UVM_LOW)

    drv.seq_item_port.connect(seqr.seq_item_export);

    `uvm_info(get_type_name(), $sformatf("[%0t] Sequencer connected to driver", $time),UVM_LOW)

    `uvm_info(get_type_name(), $sformatf("[%0t] CONNECT_PHASE COMPLETED", $time), UVM_LOW)

  endfunction

endclass

`endif
