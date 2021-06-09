#!/bin/sh
cd Verilator/StreamElement
verilator --cc --exe --trace --build -j TestStreamElement.cpp ../../Verilog/module/StreamElement.sv  -o TestStreamElement
./obj_dir/TestStreamElement
