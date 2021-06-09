verilator --cc --exe --trace --top-module AXIStreamCompressor --build -j TestModule.cpp ../../Verilog/module/AXIStreamCompressor.sv \
                                                              ../../Verilog/module/CompressionModule.sv \
                                                              ../../Verilog/module/ReturnFIFO.sv \
                                                              ../../Verilog/module/StreamElement.sv -o TestModule

#make -j -C obj_dir -f VStreamElement.mk VStreamElement 
