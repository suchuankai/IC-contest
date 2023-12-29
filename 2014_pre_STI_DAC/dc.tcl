source synopsys_dc.setup
read_file STI_DAC.v
source STI_DAC.sdc
compile 
write -format verilog -hierarchy -output STI_DAC_syn.v
write -format ddc -hierarchy -output STI_DAC_syn.ddc
write_sdf -version 2.1 STI_DAC_syn.sdf