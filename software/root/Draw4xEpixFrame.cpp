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
#include "TH2F.h"
#include "TStyle.h"
#include "TSystem.h"
#include "XmlVariables.h"
#include "DataRead.h"
#include "Data.h"
#include <math.h>
#include <iostream>
#include <iomanip>
#include <stdio.h>

#define N_HEADER_WORDS (8)
#define N_FOOTER_WORDS (1)
#define N_TEMPER_WORDS (2)
#define MAX_ROW     (352*2-1)
#define MAX_COL     (96*8-1)
#define MAX_ADC     (16383)
#define MIN_ADC     (0)

using namespace std;

TH2F *ReadFrame(TH2F *outHist, TH1F *pixHist, uint *rawData, uint numWords);
void EventLoop(DataRead);
TGaxis *ReverseYAxis (TH1 *h);
TGaxis *ReverseXAxis (TH1 *h);
TGaxis *RedrawXAxis (TH1 *h);

int main(int argc, char **argv) {
   if (argc != 1) {
      cout << "No arguments please!" << endl;
      return 1;
   }
   
   DataRead  dataRead;
   dataRead.openShared("epix",1);

   TApplication theApp("App", &argc, argv);

   EventLoop(dataRead);

   theApp.Run();

   return 0;
}

void EventLoop(DataRead dataRead) {
   TH2F    *frame   = NULL;
   TGaxis  *frameX  = NULL;
   TGaxis  *frameY  = NULL;
   TH1F    *pixHist = new TH1F("allPixels","",MAX_ADC-MIN_ADC+1,float(MIN_ADC)-0.5,float(MAX_ADC)+0.5);
   Data     event, *last_event;
   TCanvas *C     = new TCanvas("C","Last Frame",2000,1000);
   bool     first = true;
   uint     last_frame = 0;
   C->Divide(2,1);
   
   while (1) {
      if (!dataRead.next(&event)) {
         gSystem->ProcessEvents();
      } else {
         cout << event.data()[1] << endl;
         if ( event.data()[1] != last_frame) {
//         if ( last_event != &event ) {
            uint *eventBuffer = event.data();
            uint size = event.size();
            cout << "total size = " << size << endl;
            frame = ReadFrame(frame,pixHist,eventBuffer,size);
            C->cd(1);
            frame->Draw("colz");
            if (first) {
               gStyle->SetPalette(1);
               gPad->SetRightMargin(0.15);
               frame->SetMaximum(16383);
               //frame->SetMaximum(4000);
               frame->SetMinimum(0);
               gStyle->SetOptStat(0);
               frameY = ReverseYAxis(frame);
               frameX = RedrawXAxis(frame);
               pixHist->GetXaxis()->SetTitle("pixel output [ADC counts]");
               pixHist->GetXaxis()->SetTitleOffset(1.1);
               first = false;
            }
            frameY->Draw();
            frameX->Draw();
            C->cd(2);
            pixHist->Draw();
            //pixHist->GetXaxis()->SetRangeUser(1000,3000);
            C->Update();
            gSystem->ProcessEvents();
            last_event = &event;
            last_frame = event.data()[1];
         } else {
            gSystem->ProcessEvents();
         }
      }
   }   
}

TH2F *ReadFrame(TH2F *outHist, TH1F *pixHist, uint *rawData, uint numWords) {
   float rowLowF  = float(0  - 0.5);
   float rowHighF = float(MAX_ROW + 0.5);
   float colLowF  = float(0  - 0.5);
   float colHighF = float(MAX_COL + 0.5);
   int nRows = MAX_ROW + 1;
   int nCols = MAX_COL + 1;
   if (!outHist) {
      outHist = new TH2F("frame","",nCols,colLowF,colHighF,nRows,rowLowF,rowHighF);
   }
   if (!pixHist) {
      pixHist = new TH1F("allPixels","",(MAX_ADC-MIN_ADC+1),float(MIN_ADC)-0.5,float(MAX_ADC)+0.5);
   } else {
      pixHist->Reset();
   }

   unsigned short int *adcData = (unsigned short int *) &(rawData[N_HEADER_WORDS]);

   cout << "size: " << outHist->GetSize() << endl;

   for (int i = 0; i < 352*96*16; ++i) {
      int c_readout = i % (96*8);
      int r_readout = i / (96*8);
      int c_logical = c_readout;
      int r_logical = 352 + (r_readout%2 == 0 ? 1 : -1)*int((r_readout+1)/2);
      int bin = outHist->FindBin( (float) c_logical, (float) MAX_ROW - r_logical );
      unsigned short int thisData = adcData[i];
      outHist->SetBinContent(bin,thisData);
      pixHist->Fill(thisData);
   }

   uint event = rawData[1];
   cout << "Event: " << event << " - ";
   for (int i = 0; i < 4; ++i) {
      uint tps_value = rawData[numWords-3+i/2];
      if (i % 2 == 1) {
         tps_value = tps_value >> 16;
      } else {
         tps_value = tps_value & 0xFFFF;
      }
      cout << "TPS[" << i << "]: " << setw(5) << setfill(' ') << tps_value << " ";
   }
   cout << endl;

   return outHist;
}


TGaxis *ReverseYAxis (TH1 *h) {
   // Remove the current axis
   h->GetYaxis()->SetLabelOffset(999);
   h->GetYaxis()->SetTickLength(0);

   // Redraw the new axis
   gPad->Update();
   TGaxis *newaxis = new TGaxis(gPad->GetUxmin(),
                                gPad->GetUymax(),
                                gPad->GetUxmin()-0.001,
                                gPad->GetUymin(),
                                h->GetYaxis()->GetXmin(),
                                h->GetYaxis()->GetXmax(),
                                510,"+");
   newaxis->SetLabelOffset(-0.03);
   newaxis->Draw();
   return newaxis;
}

TGaxis *ReverseXAxis (TH1 *h) {
   // Remove the current axis
   h->GetXaxis()->SetLabelOffset(999);
   h->GetXaxis()->SetTickLength(0);

   // Redraw the new axis
   gPad->Update();
   TGaxis *newaxis = new TGaxis(gPad->GetUxmax(),
                                gPad->GetUymin(),
                                gPad->GetUxmin(),
                                gPad->GetUymin(),
                                h->GetXaxis()->GetXmin(),
                                h->GetXaxis()->GetXmax(),
                                510,"-");
   newaxis->SetLabelOffset(-0.03);
   newaxis->Draw();
   return newaxis;
}

TGaxis *RedrawXAxis (TH1 *h) {
   // Remove the current axis
   h->GetXaxis()->SetLabelOffset(999);
   h->GetXaxis()->SetTickLength(0);

   // Redraw the new axis
   gPad->Update();
   TGaxis *newaxis = new TGaxis(gPad->GetUxmin(),
                                gPad->GetUymin(),
                                gPad->GetUxmax(),
                                gPad->GetUymin(),
                                h->GetXaxis()->GetXmin(),
                                h->GetXaxis()->GetXmax(),
                                510,"");
   newaxis->SetLabelOffset(0.02);
   newaxis->Draw();
   return newaxis;
}

