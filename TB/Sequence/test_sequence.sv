
`ifndef TEST_SEQUENCE_SV
`define TEST_SEQUENCE_SV

class cpu_base_sequence extends uvm_sequence #(cpu_sequence_item);

  `uvm_object_utils(cpu_base_sequence)

  cpu_sequence_item req;

  function new(string name = "cpu_base_sequence");
    super.new(name);
  endfunction

//send transacton
  task send_transaction(
    bit wr_en  = 1'b0,
    bit rd_en  = 1'b0,
    channel_e ch     = AW_CH,
    txn_id_e  txn_id = ID_0,
    len_e     len    = BURST_LEN1,
    size_e    size   = BYTE1,
    burst_e   burst  = FIXED,
    lock_e    lock   = NORMAL_ACCESS,
    cache_e   cache  = BUFFERABLE,
    prot_e    prot   = NORMAL_SECURE_DATA,
    bit [3:0] wstrb  = 4'b0000,
    bit [`ADR_WID-1:0] addr = '0,
    bit [`DATA_WID-1:0] wdata = '0
    
  );

    req = cpu_sequence_item::type_id::create("req");

    start_item(req);

    if (!req.randomize() with {
      this.wr_en  == local::wr_en;
      this.rd_en  == local::rd_en;
      this.ch     == local::ch;
      this.txn_id == local::txn_id;
      this.len    == local::len;
      this.size   == local::size;
      this.burst  == local::burst;
      this.lock   == local::lock;
      this.cache  == local::cache;
      this.prot   == local::prot;
      this.wstrb  == local::wstrb;
      this.addr  == local::addr;
      this.wdata == local::wdata;
    }) begin
      `uvm_fatal(get_type_name(), "Randomization Failed")
    end

    req.build_fifo_packet();

    finish_item(req);

  endtask

  virtual task body();

  endtask

endclass : cpu_base_sequence





//======================================================
// Directed CPU Write Sequence
//======================================================
class cpu_write_sequence extends cpu_base_sequence;

  `uvm_object_utils(cpu_write_sequence)

  function new(string name = "cpu_write_sequence");
    super.new(name);
  endfunction

  virtual task body();

    send_transaction(
      1,                  // wr_en
      0,                  // rd_en
      AW_CH,
      ID_0,
      BURST_LEN4,
      BYTE4,
      INCR,
      NORMAL_ACCESS,
      BUFFERABLE,
      NORMAL_SECURE_DATA,
      4'b1111,
      32'h0000_1000,  // address
      32'h1122_3344   //wdata
    );

  endtask

endclass : cpu_write_sequence


//======================================================
// CPU Read Sequence
//======================================================
class cpu_read_sequence extends cpu_base_sequence;

  `uvm_object_utils(cpu_read_sequence)

  function new(string name = "cpu_read_sequence");
    super.new(name);
  endfunction

  virtual task body();

    send_transaction(
      1, 0,
      AR_CH,
      ID_0,
      BURST_LEN4,
      BYTE4,
      INCR,
      NORMAL_ACCESS,
      BUFFERABLE,
      NORMAL_SECURE_DATA,
      4'b0000
      
    );

  endtask

endclass : cpu_read_sequence




`endif

