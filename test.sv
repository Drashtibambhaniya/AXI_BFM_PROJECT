class base_test extends uvm_test;

  `uvm_component_utils(base_test)

  environment env;

  function new(string name = "base_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    `uvm_info(get_type_name(), $sformatf("[%0t] BASE TEST BUILD_PHASE STARTED", $time), UVM_LOW)

    env = environment::type_id::create("env", this);

    `uvm_info(get_type_name(), $sformatf("[%0t] Environment created", $time), UVM_LOW)

    `uvm_info(get_type_name(), $sformatf("[%0t] BASE TEST BUILD_PHASE COMPLETED", $time), UVM_LOW)
  endfunction

endclass

class write_test extends base_test;

  `uvm_component_utils(write_test)

  function new(string name = "write_test",
               uvm_component parent = null);
    super.new(name, parent);
  endfunction


  task run_phase(uvm_phase phase);

    cpu_write_sequence seq;

    phase.raise_objection(this);

    `uvm_info(get_type_name(),
              $sformatf("[%0t] WRITE_TEST RUN_PHASE STARTED", $time),
              UVM_LOW)

    seq = cpu_write_sequence::type_id::create("seq");

    `uvm_info(get_type_name(),
              $sformatf("[%0t] Starting CPU write sequence", $time),
              UVM_LOW)

    seq.start(env.cpu_agent.seqr);

    `uvm_info(get_type_name(),
              $sformatf("[%0t] CPU write sequence completed", $time),
              UVM_LOW)

    #100;

    phase.drop_objection(this);

    `uvm_info(get_type_name(),
              $sformatf("[%0t] WRITE_TEST RUN_PHASE COMPLETED", $time),
              UVM_LOW)

  endtask

endclass


