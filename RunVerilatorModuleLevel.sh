#!/bin/sh 

cd Verilator/ModuleLevel
verilator --cc --exe --trace --top-module AXIStreamCompressor --build -j TestModule.cpp ../../Verilog/module/AXIStreamCompressor.sv \
                                                              ../../Verilog/module/CompressionModule.sv \
                                                              ../../Verilog/module/ReturnFIFO.sv \
                                                              ../../Verilog/module/StreamElement.sv -o TestModule

./obj_dir/TestModule
