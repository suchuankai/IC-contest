read_file IOTDF.v
source IOTDF_DC.sdc
compile
write -format ddc     -hierarchy -output "IOTDF_syn.ddc"
write_sdf -version 1.0  IOTDF_syn.sdf
write -format verilog -hierarchy -output IOTDF_syn.v
report_area > area.log
report_timing > timing.log
report_qor   >  IOTDF_syn.qor
