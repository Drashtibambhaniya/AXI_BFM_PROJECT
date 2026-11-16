`timescale 1ns/1ps

`include "uvm_macros.svh" 
`include "../RTL/axi_fifo_design.v"


import uvm_pkg::*;
import axi4_globals_pkg::*; 
import axi4_slave_pkg::*;
import axi_fifo_test_pkg::*;

module top;

  bit clk = 0;
  bit ACLK  = 0 ;

  bit rstn = 1 ;
  bit ARESETn = 1;

  bit [3:0] wid; // just to declare the wid pin, not useful in axi4 
  always #5 clk = ~clk;

  always #5 ACLK = ~ACLK;

  initial begin    
    rstn = 1 ; ARESETn = 1;
    repeat(1) @(posedge clk or posedge ACLK) ;
    rstn = 0 ; ARESETn = 0;
    repeat(1) @(posedge clk or posedge ACLK) ;
    rstn = 1  ; ARESETn = 1;
  end
  
  // axi interface declaration 
  axi4_if axi_vif( ACLK , ARESETn ) ;

  // fifo_interface declaration
  fifo_interface#( .FIFO_DATA_WIDTH(`FIFO_DATA_WIDTH) ) fifo_vif ( clk , rstn );
  
  // Instantiate AVIP's slave BFM Module
  axi4_slave_agent_bfm axi_bfm_slave_wrapper( axi_vif );

  // dut instance 
  Top_Module_AXI4#(
    .data_wid (`DATA_WID),
    .adr_wid  (`ADR_WID),
    .id_wid   (`ID_WID),
    .len_wid  (`LEN_WID),
    .siz_wid  (`SIZ_WID),
    .bst_wid  (`BST_WID),
    .loc_wid  (`LOC_WID),
    .cach_wid (`CACH_WID),
    .prot_wid (`PROT_WID),
    .strb_wid (`STRB_WID),
    .rsp_wid  (`RSP_WID)
  ) DUT (

    //globals signals
    .clk(clk),
    .rstn(rstn),
    
    .ACLK(ACLK),
    .ARESETn(ARESETn),
    //fifo input
    .wr_en (fifo_vif.wr_en),
    .rd_en (fifo_vif.rd_en),
    .wr_data (fifo_vif.wr_data)
    //fifo output
    .rd_data (fifo_vif.rd_data),
    .full (fifo_vif.full),
    .empty (fifo_vif.empty),

    // aw input
    .AWREADY_a (axi_vif.awready),

    // W INPUT 
    .WREADY_a (axi_vif.wready),

    // AR INPUT
    .ARREADY_a (axi_vif.arready),

    // R INPUT
    .RID_a (axi_vif.rid),
    .RDATA_a (axi_vif.rdata),
    .RRESP_a (axi_vif.rresp),
    .RLAST_a (axi_vif.rlast),
    .RVALID_a (axi_vif.rvalid),

    // B INPUT
    .BID_a (axi_vif.bid),
    .BRESP_a (axi_vif.bresp),
    .BVALID_a (axi_vif.bvalid),

    // AW OUTPUT
    .AWID_a (axi_vif.awid),
    .AWADDR_a (axi_vif.awaddr),
    .AWLEN_a (axi_vif.awlen),
    .AWSIZE_a (axi_vif.awsize),
    .AWBURST_a (axi_vif.awburst),
    .AWLOCK_a (axi_vif.awlock),
    .AWCACHE_a (axi_vif.awcache),
    .AWPROT_a (axi_vif.awprot),
    .AWVALID_a (axi_vif.awvalid),

    //AR OUTPUT
    .ARID_a (axi_vif.arid),
    .ARADDR_a(axi_vif.araddr),
    .ARLEN_a (axi_vif.arlen),
    .ARSIZE_a (axi_vif.arsize),
    .ARBURST_a (axi_vif.arburst),
    .ARLOCK_a (axi_vif.arlock),
    .ARCACHE_a (axi_vif.arcache),
    .ARPROT_a (axi_vif.arprot),
    .ARVALID_a (axi_vif.arvalid),

    // W OUTPUT
    .WID_a (wid),
    .WDATA_a (axi_vif.wdata),
    .WSTRB_a (axi_vif.wstrb),
    .WLAST_a (axi_vif.wlast),
    .WVALID_a (axi_vif.wvalid),

    // R OUTPUT
    .RREADY_a (axi_vif.rready),

    // B OUTPUT
    .BREADY_a (axi_vif.bready)

  );


  initial begin 
    uvm_config_db#(virtual fifo_interface)::set(null,"*","fifo_vif",fifo_vif);
    uvm_config_db#(virtual axi4_if)::set(null,"*","axi4_if",axi_vif);   
    $dumpfile("wave.vcd");
    $dumpvars;
  end

  initial begin 
    
    run_test("write_test");

    #1000000 ; $finish;
  end

endmodule
