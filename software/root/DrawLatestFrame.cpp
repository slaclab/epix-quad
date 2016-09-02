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
#include <iostream>
#include <stdio.h>

#define WORD_HEADER (0x01234567)
#define MAX_ROW     (97)
#define MAX_COL     (95)
#define MAX_ADC     (16383)
#define MIN_ADC     (0)

using namespace std;

TH2F *ReadFrame(TH2F *outHist, TH1F *pixHist, uint *rawData, uint numWords, int rowLow, int rowHigh, int colLow, int colHigh);
void EventLoop(DataRead);
TGaxis *ReverseYAxis (TH1 *h);
TGaxis *ReverseXAxis (TH1 *h);
TGaxis *RedrawXAxis (TH1 *h);

int main(int argc, char **argv) {
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
   TCanvas *C     = new TCanvas("C","Last Frame",500,1000);
   bool     first = true;
   C->Divide(1,2);
   
   while (1) {
      if (!dataRead.next(&event)) {
         gSystem->ProcessEvents();
      } else {
         int bytes_total = event.size()*sizeof(uint);
         if ( last_event != &event ) {
            uint *eventBuffer = event.data();
            uint size = event.size();
            frame = ReadFrame(frame,pixHist,eventBuffer,size,0,MAX_ROW,0,MAX_COL);
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
         } else {
            gSystem->ProcessEvents();
         }
      }
   }   
}

TH2F *ReadFrame(TH2F *outHist, TH1F *pixHist, uint *rawData, uint numWords, int rowLow, int rowHigh, int colLow, int colHigh) {
   float rowLowF  = float(rowLow  - 0.5);
   float rowHighF = float(rowHigh + 0.5);
   float colLowF  = float(colLow  - 0.5);
   float colHighF = float(colHigh + 0.5);
   int nRows = rowHigh - rowLow + 1;
   int nCols = colHigh - colLow + 1;
   if (!outHist) {
      outHist = new TH2F("frame","",nCols,colLowF,colHighF,nRows,rowLowF,rowHighF);
   }
   if (!pixHist) {
      pixHist = new TH1F("allPixels","",(MAX_ADC-MIN_ADC+1),float(MIN_ADC)-0.5,float(MAX_ADC)+0.5);
   } else {
      pixHist->Reset();
   }

   bool goodEvent = true;
   int col = 0;
   int row = 0;
   for (uint i = 0; i < numWords-1; ++i) {
      if (i == 0) {
         if (rawData[i] != WORD_HEADER) {
            goodEvent = false;
            cerr << "Event did not have expected header." << endl;
            break;
         }
      } else {
         int bin = outHist->FindBin( (float) col, (float) MAX_ROW-row);
         outHist->SetBinContent(bin,rawData[i]);
         pixHist->Fill(rawData[i]);
         col = col + 1;
         if (col > MAX_COL) {
            col = 0;
            row = row + 1;
            if (row > MAX_ROW) {
               row = 0;
            }
         }
      }
   }

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

