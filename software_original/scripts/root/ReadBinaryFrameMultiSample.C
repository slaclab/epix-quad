#include "TH2F.h"
#include "TGraph.h"
#include "TCanvas.h"
#include "TSystem.h"
#include "TStyle.h"

#include <iostream>
#include <fstream>

#define WORD_HEADER 0x01234567
#define NSAMPLES 1

using namespace std;

void ReadBinaryFrameMultiSample(char *filename = "data.bin") {
   gStyle->SetOptStat(1);
   //Open input file
   ifstream fin(filename);

   //Set up data objects
   TGraph *waveform_graph = new TGraph();
   float dt = 4.0/0.125;
   TH2F *frame_hist[NSAMPLES];
   TGraph *waveform = new TGraph(6*96);
   for (int i = 0; i < NSAMPLES; ++i) {
      char title[1024];
      sprintf(title,"frame%i",i);
      frame_hist[i] = new TH2F(title,title,96,-0.5,95.5,98,-0.5,97.5);
   }
   TCanvas *C = new TCanvas();
   C->Divide(3,3);

   int event = 0;
   //Event loop
   while (fin) {
      //Read event size
      UInt_t num_words;
      fin.read((char *) &num_words,sizeof(UInt_t));
      //Read in the data
      UInt_t *data = new UInt_t[num_words];
      fin.read((char *) data, sizeof(UInt_t)*num_words);
      //Do what you like with the data
      bool good_event = true;
	   int col = 0;
 	   int row = 0;
      int sample = 0;
      for (int i = 0; i < num_words-1; ++i) {
   		if (i == 0) {
            if (data[i] != WORD_HEADER) {
               good_event = false;
               break;
		      }
         } else {
   		   int bin = frame_hist[sample]->FindBin( (float) col, (float) 97-row);
   		   frame_hist[sample]->SetBinContent(bin,data[i]);
            if (row == 0) {
               waveform->SetPoint(sample+col*NSAMPLES,sample+col*NSAMPLES,data[i]);
            }
            sample = sample + 1;
            if (sample == NSAMPLES) {
               sample=0;
      		   col = col + 1;
      		   if (col == 96) {
      		  	   col = 0;
      			   row = row + 1;
      			   if (row == 98) {
      			      row = 0;
      			   }
      		   }
            }
         }
      }
      if (good_event) {
   		gStyle->SetOptStat(0);
         for (int j = 0; j < NSAMPLES; ++j) {
            frame_hist[j]->SetMaximum(16000);
            C->cd(j+1);
            frame_hist[j]->Draw("colz");
         }
         event++;
         gSystem->ProcessEvents();
      }
      //Clean up
      delete [] data;
   }   

   TCanvas *C2 = new TCanvas();
   waveform->Draw("APL");

   //Close input file
   fin.close();

   //Draw outputs
//   waveform_hist->Draw();
//   float max_counts = waveform_hist->GetBinCenter(waveform_hist->GetMaximumBin());
//   float rms_counts = waveform_hist->GetRMS();
//   float width = rms_counts*10;
//   waveform_hist->GetXaxis()->SetRangeUser(max_counts-width,max_counts+width);
}
