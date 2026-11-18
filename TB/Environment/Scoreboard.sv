`ifndef SCOREBOARD_SV
`define SCOREBOARD_SV

`uvm_analysis_imp_decl(_req)
`uvm_analysis_imp_decl(_rsp)
`uvm_analysis_imp_decl(_aw)
`uvm_analysis_imp_decl(_w)
`uvm_analysis_imp_decl(_b)
`uvm_analysis_imp_decl(_ar)
`uvm_analysis_imp_decl(_r)

//==============================================================
// FIFO-level scoreboard
//
//  req_imp : words the CPU writes into the WRITE FIFO  (requests)
//  rsp_imp : words the CPU reads from the READ FIFO    (responses)
//
//  1. For every request, predict the response the DUT must send.
//  2. Store the prediction in an associative array, key = TXN_ID.
//  3. When a response comes out, compare it with the prediction.
//
//  aw/w/b/ar/r_imp : AXI side, printed for debug only (not compared)
//==============================================================
class scoreboard extends uvm_scoreboard;

  `uvm_component_utils(scoreboard)

  // FIFO level (compared)
  uvm_analysis_imp_req #(cpu_sequence_item, scoreboard) req_imp;
  uvm_analysis_imp_rsp #(cpu_sequence_item, scoreboard) rsp_imp;

  // AXI level (debug prints only)
  uvm_analysis_imp_aw #(axi4_slave_tx, scoreboard) aw_imp;
  uvm_analysis_imp_w  #(axi4_slave_tx, scoreboard) w_imp;
  uvm_analysis_imp_b  #(axi4_slave_tx, scoreboard) b_imp;
  uvm_analysis_imp_ar #(axi4_slave_tx, scoreboard) ar_imp;
  uvm_analysis_imp_r  #(axi4_slave_tx, scoreboard) r_imp;

  // A packet is at most 9 FIFO words (1024-bit data).
  // A whole packet is kept in one vector, FIRST WORD AT THE TOP.
  typedef bit [1151:0] packet_t;      // 9 x 128 = 1152 bits

  // Expected responses (key = TXN_ID)
  bit [127:0] exp_wr_rsp [bit [3:0]];
  packet_t    exp_rd_rsp [bit [3:0]];

  // Reference memory (key = address)
  bit [`DW-1:0] mem [bit [31:0]];

  // Words of the packet currently being collected
  bit [127:0] req_words [$];
  bit [127:0] rsp_words [$];

  int pass_count;
  int fail_count;


  function new(string name = "scoreboard", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    req_imp = new("req_imp", this);
    rsp_imp = new("rsp_imp", this);
    aw_imp  = new("aw_imp",  this);
    w_imp   = new("w_imp",   this);
    b_imp   = new("b_imp",   this);
    ar_imp  = new("ar_imp",  this);
    r_imp   = new("r_imp",   this);
  endfunction


  //============================================================
  // HOW MANY FIFO WORDS IN A PACKET  (depends on data width)
  //============================================================

  // Write request = header(64) + data(DW) + EOP(8)
  // (same numbers as fifo_size in cpu_sequence_item)
  function int write_request_words();
    case (`DW)
      32   : return 1;
      64   : return 2;
      128  : return 2;
      256  : return 3;
      512  : return 5;
      1024 : return 9;
    endcase
  endfunction

  // Read response = SOP(8) + ID(4) + data(DW) + RESP(4) + EOP(8)
  function int read_response_words();
    case (`DW)
      32   : return 1;
      64   : return 1;
      128  : return 2;
      256  : return 3;
      512  : return 5;
      1024 : return 9;
    endcase
  endfunction


  //============================================================
  // SMALL HELPERS
  //============================================================

  // Put the words of a packet into one vector, first word at the top
  function packet_t join_words(bit [127:0] words[$]);
    packet_t pkt = '0;
    foreach (words[i])
      pkt[1151 - i*128 -: 128] = words[i];
    return pkt;
  endfunction

  // Read request : one word, data byte = 00 followed by EOP
  function bit is_read_request(bit [127:0] word);
    return (word[63:56] == 8'h00) && (word[55:48] == 8'h53);
  endfunction

  // Write response : one word, EOP right after ID + RESP, rest zero
  function bit is_write_response(bit [127:0] word);
    return (word[111:104] == 8'h53) && (word[103:0] == '0);
  endfunction

  // Expected write response : {SOP, ID, RESP=OKAY, EOP, zeros}
  function bit [127:0] make_write_response(bit [3:0] id);
    return {8'hAA, id, 4'b0000, 8'h53, 104'h0};
  endfunction

  // Expected read response : {SOP, ID, DATA, RESP=OKAY, EOP, zeros}
  function packet_t make_read_response(bit [3:0] id, bit [`DW-1:0] data);
    packet_t pkt = '0;
    pkt[1151:1144]       = 8'hAA;     // SOP
    pkt[1143:1140]       = id;        // TXN_ID
    pkt[1139 -: `DW]     = data;      // READ DATA
    pkt[1139 - `DW -: 4] = 4'b0000;   // RESP = OKAY
    pkt[1135 - `DW -: 8] = 8'h53;     // EOP
    return pkt;
  endfunction


  //============================================================
  // STEP 1 : REQUEST  (word written into the write FIFO)
  //============================================================
  function void write_req(cpu_sequence_item item);

    // ignore cycles where nothing was written
    if (item.wr_en == 0 || item.full == 1)
      return;

    req_words.push_back(item.wr_data);

    // first word must start with SOP
    if (req_words.size() == 1 && item.wr_data[127:120] != 8'hAA) begin
      report_fail($sformatf("Request word without SOP : %032h", item.wr_data));
      req_words.delete();
      return;
    end

    // read request is always one word
    if (req_words.size() == 1 && is_read_request(item.wr_data)) begin
      predict_read(item.wr_data);
      req_words.delete();
      return;
    end

    // write request : wait until all its words have arrived
    if (req_words.size() == write_request_words()) begin
      predict_write(join_words(req_words));
      req_words.delete();
    end

  endfunction


  // Write request -> remember data, expect OKAY
  function void predict_write(packet_t pkt);
    bit [3:0]     id   = pkt[1143:1140];
    bit [31:0]    addr = pkt[1139:1108];
    bit [`DW-1:0] data = pkt[1087 -: `DW];       // data starts after the 64-bit header
    bit [7:0]     eop  = pkt[1087 - `DW -: 8];   // EOP right after the data

    if (eop != 8'h53) begin
      report_fail($sformatf("Write request ID=%0d has bad EOP = %02h", id, eop));
      return;
    end

    mem[addr]      = data;
    exp_wr_rsp[id] = make_write_response(id);

    `uvm_info("SCB", $sformatf("WRITE request : ID=%0d  ADDR=%08h  DATA=%0h", id, addr, data), UVM_LOW)
  endfunction


  // Read request -> expect the data stored at that address
  function void predict_read(bit [127:0] word);
    bit [3:0]  id   = word[119:116];
    bit [31:0] addr = word[115:84];

    exp_rd_rsp[id] = make_read_response(id, mem[addr]);

    `uvm_info("SCB", $sformatf("READ  request : ID=%0d  ADDR=%08h  expect DATA=%0h", id, addr, mem[addr]), UVM_LOW)
  endfunction


  //============================================================
  // STEP 2 : RESPONSE  (word read out of the read FIFO)
  //============================================================
  function void write_rsp(cpu_sequence_item item);

    rsp_words.push_back(item.rd_data);

    // first word must start with SOP
    if (rsp_words.size() == 1 && item.rd_data[127:120] != 8'hAA) begin
      report_fail($sformatf("Response word without SOP : %032h", item.rd_data));
      rsp_words.delete();
      return;
    end

    // write response is always one word
    if (rsp_words.size() == 1 && is_write_response(item.rd_data)) begin
      check_write_response(item.rd_data);
      rsp_words.delete();
      return;
    end

    // read response : wait until all its words have arrived
    if (rsp_words.size() == read_response_words()) begin
      check_read_response(join_words(rsp_words));
      rsp_words.delete();
    end

  endfunction


  function void check_write_response(bit [127:0] actual);
    bit [3:0] id = actual[119:116];

    if (!exp_wr_rsp.exists(id)) begin
      report_fail($sformatf("Unexpected WRITE response ID=%0d : %032h", id, actual));
      return;
    end

    if (actual == exp_wr_rsp[id])
      report_pass($sformatf("WRITE response ID=%0d", id));
    else
      report_fail($sformatf("WRITE response ID=%0d mismatch\n expected = %032h\n actual   = %032h",
                            id, exp_wr_rsp[id], actual));

    exp_wr_rsp.delete(id);
  endfunction


  function void check_read_response(packet_t actual);
    bit [3:0] id = actual[1143:1140];

    if (!exp_rd_rsp.exists(id)) begin
      report_fail($sformatf("Unexpected READ response ID=%0d", id));
      return;
    end

    if (actual == exp_rd_rsp[id])
      report_pass($sformatf("READ response ID=%0d", id));
    else
      report_fail($sformatf("READ response ID=%0d mismatch\n expected = %0h\n actual   = %0h",
                            id, exp_rd_rsp[id], actual));

    exp_rd_rsp.delete(id);
  endfunction


  //============================================================
  // AXI SIDE : printed for debug only (not compared)
  // run with +UVM_VERBOSITY=UVM_MEDIUM to see these
  //============================================================
  function void write_aw(axi4_slave_tx t);
    `uvm_info("SCB_AXI", $sformatf("AW : ID=%0d ADDR=%08h LEN=%0d SIZE=%0d BURST=%0d",
              t.awid, t.awaddr, t.awlen, t.awsize, t.awburst), UVM_MEDIUM)
  endfunction

  // the slave monitor sends one item per W beat, beat value is at index 0
  function void write_w(axi4_slave_tx t);
    `uvm_info("SCB_AXI", $sformatf("W  : DATA=%08h STRB=%04b LAST=%0b",
              t.wdata[0], t.wstrb[0], t.wlast), UVM_MEDIUM)
  endfunction

  function void write_b(axi4_slave_tx t);
    `uvm_info("SCB_AXI", $sformatf("B  : ID=%0d RESP=%0d", t.bid, t.bresp), UVM_MEDIUM)
  endfunction

  function void write_ar(axi4_slave_tx t);
    `uvm_info("SCB_AXI", $sformatf("AR : ID=%0d ADDR=%08h LEN=%0d SIZE=%0d BURST=%0d",
              t.arid, t.araddr, t.arlen, t.arsize, t.arburst), UVM_MEDIUM)
  endfunction

  // the VIP leaves rdata empty when the data is zero, so check the size first
  function void write_r(axi4_slave_tx t);
    bit [31:0] rdata = (t.rdata.size() > 0) ? t.rdata[0] : 32'h0;
    `uvm_info("SCB_AXI", $sformatf("R  : ID=%0d DATA=%08h RESP=%0d LAST=%0b",
              t.rid, rdata, t.rresp, t.rlast), UVM_MEDIUM)
  endfunction


  //============================================================
  // REPORTING
  //============================================================
  function void report_pass(string msg);
    pass_count++;
    `uvm_info("SCB", {"PASS : ", msg}, UVM_LOW)
  endfunction

  function void report_fail(string msg);
    fail_count++;
    `uvm_error("SCB", {"FAIL : ", msg})
  endfunction

  // Anything still expected at the end never came out of the DUT
  function void check_phase(uvm_phase phase);
    foreach (exp_wr_rsp[id])
      report_fail($sformatf("WRITE response ID=%0d never received", id));
    foreach (exp_rd_rsp[id])
      report_fail($sformatf("READ response ID=%0d never received", id));
  endfunction

  function void report_phase(uvm_phase phase);
    `uvm_info("SCB", $sformatf("PASS = %0d   FAIL = %0d", pass_count, fail_count), UVM_NONE)
  endfunction

endclass

`endif
