`ifndef TEST_SEQUENCE_SV
`define TEST_SEQUENCE_SV

class cpu_base_sequence extends uvm_sequence #(cpu_sequence_item);

  `uvm_object_utils(cpu_base_sequence)

  cpu_sequence_item req;

  virtual fifo_interface.CPU_MON_MP vif;     // only used to wait for clocks

  function new(string name = "cpu_base_sequence");
    super.new(name);
  endfunction

  // get the interface before body() runs
  virtual task pre_body();
    if (!uvm_config_db#(virtual fifo_interface.CPU_MON_MP)::get(null, get_full_name(), "fifo_vif", vif))
      `uvm_fatal(get_type_name(), "Failed to get virtual interface")
  endtask


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
      this.addr   == local::addr;
      this.wdata  == local::wdata;
    }) begin
      `uvm_fatal(get_type_name(), "Randomization Failed")
    end

    req.build_fifo_packet();

    finish_item(req);

  endtask


  // write request : single beat, 4 bytes, INCR
  task write_packet(txn_id_e id, bit [`ADR_WID-1:0] addr, bit [`DATA_WID-1:0] data);
    send_transaction(1, 0, AW_CH, id, BURST_LEN1, BYTE4, INCR,
                     NORMAL_ACCESS, BUFFERABLE, NORMAL_SECURE_DATA,
                     4'b1111, addr, data);
  endtask

  // read request : single beat, 4 bytes, INCR
  // (a read request is also written into the WRITE FIFO, so wr_en = 1)
  task read_packet(txn_id_e id, bit [`ADR_WID-1:0] addr);
    send_transaction(1, 0, AR_CH, id, BURST_LEN1, BYTE4, INCR,
                     NORMAL_ACCESS, BUFFERABLE, NORMAL_SECURE_DATA,
                     4'b0000, addr);
  endtask

  // wait n clocks (aligned to the clock)
  task wait_clocks(int n);
    repeat (n) @(vif.cpu_mon_cb);
  endtask

  // read one response word from the READ FIFO (rd_en for one cycle)
  task read_response();
    send_transaction(0, 1, AR_CH);
  endtask

  virtual task body();
  endtask

endclass : cpu_base_sequence


//==============================================================
// Write test : write, then read back the write response
//==============================================================
class cpu_write_sequence extends cpu_base_sequence;

  `uvm_object_utils(cpu_write_sequence)

  function new(string name = "cpu_write_sequence");
    super.new(name);
  endfunction

  virtual task body();
    write_packet(ID_0, 32'h0000_1000, 32'h1122_3344);
    wait_clocks(100);
    read_response();                       // write response
  endtask

endclass : cpu_write_sequence



class cpu_read_sequence extends cpu_base_sequence;

  `uvm_object_utils(cpu_read_sequence)

  function new(string name = "cpu_read_sequence");
    super.new(name);
  endfunction

  virtual task body();
    // setup
    write_packet(ID_0, 32'h0000_2000, 32'hAABB_CCDD);
    wait_clocks(100);
    read_response();                       // setup write response

    // read under test
    read_packet(ID_1, 32'h0000_2000);
    wait_clocks(100);
    read_response();                       // read response
  endtask

endclass : cpu_read_sequence


// Write-read test : write a value, read it back

class cpu_write_read_sequence extends cpu_base_sequence;

  `uvm_object_utils(cpu_write_read_sequence)

  function new(string name = "cpu_write_read_sequence");
    super.new(name);
  endfunction

  virtual task body();
    write_packet(ID_0, 32'h0000_1000, 32'h1122_3344);
    wait_clocks(100);
    read_response();                       // write response

    read_packet(ID_0, 32'h0000_1000);
    wait_clocks(100);
    read_response();                       // read response
  endtask

endclass : cpu_write_read_sequence

`endif
