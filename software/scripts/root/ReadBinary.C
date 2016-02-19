#include "TH1F.h"
#include "TGraph.h"
#include "TCanvas.h"
#include "TSystem.h"
#include "TStyle.h"

#include <iostream>
#include <fstream>

#define WORD_HEADER 0x01234567

using namespace std;

void ReadBinary(char *filename = "data.bin") {
   gStyle->SetOptStat(1);
   //Open input file
   ifstream fin(filename);

   //Set up data objects
   TGraph *waveform_graph = new TGraph();
   float dt = 4.0/0.125;
   TH1F *waveform_hist = new TH1F("waveform_hist","waveform_hist",16384,-0.5,16384-0.5);
   TCanvas *C = new TCanvas();
//   C->Divide(2,1);

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
      for (int i = 0; i < num_words; ++i) {
         if (i == 0 && data[i] != WORD_HEADER) {
            good_event = false;
            break;
         } else {
            waveform_hist->Fill(data[i]);
            waveform_graph->SetPoint(i-1,dt*float(i-1),data[i]);
         }
      }
      if (good_event) {
//         C->cd(1);
         waveform_graph->Draw("APL");
         cout << "Mean = " << waveform_graph->GetMean(2) << endl;
         cout << "RMS = " << waveform_graph->GetRMS(2) << endl;
//         C->cd(2);
//         waveform_hist->Draw();
         C->Update();
         getchar();
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
