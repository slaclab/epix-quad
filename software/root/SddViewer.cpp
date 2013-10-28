#include "TApplication.h"
#include "TPaletteAxis.h"
#include "TTimer.h"
#include "TCanvas.h"
#include "TPad.h"
#include "TStyle.h"
#include "TSystem.h"
#include "TMath.h"
#include "TAxis.h"
#include "TFrame.h"
#include "TGraph.h"

#include "XmlVariables.h"
#include "DataRead.h"
#include "Data.h"

/* MISC functions */
#include <stdint.h> 
#include <iomanip>
#include <fstream>
#include <iostream>

/************************** Constant Definitions *****************************/
#define BURST_SIZE_C   8192
#define PACKET_SIZE_C  ((8*BURST_SIZE_C) + 8 + 2)//8 burst packets + 8 temperatures + 2 headers

#define OFFSET_C	   0x2000U
#define CONVT_ADC_C	(2.0/16383.0)//Volts/counts
#define SPS_RATE_C 	50e+6/// in Hz

#define START_HDR_C     0xBABECAFE
#define STOP_HDR_C      0xBEEFCAFE

using namespace std;

/************************** Function Prototypes ******************************/
void EventLoop(DataRead);
void ReadDataFrame(uint *rawData, uint size);
double ConvToVoltage(uint16_t value);
double ConvToDegC(double value);

int main(int argc, char **argv) {
   DataRead  dataRead;
   dataRead.openShared("epix",1);

   TApplication theApp("App", &argc, argv);

   EventLoop(dataRead);

   theApp.Run();

   return 0;
}

void EventLoop(DataRead dataRead) {
   Data event;
   
   while (1) {
      if (!dataRead.next(&event)) {
         gSystem->ProcessEvents();
      } 
      else {
         uint *eventBuffer = event.data();
         uint size = event.size();   
         ReadDataFrame(eventBuffer,size);
      } 
   }   
}

void ReadDataFrame(uint *rawData, uint size) {
   static TCanvas C;
   TGraph *gr[10];   
   
   uint i,j;
   double temp_V[8],temp_C[8];
   double sdd_V[8][BURST_SIZE_C];
   double time[BURST_SIZE_C];
   double temp_sample[8];
  
   //check the headers and frame size
   if ((rawData[0] == START_HDR_C)
      && (rawData[size-1] = STOP_HDR_C)
      && (size == PACKET_SIZE_C)) {

      //get the temperature data
      for(i=0;i<8;i++){       
         temp_sample[i] = (double)i;
         temp_V[i] = ConvToVoltage((uint16_t)((rawData[i+1] >> 16)&0xFFFF));
         temp_C[i] = ConvToDegC(temp_V[i]);
      }
      
      //get the SDD data      
      for(i=0;i<8;i++){ 
         for(j=0;j<BURST_SIZE_C;j++){ 
            if(i==0){
               time[j] = 1e+6*((double(j))/SPS_RATE_C);//us
            }
            sdd_V[i][j] = ConvToVoltage((uint16_t)((rawData[(i*BURST_SIZE_C)+j+9] >> 16)&0xFFFF));
         }
      }
      
      //Graph data
      for(i=0;i<8;i++){ 
         *gr[i] = TGraph(BURST_SIZE_C,time,sdd_V[i]);
      }
      *gr[8] = TGraph(8,temp_sample,temp_V);
      *gr[9] = TGraph(8,temp_sample,temp_C);
      
      //plot the data
      for(i=0;i<8;i++){ 
         C.cd(i);
         gr[i]->GetXaxis()->SetTitle("Time (us)");
         gr[i]->GetXaxis()->CenterTitle();
         gr[i]->GetXaxis()->SetTitleOffset(1.2);
        
         gr[i]->GetYaxis()->SetTitle("Voltage (V)");
         gr[i]->GetYaxis()->CenterTitle();               
         
         gr[i]->Draw("AL*");      
      }
      
      C.cd(8);
      gr[8]->GetXaxis()->SetTitle("Channel Number");
      gr[8]->GetXaxis()->CenterTitle();
      gr[8]->GetXaxis()->SetTitleOffset(1.2);
     
      gr[8]->GetYaxis()->SetTitle("Voltage (V)");
      gr[8]->GetYaxis()->CenterTitle();               
      
      gr[8]->Draw("AL*");  

      C.cd(9);
      gr[9]->GetXaxis()->SetTitle("Channel Number");
      gr[9]->GetXaxis()->CenterTitle();
      gr[9]->GetXaxis()->SetTitleOffset(1.2);
     
      gr[9]->GetYaxis()->SetTitle("Temperature (degC)");
      gr[9]->GetYaxis()->CenterTitle();               
      
      gr[9]->Draw("AL*");        
      
      C.Update();
      gSystem->ProcessEvents();      
   }      
}

//convert from ADC counts to voltage
double ConvToVoltage(uint16_t value) {
   double result = ((double)value)*CONVT_ADC_C;
   result -= ((double)OFFSET_C)*CONVT_ADC_C;
   return result;
}

//convert from voltage to deg C (assumes 27.4kOhm pull-up to +5V on NTC)
double ConvToDegC(double value) {
   return ((-425.855513*value) + 240.547529);
}
