`ifndef VIRTUAL_SEQUENCE_SV
`define VIRTUAL_SEQUENCE_SV


// axi_fifo_vseq : the same for every test
//   1. starts the AXI slave sequences (answer every write / read)
//   2. starts the CPU sequence the test chose (cpu_seq)
//

class axi_fifo_vseq extends uvm_sequence;

  `uvm_object_utils(axi_fifo_vseq)
  `uvm_declare_p_sequencer(virtual_sequencer)

  cpu_base_sequence   cpu_seq;          // set by the test before start()
  axi4_slave_base_seq slave_wr_seq;     // AVIP slave sequence
  axi4_slave_base_seq slave_rd_seq;

  function new(string name = "axi_fifo_vseq");
    super.new(name);
  endfunction

  task body();
    if (cpu_seq == null)
      `uvm_fatal(get_type_name(), "cpu_seq not set by the test")

    slave_wr_seq = axi4_slave_base_seq::type_id::create("slave_wr_seq");
    slave_wr_seq.writeOrRead       = axi4_globals_pkg::WRITE;
    slave_wr_seq.writeTransferType = axi4_globals_pkg::OUTSTANDING_WRITE;


    slave_rd_seq = axi4_slave_base_seq::type_id::create("slave_rd_seq");
    slave_rd_seq.writeOrRead       = axi4_globals_pkg::READ;
    slave_rd_seq.readTransferType  = axi4_globals_pkg::OUTSTANDING_READ;

    // AXI slave answers in the background (loops until the test ends)
    fork
      slave_wr_seq.start(p_sequencer.axi_wr_seqr);
      slave_rd_seq.start(p_sequencer.axi_rd_seqr);
    join_none

    // the scenario
    cpu_seq.start(p_sequencer.cpu_seqr);
  endtask

endclass

`endif
