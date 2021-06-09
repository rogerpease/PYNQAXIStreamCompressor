`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08/20/2020 03:59:42 PM
// Design Name: 
// Module Name: tb_StreamElement
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


module tb_StreamElement(    );

   parameter DATA_BUS_WIDTH_BYTES = 8;
   parameter MAX_USE_BYTES=38;
   parameter FIXEDFIELD_LENGTH_BYTES = 17; 
   parameter MAX_VARIABLEFIELD_LENGTH = 16;
   parameter MAX_STREAMELEMENT_LENGTH = MAX_VARIABLEFIELD_LENGTH + FIXEDFIELD_LENGTH_BYTES + 1;
   parameter NUMSTREAMELEMENTS = 4; 

   reg clk, reset;

   reg [(DATA_BUS_WIDTH_BYTES-1):0][7:0] dataIn;
   reg                                   dataInValid;
         
   always begin clk = 1; #5; clk = 0; #5;    end
   

   reg [7:0] TestStreamData[20*MAX_USE_BYTES-1:0];
   integer TestStreamDataLength; 

   typedef struct { 
     reg[7:0] StreamBeginByte;
     integer StreamLength;
   } TestStreamInfoType; 
     
   TestStreamInfoType TestStreams[20];
   TestStreamInfoType ReceivedStreams[20];
   TestStreamInfoType SortedStreams[20];

   reg [DATA_BUS_WIDTH_BYTES-1:0][7:0] dataIn;
   reg                                 dataInValid;
        
   task SendStreamData;
     integer cycleNum, byteNum,dataIndex;
   begin

     dataInValid = 1; 
     dataIndex = 0; 
     for (cycleNum = 0; cycleNum < TestStreamDataLength;cycleNum = cycleNum + DATA_BUS_WIDTH_BYTES)
     begin
       $display("Sending Stream Data Cycle ",cycleNum); 
       for (byteNum = 0; byteNum < DATA_BUS_WIDTH_BYTES; byteNum = byteNum + 1) 
       begin
         dataIn[byteNum] = TestStreamData[dataIndex++];
       end          
       $display("Sent data",$time); 
       #10;
       $display("Relooping"); 
     end
     dataInValid = 0;  
   end   
   endtask
   
   parameter NUM_TESTSTREAMELEMENTS = 200; 

   //
   // Record the data we received from the unit 
   //
   reg [(MAX_STREAMELEMENT_LENGTH * NUM_TESTSTREAMELEMENTS)-1:0][7:0]   CompressedDataReceived; 
   reg [$clog2(MAX_STREAMELEMENT_LENGTH * NUM_TESTSTREAMELEMENTS)-1:0]  CompressedDataReceivedIndex; 

   integer CompressedStreamElementsFound = 0;       
   integer CompressedStreamElementsReceived[20] = {0,0,0,0,0,
                                                   0,0,0,0,0,
                                                   0,0,0,0,0,
                                                   0,0,0,0,0}; 
   
   
   task EvaluateCompressedStreamData;
     integer compressedDataReceivedIndex;  
     integer startStreamIndex;  
     integer endStreamIndex;  
   begin 
     compressedDataReceivedIndex = 0; 
     CompressedStreamElementsFound = 0; 
     
     while ((compressedDataReceivedIndex < CompressedDataReceivedIndex)) 
     begin 
       startStreamIndex = compressedDataReceivedIndex;   
       // Find Delimiter 
       while ((compressedDataReceivedIndex < CompressedDataReceivedIndex) &&
            (CompressedDataReceived[compressedDataReceivedIndex] != 'h2c)) 
         compressedDataReceivedIndex ++;   
       // Find End 
       compressedDataReceivedIndex += FIXEDFIELD_LENGTH_BYTES;   
       if (compressedDataReceivedIndex <= CompressedDataReceivedIndex) 
       begin   
         CompressedStreamElementsReceived[CompressedStreamElementsFound] = compressedDataReceivedIndex - startStreamIndex - 1; 
         CompressedStreamElementsFound ++;  
       end
     end  
   end 
   endtask

   //
   // Capture all Stream Elements as they come in. 
   //
   

   integer numStreamsReceived = 0; 

   task MonitorStreamOut;
     integer streamElementNumber,streamEntryCount;
     integer sortedStreamIndex; 
     integer dataByte; 
     
   begin
     #1;
     CompressedDataReceivedIndex = 0; 
     //
     // Receive data back from the 
     //
     while (numStreamsReceived < 20) 
     begin 
       EvaluateCompressedStreamData();
     end   
     streamEntryCount = 0; 
     // We don't guarantee In-order delivery of streams in this case. 
      
 
     
     $finish("Received all streams Properly");
   end   
   endtask


   ///////////////////////////////////////////////
   //
   //   
   //
   //
   
   always @(posedge clk) 
   begin
     integer dataByte;

     if ((reset == 0) && (dataOutValid)) 
     begin
       for (dataByte = 0; dataByte < DATA_BUS_WIDTH_BYTES; dataByte++) 
       begin
         CompressedDataReceived[CompressedDataReceivedIndex++] = dataOut[dataByte]; 
       end 
     end
   end 
   
   initial   
   begin : SENDSTREAM 
       automatic int debug = 1; 
       automatic int dataIndex = 0; 
       automatic integer streamIndex; 
       automatic integer streamLengths[20] = '{27,21,21,24,31,19,26,23,33,33,
                                               31,19,19,20,29,19,30,19,20,21};
       
       for (streamIndex = 0; streamIndex < 20; streamIndex = streamIndex + 1) 
       begin    
          automatic integer streamLength = streamLengths[streamIndex];
          automatic integer firstFixedByteOffset = streamLength-FIXEDFIELD_LENGTH_BYTES;
          automatic integer streamByteNumber = 0; 
          automatic integer isFixedArea = 0;

          if (streamLength > MAX_STREAMELEMENT_LENGTH)
          begin
             $display("Stream Element Length may not exceed ",MAX_STREAMELEMENT_LENGTH);
             $stop();
          end
          if (streamLength <= FIXEDFIELD_LENGTH_BYTES + 1)
          begin
             $display("Stream Element Length must be more than ",FIXEDFIELD_LENGTH_BYTES + 1);
             $stop();
          end
          TestStreams[streamIndex].StreamLength = streamLength;

          if (debug)
            $display("Stream Element ",streamIndex," started at byte ",dataIndex);

          for (streamByteNumber = 0; streamByteNumber < streamLength;streamByteNumber++) 
          begin
             // Set the delimiter
             if (streamByteNumber == firstFixedByteOffset-1)
             begin 
               TestStreamData[dataIndex] = 'h2C;
               isFixedArea               = 1; 
             end
             else
             begin
               if (isFixedArea)
               begin 
                 // Make 2c the last byte to try to confuse the delimiter parser. 
                 if (streamByteNumber == (streamLength - 1))
                   TestStreamData[dataIndex] = 8'h2c;
                 else 
                   TestStreamData[dataIndex] = 8'hB0 + streamByteNumber-firstFixedByteOffset;
               end
               else
               if (streamByteNumber == 0) // Put the Stream Index as the first byte. 
                 TestStreamData[dataIndex] = streamIndex;
               else
                 TestStreamData[dataIndex] = 8'hA0 + streamByteNumber;
             end             
             if (streamByteNumber == 0)
               TestStreams[streamIndex].StreamBeginByte = TestStreamData[dataIndex];
                                
             dataIndex = dataIndex + 1; 
          end      
       end
       dataInValid = 0; 
       TestStreamDataLength = dataIndex;
       reset = 1;
       $display("Raised Reset"); 
       #200;
       $display("Dropping Reset"); 
       reset = 0;
       #10;
       #1;
       SendStreamData();   
   end 
   
   
  wire [DATA_BUS_WIDTH_BYTES-1:0][7:0] dataOut;
  wire dataOutValid;

  
  
   AXIStreamCompressor  
  #(
   .DATA_BUS_WIDTH_BYTES     (8),
   .NUM_STREAM_ELEMENTS      (4),
   .NUM_COMPRESSION_ELEMENTS (1),
   .MAX_VARIABLEFIELD_LENGTH (16),
   .FIXEDFIELD_LENGTH_BYTES  (11),
   .COMPRESSIONALGORITHM     (0),
   .FIFO_MAX_INGEST_BYTES    (16),
   .MAX_UNCOMPRESSED_BYTES   (34),
   .MAX_COMPRESSED_BYTES     (34),
   .FIFO_DEPTH               (64)
  )
  AXIStreamCompressor_inst
  (
      .clk(clk),
      .reset(reset),
      .dataIn(dataIn),
      .dataInValid(dataInValid),
      .dataOut(dataOut),
      .dataOutValid(dataOutValid)
  );
  
endmodule
