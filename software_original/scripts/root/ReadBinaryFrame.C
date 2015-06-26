#include "TH2F.h"
#include "TH1F.h"
#include "TGraph.h"
#include "TCanvas.h"
#include "TSystem.h"
#include "TStyle.h"

#include <iostream>
#include <fstream>

#define WORD_HEADER 0x01234567

using namespace std;

void ReadBinaryFrame(char *filename = "data.bin", bool draw = true, int hist_row = 0, int hist_col = 0, int hist_row2 = 10, int hist_col2 = 10) {
   gStyle->SetOptStat(1);
   //Open input file
   ifstream fin(filename);

   //Set up data objects
   TGraph *waveform_graph = new TGraph();
   float dt = 4.0/0.125;
   TH2F *frame_hist = new TH2F("frame_hist","frame_hist",96,-0.5,95.5,98,-0.5,97.5);
   //TH2F *frame_hist = new TH2F("frame_hist","frame_hist",96,-0.5,95.5,96,-0.5,95.5);
   TH1F *pixel_hist = new TH1F("pixel_hist","pixel_hist",pow(2,14),-0.5,pow(2,14)-1);
   TH1F *single_pixel_hist = new TH1F("single_pixel_hist","single_pixel_hist",pow(2,14),-0.5,pow(2,14)-1);
   TH1F *single_pixel_hist2 = new TH1F("single_pixel_hist2","single_pixel_hist",pow(2,14),-0.5,pow(2,14)-1);
   TH2F *pix1_vs_pix2 = new TH2F("pix1_vs_pix2","double_pixel_hist",pow(2,14),-0.5,pow(2,14)-1,pow(2,14),-0.5,pow(2,14)-1);
   TCanvas *C = new TCanvas();
//   C->Divide(2,1);

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
      for (int i = 0; i < num_words-1; ++i) {
		if (i == 0) {
		  if (data[i] != WORD_HEADER) {
            good_event = false;
            break;
		  }
		} else {
//         if (row == 97) continue;
		   int bin = frame_hist->FindBin( (float) col, (float) 97-row);
         pixel_hist->Fill(data[i]);
         if (row == hist_row && col == hist_col) {
            single_pixel_hist->Fill(data[i]);
         }
         if (row == hist_row2 && col == hist_col2) {
            single_pixel_hist2->Fill(data[i]);
         }
         if (data[i] < 16383) {
   		   frame_hist->SetBinContent(bin,data[i]);
         } else {
   		   frame_hist->SetBinContent(bin,25000);
         }
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
      if (good_event && draw) {
   		gStyle->SetOptStat(0);
         frame_hist->SetMaximum(26000);
//         if (event%10 == 0) { 
         if (1) {
            frame_hist->Draw("colz");
            C->Update();
//            C->Print("animation1.gif+");
            cout << event << endl;
         }
         event++;
         gSystem->ProcessEvents();
      }
      //Clean up
      delete [] data;
   }   

   //Close input file
   fin.close();

   //Draw outputs
//   waveform_hist->Draw();
//   float max_counts = waveform_hist->GetBinCenter(waveform_hist->GetMaximumBin());
//   float rms_counts = waveform_hist->GetRMS();
//   float width = rms_counts*10;
//   waveform_hist->GetXaxis()->SetRangeUser(max_counts-width,max_counts+width);

}
