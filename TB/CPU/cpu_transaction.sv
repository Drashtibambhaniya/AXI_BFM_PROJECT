
`ifndef CPU_SEQUENCE_ITEM_SV
`define CPU_SEQUENCE_ITEM_SV

`timescale 1ns/1ps

`include "uvm_macros.svh"
import uvm_pkg::*;

class cpu_sequence_item extends uvm_sequence_item;

  rand bit wr_en;
  rand bit rd_en;
  rand bit [31:0] addr;
  rand bit [3:0] wstrb;
  rand bit [1023:0]  wdata;

  int unsigned data_bits;

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

  localparam bit [7:0] SOP = 8'hAA;
  localparam bit [7:0] EOP = 8'h53;

  //packet stored as 128bit fifo words
  bit [127:0] fifo_word[];
  int unsigned fifo_size;

  `uvm_object_utils_begin(cpu_sequence_item)
    `uvm_field_int(wr_en, UVM_ALL_ON)
    `uvm_field_int(rd_en, UVM_ALL_ON)

    `uvm_field_int(addr, UVM_ALL_ON)
    `uvm_field_int(wstrb, UVM_ALL_ON)
    `uvm_field_int(wdata, UVM_ALL_ON)

    `uvm_field_enum(channel_e, ch, UVM_ALL_ON)
    `uvm_field_enum(txn_id_e, txn_id, UVM_ALL_ON)
    `uvm_field_enum(len_e, len, UVM_ALL_ON)
    `uvm_field_enum(size_e, size, UVM_ALL_ON)
    `uvm_field_enum(burst_e, burst, UVM_ALL_ON)
    `uvm_field_enum(lock_e, lock, UVM_ALL_ON)
    `uvm_field_enum(cache_e, cache, UVM_ALL_ON)
    `uvm_field_enum(prot_e, prot, UVM_ALL_ON)

    `uvm_field_int(rd_data, UVM_ALL_ON)
    `uvm_field_int(wr_data, UVM_ALL_ON)
    `uvm_field_int(full, UVM_ALL_ON)
    `uvm_field_int(empty, UVM_ALL_ON)
  `uvm_object_utils_end

  function new(string name = "cpu_sequence_item");
    super.new(name);
  endfunction

  
  constraint c_cpu_request {
    wr_en == 1'b1;
    rd_en == 1'b0;
  }

  constraint c_reserved {
    burst != BURST_RESERVED;
  }

  constraint c_read_request {
    if (ch == AR_CH) {
      wdata == '0;
      wstrb == '0;
    }
  }

  // addr should be aligned to the transfer size.
  constraint c_address_alignment {
    addr % (1 << int'(size)) == 0;
  }

  constraint c_wrap_length {
    if (burst == WRAP) {
      len inside {
        BURST_LEN2,
        BURST_LEN4,
        BURST_LEN8,
        BURST_LEN16
      };
    }
  }

  //wrap burst type must start on a wrap-boundary address.
  constraint c_wrap_alignment {
    if (burst == WRAP) {
      addr % ((int'(len) + 1) *
              (1 << int'(size))) == 0;
    }
  }

  // Derive the active payload width after randomization.
  function void calculate_data_bits();

    if (ch == AR_CH)
      data_bits = 8;
    else
      data_bits = (int'(len) + 1) *
                  (1 << int'(size)) * 8;

  endfunction


  function void build_fifo_packet();

    bit [63:0] header;
    bit packet_bits[$];

    int unsigned i;
    int unsigned total_bits;

    fifo_word.delete();
    packet_bits.delete();
    fifo_size = 0;

    if (ch != AW_CH && ch != AR_CH) begin
      `uvm_error("CPU_ITEM", $sformatf("Unsupported request channel: %0d", ch))
      return;
    end


    if ((ch == AW_CH &&
         (data_bits < 8 ||
          data_bits > 1024 ||
          data_bits % 8 != 0)) ||
        (ch == AR_CH && data_bits != 8)) begin

      `uvm_error("CPU_ITEM",
        $sformatf("Invalid data_bits=%0d for channel=%0d",
                  data_bits, ch))
      return;
    end

    header = {
      SOP,
      txn_id,
      addr,
      len,
      size,
      burst,
      lock,
      cache,
      prot,
      wstrb
    };

    for (i = 0; i < 64; i++)
      packet_bits.push_back(header[63-i]);

    if (ch == AW_CH) begin
      for (i = 0; i < data_bits; i++)
        packet_bits.push_back(wdata[data_bits-1-i]);
    end

    else begin
      for (i = 0; i < 8; i++)
        packet_bits.push_back(1'b0);
    end

    for (i = 0; i < 8; i++)
      packet_bits.push_back(EOP[7-i]);

    // required number of 128-bit FIFO words.
    total_bits = packet_bits.size();
    fifo_size = (total_bits + 127) / 128;

    fifo_word = new[fifo_size];

    //padding remains zero.
    foreach (fifo_word[j])
      fifo_word[j] = '0;

    for (i = 0; i < total_bits; i++)
      fifo_word[i / 128][127 - (i % 128)] = packet_bits[i];

  endfunction

endclass

`endif
