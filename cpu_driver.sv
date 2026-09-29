`ifndef CPU_DRIVER_SV
`define CPU_DRIVER_SV

`include "uvm_macros.svh"

import uvm_pkg::*;

class cpu_driver extends uvm_driver #(cpu_sequence_item);
  `uvm_component_utils(cpu_driver)

  virtual fifo_interface.CPU_DRIVER_MP fifo_vif;


  function new(string name = "cpu_driver", uvm_component parent = null);
    super.new(name, parent);
  endfunction


  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    `uvm_info(get_type_name(), $sformatf("[%0t] BUILD_PHASE STARTED", $time), UVM_LOW)

    if(!uvm_config_db#(virtual fifo_interface.CPU_DRIVER_MP)::get(this, "", "fifo_vif", fifo_vif))
      `uvm_fatal(get_type_name(), "Failed to get virtual interface")

    `uvm_info(get_type_name(), $sformatf("[%0t] Virtual interface connected", $time), UVM_LOW)

    `uvm_info(get_type_name(), $sformatf("[%0t] BUILD_PHASE COMPLETED", $time), UVM_LOW)

  endfunction


  task run_phase(uvm_phase phase);

    `uvm_info(get_type_name(), $sformatf("[%0t] RUN_PHASE STARTED", $time), UVM_LOW)

    repeat(1) @(fifo_vif.cpu_driver_cb);

    forever begin

      seq_item_port.get_next_item(req);

      `uvm_info(get_type_name(),
                $sformatf("[%0t] Received CPU transaction : wr_en=%0b rd_en=%0b ch=%s txn_id=%0d",
                          $time, req.wr_en, req.rd_en, req.ch.name(), req.txn_id), UVM_MEDIUM)

      drive_to_dut();

      seq_item_port.item_done();

    end

  endtask


  task drive_to_dut();

    //only read
    if(req.rd_en && !req.wr_en)
    begin

      `uvm_info(get_type_name(), $sformatf("[%0t] Driving READ transaction", $time), UVM_MEDIUM)

      fifo_vif.cpu_driver_cb.wr_en <= 0;
      fifo_vif.cpu_driver_cb.wr_data <= '0;
      fifo_vif.cpu_driver_cb.rd_en <= 0;

      while(fifo_vif.cpu_driver_cb.empty)
      begin
        `uvm_info(get_type_name(),
                  $sformatf("[%0t] Read FIFO is empty, waiting for data", $time), UVM_HIGH)
        @(fifo_vif.cpu_driver_cb);
      end

      fifo_vif.cpu_driver_cb.rd_en <= 1;

      `uvm_info(get_type_name(), $sformatf("[%0t] Read enable asserted", $time), UVM_HIGH)

      @(fifo_vif.cpu_driver_cb);

    end


    //only write
    else if(req.wr_en && !req.rd_en)
    begin

      `uvm_info(get_type_name(),
                $sformatf("[%0t] Driving WRITE transaction : %0d FIFO words", $time, req.fifo_size), UVM_MEDIUM)

      fifo_vif.cpu_driver_cb.rd_en <= 0;

      foreach(req.fifo_word[i])
      begin

        while(fifo_vif.cpu_driver_cb.full)
        begin
          `uvm_info(get_type_name(),
                    $sformatf("[%0t] Write FIFO full, waiting before FIFO[%0d]", $time, i), UVM_HIGH)
          @(fifo_vif.cpu_driver_cb);
        end
        fifo_vif.cpu_driver_cb.wr_en   <= 1;
        fifo_vif.cpu_driver_cb.wr_data <= req.fifo_word[i];

        `uvm_info(get_type_name(),$sformatf("[%0t] Driving FIFO[%0d] = %032h", $time, i, req.fifo_word[i]), UVM_HIGH)

        @(fifo_vif.cpu_driver_cb);

      end

    end


    //both read and write
    else if(req.wr_en && req.rd_en)
    begin

      `uvm_info(get_type_name(), $sformatf("[%0t] Driving SIMULTANEOUS READ-WRITE : %0d FIFO words", $time, req.fifo_size), UVM_MEDIUM)

      fifo_vif.cpu_driver_cb.wr_en <= 1;
      fifo_vif.cpu_driver_cb.rd_en <= 0;

      foreach(req.fifo_word[i])
      begin

        while(fifo_vif.cpu_driver_cb.full)
        begin
          `uvm_info(get_type_name(), $sformatf("[%0t] Write FIFO full, waiting before FIFO[%0d]", $time, i), UVM_HIGH)
          @(fifo_vif.cpu_driver_cb);
        end
        fifo_vif.cpu_driver_cb.wr_data <= req.fifo_word[i];

        //one-cycle read pulse
        if(i == 0)
        begin

          while(fifo_vif.cpu_driver_cb.empty)
          begin
            `uvm_info(get_type_name(), $sformatf("[%0t] Read FIFO is empty, waiting before read", $time), UVM_HIGH)
            fifo_vif.cpu_driver_cb.rd_en <= 0;
            @(fifo_vif.cpu_driver_cb);
          end

          fifo_vif.cpu_driver_cb.rd_en <= 1;
          `uvm_info(get_type_name(), $sformatf("[%0t] Read enable asserted with FIFO[%0d] write", $time, i), UVM_HIGH)
        end

        else
        begin
          fifo_vif.cpu_driver_cb.rd_en <= 0;
        end

        `uvm_info(get_type_name(),
                  $sformatf("[%0t] Driving FIFO[%0d] = %032h", $time, i, req.fifo_word[i]), UVM_HIGH)

        @(fifo_vif.cpu_driver_cb);

      end

    end



    else
    begin
      `uvm_info(get_type_name(),
                $sformatf("[%0t] No READ/WRITE operation requested", $time), UVM_HIGH)
    end


    fifo_vif.cpu_driver_cb.wr_en   <= 0;
    fifo_vif.cpu_driver_cb.rd_en   <= 0;
    fifo_vif.cpu_driver_cb.wr_data <= '0;

    `uvm_info(get_type_name(), $sformatf("[%0t] CPU transaction completed", $time), UVM_MEDIUM)

  endtask

endclass

`endif
