
module tb_CompressAndReturn();

   parameter DATA_BUS_WIDTH_BYTES      = 8; 
   parameter MAX_STREAM_ELEMENT_LENGTH = 34; 
   parameter NUM_STREAM_ELEMENTS       = 1; 

   reg clk;
   reg reset;
   
 
   always  begin clk = 1;   #5;   clk = 0; #5;  end 
   initial begin reset = 1; #200; reset = 0;  end 
 
   reg [(DATA_BUS_WIDTH_BYTES*8-1):0] dataBus;
   reg                                dataValid;
   integer streamLengths[20] = {  
                     30,31,17,23,19,31,30,28,21,31,
                     30,31,17,23,19,31,30,28,21,31}; 
   integer element;
   
   parameter STREAM_ELEMENT_SHIFT_LENGTH = 8;

   // Pass data from the SendStreamData() task to each of these elements which will pass them to our 
   // Compression Module.
   
   reg [MAX_STREAM_ELEMENT_LENGTH-1:0][7:0]    USEStreamerInData      [0:NUM_STREAM_ELEMENTS-1]; 
   reg [$clog2(MAX_STREAM_ELEMENT_LENGTH)-1:0] USEStreamerInByteCount [0:NUM_STREAM_ELEMENTS-1];

   reg [MAX_STREAM_ELEMENT_LENGTH-1:0][7:0]     USEStreamerData       [0:NUM_STREAM_ELEMENTS-1]; 
   reg [$clog2(MAX_STREAM_ELEMENT_LENGTH)-1:0]  USEStreamerByteCount  [0:NUM_STREAM_ELEMENTS-1];
   wire                                         USEStreamerDataTaken  [0:NUM_STREAM_ELEMENTS-1];

   genvar streamer;
   for (streamer = 0; streamer < NUM_STREAM_ELEMENTS; streamer ++) 
     always @(posedge clk) 
     begin 
       integer byteCount;
       if (reset) 
       begin 
          USEStreamerData[streamer] = 0;
          USEStreamerByteCount[streamer] = 0; 
       end
       else
       begin 
         if (USEStreamerInByteCount[streamer])
         begin
           USEStreamerByteCount[streamer] <= USEStreamerInByteCount[streamer];
           USEStreamerData[streamer]      <= USEStreamerInData[streamer]; 
         end 
         else 
         begin
           if (USEStreamerDataTaken[streamer]) 
           begin
             USEStreamerByteCount[streamer] <= 0;
             USEStreamerData[streamer]      <= 'hX; 
           end
         end
       end
     end
    

   task SendDataIn;
   begin 
     integer streamIndex;
      integer dataByte; 
     element = 0; 
     for (streamIndex = 0; streamIndex < 20; streamIndex ++)  
     begin 
       for (dataByte = 0; dataByte < MAX_STREAM_ELEMENT_LENGTH; dataByte++)  
         if (dataByte < streamLengths[streamIndex]) 
           USEStreamerInData[element][dataByte] = dataByte;
         else 
           USEStreamerInData[element][dataByte] = 0;
       USEStreamerInByteCount[element] = streamLengths[streamIndex]; 
       #10;
       USEStreamerInByteCount[element] = 0; 
       #40;
       element = (element + 1) % NUM_STREAM_ELEMENTS;
     end 
   end
   endtask

   task ResetUSEDataInput();
     integer element;
     integer dataByte; 
     for (element = 0; element < NUM_STREAM_ELEMENTS; element++) 
     begin
       for (dataByte = 0; dataByte < MAX_STREAM_ELEMENT_LENGTH*8; dataByte++)  
         USEStreamerInData[element][dataByte] = 0;  
       USEStreamerInByteCount[element] = 0;  
     end
   endtask
   
   
   initial begin
     ResetUSEDataInput(); 
     #200; 
     SendDataIn();  
   end       
 
 
   
 CompressAndReturn 
 #(.NUM_UNCOMPRESSED_ELEMENTS(1))
 CompressAndReturn_inst
 (
   .clk(clk), 
   .reset, 
   .USEDataInput(USEStreamerData), 
   .USEByteCount(USEStreamerByteCount), 
   .USEDataTaken(USEStreamerDataTaken), 

   .dataBus(dataBus), 
   .dataValid(dataValid)
  );



endmodule
