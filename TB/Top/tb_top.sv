`timescale 1ns/1ps

`include "uvm_macros.svh"

import uvm_pkg::*;
//import axi4_globals_pkg::*;
//import axi4_slave_pkg::*;
import axi_fifo_test_pkg::*;


module tb_top;

  logic clk;
  logic rstn;

  fifo_interface fifo_vif(
    .clk  (clk),
    .rstn (rstn)
  );


  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end


  initial begin

    rstn = 1'b1;

    fifo_vif.full    = 1'b0;
    fifo_vif.empty   = 1'b1;
    fifo_vif.rd_data = '0;

  end


  initial begin

    uvm_config_db#(virtual fifo_interface.CPU_DRIVER_MP)::set(null, "*", "fifo_vif",fifo_vif);

    uvm_config_db#(virtual fifo_interface.CPU_MON_MP)::set(null, "*", "fifo_vif", fifo_vif);
    run_test("write_test");

  end


  initial begin

    forever begin

      @(posedge clk);

      if(fifo_vif.wr_en) begin
        $display(
          "[FIFO WRITE] time=%0t wr_data=%032h",
          $time,
          fifo_vif.wr_data
        );
      end

      if(fifo_vif.rd_en) begin
        $display(
          "[FIFO READ]  time=%0t rd_data=%032h",
          $time,
          fifo_vif.rd_data
        );
      end

    end

  end

endmodule
