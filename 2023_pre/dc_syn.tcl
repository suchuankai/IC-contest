#Read All Files
read_file -format verilog  LASER.v
#read_file -format sverilog  LASER.v
current_design LASER
link

#Setting Clock Constraints
source -echo -verbose LASER.sdc
check_design
set high_fanout_net_threshold 0
uniquify
set_fix_multiple_port_nets -all -buffer_constants [get_designs *]
#set_max_area 0
#Synthesis all design
compile
#compile -map_effort high -area_effort high
#compile -map_effort high -area_effort high -inc
#compile_ultra

write -format ddc     -hierarchy -output "LASER_syn.ddc"
write_sdf -version 1.0  LASER_syn.sdf
write -format verilog -hierarchy -output LASER_syn.v
report_area > area.log
report_timing > timing.log
report_qor   >  LASER_syn.qor
