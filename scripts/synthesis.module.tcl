read_verilog [ glob ./Verilog/module/*.sv ./Verilog/module/*.v ]
# Run synthesis
synth_design -top AXIStreamCompressor  -part xc7z020clg400-1 -flatten_hierarchy rebuilt
create_clock -period 10.000 -name sys_clk_100mhz -waveform {0.000 5.000} [get_ports *clk]
# Write design checkpoint
write_checkpoint -force synthesis/module/post_synth
# Write report utilization and timing estimates
write_verilog -force synthesis/module/netlist.v
report_utilization -force -file synthesis/module/utilization.txt
report_timing -file synthesis/module/timing.t
