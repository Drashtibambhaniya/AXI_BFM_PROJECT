class write_read_vseq extends uvm_sequence;

  `uvm_object_utils(write_read_vseq)
  `uvm_declare_p_sequencer(virtual_sequencer)

  cpu_write_read_sequence cpu_seq;
  axi_slave_write_seq     slave_wr_seq;
  axi_slave_read_seq      slave_rd_seq;

  function new(string name = "write_read_vseq");
    super.new(name);
  endfunction

  task body();
    cpu_seq      = cpu_write_read_sequence::type_id::create("cpu_seq");
    slave_wr_seq = axi_slave_write_seq::type_id::create("slave_wr_seq");
    slave_rd_seq = axi_slave_read_seq::type_id::create("slave_rd_seq");

    fork
      slave_wr_seq.start(p_sequencer.axi_wr_seqr);   // slave answers writes
      slave_rd_seq.start(p_sequencer.axi_rd_seqr);   // slave answers reads
    join_none

    cpu_seq.start(p_sequencer.cpu_seqr);             // run the scenario
  endtask

endclass
