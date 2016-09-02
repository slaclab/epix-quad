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
void EventLoop(DataRead, int, int);

int main(int argc, char **argv) {
   if (argc != 3) {
      cout << "please provide channel number and number of samples" << endl;
      return -1;
   }
   int ch = 0, npoints = 0;
   sscanf(argv[1],"%d",&ch);
   sscanf(argv[2],"%d",&npoints);

   DataRead  dataRead;
   dataRead.openShared("epix",1);

   TApplication theApp("App", &argc, argv);

   EventLoop(dataRead,ch,npoints);

   theApp.Run();

   return 0;
}

void EventLoop(DataRead dataRead, int ch, int npoints) {
   TVirtualFFT::SetTransform(0);
   Data      event;
   uint acqCount = 0;  
   uint lastAcqCount = 0;
 
   while (1) {
      if (!dataRead.next(&event)) {
         gSystem->ProcessEvents();
      } else {
         acqCount = event.data()[1];
         if ( acqCount != lastAcqCount ) {
            short unsigned int *eventBuffer = (short unsigned int *) &(event.data()[8 + ch*npoints/2]);
            short unsigned int *fullEventBuffer = (short unsigned int *) &(event.data()[8]);
            float mean = 0, mean_all = 0;
            short unsigned int first_val = eventBuffer[0];
            short unsigned int mismatches[8] = {0};
            for (int c = 0; c < 16; ++c) {
               cout << "[" << c << "]: " << hex << fullEventBuffer[c*npoints] << " , " << fullEventBuffer[c*npoints + npoints-1] << dec << endl;
            }
            for (int j = 0; j < npoints; ++j) {
               float sumAdc = 0;
               for (int c = ch/8; c < ch/8+8; ++c) {
                  if (fullEventBuffer[c*npoints+j] != first_val) {
                     if (mismatches[c] == 0) {
                        cout << "\t" << c << ": " << hex << fullEventBuffer[c*npoints+j] << dec << endl;
                     }
                     mismatches[c]++;
                  }
                  sumAdc += float(fullEventBuffer[c*npoints+j]);
               }
               mean_all += sumAdc/8.0;
               mean += (float) eventBuffer[j];
            }
            mean /= float(npoints);
            mean_all /= float(npoints);
            cout << "First    : " << hex << first_val << dec << endl;
            for (int c = 0; c < 8; ++c) {
               if (mismatches[c] != 0) {
                  cout << mismatches[c] << " mismatches in channel " << c << endl;
               }  
            }
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


