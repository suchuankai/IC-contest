#Read All Files
read_file -format verilog  Bicubic.v
#read_file -format sverilog  Bicubic.v
current_design Bicubic
link

#Setting Clock Constraints
source -echo -verbose Bicubic.sdc
set_fix_hold                [all_clocks]
check_design
set high_fanout_net_threshold 0
uniquify
set_fix_multiple_port_nets -all -buffer_constants [get_designs *]
#set_max_area 0
#Synthesis all design
#compile -map_effort high -area_effort high
#compile -map_effort high -area_effort high -inc
compile_ultra

write -format ddc     -hierarchy -output "Bicubic_syn.ddc"
write_sdf -version 1.0  Bicubic_syn.sdf
write -format verilog -hierarchy -output Bicubic_syn.v
report_area > area.log
report_timing > timing.log
report_qor   >  Bicubic_syn.qor
write_parasitics -output Bicubic_syn.spef
