#include <iostream>
#include "VAXIStreamCompressor.h"
#include <memory> 
#include <sstream> 

#define MAX_WORDLIST_LEN      (34)
#define DELIMITER             (0x2c)
#define NUMBYTESPASTDELIMITER (17)
#define NUMSTREAMLENGTHS      (20) 
#define FIFO_OUT_WIDTH_BYTES  (8)   // Width of FIFO in Bytes


class NextStreamDataInClass  {
  public:
   unsigned int NextByteOrWord; 
   char LastByteOrWord; 

};

#define BYTE1(x) ((x>>8)&0xFF)
#define BYTE0(x) ((x>>0)&0xFF)

unsigned char myBaseballData[] = {
         //                     AVG                     AB                   H                          BB 
         'A',' ', 'R' ,'F',0x2c,BYTE1(344),BYTE0(344),BYTE1(512),BYTE0(512),BYTE1(212),BYTE0(212), BYTE1(100),BYTE0(100),
         //                 2B                 3B                  HR                   K       SB 
                       BYTE1(30),BYTE0(30),BYTE1(512),BYTE0(512),BYTE1(61),BYTE0(61), 0xFF,0xFF,0xFF,
         'B','L','e','f','t', ' ' ,'F','i','e','l','d','e','r',0x2c, BYTE1(200),BYTE0(200),BYTE1(512),BYTE0(512),BYTE1(212),BYTE0(212), BYTE1(100),BYTE0(100),
                                                                 BYTE1(30),BYTE0(30),BYTE1(512),BYTE0(512),BYTE1(61),BYTE0(61), 0xFF,0xFF,0xFF,
         'C','e','n','t','e','r',' ' ,'F','i','e','l','d','e','r',0x2c,BYTE1(344),BYTE0(344),BYTE1(512),BYTE0(512),BYTE1(212),BYTE0(212), BYTE1(100),BYTE0(100),
                                                                 BYTE1(30),BYTE0(30),BYTE1(512),BYTE0(512),BYTE1(61),BYTE0(61), 0xEE,0xEE,0xEE,
         'D','a','t','c','h','e','r',' ' ,'C',0x2c,BYTE1(344),BYTE0(344),BYTE1(512),BYTE0(512),BYTE1(212),BYTE0(212), BYTE1(100),BYTE0(100),
                                                                 BYTE1(30),BYTE0(30),BYTE1(512),BYTE0(512),BYTE1(61),BYTE0(61), 0xEE,0xEE,0xEE,
         'E','i','t','c','h','e','r',' ' ,'D',0x2c,BYTE1(344),BYTE0(344),BYTE1(512),BYTE0(512),BYTE1(212),BYTE0(212), BYTE1(100),BYTE0(100),
                                                                 BYTE1(30),BYTE0(30),BYTE1(512),BYTE0(512),BYTE1(61),BYTE0(61), 0xEE,0xEE,0xEE,
         'F','i','r','s','t',' ','B','a' ,'s','e',0x2c,BYTE1(344),BYTE0(344),BYTE1(512),BYTE0(512),BYTE1(212),BYTE0(212), BYTE1(100),BYTE0(100),
                                                                 BYTE1(30),BYTE0(30),BYTE1(512),BYTE0(512),BYTE1(61),BYTE0(61), 0xEE,0xEE,0xEE,
         0xFF,0xEE,0xEE,0xDD,0x0};

class StreamCompressorDataClass
{ 

  int totalNumStreamBytes; 
  unsigned char * StreamBytes;  

  int byteIndex; 
  
  void InitializeBasicDataset()
  {
      const char StreamLengths[] = { 23,19,21,34,21,22,31,31,19,22, 31,19,19,21,33,22,22,23,23,24 }; 

      totalNumStreamBytes  = 0; 

      for (int i = 0; i < NUMSTREAMLENGTHS;i++) 
        totalNumStreamBytes += StreamLengths[i]; 
      assert(totalNumStreamBytes > 0); 

      StreamBytes = (unsigned char*) malloc(totalNumStreamBytes);
      assert(StreamBytes != nullptr); 

      int streamLengthIndex = 0;  
      int streamByteIndex = 0;  

      //
      // Initialize stream data. Given the number of streamLengths, compute where the delimiter token will be. 
      //   Then start Filling in bytes.
      // 
      //  A full stream should look like (lowest byte to the left): 
      //           ID Len                Delim
      //           00  16  02  03  04  05  2C  A0 A1 A2 ... B0
      //
      // And the IDs keep incrementing (2c is skipped) 
      // 
      while (streamLengthIndex < NUMSTREAMLENGTHS) 
      {
         
         int streamLength = StreamLengths[streamLengthIndex]; 
         int delimiterBytePosition = streamLength - NUMBYTESPASTDELIMITER - 1; 
         assert(delimiterBytePosition > 0); 
         int streamByteWithinStream = 0;
         while (streamByteWithinStream < streamLength)
         {
           if (streamByteWithinStream == delimiterBytePosition)         // Delimiter 
              *(StreamBytes + streamByteIndex) = DELIMITER;
           else if (streamByteWithinStream == 0)                    // First Byte
              *(StreamBytes + streamByteIndex) = streamLengthIndex;
           else if (streamByteWithinStream == 1)  
              *(StreamBytes + streamByteIndex) = streamLength;
           else if (streamByteWithinStream < delimiterBytePosition) // Pre-delimiter
              *(StreamBytes + streamByteIndex) = streamByteWithinStream;
           else                                                 // Post Delimiter
              *(StreamBytes + streamByteIndex) = (0xA<<4) + streamByteWithinStream-delimiterBytePosition-1; 
           
           streamByteWithinStream++; 
           streamByteIndex++; 
         } 
         streamLengthIndex ++; 
      }
      assert (*(StreamBytes + 5)  == DELIMITER); 
      assert (*(StreamBytes + 23) ==         1); // Stream ID of second stream.   
      assert (*(StreamBytes + 24) ==      0x2c); // Delimiter Position of 2nd stream.
      byteIndex = 0; 

  }

  void InitializeBaseballDataSet()
  {
    StreamBytes = &myBaseballData[0]; 
    int len = 0; 
    while (!(
             (*(StreamBytes+len) == 0xFF) && (*(StreamBytes+len+1) == 0xEE) && (*(StreamBytes+len+2) == 0xEE) && (*(StreamBytes+len+3) == 0xDD)
          ))
    {
      len++;
    } 
    byteIndex = 0; 
    totalNumStreamBytes = len; 
    printf("Total Number Stream Bytes %d\n",totalNumStreamBytes); 
    printf("First stream byte %d\n",*(StreamBytes)); 
  }

  public: 
    // First BytePosition is what is passed to the 
    StreamCompressorDataClass(int dataset)
    { 
      if (dataset == 0)  { InitializeBasicDataset(); } 
      else if (dataset == 1)  { InitializeBaseballDataSet(); } 
      else { printf("Bad dataset!"); exit(1); } 
      printf("TotalNumStreamBytes %d\n",totalNumStreamBytes); 

 

    }

    NextStreamDataInClass GetNextByte()
    {
      NextStreamDataInClass result; 
      result.NextByteOrWord = (byteIndex < totalNumStreamBytes) ? *(StreamBytes + byteIndex) : 0xFF;  
      result.LastByteOrWord = (byteIndex < totalNumStreamBytes) ? 0:1;
      byteIndex++; 
      return result; 
    } 
    NextStreamDataInClass GetNextWord()
    {
       NextStreamDataInClass streamByte; 
       NextStreamDataInClass result; 
       streamByte = GetNextByte(); result.NextByteOrWord  =  streamByte.NextByteOrWord;
       streamByte = GetNextByte(); result.NextByteOrWord |= (streamByte.NextByteOrWord << 8);
       streamByte = GetNextByte(); result.NextByteOrWord |= (streamByte.NextByteOrWord << 16);
       streamByte = GetNextByte(); result.NextByteOrWord |= (streamByte.NextByteOrWord << 24);
       result.LastByteOrWord = streamByte.LastByteOrWord; 
       return result; 
    }  
    void ResetByteIndex() { byteIndex = 0; } 

}; 


//
// Drive a stream element and compare results. 
//
//

class AXIStreamCompressorWrapperClass : VAXIStreamCompressor 
{

  public:
  bool debug = true;  
  
  AXIStreamCompressorWrapperClass () 
  {  
    const std::unique_ptr<VerilatedContext> contextp{new VerilatedContext};
    VAXIStreamCompressor{contextp.get(), "VAXIStreamCompressor"};
  } 

  void ToggleClock() { 
     this->clk = 1; this->eval(); this->clk = 0; this->eval(); 
     if (debug) printf("Clock Toggled\n"); 
    
  } 
  void Reset() { this->reset = 1; ToggleClock(); ToggleClock(); this->reset = 0; ToggleClock(); } 


  bool DriveStreamCycleAndCheckResult(int dataset) 
  {
      ToggleClock(); 

      StreamCompressorDataClass Data(dataset);

      NextStreamDataInClass streamDataObject; 
      streamDataObject.LastByteOrWord = false; 

      std::vector<unsigned long int> sentData; 
      std::vector<unsigned long int> capturedData; 

      while (streamDataObject.LastByteOrWord == false)
      { 

        streamDataObject = Data.GetNextWord();
        this->dataIn     = streamDataObject.NextByteOrWord;  
        streamDataObject = Data.GetNextWord();
        this->dataIn    |= ((unsigned long int) streamDataObject.NextByteOrWord << 32);  
        this->dataInValid = 1;

        sentData.push_back(this->dataIn); 
        std::cout << "Test: DataIn: " <<  std::hex << this->dataIn << std::dec << " Data In Valid " << (int) this->dataInValid << std::endl;

        ToggleClock(); 
        if (this->dataOutValid) 
        {
          capturedData.push_back(this->dataOut); 
          if (debug) printf("DATA OUT: %lx\n",this->dataOut);  
        } 
      }
      // flush for 15 more cycles. 
      int flushCycle = 20;
      while (flushCycle>0)
      {
         this->dataInValid = 0; 
         ToggleClock(); 
         if (this->dataOutValid) 
         {
           capturedData.push_back(this->dataOut); 
           if (debug) printf("DATA OUT: %lx\n",this->dataOut);  
         } 
         flushCycle--;
      }

      //
      // The out fifo only outputs elements 8 at a time, so if there are 7 elements left
      // we won't get them. 
      //
      int numElementsToCompare = std::max(sentData.size(),capturedData.size()); 
          numElementsToCompare -= numElementsToCompare % FIFO_OUT_WIDTH_BYTES; 

      // Sanity check our Stream elements index. 
      assert (numElementsToCompare > 10);

      bool fail = false; 

      std::stringstream debugString; 

      for (int index = 0; index < numElementsToCompare; index++)
      { 
         if (index < sentData.size())  { debugString << std::hex << sentData[index] << std::dec << " ";  }
         else                          { fail = true; debugString << "----------------"; } 
         if (index < capturedData.size())  { debugString << std::hex << capturedData[index] << std::dec << " ";  }
         else                          { fail = true; debugString << "----------------"; } 
         if (sentData[index] != capturedData[index]) { debugString << " MISMATCH"; fail = true; } 
         debugString << std::endl; 
      } 

      this->dataInValid = 0;

      if (fail) { std::cout << debugString.str(); return false;   } 
      else      { return true;    } 
  } 
};


int main(int argc, char **argv) 
{
   int arg = 0; 
   int dataset = 0; 
   while (arg < argc)
   { 
     if (std::string(argv[arg]) == std::string("--dataset"))
       dataset = atoi(argv[++arg]);
     arg ++;
   }
   const bool debug = false; 

   printf("FifoOutWidthBytes %d\n", (FIFO_OUT_WIDTH_BYTES));   // Width of FIFO in Bytes

   AXIStreamCompressorWrapperClass AXIStreamCompressorWrapper; 
   AXIStreamCompressorWrapper.Reset();  
   assert (AXIStreamCompressorWrapper.DriveStreamCycleAndCheckResult(dataset));  
   std::cout << "Test: ************************************** PASS!!!!  ************************************" <<std::endl;       

}
