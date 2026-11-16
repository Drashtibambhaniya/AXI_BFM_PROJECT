
`ifndef CPU_DRIVER_SV
`define CPU_DRIVER_SV

`include "uvm_macros.svh"
import uvm_pkg::*;

class cpu_driver extends uvm_driver #(cpu_sequence_item);

  `uvm_component_utils(cpu_driver)

  virtual fifo_interface.CPU_DRIVER_MP fifo_vif;

  int unsigned max_fifo_wait_cycles = 1000;
  function new(
    string name = "cpu_driver",
    uvm_component parent = null
  );
    super.new(name, parent);
  endfunction



  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    if (!uvm_config_db#(
          virtual fifo_interface.CPU_DRIVER_MP
        )::get(this, "", "fifo_vif", fifo_vif)) begin

      `uvm_fatal(get_type_name(),
        "Cannot get fifo_vif from uvm_config_db")

    end

    `uvm_info(get_type_name(),
      $sformatf("Virtual interface connected at %0t", $time),
      UVM_LOW)

  endfunction


 
  task check_reset_active();

    if (fifo_vif.rstn !== 1'b1) begin
      `uvm_fatal(get_type_name(),
        $sformatf(
          "Reset asserted during an active transaction at %0t",
          $time
        ))
    end

  endtask



  task run_phase(uvm_phase phase);

    `uvm_info(get_type_name(),
      $sformatf("RUN_PHASE started at %0t", $time),
      UVM_LOW)

    //@(fifo_vif.cpu_driver_cb);

    //fifo_vif.cpu_driver_cb.wr_en   <= 1'b0;
    //fifo_vif.cpu_driver_cb.rd_en   <= 1'b0;
    //fifo_vif.cpu_driver_cb.wr_data <= '0;

    wait (fifo_vif.rstn === 1'b1);
    @(fifo_vif.cpu_driver_cb);

    forever begin

     // wait (fifo_vif.rstn === 1'b1); ///drive reset instead cheking reset.l

      seq_item_port.get_next_item(req);

      `uvm_info(get_type_name(),
        $sformatf(
          "Transaction received at %0t: wr_en=%0b rd_en=%0b ch=%0d txn_id=%0d",
          $time, req.wr_en, req.rd_en, req.ch, req.txn_id
        ),
        UVM_MEDIUM)

      drive_to_dut();

      seq_item_port.item_done();

    end

  endtask

  task drive_to_dut();

    check_reset_active();

    @(fifo_vif.cpu_driver_cb);

    //check_reset_active();

    // Keep all outputs idle before starting the operation.
    fifo_vif.cpu_driver_cb.wr_en   <= 1'b0;
    fifo_vif.cpu_driver_cb.rd_en   <= 1'b0;
    fifo_vif.cpu_driver_cb.wr_data <= '0;

    case ({req.wr_en, req.rd_en})

      2'b10: begin
        drive_request_fifo_words();
      end

      2'b01: begin
        drive_response_fifo_read();
      end

      2'b11: begin
        fork
          drive_request_fifo_words();
          drive_response_fifo_read();
        join
      end

      2'b00: begin
        `uvm_info(get_type_name(),
          $sformatf("No FIFO operation requested at %0t", $time),
          UVM_HIGH)
      end

    endcase

    // Return outputs to idle.
    fifo_vif.cpu_driver_cb.wr_en   <= 1'b0;
    fifo_vif.cpu_driver_cb.rd_en   <= 1'b0;
    fifo_vif.cpu_driver_cb.wr_data <= '0;

    `uvm_info(get_type_name(),
      $sformatf("Transaction completed at %0t", $time),
      UVM_MEDIUM)

  endtask


  task drive_request_fifo_words();

    int unsigned i;
    int unsigned wait_cycles;


    if ((req.fifo_size == 0) ||
        ($size(req.fifo_word) != req.fifo_size)) begin

      `uvm_fatal(get_type_name(),
        $sformatf(  "Invalid request packet: fifo_size=%0d, array_size=%0d",
          req.fifo_size, $size(req.fifo_word)
        ))

    end

    for (i = 0; i < req.fifo_size; i++) begin

      @(fifo_vif.cpu_driver_cb);
      check_reset_active();

      wait_cycles = 0;

      while (fifo_vif.cpu_driver_cb.full !== 1'b0) begin

        fifo_vif.cpu_driver_cb.wr_en <= 1'b0;

        if (wait_cycles >= max_fifo_wait_cycles) begin
          `uvm_fatal(get_type_name(),
            $sformatf(
              "Timeout waiting for request FIFO space: word=%0d time=%0t",
              i, $time
            ))
        end

        wait_cycles++;

        `uvm_info(get_type_name(),
          $sformatf(
            "Request FIFO full; waiting for word %0d at %0t",
            i, $time
          ),
          UVM_HIGH)

        @(fifo_vif.cpu_driver_cb);
        check_reset_active();

      end

      
      fifo_vif.cpu_driver_cb.wr_data <= req.fifo_word[i];
      fifo_vif.cpu_driver_cb.wr_en  <= 1'b1;

      `uvm_info(get_type_name(),
        $sformatf(
          "Driving word %0d/%0d: data=0x%032h at %0t",
          i + 1, req.fifo_size, req.fifo_word[i], $time
        ),
        UVM_HIGH)

      //samples wr_en and wr_data at the next clock edge
    
      @(fifo_vif.cpu_driver_cb);
      check_reset_active();

      // Deassert write enable after the sampling edge.
      fifo_vif.cpu_driver_cb.wr_en <= 1'b0;

    end

    `uvm_info(get_type_name(),
      $sformatf(
        "Request packet transfer completed: %0d words at %0t",
        req.fifo_size, $time
      ),
      UVM_MEDIUM)

  endtask

  task drive_response_fifo_read();

    int unsigned wait_cycles;

    // Keep read enable low while waiting.
    fifo_vif.cpu_driver_cb.rd_en <= 1'b0;

    @(fifo_vif.cpu_driver_cb);
    check_reset_active();

    wait_cycles = 0;

    // Wait until response data is available.
    while (fifo_vif.cpu_driver_cb.empty !== 1'b0) begin

      fifo_vif.cpu_driver_cb.rd_en <= 1'b0;

      if (wait_cycles >= max_fifo_wait_cycles) begin
        `uvm_fatal(get_type_name(),
          $sformatf(
            "Timeout waiting for response FIFO data at %0t",
            $time
          ))
      end

      wait_cycles++;

      `uvm_info(get_type_name(),
        $sformatf(
          "Response FIFO empty; waiting at %0t", $time
        ),
        UVM_HIGH)

      @(fifo_vif.cpu_driver_cb);
      check_reset_active();

    end

    // Assert read enable for one FIFO sampling cycle.
    fifo_vif.cpu_driver_cb.rd_en <= 1'b1;

    `uvm_info(get_type_name(),
      $sformatf("Response FIFO read asserted at %0t", $time),
      UVM_HIGH)

    // sampling rd_en at the next rising edge.
    @(fifo_vif.cpu_driver_cb);
    check_reset_active();

    // read enable after the sampling edge.
    fifo_vif.cpu_driver_cb.rd_en <= 1'b0;

    `uvm_info(get_type_name(),
      $sformatf("Response FIFO read completed at %0t", $time),
      UVM_MEDIUM)

  endtask

endclass

`endif

