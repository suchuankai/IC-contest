source synopsys_dc.setup
read_file CONV.v
source CONV.sdc
compile
write -format verilog -hierarchy -output CONV_syn.v
write -format ddc -hierarchy -output CONV_syn.ddc
write_sdf -version 2.1 CONV_syn.sdf
report_area > area.log
report_timing > timing.log
report_qor   >  SME_syn.qor
