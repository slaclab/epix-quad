//////////////////////////////////////////////////////////////////////////////
// This file is part of 'EPIX Development Softare'.
// It is subject to the license terms in the LICENSE.txt file found in the 
// top-level directory of this distribution and at: 
//    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
// No part of 'EPIX Development Softare', including this file, 
// may be copied, modified, propagated, or distributed except according to 
// the terms contained in the LICENSE.txt file.
//////////////////////////////////////////////////////////////////////////////
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
#include "TStyle.h"

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
#define PACKET_SIZE_C  32781
#define SDD_OFFSET_C   8
#define TEMP_OFFSET_C  32776

#define OFFSET_C	   0x2000U
#define CONVT_ADC_C	(2.0/16383.0)//Volts/counts
#define SPS_RATE_C 	50e+6/// in Hz

using namespace std;

/************************** Function Prototypes ******************************/
void EventLoop(DataRead);
void ReadDataFrame(TCanvas *C, uint *rawData, uint size);
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
   //modification of ROOT default style
   gStyle->SetFrameBorderSize(5);
   
   gStyle->SetLabelSize(0.1,"x");
   gStyle->SetLabelSize(0.1,"y");
   
   gStyle->SetTitleSize(0.09,"xyz");   
   
   gStyle->SetTitleOffset(1.1,"x");
   gStyle->SetTitleOffset(0.6,"y");
   
   gStyle->SetPadBottomMargin(0.2); 
   gStyle->SetTitleFontSize(0.09); 
   
   Data event;   
   TCanvas *C     = new TCanvas("C","SDD Waveform Viewer",1750,1000);
   C->Divide(2,5);
   C->SetFillColor(kBlack);
   
   while (1) {
      if (!dataRead.next(&event)) {
         gSystem->ProcessEvents();
      } 
      else {
         uint *eventBuffer = event.data();
         uint size = event.size();   
         ReadDataFrame(C,eventBuffer,size);
      } 
   }   
}

void ReadDataFrame(TCanvas *C, uint *rawData, uint size) {
   TGraph *gr[10];   
   
   uint i,j;
   double temp_V[8],temp_C[8];
   double sdd_V[8][BURST_SIZE_C];
   double time[BURST_SIZE_C];
   double temp_sample[8];
   char title[100];
   
   //check the headers and frame size
   if (size == PACKET_SIZE_C) {
      //get the SDD data      
      for(i=0;i<8;i++){ 
         for(j=0;j<(BURST_SIZE_C/2);j++){ 
            sdd_V[i][2*j+0] = ConvToVoltage((uint16_t)((rawData[(i*(BURST_SIZE_C/2))+j+SDD_OFFSET_C] >> 0)&0xFFFF));
            sdd_V[i][2*j+1] = ConvToVoltage((uint16_t)((rawData[(i*(BURST_SIZE_C/2))+j+SDD_OFFSET_C] >> 16)&0xFFFF));
         }
      }
      
      //generate a time axis for SDD waveforms
      for(i=0;i<BURST_SIZE_C;i++){ 
         time[i] = 1e+6*((double(i))/SPS_RATE_C);//us.
      }
  
      //get the temperature data
      for(i=0;i<4;i++){       
         temp_sample[2*i+0] = (double)(2*i+0);
         temp_sample[2*i+1] = (double)(2*i+1);
         
         temp_V[2*i+0] = ConvToVoltage((uint16_t)((rawData[i+TEMP_OFFSET_C] >> 0)&0xFFFF));
         temp_V[2*i+1] = ConvToVoltage((uint16_t)((rawData[i+TEMP_OFFSET_C] >> 16)&0xFFFF));
         
         temp_C[2*i+0] = ConvToDegC(temp_V[2*i+0]);
         temp_C[2*i+1] = ConvToDegC(temp_V[2*i+1]);
      }
 
      //Graph data
      for(i=0;i<8;i++){ 
         gr[i] = new TGraph(BURST_SIZE_C,time,sdd_V[i]);
      }
      gr[8] = new TGraph(8,temp_sample,temp_V);
      gr[9] = new TGraph(8,temp_sample,temp_C);
      
      //plot the data
      for(i=0;i<8;i++){ 
         C->cd(i+1);
         sprintf(title,"SDD[%d]",(int)i);
         gr[i]->SetTitle(title);
         gr[i]->GetXaxis()->SetTitle("Time (us)");
         gr[i]->GetXaxis()->CenterTitle();
        
         gr[i]->GetYaxis()->SetTitle("Voltage (V)");
         gr[i]->GetYaxis()->CenterTitle();               
         
         gr[i]->Draw("AL");      
      }
      
      sprintf(title,"SDD Temperatures");
      
      C->cd(8+1);
      gr[8]->SetTitle(title);
      gr[8]->GetXaxis()->SetTitle("Channel Number");
      gr[8]->GetXaxis()->CenterTitle();
     
      gr[8]->GetYaxis()->SetTitle("Voltage (V)");
      gr[8]->GetYaxis()->CenterTitle();               
      
      gr[8]->Draw("AL*");  

      C->cd(9+1);
      gr[9]->SetTitle(title);
      gr[9]->SetTitle(title);
      gr[9]->GetXaxis()->SetTitle("Channel Number");
      gr[9]->GetXaxis()->CenterTitle();
     
      gr[9]->GetYaxis()->SetTitle("Temperature (degC)");
      gr[9]->GetYaxis()->CenterTitle();               
      
      gr[9]->Draw("AL*");        
      
      C->Update();
      gSystem->ProcessEvents();   

      for(i=0;i<10;i++){ 
         delete gr[i];
      }
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
