#include "TFile.h"
#include "TTree.h"
#include "TGraph.h"
#include "TH1F.h"
#include "TProfile2D.h"
#include "TF1.h"
#include "TCanvas.h"
#include <fstream>
#include <iostream>
#include <iomanip>

//#define NROW 352
#define NROW 98
#define NCOL 96
#define NCH 16
#define NHEADERS 8
#define NTPSWORDS 2
#define NFOOTERS 1
#define NUMWORDS (NROW*NCOL*NCH/2 + NHEADERS + NTPSWORDS + NFOOTERS)


using namespace std;

void LinearityMap(char *file, int chToAnalyze, char *gainMapOut = NULL) {
   TFile *f1 = new TFile(file);
   TTree *tree = (TTree *) f1->Get("tree");
   int event, col, row, ch;
   float adc;
   tree->SetBranchAddress("event", &event);
   tree->SetBranchAddress(  "col", &col);
   tree->SetBranchAddress(  "row", &row);
   tree->SetBranchAddress(   "ch", &ch);
   tree->SetBranchAddress(  "adc", &adc);

   int max_event = 100;

   TF1 *linearFit = new TF1("linearFit","pol1",0,max_event);
   linearFit->SetLineStyle(kDashed);
   TProfile2D *gainMap = new TProfile2D("gainMap","gainMap",96,-0.5,95.5,98,-0.5,97.5);
   TProfile2D *offsetMap = new TProfile2D("offsetMap","offsetMap",96,-0.5,95.5,98,-0.5,97.5);
   TH1F *gainHistEven = new TH1F("gainHistEven","gainHistEven",100,0.8,1.2);
   TH1F *gainHistOdd = new TH1F("gainHistOdd","gainHistOdd",100,0.8,1.2);

   TGraph *graph[NROW];
   for (int i = 0; i < NROW; ++i) {
      graph[i] = new TGraph(max_event);
   }

   for (int j = 0; j < NCOL; ++j) {
      cout << "Beginning column: " << j << endl;
      for (int k = 0; k < tree->GetEntries(); ++k) {
         tree->GetEntry(k);
         if (ch != chToAnalyze || col != j || row >= NROW) {
            continue;
         }
         if (event > max_event) {
             break;
         }
         graph[row]->SetPoint(event,event,adc);
      }
      for (int i = 0; i < NROW; ++i) {
//         graph[i]->Draw("AP");
//         graph[i]->SetMarkerStyle(6);
         graph[i]->Fit(linearFit);
//         graph[i]->Draw("P");
//         return;
         double c0 = linearFit->GetParameter(0);
         double e0 = linearFit->GetParError(0);
         double c1 = linearFit->GetParameter(1);
         double e1 = linearFit->GetParError(1);
//         int bin = gainMap->FindBin(j,i);
//         gainMap->SetBinContent(bin,c1);
//         gainMap->SetBinError(bin,e1);
//         offsetMap->SetBinContent(bin,c0);
//         offsetMap->SetBinError(bin,e0);
         gainMap->Fill(j,NROW-1-i,c1);
         offsetMap->Fill(j,NROW-1-i,c0);
      }
   }

   double meanGain = gainMap->GetMean(3);
   cout << "Adjusting gains by: " << meanGain << endl;

   gainMap->Scale(1./meanGain);
//   gainMap->Scale(1./1.25);
   gainMap->GetZaxis()->SetRangeUser(0.8,1.2);

   for (int i = 0; i < NROW; ++i) {
      for (int j = 0; j < NCOL; ++j) {
         double value = gainMap->GetBinContent(j+1,i+1);
         if (j%2==0) {
            gainHistEven->Fill(value);
         } else {
            gainHistOdd->Fill(value);
         }
      }
   }

   TCanvas *C0 = new TCanvas();
   gainMap->GetXaxis()->SetTitle("column");
   gainMap->GetYaxis()->SetTitle("97-row");
   gainMap->Draw("colz");
   TCanvas *C1 = new TCanvas();
   gainHistEven->SetLineColor(kRed);
   gainHistOdd->GetXaxis()->SetTitle("normalized gain");
   gainHistOdd->Draw();
   gainHistEven->Draw("sames");

   if (gainMapOut) {
      ofstream fout(gainMapOut);
      for (int i = 0; i < NROW; ++i) {
         for (int j = 0; j < NCOL; ++j) {
            double value = gainMap->GetBinContent(j+1,NROW-1-i+1);
            fout << setiosflags(std::ios::fixed)
                 << setprecision(3)
                 << setw(5)
                 << left
                 << value
                 << " ";
         }
         fout << endl;
      }
      fout.close();
   }


}

