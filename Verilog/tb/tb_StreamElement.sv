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

   reg [(DATA_BUS_WIDTH_BYTES*8-1):0] dataIn;
   reg dataInValid;
         
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

        
   task SendStreamData;
     integer cycleNum, byteNum,dataIndex;
   begin

     dataInValid = 1; 
     dataIndex = 0; 
     for (cycleNum = 0; cycleNum < TestStreamDataLength;cycleNum = cycleNum + DATA_BUS_WIDTH_BYTES)
     begin
       for (byteNum = 0; byteNum < DATA_BUS_WIDTH_BYTES; byteNum = byteNum + 1) 
       begin
         dataIn[(byteNum*8+7)-:8] = TestStreamData[dataIndex];
         dataIndex = dataIndex + 1;
       end          
       #10;
     end
     dataInValid = 0;  
   end   
   endtask
   
   
   // capture all streams as they come in. 
   task MonitorStreamOut;
     integer streamElementNumber,streamEntryCount;
     integer sortedStreamIndex; 
   begin
     #1;
     streamElementNumber = 0; 
     streamEntryCount = 0; 
     while (streamEntryCount < 20)
     begin
       USEStreamAcks = 0;
       if ((USEStreamReadys != 0) && (reset == 0)) 
       begin
         streamElementNumber = 0; 
         while (streamElementNumber < NUMSTREAMELEMENTS)
         begin
             if (USEStreamReadys[streamElementNumber] == 1) 
             begin 
               USEStreamAcks[streamElementNumber] = 1; 
               ReceivedStreams[streamEntryCount].StreamBeginByte   = USEStreamOuts[streamElementNumber][7:0];
               ReceivedStreams[streamEntryCount].StreamLength     =  USEStreamByteCounts[streamElementNumber];
               streamEntryCount ++; 
               streamElementNumber = NUMSTREAMELEMENTS;  
             end    
             else 
             begin
               USEStreamAcks[streamElementNumber] = 0;
               streamElementNumber ++;
             end
         end             
       end
       #10;
     end 
     streamEntryCount = 0; 
     //Now, Sort the streams by Begin Byte. 
     while (streamEntryCount < 20) 
     begin
         sortedStreamIndex = ReceivedStreams[streamEntryCount].StreamBeginByte;
         SortedStreams[sortedStreamIndex].StreamBeginByte = sortedStreamIndex;
         SortedStreams[sortedStreamIndex].StreamLength = ReceivedStreams[streamEntryCount].StreamLength;
         streamEntryCount ++; 
     end
     // And make sure everything matches. 

     streamEntryCount = 0; 
     //Now, Sort the streams by Begin Byte. 
     while (streamEntryCount < 20) 
     begin
       assert(SortedStreams[streamEntryCount].StreamLength == TestStreams[streamEntryCount].StreamLength)
       else 
       begin
         $display("Stream ",streamEntryCount, " expected length ", TestStreams[streamEntryCount].StreamLength,
                   " actual ",SortedStreams[sortedStreamIndex].StreamLength);
         $stop();         
       end
       streamEntryCount ++; 
     end
     
     $finish("Received all streams Properly");
   end   
   endtask
   
   initial begin
     @(negedge reset);
     MonitorStreamOut();
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
             if (streamByteNumber == streamLength-FIXEDFIELD_LENGTH_BYTES-1 )
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
                   TestStreamData[dataIndex] = 8'hB0 + streamByteNumber;
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
       #200;
       reset = 0;
       #10;
       #1;
       SendStreamData();   
   end 
  
  
      
  reg [NUMSTREAMELEMENTS-1:0] tokenChain;
  wire [2:0] firstByteOffset[5:0];        
  reg [NUMSTREAMELEMENTS-1:0][MAX_USE_BYTES*8-1:0] USEStreamOuts; 
  reg [NUMSTREAMELEMENTS-1:0][5:0] USEStreamByteCounts; 
  reg [NUMSTREAMELEMENTS-1:0] USEStreamReadys;
  reg [NUMSTREAMELEMENTS-1:0] USEStreamAcks;

      
  genvar streamElement;
  for (streamElement = 0; streamElement < NUMSTREAMELEMENTS; streamElement++)     
  begin 
   defparam StreamElement_inst.DATA_BUS_WIDTH_BYTES = DATA_BUS_WIDTH_BYTES;
   defparam StreamElement_inst.VARIABLEFIELD_DELIMITER='h2c;
   defparam StreamElement_inst.MY_ID=streamElement;    // Do I hold the token on reset or does someone else? 
   defparam StreamElement_inst.RESET_TOKEN_HOLDER_ID=0;    // Do I hold the token on reset or does someone else? 
   defparam StreamElement_inst.FIXEDFIELD_LENGTH_BYTES=FIXEDFIELD_LENGTH_BYTES;
   defparam StreamElement_inst.MAX_VARIABLEFIELD_LENGTH=MAX_VARIABLEFIELD_LENGTH;

   StreamElement StreamElement_inst 
   ( 
      .clk(clk), 
      .reset(reset), 

      .dataIn (dataIn),
      .dataInValid(dataInValid),  
        
      .tokenIn(tokenChain[streamElement]), 
      .firstByteOffsetIn(firstByteOffset[streamElement]), 

      .tokenOut(tokenChain[(streamElement+1)%NUMSTREAMELEMENTS]), 
      .firstByteOffsetOut(firstByteOffset[(streamElement+1)%NUMSTREAMELEMENTS]), 

      .USEStreamOut(USEStreamOuts[streamElement]),
      .USEStreamByteLengthOut(USEStreamByteCounts[streamElement]),
      .USEStreamReadyOut(USEStreamReadys[streamElement]),
      .USEStreamReadyAck(USEStreamAcks[streamElement])
   ); 
   end
   
   
   
endmodule
