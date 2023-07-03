source synopsys_dc.setup
read_file SET.v
source SET.sdc
compile 
write -format verilog -hierarchy -output SET_syn.v
write -format ddc -hierarchy -output SET_syn.ddc
write_sdf -version 2.1 SET_syn.sdf