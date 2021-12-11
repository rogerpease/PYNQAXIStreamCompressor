#include <iostream>
#include "VAXIStreamCompressor.h"
#include <memory> 
#include <sstream> 
#include <fstream> 
#include <boost/json.hpp>


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


namespace json = boost::json;
using namespace std;
using namespace json;

void pretty_print( std::ostream& os, json::value const& jv, std::string* indent = nullptr );


class StreamCompressorDataClass
{ 
  public: 
  int totalNumStreamBytes; 
  vector<vector<unsigned char>> StreamBytePackets;  
  int byteIndex; 
  
  vector<unsigned char> StreamBytePayload()  
  {
    vector<unsigned char> result; 
    for (auto a: StreamBytePackets)
      for (auto b: a)
        result.push_back(b);
    return result; 
      
  } 
  
  void InitializeDataset()
  {
//      cout << "InitializeDataset()" << endl; 
//      std::ifstream t; 
//      t.open("testInData/BaseballData.json");
//      std::string buffer;
//      while (t) { std::string line; std::getline(t,line); buffer += line; } 
//      t.close();
//      cout << buffer << endl; 

//      json::error_code ec;
//      json::value jv = parse(buffer, ec );
//      pretty_print( std::cout , jv);
      for (int i = 0; i < 10;i++) 
      { 
        vector<unsigned char> StreamPacket; 
        for (int j = 0; j < 10;j++) StreamPacket.push_back(j);  
        StreamPacket.push_back(0x2c);  
        for (int j = 0; j < 17;j++) StreamPacket.push_back(0x10+j);  
        StreamBytePackets.push_back(StreamPacket); 
        StreamPacket.clear(); 
      } 
 
 

  }

  public: 
    // First BytePosition is what is passed to the 
    StreamCompressorDataClass(int dataset)
    { 
      InitializeDataset();
    }

    bool GetDataBytes(vector<unsigned char>& dataBytes, bool & lastByte)
    {
       dataBytes.clear();
       const int dataBytesNeeded = 8; 
       lastByte = true; 
       while (dataBytes.size() < dataBytesNeeded) 
       { 
         
         if (StreamBytePackets.size() == 0) // Nothing more to push out. 
           return (dataBytes.size())? true : false;     

         if (StreamBytePackets[0].size() == 0) 
             StreamBytePackets.erase(StreamBytePackets.begin());
         if (StreamBytePackets.size() == 0) // Nothing more to push out. 
           return (dataBytes.size())? true : false;     
           
         if (StreamBytePackets[0].size() != 0) 
         {
           dataBytes.push_back(StreamBytePackets[0][0]); 
           StreamBytePackets[0].erase(StreamBytePackets[0].begin());
         }
       }
       lastByte = false; 
       return true;  
    } 
    int dataBytes=8; 
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
     this->dataIn_clk = 1; this->dataOut_clk = 1; this->eval(); this->dataIn_clk = 0;  this->dataOut_clk = 0; this->eval(); 
     if (debug) printf("=====================================Clock Toggled===========================================\n"); 
    
  } 
  void Reset() { this->dataIn_aresetn = 1; ToggleClock(); ToggleClock(); this->dataIn_aresetn = 0; ToggleClock(); } 


  bool DriveStreamCycleAndCheckResult(int dataset) 
  {
      ToggleClock(); 

      StreamCompressorDataClass Data(dataset);
      vector<unsigned char> dataBytes;
      vector<unsigned char> capturedData;
      bool lastByte;

      auto goldenData = Data.StreamBytePayload();
 
      while (lastByte == false)
      { 
        auto result = Data.GetDataBytes(dataBytes, lastByte);
        while (dataBytes.size() < 8) dataBytes.push_back(0); 
        cout << "DataBytes "; for (int i = 7; i >= 0; i--)  cout << hex << (int) dataBytes[i] << dec << " "; cout << endl; 
        cout << "LastByte " << lastByte << endl;  
        unsigned long long dataIn = 0; 
        for (int i = 7; i >= 0; i--) dataIn = dataIn << 8 | dataBytes[i];  

        this->dataIn_tdata  = dataIn;
        this->dataIn_tvalid = 1;

        //sentData.push_back(this->dataIn_tdata); 
        std::cout << "Test: DataIn: " <<  std::hex << this->dataIn_tdata << std::dec << " Data In Valid " << (int) this->dataIn_tvalid << std::endl;

        ToggleClock(); 
        if (this->dataOut_tvalid) 
        {
          for (int i = 0; i <= 7; i++) 
            capturedData.push_back(((this->dataOut_tdata)>>(i*8)) & 0xFF); 
          if (debug) printf("DATA OUT: %lx\n",this->dataOut_tdata);  
        } 
      }
      // flush for 15 more cycles. 
      int flushCycle = 20;
      while (flushCycle)
      {
         this->dataIn_tvalid = 0; 
         ToggleClock(); 
         if (this->dataOut_tvalid) 
         {
           for (int i = 0; i <= 7; i++) 
             capturedData.push_back(((this->dataOut_tdata)>>(i*8)) & 0xFF); 
           if (debug) printf("DATA OUT: %lx\n",this->dataOut_tdata);  
         } 
         flushCycle--;
      }
      cout << "Captured "; for (int i = capturedData.size()-1; i >= 0; i--)  cout << hex << (int) capturedData[i] << dec << " "; cout << endl; 
      cout << "Expected "; for (int i = goldenData.size()-1;   i >= 0; i--)  cout << hex << (int) goldenData[i]   << dec << " "; cout << endl; 
      assert(capturedData.size() == goldenData.size());
      assert(equal(capturedData.begin(),capturedData.end(),goldenData.begin()));
      return true; 

  } 
};

void Test()
{

   StreamCompressorDataClass A(0);

   auto payload = A.StreamBytePayload();
   assert(payload.size() == 28*10);

   vector<unsigned char> dataBytes;
   bool lastByte;
   auto result = A.GetDataBytes(dataBytes, lastByte);

   assert(result   == true); 
   assert(lastByte == false); 
   assert(dataBytes[0]== 0x00); 
   assert(dataBytes[1]== 0x01); 
   result = A.GetDataBytes(dataBytes, lastByte);
   assert(dataBytes[0]== 0x08); 
   assert(dataBytes[1]== 0x09); 

   for (int i = 0 ; i < 50; i++) 
     A.GetDataBytes(dataBytes, lastByte);
   assert(lastByte == true); 

}

int main(int argc, char **argv) 
{
  
   int arg = 0; 
   int dataset = 0; 
 
   Test(); 

   const bool debug = false; 
   AXIStreamCompressorWrapperClass AXIStreamCompressorWrapper; 
   AXIStreamCompressorWrapper.Reset();  
   assert (AXIStreamCompressorWrapper.DriveStreamCycleAndCheckResult(dataset));  
   std::cout << "Test: ************************************** PASS!!!!  ************************************" <<std::endl;       

}
