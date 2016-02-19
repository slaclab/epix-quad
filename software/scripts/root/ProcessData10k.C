#include "TFile.h"
#include "TSystem.h"
#include "TCanvas.h"
#include "TGraph.h"
#include "TH1F.h"
#include "TH1.h"
#include "TTimer.h"
#include "TTree.h"
#include <fstream>
#include <iostream>

//#define NROW 352
#define NROW 50
#define NCOL 48
#define NCH 16
#define NUMWORDS (NROW*NCOL*NCH/2 + 11)
#define NHEADERS 8


using namespace std;

static int channel_map[16] = {4,5,6,7,15,14,13,12,11,10,9,8,0,1,2,3};

float* CalculatePedestals(ifstream &fin, unsigned int ch, int nevents);
void DrawEvent(ifstream &fin, unsigned int ch, float *pedestals, TGraph *eventGraph, TH1F *hist);
bool AccumulateEvent(ifstream &fin, unsigned int ch, float *pedestals, TTree *tree, bool advance);
TH1 *CalcFFT(TGraph *graph);

void ProcessData(char *filename, char *ped_filename = NULL, bool visualize = true, char *out_root = NULL) {
   TTimer timer(0);
   timer.SetCommand("gSystem->ProcessEvents();");

   ifstream fin(filename);
   ifstream fin_tuple(filename);
   if (!fin) {
      cout << "Couldn't open: " << filename << endl;
      return;
   }
   ifstream fin_ped;
   if (ped_filename != NULL) {
      fin_ped.open(ped_filename);
      if (!fin_ped) {
         cout << "Coudln't open: " << ped_filename << endl;
         return;
      }
   }

   unsigned int chs[4] = {0,4,8,12};
   //unsigned int chs[4] = {8,9,10,11};
   int bins = 1000;  //41
   float low = 8000; //-20
   float high = 11000; //20

   TFile *f1 = NULL;
   if (out_root) {
      f1 = new TFile(out_root,"RECREATE","file");
   }

   TTree *tree = new TTree("tree","Pixel Tree");

   int ped_events = 50;
   cout << "Calculating pedestals..." << endl;
   float *pedestalsU1 = CalculatePedestals(fin_ped, chs[0], ped_events);
   float *pedestalsU2 = CalculatePedestals(fin_ped, chs[1], ped_events);
   float *pedestalsU3 = CalculatePedestals(fin_ped, chs[2], ped_events);
   float *pedestalsU4 = CalculatePedestals(fin_ped, chs[3], ped_events);
   cout << "...done." << endl;
   TGraph *eventGraphU1 = new TGraph(NROW*NCOL);
   TGraph *eventGraphU2 = new TGraph(NROW*NCOL);
   TGraph *eventGraphU3 = new TGraph(NROW*NCOL);
   TGraph *eventGraphU4 = new TGraph(NROW*NCOL);
   TH1F *eventHistU1 = new TH1F("eventHistU1","U1",bins,low,high);
   TH1F *eventHistU2 = new TH1F("eventHistU2","U2",bins,low,high);
   eventHistU2->SetLineColor(kRed);
   TH1F *eventHistU3 = new TH1F("eventHistU3","U3",bins,low,high);
   eventHistU3->SetLineColor(kMagenta);
   TH1F *eventHistU4 = new TH1F("eventHistU4","U4",bins,low,high);
   eventHistU4->SetLineColor(kGreen);
   TH1 *fft = NULL;
   TCanvas *C;
   if (visualize) {
      C = new TCanvas();
      C->Divide(1,2);
      C->cd(1)->Divide(2,1);
   }

   cout << "Entering event loop..." << endl;
   while(fin && fin_tuple) {
      bool fail = false;
      fail = AccumulateEvent(fin_tuple, chs[0], pedestalsU1, tree, false);
      fail = AccumulateEvent(fin_tuple, chs[1], pedestalsU2, tree, false);
      fail = AccumulateEvent(fin_tuple, chs[2], pedestalsU3, tree, false);
      fail = AccumulateEvent(fin_tuple, chs[3], pedestalsU4, tree, true);
      if (fail) break;
      if (fft) {
         delete fft;
         fft = NULL;
      }
      if (visualize) {
         int pos = fin.tellg();
         DrawEvent(fin,chs[0],pedestalsU1,eventGraphU1,eventHistU1);
         fin.seekg(pos);
         DrawEvent(fin,chs[1],pedestalsU2,eventGraphU2,eventHistU2);
         fin.seekg(pos);
         DrawEvent(fin,chs[2],pedestalsU3,eventGraphU3,eventHistU3);
         fin.seekg(pos);
         DrawEvent(fin,chs[3],pedestalsU4,eventGraphU4,eventHistU4);
         fft = CalcFFT(eventGraphU1);
         C->cd(1)->cd(1);
         eventGraphU1->Draw("APL");
         eventGraphU1->GetXaxis()->SetTitle("time [us]");
         eventGraphU1->SetTitle("waveforms");
         eventGraphU2->SetLineColor(kRed);
         eventGraphU2->SetMarkerColor(kRed);
         eventGraphU2->Draw("PL");
         eventGraphU3->SetLineColor(kMagenta);
         eventGraphU3->SetMarkerColor(kMagenta);
         eventGraphU3->Draw("PL");
         eventGraphU4->SetLineColor(kGreen);
         eventGraphU4->SetMarkerColor(kGreen);
         eventGraphU4->Draw("PL");
         C->cd(1)->cd(2);
         eventHistU1->Draw();
         eventHistU2->Draw("same");
         eventHistU3->Draw("same");
         eventHistU4->Draw("same");
         C->cd(2);
         fft->Draw();
         fft->GetXaxis()->SetRangeUser(0,2.5);
         C->Update();
         gSystem->ProcessEvents();
         C->WaitPrimitive();
      }
   }

   if (f1) {
      f1->Write();
   }
   f1->Close();

}

float* CalculatePedestals(ifstream &fin, unsigned int ch, int nevents) {

   float *pedestals = new float[NROW*NCOL]();

   int pos = fin.tellg();

   unsigned int *event_buffer = new unsigned int[NUMWORDS];
   unsigned short int *adc_buffer = (unsigned short int *) &(event_buffer[NHEADERS]);
   unsigned int size = 0;

   //Skip first frame, it's often garbage anyway
   fin.read( (char *) &size, sizeof(unsigned int) );
   fin.read( (char *) event_buffer, NUMWORDS*sizeof(unsigned int) );

   if (!fin) {
      cout << "Skipping pedestals for channel " << ch << endl;
      delete [] event_buffer;
      return pedestals;
   }


   for (int i = 0; i < nevents; ++i) {
      fin.read( (char *) &size, sizeof(unsigned int) );
      if (size != NUMWORDS) {
         cout << "WARNING!  Size did not match expected size!" << endl;
      }
      fin.read( (char *) event_buffer, NUMWORDS*sizeof(unsigned int) );
      for (int row = 0; row < NROW; ++row) {
         for (int col = 0; col < NCOL; ++col) {
            int temp_col = col;
            if (channel_map[ch] > 7) {
               temp_col = (NCOL-1)-col;
            }
            float value = (float) adc_buffer[row*768*2+channel_map[ch]*NCOL+temp_col];
            pedestals[row*NCOL+col] += value;
         }
      }
   }

   for (int i = 0; i < NROW*NCOL; ++i) {
      pedestals[i] /= (float) (nevents);
   }

   fin.seekg(pos);

   delete [] event_buffer;
   return pedestals;
}

void DrawEvent(ifstream &fin, unsigned int ch, float *pedestals, TGraph *graph, TH1F *hist) {
   unsigned int *event_buffer = new unsigned int[NUMWORDS];
   unsigned int size = 0;
   fin.read( (char *) &size, sizeof(unsigned int) );
   if (size != NUMWORDS) {
      cout << "WARNING!  Size did not match expected size!" << endl;
   }
   fin.read( (char *) event_buffer, NUMWORDS*sizeof(unsigned int) );
   unsigned short int *adc_buffer = (unsigned short int *) &(event_buffer[NHEADERS]);
   hist->Reset();

   for (int row = 0; row < NROW; ++row) {
      for (int col = 0; col < NCOL; ++col) {
         int temp_col = col;
         if (channel_map[ch] > 7) {
            temp_col = (NCOL-1)-col;
         }
         float value = (float) adc_buffer[row*NCOL*NCH+channel_map[ch]*NCOL+temp_col];
         value -= pedestals[row*NCOL+col];
         graph->SetPoint(row*NCOL+col,float(row*NCOL+col)*0.2,value);
         hist->Fill(value);
      }
   }
   
   delete [] event_buffer;
}

bool AccumulateEvent(ifstream &fin, unsigned int ch, float *pedestals, TTree *tree, bool advance) {
   int pos = fin.tellg();


   static int event = 0;
   static int col = 0;
   static int row = 0;
   static int temp_ch;
   temp_ch = ch;
   static float value = 0;

   static bool first = true;
   if (first) {
      tree->Branch("event", &event  , "event/I");
      tree->Branch(  "col", &col    , "col/I");
      tree->Branch(  "row", &row    , "row/I");
      tree->Branch(   "ch", &temp_ch, "ch/I");
      tree->Branch(  "adc", &value  , "adc/F");
      first = false;
   }

   unsigned int *event_buffer = new unsigned int[NUMWORDS];
   unsigned int size = 0;
   fin.read( (char *) &size, sizeof(unsigned int) );
   if (!fin) {
      cout << "WARNING!  Read from file failed." << endl;
      return true;
   }
   if (size != NUMWORDS) {
      cout << "WARNING!  Size did not match expected size!  Skipping event." << endl;
      return false;
   }
   fin.read( (char *) event_buffer, NUMWORDS*sizeof(unsigned int) );
   static unsigned int lastAcqCount = event_buffer[1];
   static unsigned int lastSeqCount = event_buffer[2];

   unsigned int acqCount = event_buffer[1];
   unsigned int seqCount = event_buffer[2];
   
   if (acqCount - lastAcqCount > 1 || seqCount - lastSeqCount > 1) {
      cout << "sync slip? this, last acq: " << acqCount << " , " << lastAcqCount << endl;
      cout << "           this, last seq: " << seqCount << " , " << lastSeqCount << endl;
   }
   lastAcqCount = acqCount;
   lastSeqCount = seqCount;

   unsigned short int *adc_buffer = (unsigned short int *) &(event_buffer[NHEADERS]);

   for (row = 0; row < NROW; ++row) {
      for (col = 0; col < NCOL; ++col) {
         int temp_col = col;
         if (channel_map[ch] > 7) {
            temp_col = (NCOL-1)-col;
         }
         value = (float) adc_buffer[row*768*2+channel_map[ch]*NCOL+temp_col];
         value -= pedestals[row*NCOL+col];
      
         tree->Fill();   
      }
   }
   
   if (!advance) {
      fin.seekg(pos);
   } else {
      event++;
   }

   delete [] event_buffer;
   
   return false;

}

TH1 *CalcFFT(TGraph *graph) {
   TH1F *hist = new TH1F("hist","hist",graph->GetN(),0,float(graph->GetN())*0.200);
   TH1F *fft  = new TH1F("fft","fft",graph->GetN(),0,5);
   double *y = graph->GetY();
   for (int i = 0; i < graph->GetN(); ++i) {
      hist->SetBinContent(i+1,y[i]);
   }
   fft = (TH1F *) hist->FFT(fft,"MAG R2C");
   delete hist;
   return fft;
}

