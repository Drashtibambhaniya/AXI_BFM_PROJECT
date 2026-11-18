`ifndef ENV_SV
`define ENV_SV

`include "uvm_macros.svh"

import uvm_pkg::*;
import axi4_slave_pkg::*;

class environment extends uvm_env;

  `uvm_component_utils(environment)

  cpu_active_agent        cpu_agent;
  scoreboard              sb;
  axi4_slave_agent        axi_slave_agent;
  axi4_slave_agent_config axi_slave_cfg;
  virtual_sequencer vseqr;

  function new(string name = "environment", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    `uvm_info(get_type_name(), $sformatf("[%0t] BUILD_PHASE STARTED", $time), UVM_LOW)

    cpu_agent = cpu_active_agent::type_id::create("cpu_agent", this);
    sb        = scoreboard::type_id::create("sb", this);

    // AXI slave VIP : answers the DUT's AXI transactions
    axi_slave_cfg = axi4_slave_agent_config::type_id::create("axi_slave_cfg");
    axi_slave_cfg.is_active    = UVM_ACTIVE;
    axi_slave_cfg.has_coverage = 0;
    axi_slave_cfg.slave_id     = 0;
    axi_slave_cfg.min_address  = 'h0000_0000;
    axi_slave_cfg.max_address  = 'hFFFF_FFFF;
    axi_slave_cfg.wait_count_write_response_channel = 0;
    axi_slave_cfg.wait_count_read_data_channel      = 0;
    axi_slave_cfg.maximum_transactions = 4'd8;

    // responses in order (out-of-order only makes debug harder)
    if (!axi_slave_cfg.randomize() with { slave_response_mode == axi4_globals_pkg::RESP_IN_ORDER; })
      `uvm_fatal(get_type_name(), "Failed to randomize AXI slave configuration")

    axi_slave_agent = axi4_slave_agent::type_id::create("axi_slave_agent", this);
    vseqr = virtual_sequencer::type_id::create("vseqr", this);
    axi_slave_agent.axi4_slave_agent_cfg_h = axi_slave_cfg;

    `uvm_info(get_type_name(), $sformatf("[%0t] BUILD_PHASE COMPLETED", $time), UVM_LOW)
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);

    // FIFO level : these are compared
    cpu_agent.mon.analysis_port.connect(sb.req_imp);          // requests  -> write FIFO
    cpu_agent.pmon.passive_mon_port.connect(sb.rsp_imp);      // responses <- read FIFO

    // AXI level : printed for debug only
    axi_slave_agent.axi4_slave_mon_proxy_h.axi4_slave_write_address_analysis_port.connect(sb.aw_imp);
    axi_slave_agent.axi4_slave_mon_proxy_h.axi4_slave_write_data_analysis_port.connect(sb.w_imp);
    axi_slave_agent.axi4_slave_mon_proxy_h.axi4_slave_write_response_analysis_port.connect(sb.b_imp);
    axi_slave_agent.axi4_slave_mon_proxy_h.axi4_slave_read_address_analysis_port.connect(sb.ar_imp);
    axi_slave_agent.axi4_slave_mon_proxy_h.axi4_slave_read_data_analysis_port.connect(sb.r_imp);
    vseqr.cpu_seqr    = cpu_agent.seqr;
    vseqr.axi_wr_seqr = axi_slave_agent.axi4_slave_write_seqr_h;
    vseqr.axi_rd_seqr = axi_slave_agent.axi4_slave_read_seqr_h;

    `uvm_info(get_type_name(), $sformatf("[%0t] CONNECT_PHASE COMPLETED", $time), UVM_LOW)
  endfunction

endclass

`endif
