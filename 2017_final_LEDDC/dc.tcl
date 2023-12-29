remove_design -all
source .synopsys_dc.setup
read_file LEDDC.v
source LEDDC_DC.sdc
compile_ultra
write -format verilog -hierarchy -output LEDDC_syn.v
write -format ddc -hierarchy -output LEDDC_syn.ddc
write_sdf -version 2.1 LEDDC_syn.sdf
