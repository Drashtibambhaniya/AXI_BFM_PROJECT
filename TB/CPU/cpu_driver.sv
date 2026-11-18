
`ifndef CPU_DRIVER_SV
`define CPU_DRIVER_SV

class cpu_driver extends uvm_driver #(cpu_sequence_item);

  `uvm_component_utils(cpu_driver)

  virtual fifo_interface.CPU_DRIVER_MP fifo_vif;


  function new(
    string name = "cpu_driver",
    uvm_component parent = null
  );
    super.new(name, parent);
  endfunction

//build phase
  function void build_phase(uvm_phase phase);

    super.build_phase(phase);

    if (!uvm_config_db#(
          virtual fifo_interface.CPU_DRIVER_MP
        )::get(this, "", "fifo_vif", fifo_vif)) begin

      `uvm_fatal(get_type_name(),
        "Failed to get virtual interface")

    end

  endfunction


  //==============================================================
  // Run Phase
  //==============================================================
  task run_phase(uvm_phase phase);

    `uvm_info(get_type_name(), "CPU DRIVER STARTED", UVM_MEDIUM)

    repeat (2) @(fifo_vif.cpu_driver_cb);

    forever begin

      seq_item_port.get_next_item(req);
      `uvm_info(get_type_name(), $sformatf("Received transaction: wr_en=%0b rd_en=%0b ch=%0d wdata= %0h", req.wr_en, req.rd_en, req.ch, req.wdata), UVM_MEDIUM)

      drive_to_dut();
      `uvm_info(get_type_name(), "Transaction successfully driven to DUT",UVM_MEDIUM)

      seq_item_port.item_done();

    end

  endtask


  //==============================================================
  // Drive Task
  //==============================================================
  task drive_to_dut();


    //------------------------------------------------------------
    // READ ONLY
    //------------------------------------------------------------
    if (req.rd_en && !req.wr_en) begin

      fifo_vif.cpu_driver_cb.wr_en   <= 0;
      fifo_vif.cpu_driver_cb.rd_en   <= 1;
      fifo_vif.cpu_driver_cb.wr_data <= 'b0;

      @(fifo_vif.cpu_driver_cb);

    end


    //------------------------------------------------------------
    // WRITE ONLY
    //------------------------------------------------------------
    else if (req.wr_en && !req.rd_en) begin

      fifo_vif.cpu_driver_cb.wr_en <= 1;
      fifo_vif.cpu_driver_cb.rd_en <= 0;

      foreach (req.fifo_word[i]) begin

        fifo_vif.cpu_driver_cb.wr_data <= req.fifo_word[i];

        @(fifo_vif.cpu_driver_cb);

      end

    end


    //------------------------------------------------------------
    // SIMULTANEOUS READ & WRITE
    //------------------------------------------------------------
    else if (req.wr_en && req.rd_en) begin

      fifo_vif.cpu_driver_cb.wr_en <= 1;
      fifo_vif.cpu_driver_cb.rd_en <= 1;

      foreach (req.fifo_word[i]) begin

        fifo_vif.cpu_driver_cb.wr_data <= req.fifo_word[i];

        @(fifo_vif.cpu_driver_cb);

      end

    end


    //------------------------------------------------------------
    // IDLE AFTER EVERY TRANSACTION
    //------------------------------------------------------------
    fifo_vif.cpu_driver_cb.wr_en   <= 0;
    fifo_vif.cpu_driver_cb.rd_en   <= 0;
    fifo_vif.cpu_driver_cb.wr_data <= 'b0;

  repeat (15) @(fifo_vif.cpu_driver_cb);

  endtask

endclass : cpu_driver

`endif

