
`ifndef CPU_ACTIVE_MONITOR_SV
`define CPU_ACTIVE_MONITOR_SV

class cpu_monitor extends uvm_monitor;

  `uvm_component_utils(cpu_monitor)

  virtual fifo_interface.CPU_MON_MP fifo_vif;

  uvm_analysis_port #(cpu_sequence_item) analysis_port;

  function new(
    string name = "cpu_monitor",
    uvm_component parent = null
  );
    super.new(name, parent);
    analysis_port = new("analysis_port", this);
  endfunction



  function void build_phase(uvm_phase phase);

    super.build_phase(phase);

    if (!uvm_config_db#(
          virtual fifo_interface.CPU_MON_MP
        )::get(this, "", "fifo_vif", fifo_vif)) begin

      `uvm_fatal(get_type_name(),
        "Failed to get virtual interface")

    end

  endfunction


  //==============================================================
  // Run Phase
  //==============================================================
  task run_phase(uvm_phase phase);

    cpu_sequence_item item;
    `uvm_info(get_type_name(),"CPU MONITOR STARTED", UVM_MEDIUM)

    repeat (2) @(fifo_vif.cpu_mon_cb);

    forever begin

      @(fifo_vif.cpu_mon_cb);

      item = cpu_sequence_item::type_id::create("cpu_act_seq_item");

      item.wr_en   = fifo_vif.cpu_mon_cb.wr_en;
      item.wr_data = fifo_vif.cpu_mon_cb.wr_data;
      item.rd_en   = fifo_vif.cpu_mon_cb.rd_en;
      item.full    = fifo_vif.cpu_mon_cb.full;

      `uvm_info(get_type_name(), $sformatf("Observed DUT activity: wr_en=%0b rd_en=%0b full=%0b, wdata= %0h", item.wr_en, item.rd_en, item.full, item.wr_data), UVM_MEDIUM)

      analysis_port.write(item);

    end

  endtask

endclass : cpu_monitor

`endif

