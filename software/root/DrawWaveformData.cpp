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
#include <iomanip>
#include <stdio.h>

#define F_SAMPLE  (100.0/2.0)
#define F_NYQUIST (0.5*F_SAMPLE)
#define ADC_MAX 16383

#define NHEADER 8
#define VC 2
#define VC_MASK 0x3
#define NFOOTER 5

using namespace std;

void ReadEvent(TH1F *&EventWaveform, TProfile *&AllFFT, uint *eventData, uint size, bool first);
void EventLoop(DataRead);

int main(int argc, char **argv) {
   if (argc != 1) {
      cout << "No arguments plz!" << endl;
      return -1;
   }

   DataRead  dataRead;
   dataRead.openShared("epix",1);

   TApplication theApp("App", &argc, argv);

   EventLoop(dataRead);

   theApp.Run();

   return 0;
}

void EventLoop(DataRead dataRead) {

   Data event;

   TCanvas *C = new TCanvas();
   C->Divide(1,2);
   TPad *padWaveform[2], *padHisto[2];
   for (int ch = 0; ch < 2; ++ch) {
      C->cd(ch+1);
      char name[1024];
      sprintf(name,"padWaveform%d",ch);
      char title[1024];
      sprintf(title,"CH %d Waveform",ch);
      padWaveform[ch] = new TPad(name,title,0.0,0.0,0.8,1.0);
      padWaveform[ch]->Draw();
      sprintf(name,"padHisto%d",ch);
      sprintf(title,"CH %d Histo",ch);
      padHisto[ch] = new TPad(name,title,0.8,0.0,1.0,1.0);
      padHisto[ch]->Draw();
   }

   TGraph *waveA = NULL;
   TGraph *waveB = NULL;
   TH1F *histA = NULL;
   TH1F *histB = NULL;
   unsigned short int *adcA;
   unsigned short int *adcB;
   float *times = NULL;
   bool first = true;
   int traceLength = 0;

   while(1) {
      if (!dataRead.next(&event)) {
         gSystem->ProcessEvents();
      } else {
         if ( (event.data()[0] & VC_MASK) != VC) {
            gSystem->ProcessEvents();
            continue;
         }
         adcA = (unsigned short int *) &(event.data()[NHEADER]);
         adcB = (unsigned short int *) &(event.data()[NHEADER+traceLength/2]);
         traceLength = event.size() - NHEADER - NFOOTER;
         if (first || waveA->GetN() != traceLength) {
            cout << "Setting up for waveforms of length: " << traceLength << endl;
            if (waveA) delete waveA;
            if (waveB) delete waveB;
            waveA = new TGraph(traceLength);
            waveB = new TGraph(traceLength);
            waveA->SetTitle("CH A");
            waveB->SetTitle("CH B");
            waveA->SetMarkerStyle(6);
            waveB->SetMarkerStyle(6);
            waveA->SetMarkerColor(kBlack);
            waveB->SetMarkerColor(kRed);
            waveA->SetLineColor(kBlack);
            waveB->SetLineColor(kRed);
            //Set up the time array for further use
            if (times) delete times;
            times = new float[traceLength];
            for (int i = 0; i < traceLength; ++i) {
               times[i] = float(i);
            }
            first = false;
         }
         if (histA) delete histA;
         if (histB) delete histB;
         histA = new TH1F("histA","CH A",50,1,0);
         histB = new TH1F("histB","CH B",50,1,0);
         for (int i = 0; i < traceLength; ++i) { 
            waveA->SetPoint(i,times[i],(float)adcA[i]);
            waveB->SetPoint(i,times[i],(float)adcB[i]);
            histA->Fill(adcA[i]);
            histB->Fill(adcB[i]);
         }
         C->cd(1);
         padWaveform[0]->cd();
         waveA->Draw("AP");
         //waveA->GetYaxis()->SetRangeUser(8500,9000);
         padHisto[0]->cd();
         histA->Draw();

         C->cd(2);
         padWaveform[1]->cd();
         waveB->Draw("AP");
         //waveB->GetYaxis()->SetRangeUser(2200,2300);
         //waveB->GetXaxis()->SetRangeUser(20,40);
         padHisto[1]->cd();
         histB->Draw();

         C->Update();
         gSystem->ProcessEvents();
      }   
   }

/*
   TVirtualFFT::SetTransform(0);
   Data      event;
   TCanvas  *C_Waveform = new TCanvas("C_Waveform","Waveforms",1000,1000);
   C_Waveform->Divide(3,2);
//   TCanvas  *C_Waveform = new TCanvas("C_Waveform","Waveforms",500,500);
   uint acqCount = 0;  
   uint lastAcqCount = 0;
   TH1F *hist = new TH1F("hist","ADC Histogram",ADC_MAX+1,-0.5,ADC_MAX+0.5);
   TH1F *histAll = new TH1F("histAll","ADC Histogram",ADC_MAX+1,-0.5,ADC_MAX+0.5);
   TH1F *tmpHist  = new TH1F("tmpHist","FFT",npoints,-0.5,npoints-0.5);
   TH1F *tmpHist2 = new TH1F("tmpHist2","FFT",npoints,-0.5,npoints-0.5);
   TProfile *ProfFFT = new TProfile("ProfFFT","Average FFT",(npoints)/2,0,F_NYQUIST);
   TProfile *ProfFFTAll = new TProfile("ProfFFTAll","Average FFT",(npoints)/2,0,F_NYQUIST);
   TH1 *fftHist = NULL;
   TH1 *fftHistAll = NULL;
   TGraph *graph = new TGraph(npoints);
   TGraph *sum_graph = new TGraph(npoints);
   float *t = new float[npoints];
   for (int i = 0; i < npoints; ++i) {
      t[i] = float(i) / 31.25;  //ADC freq in MHz ==> t in us
   }
   graph->GetXaxis()->SetTitle("time (#mus)");
   char title[1024];
   sprintf(title,"CH %d",ch);
   graph->SetTitle(title);
   char sum_title[1024];
   sprintf(sum_title,"CH %d-%d Average",ch/8,ch/8+7);
   sum_graph->SetTitle(sum_title);
 
   while (1) {
      if (!dataRead.next(&event)) {
         gSystem->ProcessEvents();
      } else {
         acqCount = event.data()[1];
         if ( acqCount != lastAcqCount ) {
            short unsigned int *eventBuffer = (short unsigned int *) &(event.data()[8 + ch*npoints]);
            short unsigned int *fullEventBuffer = (short unsigned int *) &(event.data()[8]);
            hist->Reset();
            tmpHist->Reset();
            tmpHist2->Reset();
            float mean = 0, mean_all = 0;
            for (int j = 0; j < npoints; ++j) {
               graph->SetPoint(j,t[j],float(eventBuffer[j]));
               float sumAdc = 0;
               for (int c = ch/8; c < ch/8+8; ++c) {
                  sumAdc += float(fullEventBuffer[c*npoints+j]);
               }
               sum_graph->SetPoint(j,t[j],sumAdc/8.0);
               mean_all += sumAdc/8.0;
               hist->Fill(eventBuffer[j]);
               mean += (float) eventBuffer[j];
               histAll->Fill(sumAdc/8.0);
            }
            mean /= float(npoints);
            mean_all /= float(npoints);
            for (int j = 0; j < npoints; ++j) {
               tmpHist->SetBinContent(j+1,float(eventBuffer[j])-mean);
            }
            //Do the FFT
            fftHist = tmpHist->FFT(fftHist, "MAG");
            fftHist->Scale(1./TMath::Sqrt(tmpHist->GetNbinsX()));
            //Step through the bins and fill the scaled histogram
            for (int i = 1; i <= tmpHist->GetNbinsX(); ++i) {
               double freq = ProfFFT->GetBinCenter(i);
               double value = fftHist->GetBinContent(i);
               ProfFFT->Fill(freq,value);
            }
            //Do the composite FFT
            tmpHist->Reset();
            for (int j = 0; j < npoints; ++j) {
               double t,v;
               sum_graph->GetPoint(j,t,v);
               tmpHist->SetBinContent(j+1,v - mean_all);
            } 
            fftHist = tmpHist->FFT(fftHist, "MAG");
            fftHist->Scale(1./TMath::Sqrt(tmpHist->GetNbinsX()));
            //Step through the bins and fill the scaled histogram
            for (int i = 1; i <= tmpHist->GetNbinsX(); ++i) {
               double freq = ProfFFTAll->GetBinCenter(i);
               double value = fftHist->GetBinContent(i);
               ProfFFTAll->Fill(freq,value);
            }
            //Draw everything
            C_Waveform->cd(1);
            graph->Draw("APL");
            C_Waveform->cd(2);
            ProfFFT->Draw("hist l");
//            fftHist->Draw("l");
            C_Waveform->cd(3);
            hist->Draw();
            hist->GetXaxis()->SetRangeUser( hist->GetMean()-hist->GetRMS()*50.0, 
                                            hist->GetMean()+hist->GetRMS()*50.0 );
            gPad->SetLogy();
            C_Waveform->cd(4);
            sum_graph->Draw("APL");
            C_Waveform->cd(5);
            ProfFFTAll->Draw("hist l");
//            fftHistAll->Draw("l");
            C_Waveform->cd(6);
            histAll->Draw();
            histAll->GetXaxis()->SetRangeUser( histAll->GetMean()-histAll->GetRMS()*50.0, 
                                               histAll->GetMean()+histAll->GetRMS()*50.0 );
            gPad->SetLogy();
            C_Waveform->Update();
            gSystem->ProcessEvents();
            lastAcqCount = acqCount;
         } else {
            gSystem->ProcessEvents();
         }
      }
   }   
*/
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


