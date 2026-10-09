`ifndef CPU_ACTIVE_MONITOR_SV
`define CPU_ACTIVE_MONITOR_SV

`include "uvm_macros.svh"

import uvm_pkg::*;

class cpu_monitor extends uvm_monitor;

  `uvm_component_utils(cpu_monitor)

  virtual fifo_interface.CPU_MON_MP fifo_vif;

  uvm_analysis_port #(cpu_sequence_item) analysis_port;

  cpu_sequence_item seq;


  function new(string name = "cpu_monitor",uvm_component parent = null);
    super.new(name, parent);
    analysis_port = new("a_mon_port", this);
  endfunction


  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    `uvm_info(get_type_name(), $sformatf("[%0t] BUILD_PHASE STARTED", $time), UVM_LOW)

    if(!uvm_config_db#(virtual fifo_interface.CPU_MON_MP)::get(this, "", "fifo_vif", fifo_vif))
      `uvm_fatal(get_type_name(), "Failed to get virtual interface")

    `uvm_info(get_type_name(),
              $sformatf("[%0t] Virtual interface connected", $time),UVM_LOW)

    `uvm_info(get_type_name(), $sformatf("[%0t] BUILD_PHASE COMPLETED", $time),UVM_LOW)

  endfunction


  task run_phase(uvm_phase phase);
    //repeat(1) @(fifo_vif.cpu_mon_cb);

    `uvm_info(get_type_name(), $sformatf("[%0t] RUN_PHASE STARTED", $time),UVM_LOW)

    forever begin

      @(fifo_vif.cpu_mon_cb);

      seq = cpu_sequence_item::type_id::create("cpu_act_seq_item");

      seq.wr_en = fifo_vif.cpu_mon_cb.wr_en;
      seq.wr_data = fifo_vif.cpu_mon_cb.wr_data;
      seq.rd_en = fifo_vif.cpu_mon_cb.rd_en;
      seq.full = fifo_vif.cpu_mon_cb.full;
      seq.empty = fifo_vif.cpu_mon_cb.empty;
      seq.rd_data = fifo_vif.cpu_mon_cb.rd_data;

      `uvm_info(get_type_name(),
                $sformatf("[%0t] CPU interface observed : wr_en=%0b wr_data=%032h rd_en=%0b full=%0b empty=%0b rd_data=%032h",
                          $time, seq.wr_en, seq.wr_data, seq.rd_en,seq.full, seq.empty, seq.rd_data),UVM_HIGH)
      analysis_port.write(seq);

    end

  endtask

endclass

`endif
