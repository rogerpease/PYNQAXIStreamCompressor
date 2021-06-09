`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08/31/2020 07:55:22 AM
// Design Name: 
// Module Name: CompressionModule
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


module CompressionModule 
#(
   parameter MAX_UNCOMPRESSED_STREAM_ELEMENT_LENGTH_BYTES = 34, 
   parameter MAX_COMPRESSED_STREAM_ELEMENT_LENGTH_BYTES = 34, 
   parameter COMPRESSIONALGORITHM = 0,
   parameter SHIFTLENGTH_BYTES  = 8 
)
(
   input                                                                 clk,
   input                                                                 reset,

   input wire [MAX_UNCOMPRESSED_STREAM_ELEMENT_LENGTH_BYTES-1:0][7:0]    USEData ,  
   input wire [$clog2(MAX_UNCOMPRESSED_STREAM_ELEMENT_LENGTH_BYTES)-1:0] USEByteCount , 

   output reg [(MAX_COMPRESSED_STREAM_ELEMENT_LENGTH_BYTES-1):0][7:0]    CSEData      , 
   output reg [$clog2(MAX_COMPRESSED_STREAM_ELEMENT_LENGTH_BYTES)-1:0]   CSEByteCount, 
   input  wire                                                           CSEShift
);

   wire [(MAX_COMPRESSED_STREAM_ELEMENT_LENGTH_BYTES-1):0][7:0]    CSEData_d; 
   wire [$clog2(MAX_COMPRESSED_STREAM_ELEMENT_LENGTH_BYTES)-1:0]   CSEByteCount_d; 


   genvar CSEByteNumber;
   for (CSEByteNumber = 0; CSEByteNumber < MAX_COMPRESSED_STREAM_ELEMENT_LENGTH_BYTES; CSEByteNumber++)
      assign CSEData_d[CSEByteNumber] = (reset) ? 0 : 
                                 // Lots of data, shifting or not. 
                                 ((CSEByteCount > SHIFTLENGTH_BYTES) && CSEShift) ? 
                                           CSEData[(CSEByteNumber + SHIFTLENGTH_BYTES)%MAX_COMPRESSED_STREAM_ELEMENT_LENGTH_BYTES] :
                                 ((CSEByteCount > SHIFTLENGTH_BYTES) && (CSEShift == 0)) ? 
                                           CSEData[CSEByteNumber] :  
                                 // Little data shifting or not. 
                                 ((CSEByteCount > 0)  && (CSEShift == 1) && (USEByteCount > 0)) ? USEData[CSEByteNumber]:  
                                 ((CSEByteCount > 0)  && (CSEShift == 0)) ? CSEData[CSEByteNumber]:  
                                 // No data. 
                                 (USEByteCount != 0) ? USEData[CSEByteNumber] : 0; 

 
   
   always @(negedge clk) 
   begin 
     $display("Compression Module In:  USEData %h %h",USEData,USEByteCount); 
     $display("Compression Module Out: CSEData %h %h %d",CSEData,CSEByteCount, CSEShift); 
   end                                              
  
   assign CSEByteCount_d = (reset) ? 0: 
                            ((CSEByteCount > SHIFTLENGTH_BYTES) && CSEShift) ? (CSEByteCount - SHIFTLENGTH_BYTES): 
                            ((CSEByteCount > SHIFTLENGTH_BYTES) && (CSEShift == 0)) ? CSEByteCount : 
                            ((CSEByteCount > 0)  && (CSEShift == 1) && (USEByteCount > 0)) ? USEByteCount:  
                            ((CSEByteCount > 0)  && (CSEShift == 0)) ? CSEByteCount :
                           ((USEByteCount != 0) && (CSEByteCount == 0))  ? USEByteCount :
                           0; 
       
    
    always @(posedge clk) CSEData <= CSEData_d;
    always @(posedge clk) CSEByteCount = CSEByteCount_d; 
    

endmodule 
