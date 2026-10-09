`ifndef ENV_SV
`define ENV_SV

`include "uvm_macros.svh"

import uvm_pkg::*;
//import axi4_slave_pkg::*;

class environment extends uvm_env;

  `uvm_component_utils(environment)

  cpu_active_agent cpu_agent;
  //axi4_slave_agent axi_slave_agent;


  function new(string name = "environment", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    `uvm_info(get_type_name(), $sformatf("[%0t] BUILD_PHASE STARTED", $time), UVM_LOW)

    cpu_agent = cpu_active_agent::type_id::create("cpu_agent", this);

    `uvm_info(get_type_name(), $sformatf("[%0t] CPU active agent created", $time), UVM_LOW)

     //axi_slave_agent = axi4_slave_agent::type_id::create("axi_slave_agent", this);

    //`uvm_info(get_type_name(),
    //  $sformatf("[%0t] AXI4 slave AVIP agent created", $time), UVM_LOW)

    `uvm_info(get_type_name(), $sformatf("[%0t] BUILD_PHASE COMPLETED", $time), UVM_LOW)
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);

    `uvm_info(get_type_name(), $sformatf("[%0t] CONNECT_PHASE STARTED", $time), UVM_LOW)

    `uvm_info(get_type_name(), $sformatf("[%0t] CONNECT_PHASE COMPLETED", $time), UVM_LOW)
  endfunction

endclass
`endif
