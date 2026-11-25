`ifndef AXI_SLAVE_SEQUENCE_SV
`define AXI_SLAVE_SEQUENCE_SV


// AXI slave response sequences
//
// AXI slave VIP only answers a transaction after it gets an item from its sequencer. These sequences keep sending items, so the slave answers every write and read with OKAY and They loop forever


// Write side : AWREADY, WREADY, BRESP = OKAY
class axi_slave_write_seq extends uvm_sequence #(axi4_slave_tx);

  `uvm_object_utils(axi_slave_write_seq)

  function new(string name = "axi_slave_write_seq");
    super.new(name);
  endfunction

  task body();
    // the slave driver sends back a response object; we don't nee

    forever begin
      req = axi4_slave_tx::type_id::create("req");
      start_item(req);
      req.tx_type = axi4_globals_pkg::WRITE;
      if (!req.randomize() with { transfer_type == axi4_globals_pkg::OUTSTANDING_WRITE;
                                  bresp         == axi4_globals_pkg::WRITE_OKAY; })
        `uvm_fatal(get_type_name(), "Randomization failed")
      finish_item(req);
    end
  endtask

endclass


// Read side : ARREADY, RDATA from slave memory, RRESP = OKAY
class axi_slave_read_seq extends uvm_sequence #(axi4_slave_tx);

  `uvm_object_utils(axi_slave_read_seq)

  function new(string name = "axi_slave_read_seq");
    super.new(name);
  endfunction

  task body();

    forever begin
      req = axi4_slave_tx::type_id::create("req");
      start_item(req);
      req.tx_type = axi4_globals_pkg::READ;
      if (!req.randomize() with { transfer_type == axi4_globals_pkg::OUTSTANDING_READ;
                                  rresp == axi4_globals_pkg::READ_OKAY; })
        `uvm_fatal(get_type_name(), "Randomization failed")
      finish_item(req);
    end
  endtask

endclass

`endif
