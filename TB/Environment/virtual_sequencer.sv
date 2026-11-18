`ifndef VIRTUAL_SEQUENCER_SV
`define VIRTUAL_SEQUENCER_SV

//==============================================================
// Virtual sequencer : only holds handles, drives nothing.
// The virtual sequence uses these handles to start the
// CPU and AXI slave sequences.
//==============================================================
class virtual_sequencer extends uvm_sequencer;

  `uvm_component_utils(virtual_sequencer)

  cpu_sequencer cpu_seqr;      // CPU side
  axi4_slave_write_sequencer axi_wr_seqr;   // AXI slave write side
  axi4_slave_read_sequencer  axi_rd_seqr;   // AXI slave read side

  virtual fifo_interface.CPU_MON_MP fifo_vif;   // to see FIFO 'empty'

  function new(string name = "virtual_sequencer", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual fifo_interface.CPU_MON_MP)::get(this, "", "fifo_vif", fifo_vif))
      `uvm_fatal(get_type_name(), "Failed to get virtual interface")
  endfunction

endclass

`endif
