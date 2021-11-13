#!/bin/sh
cd Verilator/StreamElement
rm obj_dir/TestStreamElement
verilator --cc --exe --trace --build -j TestStreamElement.cpp ../../Verilog/module/StreamElement.sv  -o TestStreamElement
./obj_dir/TestStreamElement
