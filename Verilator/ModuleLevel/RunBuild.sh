#!/bin/sh 

verilator ../../Verilog/module/AXIStreamCompressor.sv ../../Verilog/module/CompressionModule.sv ../../Verilog/module/ReturnFIFO.sv ../../Verilog/module/StreamElement.sv  --cc --exe -y /usr/local/boost_1_75_0 TestModule.cpp  PrettyPrint.cpp --build -CFLAGS "-I/usr/local/boost_1_75_0" -LDFLAGS "/usr/local/boost_1_75_0/stage/lib/libboost_json.so" 

