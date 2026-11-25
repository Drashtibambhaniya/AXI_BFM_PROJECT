class cpu_passive_monitor extends uvm_monitor;

  `uvm_component_utils(cpu_passive_monitor)
  virtual fifo_interface.CPU_MON_MP fifo_vif;                 // fix 1
  uvm_analysis_port#(cpu_sequence_item) passive_mon_port;
  cpu_sequence_item seq;

  extern function new (string name = "cpu_passive_monitor", uvm_component parent);
  extern function void build_phase(uvm_phase phase);
  extern task run_phase(uvm_phase phase);

endclass

function cpu_passive_monitor::new (string name = "cpu_passive_monitor", uvm_component parent);
  super.new(name, parent);
endfunction

function void cpu_passive_monitor::build_phase(uvm_phase phase);
  super.build_phase(phase);
  passive_mon_port = new("passive_mon_port", this);
  if (!uvm_config_db#(virtual fifo_interface.CPU_MON_MP)::get(this, "", "fifo_vif", fifo_vif))   // fix 1
    `uvm_fatal(get_type_name(), {"virtual interface must be set for: cpu_passive_monitor ", get_full_name(), ".vif"});
endfunction

task cpu_passive_monitor::run_phase(uvm_phase phase);
  bit pop_pending = 0;

  repeat(2) @(fifo_vif.cpu_mon_cb);                           
  forever begin
    @(fifo_vif.cpu_mon_cb);                                   


    if (pop_pending) begin
      seq = cpu_sequence_item::type_id::create("cpu_seq");
      seq.rd_data = fifo_vif.cpu_mon_cb.rd_data;
      seq.full    = fifo_vif.cpu_mon_cb.full;
      seq.empty   = fifo_vif.cpu_mon_cb.empty;
      seq.rd_en   = 1;
      passive_mon_port.write(seq);
    end

    // a pop happens at this clock edge if rd_en is high and the FIFO is not empty
    pop_pending = (fifo_vif.cpu_mon_cb.rd_en === 1'b1) && (fifo_vif.cpu_mon_cb.empty === 1'b0);
  end
endtask
