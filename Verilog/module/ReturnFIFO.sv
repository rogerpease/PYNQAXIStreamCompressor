`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08/31/2020 07:53:39 AM
// Design Name: 
// Module Name: ReturnFIFO
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module ReturnFIFO
#(
  parameter NUM_UNCOMPRESSED_ELEMENTS = 34,
  parameter NUM_BYTES_INPUT_WIDTH = 16,
  parameter FIFO_DEPTH=64,
  parameter NUM_BYTES_OUTPUT_WIDTH = 8
)
(
   input clk, 
   input reset, 

   input wire [(NUM_BYTES_INPUT_WIDTH)-1:0][7:0]  dataIn,
   input wire [$clog2(NUM_UNCOMPRESSED_ELEMENTS)-1:0] dataInBytesValid, // Number of bytes available, may exceed 
   output wire  dataInShift, // Tells the sender to shift data down by NUM_BYTES_INPUT_WIDTH
   
   input wire endOfStream, 

   output reg [(NUM_BYTES_OUTPUT_WIDTH)-1:0][7:0] dataOut,
   output reg dataOutValid
);


   typedef reg [7:0] FifoByte_t;
   FifoByte_t [(FIFO_DEPTH-1):0] FifoPieces; 
   reg [$clog2(FIFO_DEPTH)-1:0] FifoStart; 
   reg [$clog2(FIFO_DEPTH)-1:0] FifoEnd; 
   reg [$clog2(FIFO_DEPTH)-1:0] FifoCount; 
 
 

/* verilator lint_off WIDTH */
   
  
   wire spaceAvailable,dataAvailable,takeData;
   
   // Don't add -1 to this because we need it to be 8 (for an 8 byte bus). 
   wire [$clog2(NUM_BYTES_INPUT_WIDTH):0] numBytesToRead;

   assign spaceAvailable = ((FIFO_DEPTH - FifoCount) >= numBytesToRead) ? 1 : 0;
   assign numBytesToRead =  (NUM_BYTES_INPUT_WIDTH >= dataInBytesValid) ? dataInBytesValid : NUM_BYTES_INPUT_WIDTH;
         
   assign takeData = spaceAvailable && (numBytesToRead != 0);
   assign dataInShift = takeData; 
   assign dataAvailable = (FifoCount >= NUM_BYTES_OUTPUT_WIDTH) ? 1 : 0; 
   
   
   always @(posedge clk) 
   begin 
     integer i; 
     if (reset)
     begin
     end
     if (takeData)
     begin 
       for (i = 0; i < NUM_BYTES_INPUT_WIDTH; i++)
         if (i < numBytesToRead)
           begin
             FifoPieces[FifoEnd+i] <= dataIn[i];
           end
     end   
   end
     
   always @(posedge clk)    
   begin
     integer i;          
     if ((dataAvailable) || (endOfStream))
     begin
       for (i = 0; i < NUM_BYTES_OUTPUT_WIDTH; i++)
       begin
         dataOut[i] <= FifoPieces[FifoStart+i];
       end   
       dataOutValid <= 1;
     end
     else
        dataOutValid <= 0;
   end    

   always @(posedge clk) 
   begin 
     if (reset) 
     begin 
       FifoStart <= 0;
       FifoEnd   <= 0;
       FifoCount <= 0; 
     end
     else
     begin
       if (takeData) 
         FifoEnd   <= FifoEnd + numBytesToRead;       
       if (dataAvailable)           
         FifoStart <= FifoStart + NUM_BYTES_OUTPUT_WIDTH;
          
       if (dataAvailable && takeData) 
         FifoCount <= FifoCount + numBytesToRead - NUM_BYTES_OUTPUT_WIDTH;
       else if (dataAvailable) 
         FifoCount <= FifoCount - NUM_BYTES_OUTPUT_WIDTH;
       else if (takeData)   
         FifoCount <= FifoCount + numBytesToRead;
     end
   end      

`ifdef VERILATOR
   always @(negedge clk) 
   begin
     integer elementNum; 
     integer elementCount = FifoEnd - FifoStart; 
     $display("Fifo Start ",FifoStart," Fifo End ", FifoEnd, " FifoCount ", FifoCount); 
     for (elementNum = 0;  elementNum <= elementCount; elementNum++)
     begin 
       $write("   Index  ",(elementNum+FifoStart) %FIFO_DEPTH," Element %h\n", FifoPieces[(elementNum+FifoStart)%FIFO_DEPTH]) ;
     end 
   end 
`endif 
/* verilator lint_on WIDTH */

endmodule
