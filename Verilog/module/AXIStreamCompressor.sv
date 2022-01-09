`timescale 1ns/1ps
//
//   Top-level module for AXI Stream Compressor. 
// 
//


/* verilator lint_off WIDTH */ 

module AXIStreamCompressor
  #(
   parameter DATA_BUS_WIDTH_BYTES     = 8,
   parameter NUM_STREAM_ELEMENTS      = 4,
   parameter NUM_COMPRESSION_ELEMENTS = 1,
   parameter MAX_VARIABLEFIELD_LENGTH = 16,
   parameter FIXEDFIELD_LENGTH_BYTES  = 17,
   parameter COMPRESSIONALGORITHM     = 0,
   parameter FIFO_MAX_INGEST_BYTES    = 16,
   parameter MAX_UNCOMPRESSED_BYTES   = 34,
   parameter MAX_COMPRESSED_BYTES     = 34,
   parameter FIFO_DEPTH               = 64
  )
  ( 
      input dataIn_clk, 
      input dataIn_aresetn,
      input wire  [DATA_BUS_WIDTH_BYTES-1:0][7:0] dataIn_tdata,
      input wire  dataIn_tvalid,
      input wire  [DATA_BUS_WIDTH_BYTES-1:0] dataIn_tstrb,
      input wire  [DATA_BUS_WIDTH_BYTES-1:0] dataIn_tlast,
      output wire  dataIn_tready,

      input dataOut_clk, 
      input dataOut_aresetn,
      output wire [DATA_BUS_WIDTH_BYTES-1:0][7:0] dataOut_tdata, 
      output wire dataOut_tvalid,
      output wire [DATA_BUS_WIDTH_BYTES-1:0] dataOut_tstrb,
      input  wire dataOut_tready,
      output wire dataOut_tlast

  );

  assign  dataIn_tready  = 1;
  assign  dataOut_tstrb  = 8'b11111111;


  // 
  // For routing between the Stream Capture Elements and the Compression Elements. 
  //    USE = "Uncompressed Stream Element"
  // 

  wire [MAX_UNCOMPRESSED_BYTES-1:0][7:0]     USEStreamOuts       [NUM_STREAM_ELEMENTS-1:0];
  wire [$clog2(MAX_UNCOMPRESSED_BYTES)-1:0]  USEStreamByteCounts [NUM_STREAM_ELEMENTS-1:0];
  wire [$clog2(MAX_UNCOMPRESSED_BYTES)-1:0]  USEStreamLasts      [NUM_STREAM_ELEMENTS-1:0];
  reg                                        USEStreamDataTakens [NUM_STREAM_ELEMENTS-1:0];

  wire                                       tokenChain          [NUM_STREAM_ELEMENTS-1:0]; 
  wire [$clog2(DATA_BUS_WIDTH_BYTES)-1:0]    firstByteOffset     [NUM_STREAM_ELEMENTS-1:0];
  
  genvar streamElementIndex;
  for (streamElementIndex = 0; streamElementIndex < NUM_STREAM_ELEMENTS; streamElementIndex++)
  begin
   StreamElement 
   #(
     .DATA_BUS_WIDTH_BYTES(DATA_BUS_WIDTH_BYTES),
     .VARIABLEFIELD_DELIMITER('h2c),
     .MY_ID(streamElementIndex),         // Do I hold the token on reset or does someone else?
     .RESET_TOKEN_HOLDER_ID(0),    // Do I hold the token on reset or does someone else?
     .FIXEDFIELD_LENGTH_BYTES(FIXEDFIELD_LENGTH_BYTES),
     .MAX_VARIABLEFIELD_LENGTH(MAX_VARIABLEFIELD_LENGTH),
     .MAX_UNCOMPRESSED_BYTES(MAX_UNCOMPRESSED_BYTES)
   ) 
   StreamElement_inst
   (
      .clk(dataIn_clk),
      .reset(dataIn_aresetn),

      .dataIn (dataIn_tdata),
      .dataInValid(dataIn_tvalid),
      .dataIn_tlast(dataIn_tlast),

      .tokenIn(tokenChain[streamElementIndex]),
      .firstByteOffsetIn(firstByteOffset[streamElementIndex]),

      .tokenOut(tokenChain[(streamElementIndex+1)%NUM_STREAM_ELEMENTS]),
      .firstByteOffsetOut(firstByteOffset[(streamElementIndex+1)%NUM_STREAM_ELEMENTS]),

      .USEStreamOut(USEStreamOuts[streamElementIndex]),
      .USEStreamByteLengthOut(USEStreamByteCounts[streamElementIndex]),
      .USEStreamLast(USEStreamLasts[streamElementIndex]),
      .USEStreamDataTaken(USEStreamDataTakens[streamElementIndex])
   );

  end 

   always @(negedge dataIn_clk)  
   begin 
     $display("AXIStreamCompressor TokenChain: ",tokenChain[3],
                                                 tokenChain[2],
                                                 tokenChain[1],
                                                 tokenChain[0],
                                                 " firstByteOffset ", 
                                                 firstByteOffset[3],
                                                 firstByteOffset[2],
                                                 firstByteOffset[1],
                                                 firstByteOffset[0]); 

     $display("AXIStreamCompressor StreamElementInUse: ",StreamElementInUse); 
   end 


   //
   // TODO: Add a second compression module to improve bandwidth. 
   //

   reg [1:0] StreamElementInUse;

   always_ff @(posedge dataIn_clk) 
   begin 
     if (dataIn_aresetn)
     begin  
       StreamElementInUse =  0;
     end 
     else
     begin 
       $display("AXIStreamCompressor Compressor Mux CSEByteCount: ",CSEByteCount, "(d) CSEShiftFromOutFIFO ",CSEShiftFromOutFIFO,
                "(d) USEByteCountMuxedToCompression ",USEByteCountMuxedToCompression,"(d)"); 
       USEStreamDataTakens[0] = 0;
       USEStreamDataTakens[1] = 0;
       USEStreamDataTakens[2] = 0;
       USEStreamDataTakens[3] = 0;
       if (
        ((CSEByteCount == 0) || ((CSEByteCount <= FIFO_MAX_INGEST_BYTES) && (CSEShiftFromOutFIFO))) && 
         (USEByteCountMuxedToCompression > 0) // There was data here in the first place. 
        )
       begin 
          USEStreamDataTakens[StreamElementInUse] = 1;
          $display("AXIStreamCompressor Compressor Mux: Stream Element data taken on: ",StreamElementInUse);
          StreamElementInUse = (StreamElementInUse+1) % NUM_STREAM_ELEMENTS;
          $display("AXIStreamCompressor Compressor Mux: Stream Element being updated to (net cycle):",StreamElementInUse);
        end 
      end 
    end 

    wire   [MAX_UNCOMPRESSED_BYTES-1:0][7:0]  USEDataMuxedToCompression; 
    wire   [7:0] USEByteCountMuxedToCompression; 
    assign USEDataMuxedToCompression      = USEStreamOuts[StreamElementInUse];  
    assign USEByteCountMuxedToCompression = USEStreamByteCounts[StreamElementInUse];  

 
    wire [MAX_UNCOMPRESSED_BYTES-1:0][7:0]      CSEDataToMux; 
    wire [$clog2(MAX_UNCOMPRESSED_BYTES*8)-1:0] CSEByteCount; 
    wire                                        CSEShiftFromOutFIFO; 
   
    CompressionModule 
    #(.SHIFTLENGTH_BYTES(FIFO_MAX_INGEST_BYTES))  
    CompressionModule_inst
      (.clk(dataIn_clk),
       .reset(dataIn_aresetn),

       .USEData     (USEDataMuxedToCompression), 
       .USEByteCount(USEByteCountMuxedToCompression), 

       .CSEData     (CSEDataToMux), 
       .CSEByteCount(CSEByteCount), 
       .CSEShift    (CSEShiftFromOutFIFO));


   always @(posedge dataIn_clk) 
   begin 
     $display("CSEDataToReturnFifoe",CSEDataToMux," ByteCount: ",CSEByteCount," Shift Out ",CSEShiftFromOutFIFO);
   end 

   ReturnFIFO  
   #(
    .NUM_UNCOMPRESSED_ELEMENTS(MAX_UNCOMPRESSED_BYTES),
    .NUM_BYTES_INPUT_WIDTH(16),
    .FIFO_DEPTH(64),
    .NUM_BYTES_OUTPUT_WIDTH(8)
   )
   ReturnFIFO_inst
   (
   .clk(dataOut_clk), 
   .reset(dataOut_aresetn), 
   .dataIn(CSEDataToMux),
   .dataInBytesValid(CSEByteCount),
   .dataInShift(CSEShiftFromOutFIFO), 
   .endOfStream(0),
   .dataOut(dataOut_tdata),
   .dataOutValid(dataOut_tvalid),
   .dataOut_tready(dataOut_tready)
   );


endmodule 
/* verilator lint_on WIDTH */ 
