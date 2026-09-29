`ifndef CPU_BASE_SEQUENCE_SV
`define CPU_BASE_SEQUENCE_SV

`include "uvm_macros.svh"
import uvm_pkg::*;

class cpu_base_sequence extends uvm_sequence #(cpu_sequence_item);

  `uvm_object_utils(cpu_base_sequence)

  cpu_sequence_item req;

  function new(string name = "cpu_base_sequence");
    super.new(name);
  endfunction

  task body();
  endtask

endclass

class cpu_write_sequence extends cpu_base_sequence;

  `uvm_object_utils(cpu_write_sequence)

  function new(string name = "cpu_write_sequence");
    super.new(name);
  endfunction


  task body();

    req = cpu_sequence_item::type_id::create("req");

    start_item(req);

    req.wr_en  = 1'b1;
    req.rd_en  = 1'b0;

    req.ch     = AW_CH;
    req.txn_id = ID_0;

    req.len    = BURST_LEN4;
    req.size   = BYTE4;
    req.burst  = INCR;

    req.lock   = NORMAL_ACCESS;
    req.cache  = BUFFERABLE;
    req.prot   = NORMAL_SECURE_DATA;

    req.wstrb  = 4'b1111;
    req.addr   = 32'h0000_1000;

    req.wdata = {
      64'h0000_0000_0000_0010,
      64'h0000_0000_0000_000F,
      64'h0000_0000_0000_000E,
      64'h0000_0000_0000_000D,
      64'h0000_0000_0000_000C,
      64'h0000_0000_0000_000B,
      64'h0000_0000_0000_000A,
      64'h0000_0000_0000_0009,
      64'h0000_0000_0000_0008,
      64'h0000_0000_0000_0007,
      64'h0000_0000_0000_0006,
      64'h0000_0000_0000_0005,
      64'h0000_0000_0000_0004,
      64'h0000_0000_0000_0003,
      64'h0000_0000_0000_0002,
      64'h0000_0000_0000_0001
    };

    req.build_fifo_packet();

    finish_item(req);

  endtask

endclass
`endif

