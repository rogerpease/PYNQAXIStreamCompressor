/////////////////////////////////////////////////////////////////////
//
//
//  StreamElement takes in data from data_in. 
//  A token is passed between the different stream elements indicating which one
//  is responsible for taking data from data_in. 
// 
//   Consider a 23-byte Stream element coming in.
//   The delimiter would be at 23-FIXEDFIELD_LENGTH_BYTES (say, 6).
//   Now suppose the token comes in with firstByteOffset set to 3. 
//   
//  First, USEStreamByteFifo[0-7] will take data_in[0-7]... Stream Bytes 0-4 will be in data[3-7]. Rest is ignored. USEStartByte = 3. 
//         USEStreamByteFifo[8-15] will take data_in[0-7]... Stream Bytes 5-12 will be in data[0-7].  Delimiter will be found here and end will be computed. 
//         USEStreamByteFifo[16-23] will take data_in[0-7]... Stream Bytes 13-20 will be in data[0-7].  
//         USEStreamByteFifo[24-31] will take data_in[0-7]... Stream Bytes 21-22 will be in data[0-1]. 
//                           We tell the next stream element to start at byte 2 and pass it the token.
//  Then we shift down by 3. Shift by 2 on the first cycle and 1 on the second. USEStartByte is decremented with each shift. 
//
//  Then we set USEStreamByteLengthOut. Once the data is taken (USEStreamDataTaken==1), USEStreamByteLengthOut 
//    is set to 0 and the module begins expecting more data. 
// 
//  
//

module StreamElement
  #(
    // DATA_BUS_WIDTH must not be larger than (FIXEDFIELD_LENGTH_BYTES + 1)
    parameter DATA_BUS_WIDTH_BYTES=8, // Must be 2**n 
    parameter MAX_VARIABLEFIELD_LENGTH=16,
/* verilator lint_off UNUSED */
    parameter VARIABLEFIELD_DELIMITER=8'h2c,
/* verilator lint_on UNUSED */
    parameter FIXEDFIELD_LENGTH_BYTES= 17,
    parameter MAX_UNCOMPRESSED_BYTES = 34,
    parameter MY_ID=0,                   // Do I hold the token on reset or does someone else? 
    parameter RESET_TOKEN_HOLDER_ID=0    // Do I hold the token on reset or does someone else? 
   )
   ( 
      input clk, 
      input reset, 

      input [(DATA_BUS_WIDTH_BYTES-1):0][7:0] dataIn, 
      input dataInValid, 
   
      input wire tokenIn, 
      input wire [$clog2(DATA_BUS_WIDTH_BYTES)-1:0] firstByteOffsetIn, 

      output wire tokenOut, 
      output wire [$clog2(DATA_BUS_WIDTH_BYTES)-1:0] firstByteOffsetOut, 

      output wire [(MAX_UNCOMPRESSED_BYTES)-1:0][7:0]    USEStreamOut,
      output reg  [$clog2(MAX_UNCOMPRESSED_BYTES)-1:0]   USEStreamByteLengthOut,
      input  wire                                        USEStreamDataTaken
   );  
   

   
    parameter USEStreamState_Empty = 0, 
              USEStreamState_Filling = 1, 
              USEStreamState_Shifting = 2,
              USEStreamState_WaitingForTake = 3; 

    parameter DEEPEST_NUM_BYTES_MESSAGE_COULD_OCCUPY = MAX_USE_BYTES+DATA_BUS_WIDTH_BYTES; 
   

   reg  [$clog2(DEEPEST_NUM_BYTES_MESSAGE_COULD_OCCUPY)-1:0]   USEStreamByteLength;

    reg [$clog2(DATA_BUS_WIDTH_BYTES)-1:0]           USEStartByte;  
    parameter USEBANKSELECTWIDTH = $clog2(DEEPEST_NUM_BYTES_MESSAGE_COULD_OCCUPY);  
    reg [USEBANKSELECTWIDTH-1:0]      USECurrentBank;  

    typedef reg[7:0] byteReg;
    byteReg [(DEEPEST_NUM_BYTES_MESSAGE_COULD_OCCUPY-1):0]   USEStreamByteFifo;
    reg                              [1:0]      USEStreamState;  

    //
    //
    // LOOK AT:
    //   delimiterByteNum to figure out where it thinks the delimiter is. 
    //   streamElementLength to figure out where it thinks the last Byte is. 
    

    reg token;
    reg passToken; 
    parameter MAX_USE_BYTES = MAX_VARIABLEFIELD_LENGTH + FIXEDFIELD_LENGTH_BYTES + 1;

    always @(posedge clk) 
    begin 
      if (reset) 
        begin 
         $display("RESET TOKEN HOLDER ID ",RESET_TOKEN_HOLDER_ID, " MY_ID ", MY_ID); 
          if (RESET_TOKEN_HOLDER_ID == MY_ID) 
          begin
            $display("Stream Element ",MY_ID," I hold the token at reset"); 
            token <= 1;
          end
          else  
            token <= 0;
        end 
      else 
        if (tokenIn) 
        begin 
          $display("Stream Element ",MY_ID," I am getting the token"); 
          token <= 1; 
        end
        else if (passToken)  
        begin
          $display("Stream Element ",MY_ID," I am passing the token"); 
          token <= 0; 
        end
        else 
        begin 
          $display("Stream Element ",MY_ID," Token Status ",token); 
          token <= token; 
        end
    end
 
    assign tokenOut = passToken; 
 

    //////////////////////////////////////////////////////////////////
    // 
    // Each byte in our chain of bytes gets data from two places: 
    //    
    //   *  
    //    

    /* verilator lint_off UNDRIVEN */ 
    logic [DEEPEST_NUM_BYTES_MESSAGE_COULD_OCCUPY-1:0]         delimiterByteArray;
    logic [$clog2(DEEPEST_NUM_BYTES_MESSAGE_COULD_OCCUPY)-1:0] delimiterByteNum; // Defined as the absolute byte position of the delimiter Byte (not the offset from the start).
    /* verilator lint_on UNDRIVEN */ 

    // Build an array of delimiter detectors. 
    // then pick the smallest. 
    integer i;  
    always_comb 
    begin 
      delimiterByteNum = DEEPEST_NUM_BYTES_MESSAGE_COULD_OCCUPY-1; 
      for (i = DEEPEST_NUM_BYTES_MESSAGE_COULD_OCCUPY-1; i>=0; i--) 
        if (delimiterByteArray[i] && (i > USEStartByte)) 
          delimiterByteNum = i[$clog2(DEEPEST_NUM_BYTES_MESSAGE_COULD_OCCUPY)-1:0]; 
    end 

    // Set the bytelength. Either assume it's the max (so we keep accumulating)
    // or set it to FIXEDFIELD_LENGTH_BYTES past the delimiter. 
    // If VARIABLEFIELD is 10, delimiter will be at byte 10.
    // whch means chain will end at byte 27
    
    
    reg  [$clog2(MAX_USE_BYTES)-1:0] USEStreamComputedByteLength;  
     
    /* verilator lint_off WIDTH */
    assign USEStreamComputedByteLength = FIXEDFIELD_LENGTH_BYTES[$clog2(MAX_USE_BYTES)-1:0] + 
                                         delimiterByteNum[$clog2(MAX_USE_BYTES)-1:0] + {6'b000001} - {3'b000, USEStartByte};  



    always @(posedge clk) USEStreamByteLength <= (delimiterByteNum == 0) ? MAX_USE_BYTES : USEStreamComputedByteLength; 

    /* verilator lint_on WIDTH */

    // Generate the output  
    genvar streamOutByte;
    for (streamOutByte = 0; streamOutByte < MAX_USE_BYTES; streamOutByte = streamOutByte + 1) begin : outputBytes
        assign USEStreamOut[streamOutByte] = USEStreamByteFifo[streamOutByte];
    end

   //
   // This is the byte position of the last byte in the message, regardless of the number of bytes we may need to shift. 
   //
   wire [6:0] AbsoluteLastByteInMessage;
   assign     AbsoluteLastByteInMessage = {1'b0,delimiterByteNum[4:0]} + FIXEDFIELD_LENGTH_BYTES[6:0]; 
   
   /////////////////////////////////////////////////////////////////////////////////////////////////
   //
   // Check each byte to see if it is the delimiter between the variable and fixed fields. 
   // Put the result in an array then pick the lowest result. 
   //
   wire latchData;
   wire latchDataToSecondBank;

   assign latchData = (token) && (dataInValid); 
   assign latchDataToSecondBank = tokenIn && (firstByteOffsetIn != 0);      

   genvar BI; 
     for (BI = 0; BI < MAX_VARIABLEFIELD_LENGTH+ DATA_BUS_WIDTH_BYTES; BI = BI + 1) begin : delimiterByteArrayBuilder 
       assign delimiterByteArray[BI] = (USEStreamByteFifo[BI][7:0] == 'h2c) ? 1 : 0;
     end


   // Rules are pretty simple:
   // Each byte should be doing one of three things:
   //   Capturing it's associated datain. 
   //   Shifting down by 1,2, or 4  
   //   Holding data 

   genvar streamByteNum; 

   for (streamByteNum = 0; streamByteNum < DEEPEST_NUM_BYTES_MESSAGE_COULD_OCCUPY; streamByteNum = streamByteNum + 1)             
   begin : dataInCaptureBlock 
     wire [7:0] dataInSelection; 
     wire [7:0] dataShiftSelection; 
     wire latchCurrentBank; 
     wire [USEBANKSELECTWIDTH-1:0] streamBankNum; 
     assign dataInSelection = dataIn[streamByteNum%DATA_BUS_WIDTH_BYTES]; 

     assign dataShiftSelection = (USEStartByte[2]) ? USEStreamByteFifo[(streamByteNum+4) % DEEPEST_NUM_BYTES_MESSAGE_COULD_OCCUPY]: 
                                 (USEStartByte[1]) ? USEStreamByteFifo[(streamByteNum+2) % DEEPEST_NUM_BYTES_MESSAGE_COULD_OCCUPY]: 
                                 (USEStartByte[0]) ? USEStreamByteFifo[(streamByteNum+1) % DEEPEST_NUM_BYTES_MESSAGE_COULD_OCCUPY]: 
                                 USEStreamByteFifo[streamByteNum]; 

     assign streamBankNum = (streamByteNum >> 3); 

     assign latchCurrentBank = 
           (((!token) && (!tokenIn) && (USEStreamState == USEStreamState_Empty)) ||   // We're empty 
            (tokenIn && (firstByteOffsetIn != 0) && (streamBankNum == 1))  || 
            (tokenIn && (firstByteOffsetIn == 0) && (streamBankNum == 0))  || 
            (token && (streamBankNum == USECurrentBank)));

     always @(posedge clk) 
       if (latchCurrentBank) 
         USEStreamByteFifo[streamByteNum] <= dataIn[streamByteNum%DATA_BUS_WIDTH_BYTES]; 
       else if (USEStreamState == USEStreamState_Shifting) 
         USEStreamByteFifo[streamByteNum] <= dataShiftSelection;
       else 
         USEStreamByteFifo[streamByteNum] <= USEStreamByteFifo[streamByteNum];
   end
        
   /* verilator lint_off WIDTH */  
   assign firstByteOffsetOut = (USEStreamByteLength + USEStartByte) % DATA_BUS_WIDTH_BYTES;
   /* verilator lint_on WIDTH */  
 

    reg [6:0] someNumber = 10; 
    //
    // Now for the specific controller. 
    //
    always @(posedge clk) 
    begin 
      integer AbsoluteLastByteIWillHave = 0; 
      if (reset) 
      begin 
        USEStreamState         <= USEStreamState_Empty; 
        USEStartByte           <= 0; 
        USEStreamByteLengthOut <= 0;
        USECurrentBank         <= 0; 
        passToken              <= 0;
      end
      else 
      begin    
        passToken <= 0;      
        someNumber = 10;
        
        if (USEStreamState == USEStreamState_Empty) 
        begin
           $display("Model: Stream Element ", MY_ID," in Empty"); 
           if (tokenIn)
              USEStartByte   <= firstByteOffsetIn;

           // Preparing for the *next* cycle. 
           if ((dataInValid) && ((tokenIn) || (token))) 
           begin
              $display("Model: Stream Element ", MY_ID," Transitioning to Filling FirstByteOffsetIn", firstByteOffsetIn); 
              USEStreamState <= USEStreamState_Filling; 
              if ((token) || (firstByteOffsetIn == 0)) 
              begin
                USECurrentBank <= 1; 
              end
              else 
              begin
                USECurrentBank <= 2;
              end
            end
        end
        else if (USEStreamState == USEStreamState_Filling) 
        begin
           AbsoluteLastByteIWillHave = $unsigned(USECurrentBank + 1) *DATA_BUS_WIDTH_BYTES-1; 
           if (latchData) begin     
             $display("Model: Stream Element ", MY_ID," Filling " , USECurrentBank , " latchdata high " );
             $display("Model: Stream Element ", MY_ID," USEStartByte ",USEStartByte, " USEStreamByteLength ", USEStreamByteLength,  
                      " AbsoluteLastByteIWillHave ", AbsoluteLastByteIWillHave, 
                      " AbsoluteLastByteInMessage ", AbsoluteLastByteInMessage, " ", someNumber );

             USECurrentBank <= USECurrentBank + 1;  
             // If we have the data we need. 
    /* verilator lint_off WIDTH */
             if (AbsoluteLastByteIWillHave >= AbsoluteLastByteInMessage) 
             begin
               passToken <= 1; 
               if (USEStartByte > 0)  // If nothing to shift go straight to 
               begin
                 $display("Model: Stream Element ", MY_ID," passing token and sending to Shifting state." );
                 USEStreamState <= USEStreamState_Shifting; 
               end 
               else 
               begin 
                 $display("Model: Stream Element ", MY_ID," passing token and sending to waiting state." );
                 USEStreamState <= USEStreamState_WaitingForTake; 
                 USEStreamByteLengthOut <= USEStreamByteLength;
               end
               //
               // If I started at byte 3 and took in a 30 byte message 
               // my new first byte would be at 33%8 = 1 
               //
             end
             else 
               $display("Model: Stream Element ", MY_ID," still not enough data." );
    /* verilator lint_on WIDTH */
           end
           else 
             $display("Model: Stream Element ", MY_ID," still not enough data (latchdata low)." );
        end 
        else if (USEStreamState == USEStreamState_Shifting) 
        begin
            $display("Model: Stream Element ", MY_ID," Shifting state." );
    /* verilator lint_off WIDTH */
            if (USEStartByte >= 4) 
            begin 
               USEStartByte     <= USEStartByte - 4; 
            end
            else
            if (USEStartByte[1] == 1) 
                USEStartByte    <= USEStartByte - 2;
            else
            if (USEStartByte[0] == 1) 
               USEStartByte     <= USEStartByte - 1;
            else             
            begin 
              USEStreamState         <= USEStreamState_WaitingForTake;
              USECurrentBank         <= 0; 
              USEStreamByteLengthOut <= USEStreamByteLength;
            end
    /* verilator lint_on WIDTH */
        end
        else if (USEStreamState == USEStreamState_WaitingForTake) 
        begin       
    /* verilator lint_off WIDTH */
          $display("Model: Stream Element ", MY_ID," started in Filling " + USECurrentBank + " latchdata " );
    /* verilator lint_on WIDTH */
          if (USEStreamDataTaken == 1) 
          begin
             USEStreamByteLengthOut <= 0;
             USEStreamState         <= USEStreamState_Empty;
             USECurrentBank         <= 0;
          end   
        end
      end
    end

 
      always @(negedge clk) 
      begin : debugTask 
       integer byteNum; 
       $write ("Model: Stream Element ID ",MY_ID, " ");
       for (byteNum= DEEPEST_NUM_BYTES_MESSAGE_COULD_OCCUPY-1; byteNum >= 0; byteNum = byteNum - 1) 
        begin 
          $write("%h",USEStreamByteFifo[byteNum]);
          if (((byteNum % 4) == 0) && (byteNum % 8 != 0)) $write("_");
          if ((byteNum % 8) == 0) $write(" ");
        end 
        $write(" Start Byte %h ",USEStartByte);
        $write(" USEStreamState  ",USEStreamState," USECurrentBank ",USECurrentBank," Token ", token," AbsoluteLastByteInMessage ",AbsoluteLastByteInMessage," ");
        $write(" DelimiterByteNum ",delimiterByteNum ,"\n"); 
       end 
    
    
    
endmodule
    
