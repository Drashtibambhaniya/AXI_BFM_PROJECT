
`ifndef CPU_ACTIVE_MONITOR_SV
`define CPU_ACTIVE_MONITOR_SV

`include "uvm_macros.svh"
import uvm_pkg::*;

class cpu_monitor extends uvm_monitor;

  `uvm_component_utils(cpu_monitor)

  virtual fifo_interface.CPU_MON_MP fifo_vif;

  uvm_analysis_port #(cpu_sequence_item) analysis_port;

  bit pending_read;

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
      `uvm_fatal(get_type_name(), "Failed to get fifo_vif")
    end
  endfunction


  task run_phase(uvm_phase phase);

    cpu_sequence_item item;

    pending_read = 1'b0;

    forever begin
      @(fifo_vif.cpu_mon_cb);

      if (fifo_vif.rstn !== 1'b1) begin
        pending_read = 1'b0;
        continue;
      end
      else begin

        if (pending_read) begin
          item = cpu_sequence_item::type_id::create("read_item");

          item.rd_en   = 1'b1;
          item.rd_data = fifo_vif.cpu_mon_cb.rd_data;

          analysis_port.write(item);

          `uvm_info(get_type_name(),
            $sformatf("Read data: 0x%032h at %0t",
                      item.rd_data, $time),
            UVM_HIGH)
        end

        // each accepted request FIFO write.
        if ((fifo_vif.cpu_mon_cb.wr_en === 1'b1) &&
            (fifo_vif.cpu_mon_cb.full  === 1'b0)) begin

          item = cpu_sequence_item::type_id::create("write_item");

          item.wr_en   = 1'b1;
          item.wr_data = fifo_vif.cpu_mon_cb.wr_data;

          analysis_port.write(item);

          `uvm_info(get_type_name(),
            $sformatf("Write data: 0x%032h at %0t",
                      item.wr_data, $time),
            UVM_HIGH)
        end

        // whether a response read was accepted.
        pending_read =
          (fifo_vif.cpu_mon_cb.rd_en === 1'b1) &&
          (fifo_vif.cpu_mon_cb.empty === 1'b0);

      end
    end

  endtask

endclass

`endif

