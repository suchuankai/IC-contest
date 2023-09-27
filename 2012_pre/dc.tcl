read_file NFC.v
source NFC.sdc
compile
write -format ddc     -hierarchy -output "NFC_syn.ddc"
write_sdf -version 1.0  NFC_syn.sdf
write -format verilog -hierarchy -output NFC_syn.v
report_area > area.log
report_timing > timing.log
report_qor   >  IOTDF_syn.qor
