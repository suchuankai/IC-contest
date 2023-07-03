source synopsys_dc.setup
read_file LBP.v
source LBP.sdc
compile 
write -format verilog -hierarchy -output LBP_syn.v
write -format ddc -hierarchy -output LBP_syn.ddc
write_sdf -version 2.1 LBP_syn.sdf