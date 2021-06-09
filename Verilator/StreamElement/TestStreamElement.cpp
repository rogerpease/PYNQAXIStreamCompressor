#include <iostream>
#include "VStreamElement.h"
#include <memory> 

#define MAX_WORDLIST_LEN      (34)
#define DELIMITER             (0x2c)
#define NUMBYTESPASTDELIMITER (17)
#define PRECHUNKFILLER        (0xDD)
#define POSTCHUNKFILLER       (0xEE)


// 
// StreamElementDataClass generates data for our stream. 
//    StreamElementDataClass (int firstBytePosition, int varIDNib, int delimiterBytePosition, int fixedIDNib) 
//    firstBytePosition is the offset (passed to firstByteOffsetIn) 
//    varIDNib is "upper nibble" of the variable length field 
//    delimiterBytePosition is byte position of the delimiter (7 means it's byte 7 AFTER THE START OF THE STREAM) . 
//    fixedIDNib is "upper nibble" of the fixed length field 
//

class NextStreamDataInClass {
  public:  
    unsigned int NextByteOrWord; 
    bool         LastByteOrWord; 
}; 

class StreamElementDataClass 
{ 
  public: 
    // First BytePosition is what is passed to the 
    StreamElementDataClass (int firstBytePosition, int varIDNib, int delimiterBytePosition, int fixedIDNib) 
    {
      this->firstBytePosition = firstBytePosition; 
      this->delimiterBytePosition = delimiterBytePosition; 
      this->varIDNib = varIDNib;
      this->fixedIDNib = fixedIDNib;
    }
    NextStreamDataInClass GetNextByte()
    {
      NextStreamDataInClass result; result.LastByteOrWord = false; 
      if (byteIndex < firstBytePosition) { result.NextByteOrWord = PRECHUNKFILLER; }
      else if (byteIndex < firstBytePosition+delimiterBytePosition) { result.NextByteOrWord = (varIDNib<<4)+((byteIndex)-firstBytePosition); }
      else if (byteIndex == firstBytePosition+delimiterBytePosition) { result.NextByteOrWord = DELIMITER;  }
      else if (byteIndex <= firstBytePosition+delimiterBytePosition+NUMBYTESPASTDELIMITER) { result.NextByteOrWord = (fixedIDNib<<4)+((byteIndex)-firstBytePosition-delimiterBytePosition-1); } 
      else { result.NextByteOrWord = POSTCHUNKFILLER; result.LastByteOrWord = true;}; 
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
    int  GetDelimiterBytePosition() { return delimiterBytePosition; } 
    int  GetFirstBytePosition() { return firstBytePosition; } 
    void SetFirstBytePosition(int s) { firstBytePosition = s; } 
  private:
    unsigned int delimiterBytePosition; 
    unsigned int byteIndex = 0; 
    unsigned int varIDNib; 
    unsigned int fixedIDNib; 
    unsigned int firstBytePosition; 

}; 

//
// Drive a stream element and compare results. 
//
//

class StreamElementWrapperClass : VStreamElement 
{

  public:
  bool debug = true;  
  
  StreamElementWrapperClass () 
  {  
    const std::unique_ptr<VerilatedContext> contextp{new VerilatedContext};
    VStreamElement{contextp.get(), "VStreamElement"};
  } 

  void ToggleClock() { 
     this->clk = 1; this->eval(); this->clk = 0; this->eval(); 
     printf("Clock Toggled\n"); 
     ReceiveStreamOut(); 
     ReceiveTokenOut(); 
    
  } 
  void Reset() { this->reset = 1; ToggleClock(); ToggleClock(); this->reset = 0; ToggleClock(); } 


  void DriveStreamCycleAndCheckResult(bool AlreadyHasToken, StreamElementDataClass * Data) 
  {
      if (debug) std::cout << "Test: ************************************BEGIN TEST ************************************" << std::endl;       
      if (debug) std::cout << "Test: FirstBytePosition " << Data->GetFirstBytePosition(); 
      if (debug) std::cout <<      " Delimiter Byte Position " << Data->GetDelimiterBytePosition() << std::endl; 
      ToggleClock(); 
 
      NextStreamDataInClass streamDataObject; 
      streamDataObject.LastByteOrWord = false; 
      this->USEStreamDataTaken = 0;
      
      //
      // Drive in DATA IN and dataInValid. 
      // TODO: Add stalls. 

      int cycle = 0;
      while (streamDataObject.LastByteOrWord == false)
      { 


        streamDataObject = Data->GetNextWord();
        this->dataIn     = streamDataObject.NextByteOrWord;  
        streamDataObject = Data->GetNextWord();
        this->dataIn    |= ((unsigned long int) streamDataObject.NextByteOrWord << 32);  

        this->dataInValid = 1;

        if ((!AlreadyHasToken) && 
              (((cycle == 1) && (Data->GetFirstBytePosition() != 0)) || 
               ((cycle == 0) && (Data->GetFirstBytePosition() == 0)))) 
        { 
                 this->tokenIn    = 1; 
        }
        else   { this->tokenIn    = 0;   } 
        this->firstByteOffsetIn = Data->GetFirstBytePosition(); 

        std::cout << "Test: DataIn: " <<  std::hex << this->dataIn << std::dec << 
                    " Data In Valid " << (int) this->dataInValid << 
                    " TokenIN " << (int) this->tokenIn <<  std::endl;

        ToggleClock(); 
        cycle++;
        std::cout << "Test: OUT: ByteLength " << (int) this->USEStreamByteLengthOut << " StreamOut[0] "  <<  std::hex << *(this->USEStreamOut) << std::dec << std::endl;
      }

      this->dataInValid = 0;
      // Allow N clock cycles to shift. 
      int NumClockTicksToShift = 
              ((Data->GetFirstBytePosition() & 0x4) ? 1 : 0) + 
              ((Data->GetFirstBytePosition() & 0x2) ? 1 : 0) + 
              ((Data->GetFirstBytePosition() & 0x1) ? 1 : 0) + 1;

      for (int toggleCount = 0;toggleCount<NumClockTicksToShift+1;toggleCount++) { ToggleClock(); } 

      if (debug) std::cout << "Test: OUT: ByteLength " << (unsigned int) this->USEStreamByteLengthOut << std::endl; 
      if (debug) ReceiveStreamOut(); 

      // Check Byte length matches

      assert (this->USEStreamByteLengthOut == Data->GetDelimiterBytePosition()+NUMBYTESPASTDELIMITER+1);

      // Check bytes Up to ByteLength Match. 
      Data->ResetByteIndex(); 
      Data->SetFirstBytePosition(0); // Get rid of "beginning bytes" padding. 
      for (int i = 0; i < this->USEStreamByteLengthOut; i++) 
      { 
        char expectedByte = Data->GetNextByte().NextByteOrWord;
        char actualByte = *((unsigned char *) this->USEStreamOut + i);    
        if (debug) printf("Expected %x Actual %x\n", expectedByte,actualByte); 
        assert ((expectedByte == actualByte)); 
      }

      // Signal that we've taken the data. 
      this->USEStreamDataTaken = 1;
      ToggleClock(); 
      this->USEStreamDataTaken = 0;

      assert (this->USEStreamByteLengthOut == 0);
      if (debug) std::cout << "Test: ************************************** END TEST ************************************" <<std::endl;       
  } 

  void ReceiveStreamOut() { 
     printf("Test: USEStreamOut "); 
     for (int i = 34/4; i >= 0;i--) 
       if (this->USEStreamByteLengthOut) printf("%x ",*(this->USEStreamOut+i)); 
     printf("\n"); 
  }

  void ReceiveTokenOut() { if (this->tokenOut) printf("Token Passed. First Byte Offset Out: %x\n", this->firstByteOffsetOut); }

};


int main(int argc, char **argv) 
{

   Verilated::commandArgs(argc,argv); 

   // Some simple unit tests on the generators. 
   // Should produce (lowest first) 0xdd 0xdd 0xdd 0x10 0x11 0x12 0x13 0x14 0x15 0x16 0x2c 0xa0 0xa1 0xa2 .. 0xac 0xEE 0xEE 
   StreamElementDataClass StreamElementData(3,0x1,7,0xA);  
   assert(StreamElementData.GetNextWord().NextByteOrWord == 0x10dddddd); 
   assert(StreamElementData.GetNextWord().NextByteOrWord == 0x14131211); 
   assert(StreamElementData.GetNextWord().NextByteOrWord == 0xa02c1615); 
   assert(StreamElementData.GetNextWord().NextByteOrWord == 0xa4a3a2a1); 
 

   StreamElementWrapperClass StreamElementWrapper; 
   StreamElementWrapper.Reset(); 
   //
   // We are running the following tests:
   //  1) Test from reset state (Token In defaults on)  
   //
   
   StreamElementDataClass * streamData = new StreamElementDataClass(0,0x1,7,0xA);  
   StreamElementWrapper.DriveStreamCycleAndCheckResult(true,streamData);  

   for (int startByte = 0; startByte < 8; startByte++)
     for (int tokenPos = 1; tokenPos < 16; tokenPos++)
     { 
       streamData = new StreamElementDataClass(startByte,0x1,tokenPos,0xA);  
       StreamElementWrapper.DriveStreamCycleAndCheckResult(false,streamData);  
     } 

   // Reset and try again. 
   delete(streamData);

   std::cout << " ************************* RESETTING **************************" << std::endl;

   // If we reset we need to restart from 0. 

   StreamElementWrapper.Reset();  
   streamData = new StreamElementDataClass(0,0x1,1,0xA);  
   StreamElementWrapper.DriveStreamCycleAndCheckResult(true,streamData);  

   for (int startByte = 0; startByte < 8; startByte++)
     for (int tokenPos = 1; tokenPos < 10; tokenPos ++)
   { 
     streamData = new StreamElementDataClass(startByte,0x1,tokenPos,0xA);  
     StreamElementWrapper.DriveStreamCycleAndCheckResult(false,streamData);  
   } 
}
