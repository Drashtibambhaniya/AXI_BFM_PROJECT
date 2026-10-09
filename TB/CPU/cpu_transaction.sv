`ifndef CPU_SEQUENCE_ITEM_SV
`define CPU_SEQUENCE_ITEM_SV

`timescale 1ns/1ps

`include "uvm_macros.svh"
import uvm_pkg::*;

class cpu_sequence_item extends uvm_sequence_item;

  rand bit wr_en;
  rand bit rd_en;

  rand bit [31:0]   addr;
  rand bit [3:0]    wstrb;
  rand bit [1023:0] wdata;

  rand channel_e ch;
  rand txn_id_e  txn_id;
  rand len_e     len;
  rand size_e    size;
  rand burst_e   burst;
  rand lock_e    lock;
  rand cache_e   cache;
  rand prot_e    prot;

  bit [127:0] rd_data;
  bit [127:0] wr_data;

  bit full;
  bit empty;

  bit [7:0] sop = 8'hAA;
  bit [7:0] eop = 8'h53;

  bit [127:0] fifo_word[];
  int fifo_size;


  `uvm_object_utils_begin(cpu_sequence_item)

    `uvm_field_int(wr_en,   UVM_ALL_ON)
    `uvm_field_int(rd_en,   UVM_ALL_ON)
    `uvm_field_int(addr,    UVM_ALL_ON)
    `uvm_field_int(wstrb,   UVM_ALL_ON)
    `uvm_field_int(wdata,   UVM_ALL_ON)

    `uvm_field_enum(channel_e, ch,     UVM_ALL_ON)
    `uvm_field_enum(txn_id_e,  txn_id, UVM_ALL_ON)
    `uvm_field_enum(len_e,     len,    UVM_ALL_ON)
    `uvm_field_enum(size_e,    size,   UVM_ALL_ON)
    `uvm_field_enum(burst_e,   burst,  UVM_ALL_ON)
    `uvm_field_enum(lock_e,    lock,   UVM_ALL_ON)
    `uvm_field_enum(cache_e,   cache,  UVM_ALL_ON)
    `uvm_field_enum(prot_e,    prot,   UVM_ALL_ON)

    `uvm_field_int(rd_data, UVM_ALL_ON)
    `uvm_field_int(wr_data, UVM_ALL_ON)
    `uvm_field_int(full,    UVM_ALL_ON)
    `uvm_field_int(empty,   UVM_ALL_ON)

  `uvm_object_utils_end


  function new(string name = "cpu_sequence_item");
    super.new(name);
  endfunction


  constraint c_reserved {
    ch    != RESERVED_CH;
    lock  != LOCK_RESERVED1;
    lock  != LOCK_RESERVED2;
    burst != BURST_RESERVED;
  }


  constraint c_read_packet {
    if(ch == AR_CH) {
      wstrb == 4'b0000;
      wdata == '0;
    }
  }


  constraint c_address_alignment {
    addr % (1 << size) == 0;
  }


  constraint c_wrap_alignment {
    if(burst == WRAP)
      addr % ((len + 1) * (1 << size)) == 0;
  }


  constraint c_wrap_length {
    if(burst == WRAP)
      len inside {
        BURST_LEN2,
        BURST_LEN4,
        BURST_LEN8,
        BURST_LEN16
      };
  }


  function void build_fifo_packet();

    fifo_word.delete();

    if(ch == AW_CH || ch == W_CH) begin

      fifo_size = 9;
      fifo_word = new[fifo_size];

      fifo_word[0] = {
        sop,
        txn_id,
        addr,
        len,
        size,
        burst,
        lock,
        cache,
        prot,
        wstrb,
        wdata[1023:960]
      };

      fifo_word[1] = wdata[959:832];

      fifo_word[2] = wdata[831:704];

      fifo_word[3] = wdata[703:576];

      fifo_word[4] = wdata[575:448];

      fifo_word[5] = wdata[447:320];

      fifo_word[6] = wdata[319:192];

      fifo_word[7] = wdata[191:64];

      fifo_word[8] = {
        wdata[63:0],
        eop,
        56'h0
      };

    end

    else if(ch == AR_CH) begin

      fifo_size = 1;
      fifo_word = new[fifo_size];

      fifo_word[0] = {
        sop,
        txn_id,
        addr,
        len,
        size,
        burst,
        lock,
        cache,
        prot,
        wstrb,
        8'h00,
        eop,
        48'h0
      };

    end

    else begin

      fifo_size = 0;

    end

  endfunction

endclass

`endif
