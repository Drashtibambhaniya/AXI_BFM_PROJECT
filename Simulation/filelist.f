-mfcu

+incdir+../TB/Packages
+incdir+../TB/Interface
+incdir+../TB/CPU
+incdir+../TB/Sequence
+incdir+../TB/Environment
+incdir+../TB/TEST

-f axi_avip.f

../TB/Interface/fifo_if.sv

../RTL/sync_fifo.v
../RTL/write_response_handler.v
../RTL/design_fifo.v
../RTL/my_decoder.v
../RTL/AXI_MASTER_WRITE__CONTROL.v
../RTL/AXI_MASTER_READ_Control.v
../RTL/AXI_Master.v
../RTL/Top_Module_AXI4.v

../TB/Packages/axi_fifo_test_pkg.sv
../TB/Top/tb_top.sv
