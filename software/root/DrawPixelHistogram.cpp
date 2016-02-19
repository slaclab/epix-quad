#include "TApplication.h"
#include "TPaletteAxis.h"
#include "TTimer.h"
#include "TCanvas.h"
#include "TPad.h"
#include "TH1F.h"
#include "TGraph.h"
#include "TStyle.h"
#include "TSystem.h"
#include "XmlVariables.h"
#include "DataRead.h"
#include "Data.h"
#include <iostream>
#include <stdio.h>

#define WORD_HEADER (0x01234567)
#define MIN_ADC     (0)
#define MAX_ADC     (16383)
#define MAX_COL     (95)
#define MAX_ROW     (97)

using namespace std;

TH1F *ReadFrame(TH1F *outHist, TGraph *pixGraph, uint *rawData, uint numWords, uint rowToDraw, uint colToDraw);
void EventLoop(DataRead, uint, uint);
void Recenter(TH1 *h);

int main(int argc, char **argv) {
   if (argc != 3) {
      cerr << "Syntax: DrawPixelHistogram <row> <col>" << endl;
      exit(1);
   }
   uint rowToDraw, colToDraw;
   sscanf(argv[1],"%d",&rowToDraw);
   sscanf(argv[2],"%d",&colToDraw);

   DataRead  dataRead;
   dataRead.openShared("epix",1);

   TApplication theApp("App", &argc, argv);

   EventLoop(dataRead,rowToDraw,colToDraw);

   theApp.Run();

   return 0;
}

void EventLoop(DataRead dataRead, uint rowToDraw, uint colToDraw) {
   TH1F    *pixel = NULL;
   TGraph  *pixGr = new TGraph();
   Data     event, last_event;
   TCanvas *C     = new TCanvas("C","Single Pixel Distribution",500,1000);
   bool     first = true;
   C->Divide(1,2);
   
   while (1) {
      if (!dataRead.next(&event)) {
         gSystem->ProcessEvents();
      } else {
         int bytes_total = event.size()*sizeof(uint);
         int bytes_matched = memcmp( (void*) &event, (void*) &last_event, event.size()*sizeof(uint));
         if ( bytes_matched < bytes_total ) {
            uint *eventBuffer = event.data();
            uint size = event.size();
            pixel = ReadFrame(pixel,pixGr,eventBuffer,size,rowToDraw,colToDraw);
            C->cd(1);
            pixel->Draw();
            if (first) {
               pixel->GetXaxis()->SetTitle("output value [ADC counts]");
               gStyle->SetOptStat(1);
               first = false;
            }
            Recenter(pixel);
            C->cd(2);
            pixGr->Draw("APL");
            C->Update();
            gSystem->ProcessEvents();
            last_event = event;
         } else {
            gSystem->ProcessEvents();
         }
      }
   }   
}

TH1F *ReadFrame(TH1F *outHist, TGraph *pixGraph, uint *rawData, uint numWords, uint rowToDraw, uint colToDraw) {
   if (!outHist) {
      float minAdc = float(MIN_ADC) - 0.5;
      float maxAdc = float(MAX_ADC) + 0.5;
      int nBins = MAX_ADC - MIN_ADC + 1;
      outHist = new TH1F("pixel","",nBins,minAdc,maxAdc);
   }

   bool goodEvent = true;
   uint col = 0;
   uint row = 0;
   for (uint i = 0; i < numWords-1; ++i) {
      if (i == 0) {
         if (rawData[i] != WORD_HEADER) {
            goodEvent = false;
            cerr << "Event did not have expected header." << endl;
            break;
         }
      } else {
         if (col == colToDraw && row == rowToDraw) {
            outHist->Fill(rawData[i]);
            int n = pixGraph->GetN();
            pixGraph->SetPoint(n,n,rawData[i]);
         }
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

void Recenter(TH1 *h) {
   int maxBin = h->GetMaximumBin();
   float maxBinCenter = h->GetBinCenter(maxBin);
   float rms = h->GetRMS();
   if (h->GetEntries() > 5) {
      h->GetXaxis()->SetRangeUser(maxBinCenter - 20.0*rms, maxBinCenter + 20.0*rms);
   }
}

