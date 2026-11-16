
`ifndef SCOREBOARD_SV
`define SCOREBOARD_SV

`uvm_analysis_imp_decl(_aw)
`uvm_analysis_imp_decl(_w)
`uvm_analysis_imp_decl(_b)
`uvm_analysis_imp_decl(_ar)
`uvm_analysis_imp_decl(_r)

class request_info;
  bit [3:0]  id;
  bit [31:0] address;
  bit [3:0]  len;
  bit [2:0]  size;
  bit [1:0]  burst, lock, cache;
  bit [2:0]  prot;
  bit [3:0]  strobe;
  bit [63:0] write_beats[$];

  function int number_of_beats();
    return int'(len) + 1;
  endfunction

  function int bytes_per_beat();
    return 1 << size;
  endfunction

  function string to_string();
    return $sformatf(
      "ID=%0d ADDR=0x%08h LEN=%0d SIZE=%0d BURST=%0d STRB=%04b",
      id, address, len, size, burst, strobe
    );
  endfunction
endclass


class expected_response;
  bit is_read;
  bit [3:0] id;
  bit [127:0] words[$];
endclass


class scoreboard extends uvm_scoreboard;
  `uvm_component_utils(scoreboard)

  localparam bit [7:0] SOP = 8'hAA;
  localparam bit [7:0] EOP = 8'h53;

  localparam int POS_SOP   = 0;
  localparam int POS_ID    = 8;
  localparam int POS_ADDR  = 12;
  localparam int POS_LEN   = 44;
  localparam int POS_SIZE  = 48;
  localparam int POS_BURST = 51;
  localparam int POS_LOCK  = 53;
  localparam int POS_CACHE = 55;
  localparam int POS_PROT  = 57;
  localparam int POS_STRB  = 60;
  localparam int POS_DATA  = 64;
  localparam int EOP_BITS  = 8;

  uvm_analysis_imp #(cpu_sequence_item, scoreboard) cpu_imp;
  uvm_analysis_imp_aw #(axi4_slave_tx, scoreboard) aw_imp;
  uvm_analysis_imp_w  #(axi4_slave_tx, scoreboard) w_imp;
  uvm_analysis_imp_b  #(axi4_slave_tx, scoreboard) b_imp;
  uvm_analysis_imp_ar #(axi4_slave_tx, scoreboard) ar_imp;
  uvm_analysis_imp_r  #(axi4_slave_tx, scoreboard) r_imp;

  bit cpu_packet_bits[$];
  int cpu_words_received;
  int cpu_words_expected;
  bit cpu_packet_unsupported;

  request_info expected_write_addresses[$];
  request_info expected_write_bursts[$];
  request_info expected_read_addresses[$];

  request_info current_write_burst;
  int current_write_beat;

  expected_response expected_responses[int][$];
  expected_response current_response;
  int current_response_word;

  request_info reads_in_flight[int][$];
  bit [63:0] read_beats_collected[int][$];

  bit [7:0] memory_model[bit [31:0]];

  bit check_read_after_write = 1'b1;
  string check_groups[$] =
    '{"PACKET", "AW", "W", "AR", "RESPONSE", "MEMORY"};

  int passed[string];
  int failed[string];

  function new(string name = "scoreboard",
               uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    cpu_imp = new("cpu_imp", this);
    aw_imp  = new("aw_imp", this);
    w_imp   = new("w_imp", this);
    b_imp   = new("b_imp", this);
    ar_imp  = new("ar_imp", this);
    r_imp   = new("r_imp", this);

    foreach (check_groups[i]) begin
      passed[check_groups[i]] = 0;
      failed[check_groups[i]] = 0;
    end
  endfunction

  function void record_pass(string group);
    passed[group]++;
  endfunction

  function void report_failure(string group, string message);
    failed[group]++;
    `uvm_error("SCB", $sformatf("[%s] %s", group, message))
  endfunction

  function void compare_field(
    ref string differences,
    input string field,
    input longint unsigned actual,
    inout longint unsigned expected
  );
    if (actual != expected)
      differences = {
        differences,
        $sformatf(" %s(expected=0x%0h actual=0x%0h)",
                  field, expected, actual)
      };
  endfunction

  function void finish_check(
    string group,
    string description,
    string differences
  );
    if (differences == "")
      record_pass(group);
    else
      report_failure(group, {description, differences});
  endfunction

  function bit [1023:0] packet_field(int start, int width);
    bit [1023:0] value = '0;
    for (int i = 0; i < width; i++) begin
      value = value << 1;
      if ((start+i) < cpu_packet_bits.size())
        value[0] = cpu_packet_bits[start+i];
    end
    return value;
  endfunction

  function bit [63:0] low_bits_mask(int width);
    if (width >= 64)
      return 64'hFFFF_FFFF_FFFF_FFFF;
    if (width <= 0)
      return 64'd0;
    return (64'd1 << width) - 1;
  endfunction

  function bit [63:0] get_beat(
    bit [1023:0] data,
    int beat,
    int beat_bits,
    int total_bits
  );
    int shift_amount;
    bit [1023:0] shifted;

    shift_amount = total_bits - ((beat+1)*beat_bits);
    if (shift_amount < 0)
      return '0;

    shifted = data >> shift_amount;
    return shifted[63:0] & low_bits_mask(beat_bits);
  endfunction

  function void append_bits(
    ref bit bits[$],
    input bit [1023:0] value,
    input int width
  );
    for (int i = width-1; i >= 0; i--)
      bits.push_back(value[i]);
  endfunction

  function bit [31:0] calculate_beat_address(
    bit [31:0] start_address,
    bit [3:0] len,
    bit [2:0] size,
    bit [1:0] burst,
    int beat
  );
    bit [31:0] bytes_per_beat;
    bit [31:0] burst_bytes;
    bit [31:0] wrap_base;
    bit [31:0] offset;

    bytes_per_beat = 32'd1 << size;
    burst_bytes = (int'(len)+1)*bytes_per_beat;

    case (burst)
      2'b01: return start_address + beat*bytes_per_beat;
      2'b10: begin
        if (burst_bytes == 0)
          return start_address;
        wrap_base = (start_address/burst_bytes)*burst_bytes;
        offset = (start_address-wrap_base+
                  beat*bytes_per_beat)%burst_bytes;
        return wrap_base+offset;
      end
      default: return start_address;
    endcase
  endfunction

  function void write(cpu_sequence_item item);
    if (item.wr_en)
      receive_cpu_request_word(item.wr_data);
    if (item.rd_en)
      receive_cpu_response_word(item.rd_data);
  endfunction

  function bit is_read_request_packet();
    return (packet_field(POS_DATA, 8) == 0) &&
           (packet_field(POS_DATA+8, 8) == EOP);
  endfunction

  function int data_bits_in_packet();
    int len;
    int size;

    if (is_read_request_packet())
      return 8;

    len  = packet_field(POS_LEN, 4);
    size = packet_field(POS_SIZE, 3);
    return ((len+1) << size)*8;
  endfunction

  function void receive_cpu_request_word(bit [127:0] word);
    if (cpu_words_received == 0)
      cpu_packet_bits.delete();

    for (int i = 127; i >= 0; i--)
      cpu_packet_bits.push_back(word[i]);

    cpu_words_received++;

    if (cpu_words_received == 1) begin
      if (packet_field(POS_SOP, 8) != SOP) begin
        report_failure("PACKET",
          $sformatf("Bad SOP in request word 0x%032h", word));
        cpu_words_received = 0;
        return;
      end

      cpu_packet_unsupported =
        (packet_field(POS_SIZE, 3) > 3);

      if (cpu_packet_unsupported)
        report_failure("PACKET",
          $sformatf("Unsupported SIZE=%0d",
                    packet_field(POS_SIZE, 3)));

      cpu_words_expected =
        (POS_DATA+data_bits_in_packet()+EOP_BITS+127)/128;
    end

    if (cpu_words_received == cpu_words_expected) begin
      if (!cpu_packet_unsupported)
        decode_request_packet();
      cpu_words_received = 0;
    end
  endfunction

  function request_info decode_packet_header();
    request_info request = new();

    request.id      = packet_field(POS_ID, 4);
    request.address = packet_field(POS_ADDR, 32);
    request.len     = packet_field(POS_LEN, 4);
    request.size    = packet_field(POS_SIZE, 3);
    request.burst   = packet_field(POS_BURST, 2);
    request.lock    = packet_field(POS_LOCK, 2);
    request.cache   = packet_field(POS_CACHE, 2);
    request.prot    = packet_field(POS_PROT, 3);
    request.strobe  = packet_field(POS_STRB, 4);

    return request;
  endfunction

  function void decode_request_packet();
    request_info request = decode_packet_header();

    if (is_read_request_packet()) begin
      record_pass("PACKET");
      expected_read_addresses.push_back(request);
    end
    else
      decode_write_data(request);
  endfunction

  function void decode_write_data(request_info request);
    int data_bits;
    int beat_bits;
    bit [1023:0] data;

    data_bits = data_bits_in_packet();
    beat_bits = request.bytes_per_beat()*8;

    if (packet_field(POS_DATA+data_bits, 8) != EOP) begin
      report_failure("PACKET",
        $sformatf("Bad EOP in write request ID=%0d", request.id));
      return;
    end

    record_pass("PACKET");
    data = packet_field(POS_DATA, data_bits);

    for (int beat = 0; beat < request.number_of_beats(); beat++)
      request.write_beats.push_back(
        get_beat(data, beat, beat_bits, data_bits));

    expected_write_addresses.push_back(request);
    expected_write_bursts.push_back(request);
  endfunction

  function void compare_address_fields(
    ref string differences,
    input request_info expected,
    input int id,
    input int address,
    input int len,
    input int size,
    input int burst,
    input int lock,
    input int cache,
    input int prot
  );
    compare_field(differences, "ID", id, expected.id);
    compare_field(differences, "ADDRESS", address, expected.address);
    compare_field(differences, "LEN", len, expected.len);
    compare_field(differences, "SIZE", size, expected.size);
    compare_field(differences, "BURST", burst, expected.burst);
    compare_field(differences, "LOCK", lock, expected.lock);
    compare_field(differences, "CACHE", cache, expected.cache);
    compare_field(differences, "PROT", prot, expected.prot);
  endfunction

  function void write_aw(axi4_slave_tx t);
    request_info expected;
    string differences = "";

    if (expected_write_addresses.size() == 0) begin
      report_failure("AW", "Unexpected AW transaction");
      return;
    end

    expected = expected_write_addresses.pop_front();

    compare_address_fields(differences, expected,
      t.awid, t.awaddr, t.awlen, t.awsize, t.awburst,
      t.awlock, t.awcache, t.awprot);

    finish_check("AW", "AW field mismatch:", differences);
  endfunction

  function void write_ar(axi4_slave_tx t);
    request_info expected;
    request_info read_request = new();
    string differences = "";

    if (expected_read_addresses.size() == 0) begin
      report_failure("AR", "Unexpected AR transaction");
      return;
    end

    expected = expected_read_addresses.pop_front();

    compare_address_fields(differences, expected,
      t.arid, t.araddr, t.arlen, t.arsize, t.arburst,
      t.arlock, t.arcache, t.arprot);

    finish_check("AR", "AR field mismatch:", differences);

    read_request.id = t.arid;
    read_request.address = t.araddr;
    read_request.len = t.arlen;
    read_request.size = t.arsize;
    read_request.burst = t.arburst;

    reads_in_flight[int'(t.arid)].push_back(read_request);
  endfunction

  function bit start_next_write_burst_if_needed();
    if (current_write_burst != null)
      return 1;

    if (expected_write_bursts.size() == 0) begin
      report_failure("W", "Unexpected W beat");
      return 0;
    end

    current_write_burst = expected_write_bursts.pop_front();
    current_write_beat = 0;
    return 1;
  endfunction

  function void write_w(axi4_slave_tx t);
    foreach (t.wdata[i]) begin
      if (!start_next_write_burst_if_needed())
        return;

      check_write_beat(t.wdata[i], t.wstrb[i]);

      update_memory_model(
        current_write_burst,
        current_write_beat,
        t.wdata[i],
        t.wstrb[i]
      );

      current_write_beat++;

      if (current_write_beat ==
          current_write_burst.number_of_beats()) begin
        check_write_last(t.wlast, 1);
        current_write_burst = null;
        current_write_beat = 0;
      end
      else if (t.wlast)
        check_write_last(t.wlast, 0);
    end
  endfunction

  function void check_write_beat(
    bit [63:0] data,
    bit [3:0] strobe
  );
    request_info burst;
    string differences = "";
    int beat;

    burst = current_write_burst;
    beat = current_write_beat;

    compare_field(differences, "WSTRB", strobe, burst.strobe);

    for (int lane = 0;
         lane < burst.bytes_per_beat() && lane < 8;
         lane++) begin

      if (lane < 4 && burst.strobe[lane])
        compare_field(differences,
          $sformatf("WDATA lane %0d", lane),
          data[lane*8 +: 8],
          burst.write_beats[beat][lane*8 +: 8]);
      else if (lane >= 4)
        compare_field(differences,
          $sformatf("WDATA lane %0d", lane),
          data[lane*8 +: 8],
          burst.write_beats[beat][lane*8 +: 8]);
    end

    finish_check("W",
      $sformatf("W beat %0d mismatch:", beat), differences);
  endfunction

  function void check_write_last(bit actual, bit expected_value);
    string differences = "";
    compare_field(differences, "WLAST", actual, expected_value);
    finish_check("W", "WLAST mismatch:", differences);
  endfunction

  function int response_key(bit is_read, int id);
    return (is_read ? 16 : 0) + id;
  endfunction

  function void add_expected_response(
    bit is_read,
    int id,
    ref bit packet_bits[$]
  );
    expected_response response = new();
    bit [127:0] word;

    response.is_read = is_read;
    response.id = id;

    while ((packet_bits.size()%128) != 0)
      packet_bits.push_back(1'b0);

    for (int first = 0; first < packet_bits.size(); first += 128) begin
      for (int i = 0; i < 128; i++)
        word[127-i] = packet_bits[first+i];
      response.words.push_back(word);
    end

    expected_responses[response_key(is_read, id)].push_back(response);
  endfunction

  function void write_b(axi4_slave_tx t);
    bit packet_bits[$];

    append_bits(packet_bits, SOP, 8);
    append_bits(packet_bits, 1024'(t.bid), 4);
    append_bits(packet_bits, {2'b00, t.bresp}, 4);
    append_bits(packet_bits, EOP, 8);

    add_expected_response(0, int'(t.bid), packet_bits);
  endfunction

  function void write_r(axi4_slave_tx t);
    int id;
    request_info read_request;

    id = int'(t.rid);

    if (!reads_in_flight.exists(id) ||
        reads_in_flight[id].size() == 0) begin
      report_failure("RESPONSE",
        $sformatf("R received without outstanding AR, ID=%0d", id));
      return;
    end

    read_request = reads_in_flight[id][0];

    foreach (t.rdata[i])
      read_beats_collected[id].push_back(t.rdata[i]);

    if (read_beats_collected[id].size() <
        read_request.number_of_beats())
      return;

    if (read_beats_collected[id].size() >
        read_request.number_of_beats()) begin
      report_failure("RESPONSE",
        $sformatf("Too many R beats for ID=%0d", id));
    end
    else begin
      if (check_read_after_write)
        check_read_data_against_memory(read_request, id);

      build_expected_read_response(read_request, id, t.rresp);
    end

    read_beats_collected[id].delete();
    void'(reads_in_flight[id].pop_front());
  endfunction

  function void build_expected_read_response(
    request_info read_request,
    int id,
    bit [1:0] resp
  );
    bit packet_bits[$];
    bit [1023:0] data = '0;
    int nb;
    int beat_bits;

    nb = read_request.number_of_beats();
    beat_bits = read_request.bytes_per_beat()*8;

    for (int beat = 0; beat < nb; beat++)
      data = (data << beat_bits) |
        (1024'(read_beats_collected[id][beat]) &
         ((1024'(1) << beat_bits)-1));

    append_bits(packet_bits, SOP, 8);
    append_bits(packet_bits, 1024'(id), 4);
    append_bits(packet_bits, data, nb*beat_bits);
    append_bits(packet_bits, {2'b00, resp}, 4);
    append_bits(packet_bits, EOP, 8);

    add_expected_response(1, id, packet_bits);
  endfunction

  function bit is_write_response_word(bit [127:0] word);
    return (word[111:104] == EOP) && (word[103:0] == '0);
  endfunction

  function expected_response take_expected_response_for(bit [127:0] word);
    bit is_read;
    int id;
    int key;

    is_read = !is_write_response_word(word);
    id = word[119:116];
    key = response_key(is_read, id);

    if (word[127:120] != SOP) begin
      report_failure("RESPONSE", "Bad SOP in CPU response");
      return null;
    end

    if (!expected_responses.exists(key) ||
        expected_responses[key].size() == 0) begin
      report_failure("RESPONSE",
        $sformatf("Unexpected response packet ID=%0d", id));
      return null;
    end

    return expected_responses[key].pop_front();
  endfunction

  function void receive_cpu_response_word(bit [127:0] word);
    bit [127:0] expected_word;

    if (current_response == null) begin
      current_response = take_expected_response_for(word);
      current_response_word = 0;
      if (current_response == null)
        return;
    end

    expected_word = current_response.words[current_response_word];

    if (word === expected_word)
      record_pass("RESPONSE");
    else
      report_failure("RESPONSE",
        $sformatf("Response ID=%0d word=%0d expected=%032h actual=%032h",
          current_response.id, current_response_word, expected_word, word));

    current_response_word++;

    if (current_response_word == current_response.words.size()) begin
      current_response = null;
      current_response_word = 0;
    end
  endfunction

  function void update_memory_model(
    request_info burst,
    int beat,
    bit [63:0] data,
    bit [3:0] strobe
  );
    bit [31:0] beat_address;

    beat_address = calculate_beat_address(
      burst.address, burst.len, burst.size, burst.burst, beat);

    for (int lane = 0;
         lane < burst.bytes_per_beat() && lane < 4;
         lane++) begin
      if (strobe[lane])
        memory_model[beat_address+lane] = data[lane*8 +: 8];
    end
  endfunction

  function void check_read_data_against_memory(
    request_info read_request,
    int id
  );
    for (int beat = 0;
         beat < read_request.number_of_beats();
         beat++) begin

      string differences = "";
      int bytes_compared = 0;

      bit [31:0] beat_address = calculate_beat_address(
        read_request.address,
        read_request.len,
        read_request.size,
        read_request.burst,
        beat);

      for (int lane = 0;
           lane < read_request.bytes_per_beat() && lane < 8;
           lane++) begin

        bit [31:0] byte_address = beat_address + lane;

        if (memory_model.exists(byte_address)) begin
          compare_field(differences,
            $sformatf("address 0x%08h", byte_address),
            read_beats_collected[id][beat][lane*8 +: 8],
            memory_model[byte_address]);
          bytes_compared++;
        end
      end

      if (bytes_compared > 0)
        finish_check("MEMORY",
          $sformatf("Read data mismatch ID=%0d beat=%0d", id, beat),
          differences);
    end
  endfunction

  function void check_phase(uvm_phase phase);
    int responses_not_read = 0;
    int reads_without_data = 0;

    super.check_phase(phase);

    foreach (expected_responses[key])
      responses_not_read += expected_responses[key].size();

    foreach (reads_in_flight[id])
      reads_without_data += reads_in_flight[id].size();

    if (expected_write_addresses.size() != 0)
      `uvm_error("SCB", "Write requests did not appear on AW")

    if (expected_write_bursts.size() != 0 ||
        current_write_burst != null)
      `uvm_error("SCB", "Write request did not receive all W beats")

    if (expected_read_addresses.size() != 0)
      `uvm_error("SCB", "Read requests did not appear on AR")

    if (reads_without_data != 0)
      `uvm_error("SCB", "Reads did not receive R data")

    if (responses_not_read != 0)
      `uvm_error("SCB", "Expected response packets were not read by CPU")

    if (cpu_words_received != 0 || current_response != null)
      `uvm_error("SCB", "Incomplete CPU packet at end of test")
  endfunction

  function void report_phase(uvm_phase phase);
    int total_passed = 0;
    int total_failed = 0;

    super.report_phase(phase);

    foreach (check_groups[i]) begin
      string group = check_groups[i];

      `uvm_info("SCB",
        $sformatf("%s passed=%0d failed=%0d",
          group, passed[group], failed[group]),
        UVM_NONE)

      total_passed += passed[group];
      total_failed += failed[group];
    end

    `uvm_info("SCB",
      $sformatf("TOTAL passed=%0d failed=%0d",
        total_passed, total_failed), UVM_NONE)
  endfunction

endclass

`endif

