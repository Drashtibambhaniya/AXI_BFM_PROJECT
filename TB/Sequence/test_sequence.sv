
`ifndef TEST_SEQUENCE_SV
`define TEST_SEQUENCE_SV

`include "uvm_macros.svh"
import uvm_pkg::*;

//======================================================
// Base sequence
//======================================================
class cpu_base_sequence extends uvm_sequence #(cpu_sequence_item);

  `uvm_object_utils(cpu_base_sequence)

  function new(string name = "cpu_base_sequence");
    super.new(name);
  endfunction

  // Reusable transaction submission task.
  task send_transaction(
    input bit          wr_en_arg,
    input bit          rd_en_arg,
    input channel_e    ch_arg,
    input txn_id_e     txn_id_arg,
    input len_e        len_arg,
    input size_e       size_arg,
    input burst_e      burst_arg,
    input bit [31:0]   addr_arg,
    input bit [3:0]    wstrb_arg,
    input bit [1023:0] wdata_arg
  );

    cpu_sequence_item req;

    req = cpu_sequence_item::type_id::create("req");

    start_item(req);

    if (!req.randomize() with {
      wr_en  == local::wr_en_arg;
      rd_en  == local::rd_en_arg;

      ch     == local::ch_arg;
      txn_id == local::txn_id_arg;
      len    == local::len_arg;
      size   == local::size_arg;
      burst  == local::burst_arg;

      addr   == local::addr_arg;
      wstrb  == local::wstrb_arg;
      wdata  == local::wdata_arg;

      // Keep these fields at zero.
      lock   == lock_e'(0);
      cache  == cache_e'(0);
      prot   == prot_e'(0);
    }) begin
      `uvm_fatal("CPU_SEQ",
        "Failed to randomize cpu_sequence_item")
    end

    if (wr_en_arg) begin

      // Calculate active payload size after randomization.
      req.calculate_data_bits();

      // Build the serialized FIFO packet.
      req.build_fifo_packet();

      if (req.fifo_size == 0) begin
        `uvm_fatal("CPU_SEQ",
          "CPU request packet generation failed")
      end
    end

    `uvm_info("CPU_SEQ",
      $sformatf(
        "Submitting transaction: wr_en=%0b rd_en=%0b ch=%0d addr=0x%08h data_bits=%0d time=%0t",
        req.wr_en, req.rd_en, req.ch, req.addr,
        req.data_bits, $time
      ),
      UVM_MEDIUM)

    finish_item(req);

  endtask

  //======================================================
  // Default base sequence
  //======================================================
  virtual task body();

    bit [1023:0] payload;

    payload = '0;
    payload[7:0] = 8'hA5;

    send_transaction(
      1'b1,             // Write request into request FIFO
      1'b0,             // Do not read response FIFO
      AW_CH,            // Write-request packet
      ID_0,             // Transaction ID
      BURST_LEN1,       // One beat
      BYTE1,            // One byte per beat
      FIXED,            // Fixed burst
      32'h0000_0100,    // Address
      4'b0001,          // WSTRB
      payload
    );

  endtask

endclass


//======================================================
// CPU write sequence
//======================================================
class cpu_write_sequence extends cpu_base_sequence;

  `uvm_object_utils(cpu_write_sequence)

  function new(string name = "cpu_write_sequence");
    super.new(name);
  endfunction

  virtual task body();

    bit [1023:0] payload;

    payload = '0;
    payload[127:0] = {
      32'h0000_0010,
      32'h0000_000F,
      32'h0000_000E,
      32'h0000_000D
    };

    send_transaction(
      1'b1,
      1'b0,
      AW_CH,
      ID_0,
      BURST_LEN4,
      BYTE4,
      INCR,
      32'h0000_0100,
      4'b1111,
      payload
    );

  endtask

endclass


//======================================================
// CPU read-request sequence
//======================================================
class cpu_read_sequence extends cpu_base_sequence;

  `uvm_object_utils(cpu_read_sequence)

  function new(string name = "cpu_read_sequence");
    super.new(name);
  endfunction

  virtual task body();

    bit [1023:0] payload;

    payload = '0;

    // Enqueue a read-address request packet.
    // The packet builder inserts an 8-bit zero DATA
    // placeholder and the EOP marker.
    send_transaction(
      1'b1,             // Write request into request FIFO
      1'b0,             // No response FIFO read yet
      AR_CH,            // Read-address request
      ID_3,             // Transaction ID
      BURST_LEN4,       // Four beats
      BYTE4,            // Four bytes per beat
      INCR,              // Incrementing burst
      32'h0000_0400,    // Address
      4'b0000,          // WSTRB is zero for read request
      payload
    );

  endtask

endclass

`endif

