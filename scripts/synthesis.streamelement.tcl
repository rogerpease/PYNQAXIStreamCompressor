read_verilog [ glob ./Verilog/module/*.sv ./Verilog/module/*.v ]
# Run synthesis
synth_design -top StreamElement -part xc7z020clg400-1 -flatten_hierarchy rebuilt
create_clock -period 5.000 -name sys_clk_200mhz -waveform {0.000 2.500} [get_ports clk]
# Write design checkpoint
write_checkpoint -force synthesis/streamelement/post_synth
# Write report utilization and timing estimates
write_verilog -force synthesis/streamelement/netlist.v
report_utilization -force -file synthesis/module/utilization.txt
report_timing -file synthesis/streamelement/timing.t
