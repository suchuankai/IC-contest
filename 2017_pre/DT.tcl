source synopsys_dc.setup
read_file DT.v
source DT.sdc
compile 
write -format verilog -hierarchy -output DT_syn.v
write -format ddc -hierarchy -output DT_syn.ddc
write_sdf -version 2.1 DT_syn.sdf