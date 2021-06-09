verilator --cc --exe --trace --build -j TestStreamElement.cpp ../../Verilog/module/StreamElement.sv  -o TestStreamElement
#make -j -C obj_dir -f VStreamElement.mk VStreamElement 
