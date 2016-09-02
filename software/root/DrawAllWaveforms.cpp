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
#include "TH1F.h"
#include "TProfile.h"
#include "TStyle.h"
#include "TSystem.h"
#include "TVirtualFFT.h"
#include "XmlVariables.h"
#include "DataRead.h"
#include "Data.h"
#include "TMath.h"
#include "TGraph.h"
#include "TPad.h"
#include <iostream>
#include <stdio.h>

#define WORD_HEADER (0x01234567)
#define WORD_FOOTER (0xBEEFCAFE)
#define F_SAMPLE  (125.0/4.0)
#define F_NYQUIST (0.5*F_SAMPLE)
#define ADC_MAX 65535

using namespace std;

void ReadEvent(TH1F *&EventWaveform, TProfile *&AllFFT, uint *eventData, uint size, bool first);
void EventLoop(DataRead, int);

int main(int argc, char **argv) {
   if (argc != 2) {
      cout << "please provide number of samples per trigger" << endl;
      return -1;
   }
   int npoints = 0;
   sscanf(argv[1],"%d",&npoints);

   DataRead  dataRead;
   dataRead.openShared("epix",1);

   TApplication theApp("App", &argc, argv);

   EventLoop(dataRead,npoints);

   theApp.Run();

   return 0;
}

void EventLoop(DataRead dataRead, int npoints) {
   TVirtualFFT::SetTransform(0);
   Data      event;
   TCanvas  *C_Waveform = new TCanvas("C_Waveform","Waveforms",1800,800);
   C_Waveform->Divide(8,2);
   uint acqCount = 0;  
   uint lastAcqCount = 0;
   TGraph *gAdc[16];
   for (int i = 0; i < 16; ++i) {
      gAdc[i] = new TGraph(npoints);
      gAdc[i]->GetXaxis()->SetTitle("time (#mus)");
      char title[1024];
      sprintf(title,"CH %d",i);
      gAdc[i]->SetTitle(title);
   }
   float *t = new float[npoints];
   for (int i = 0; i < npoints; ++i) {
      t[i] = float(i) / 31.25;  //ADC freq in MHz ==> t in us
   }
 
   while (1) {
      if (!dataRead.next(&event)) {
         gSystem->ProcessEvents();
      } else {
         acqCount = event.data()[1];
         if ( acqCount != lastAcqCount ) {
            short unsigned int *fullEventBuffer = (short unsigned int *) &(event.data()[8]);
            for (int ch = 0; ch < 16; ++ch) {
               for (int j = 0; j < npoints; ++j) {
                  gAdc[ch]->SetPoint(j,t[j],float(fullEventBuffer[j+ch*npoints]));
               }
            }
            //Draw everything
            for (int ch = 0; ch < 16; ++ch) {
               C_Waveform->cd(ch+1);
               gAdc[ch]->Draw("APL");
            }
            C_Waveform->Update();
            gSystem->ProcessEvents();
            lastAcqCount = acqCount;
         } else {
            gSystem->ProcessEvents();
         }
      }
   }   
}

void ReadEvent(TH1F *&EventWaveform, TProfile *&AllFFT, uint *eventData, uint size, bool first) {
   if (first) {
      EventWaveform = new TH1F("EventWaveform","Event Waveform",size-2,0,1/F_SAMPLE*(size-1));
      AllFFT = new TProfile("AllFFT","Average FFT",(size-2)/2,0,F_NYQUIST);
   } else {
      EventWaveform->Reset();
   }
   double sum = 0;
   for (uint i = 0; i < size; ++i) {
      if (i == 0 || i == size-1) {
         continue;
      }
      sum += eventData[i];
   }
   sum /= EventWaveform->GetNbinsX();
   //Subtract off mean
   for (uint i = 0; i < size; ++i) {
      if (i == 0 || i == size-1) {
         continue;
      }
      EventWaveform->SetBinContent(i+1,float(eventData[i]) - sum);
   }
   
   //Compute the transform and look at the magnitude of the output
   TH1 *tmpHist;
   TVirtualFFT::SetTransform(0);
   tmpHist = EventWaveform->FFT(tmpHist, "MAG");
   tmpHist->Scale(1./TMath::Sqrt(EventWaveform->GetNbinsX()));
   //NOTE: for "real" frequencies you have to divide the x-axes range with the range of your function 
   //(in this case 4*Pi); y-axes has to be rescaled by a factor of 1/SQRT(n) to be right: this is not done automatically!

   //Step through the bins and fill the scaled histogram
   for (int i = 1; i <= tmpHist->GetNbinsX(); ++i) {
      double freq = AllFFT->GetBinCenter(i);
      double value = tmpHist->GetBinContent(i);
      AllFFT->Fill(freq,value);
   } 

   delete tmpHist;

}


