
class base_test extends uvm_test;

  `uvm_component_utils(base_test)

  environment       env;
  cpu_base_sequence cpu_seq;      // chosen by each test

  function new(string name = "base_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    `uvm_info(get_type_name(), $sformatf("[%0t] BASE TEST BUILD_PHASE STARTED", $time), UVM_LOW)
    env = environment::type_id::create("env", this);
    `uvm_info(get_type_name(), $sformatf("[%0t] BASE TEST BUILD_PHASE COMPLETED", $time), UVM_LOW)
  endfunction

  task run_phase(uvm_phase phase);
    axi_fifo_vseq vseq;

    if (cpu_seq == null)
      `uvm_fatal(get_type_name(), "No CPU sequence chosen : create cpu_seq in the test's build_phase")

    phase.raise_objection(this);

    vseq = axi_fifo_vseq::type_id::create("vseq");
    vseq.cpu_seq = cpu_seq;
    vseq.start(env.vseqr);

    #200ns;                       // let the last response reach the scoreboard
    phase.drop_objection(this);
  endtask

endclass



class write_test extends base_test;
  `uvm_component_utils(write_test)

  function new(string name = "write_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    cpu_seq = cpu_write_sequence::type_id::create("cpu_seq");
  endfunction
endclass


class read_test extends base_test;
  `uvm_component_utils(read_test)

  function new(string name = "read_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    cpu_seq = cpu_read_sequence::type_id::create("cpu_seq");
  endfunction
endclass


class write_read_test extends base_test;
  `uvm_component_utils(write_read_test)

  function new(string name = "write_read_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    cpu_seq = cpu_write_read_sequence::type_id::create("cpu_seq");
  endfunction
endclass
