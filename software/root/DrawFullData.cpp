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
#include <iomanip>
#include <stdio.h>

#define N_HEADER_WORDS (8)
#define MAX_ROW     (97)
#define MAX_COL     (95)
#define MAX_ADC     (16383)
#define MIN_ADC     (0)

using namespace std;

TH2F *ReadFrame(int ch, TH2F *outHist, TH1F *pixHist, uint *rawData, uint numWords, int rowLow, int rowHigh, int colLow, int colHigh);
void EventLoop(DataRead, unsigned int, unsigned int);
TGaxis *ReverseYAxis (TH1 *h);
TGaxis *ReverseXAxis (TH1 *h);
TGaxis *RedrawXAxis (TH1 *h);

int main(int argc, char **argv) {
   if (argc != 3) {
      cout << "Please provide: <channel> <ncols>" << endl;
      return 1;
   }
   unsigned int chToRead = 0;
   unsigned int rowsToRead = 0;
   if (sscanf(argv[1],"%d",&chToRead) == 0 || sscanf(argv[2],"%d",&rowsToRead) ==  0) {
      cout << "Couldn't parse inputs!" << endl;
      return 1;
   }
   
   DataRead  dataRead;
   dataRead.openShared("epix",1);

   TApplication theApp("App", &argc, argv);

   EventLoop(dataRead, chToRead, rowsToRead);

   theApp.Run();

   return 0;
}

void EventLoop(DataRead dataRead, unsigned int chToRead, unsigned int rowsToRead) {
   TH2F    *frame   = NULL;
   TGaxis  *frameX  = NULL;
   TGaxis  *frameY  = NULL;
   TH1F    *pixHist = new TH1F("allPixels","",MAX_ADC-MIN_ADC+1,float(MIN_ADC)-0.5,float(MAX_ADC)+0.5);
   Data     event, *last_event;
   TCanvas *C     = new TCanvas("C","Last Frame",500,1000);
   bool     first = true;
   uint     last_frame = 0;
   C->Divide(1,2);
   
   while (1) {
      if (!dataRead.next(&event)) {
         gSystem->ProcessEvents();
      } else {
         int bytes_total = event.size()*sizeof(uint);
         cout << event.data()[1] << endl;
         if ( event.data()[1] != last_frame) {
//         if ( last_event != &event ) {
            uint *eventBuffer = event.data();
            uint size = event.size();
            frame = ReadFrame(chToRead,frame,pixHist,eventBuffer,size,0,rowsToRead-1,0,MAX_COL);
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

TH2F *ReadFrame(int ch, TH2F *outHist, TH1F *pixHist, uint *rawData, uint numWords, int rowLow, int rowHigh, int colLow, int colHigh) {
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

   for (int i = 0; i <= rowHigh; ++i) {
      int firstSample = N_HEADER_WORDS + i*768 + ch*48;
      for (int j = 0; j <= MAX_COL; ++j) {
         int bin = outHist->FindBin( (float) j, (float) rowHigh-i);
         uint thisData = rawData[firstSample+j/2];
         if (j%2 == 1) {
            thisData = thisData >> 16;
         }
         thisData = thisData & 0xFFFF;
         outHist->SetBinContent(bin,thisData);
         pixHist->Fill(thisData);
      }
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

