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
#define NROW 48
#define NCOL 48
#define NCH 16
#define NHEADERS 8
#define NTPSWORDS 2
#define NFOOTERS 1
#define NUMWORDS (NROW*NCOL*NCH/2 + NHEADERS + NTPSWORDS + NFOOTERS)


using namespace std;

void LinearityMap(char *file, int chToAnalyze, char *gainMapOut = NULL, bool oneRow = false, int rowToFit = 0) {
   cout << "Opening " << file << endl;
   TFile *f1 = new TFile(file);
   TTree *tree = (TTree *) f1->Get("tree");
   int event, col, row, ch;
   float adc;
   tree->SetBranchAddress("event", &event);
   tree->SetBranchAddress(  "col", &col);
   tree->SetBranchAddress(  "row", &row);
   tree->SetBranchAddress(   "ch", &ch);
   tree->SetBranchAddress(  "adc", &adc);

   int min_event = 0;
   int max_event = 40;

   TF1 *linearFit = new TF1("linearFit","pol1",0,max_event);
   linearFit->SetLineStyle(kDashed);
   TProfile2D *gainMap = new TProfile2D("gainMap","gainMap",96,-0.5,95.5,98,-0.5,97.5);
   TProfile2D *chi2Map = new TProfile2D("chi2Map","chi2Map",96,-0.5,95.5,98,-0.5,97.5);
   TH1F *gainHistEven = new TH1F("gainHistEven","gainHistEven",300,10,14);
   TH1F *gainHistOdd = new TH1F("gainHistOdd","gainHistOdd",300,10,14);

   TGraph *graph[NROW];
   for (int i = 0; i < NROW; ++i) {
      graph[i] = new TGraph(max_event);
   }

   for (int j = 0; j < NCOL; ++j) {
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
         if (oneRow && i != rowToFit) {
            continue;
         }
         cout << "Fitting " << i << " " << j << endl;
//         graph[i]->SetMarkerStyle(6);
//         graph[i]->Draw("AP");
         graph[i]->Fit(linearFit);
//         linearFit->SetLineColor(kRed);
//         linearFit->Draw("same");
//         return;
         double c0 = linearFit->GetParameter(0);
         double e0 = linearFit->GetParError(0);
         double c1 = linearFit->GetParameter(1);
         double e1 = linearFit->GetParError(1);
         double chi2 = linearFit->GetChisquare();
//         int bin = gainMap->FindBin(j,i);
//         gainMap->SetBinContent(bin,c1);
//         gainMap->SetBinError(bin,e1);
//         chi2Map->SetBinContent(bin,c0);
//         chi2Map->SetBinError(bin,e0);
         gainMap->Fill(j,NROW-1-i,c1);
         chi2Map->Fill(j,NROW-1-i,chi2);
      }
   }

   double meanGain = gainMap->GetMean(3);
   cout << "Adjusting gains by: " << meanGain << endl;

//   gainMap->Scale(1./meanGain);
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

   if (!oneRow) {
      TCanvas *C0 = new TCanvas();
      gainMap->GetXaxis()->SetTitle("column");
      gainMap->GetYaxis()->SetTitle("97-row");
      gainMap->Draw("colz");
      TCanvas *C1 = new TCanvas();
      gainHistEven->SetLineColor(kRed);
      gainHistOdd->GetXaxis()->SetTitle("normalized gain");
      gainHistOdd->Draw();
      gainHistEven->Draw("sames");
   }

   if (gainMapOut) {
      ofstream fout;
      if (oneRow) {
         fout.open(gainMapOut,ios_base::app);
      } else {
         fout.open(gainMapOut);
      }
      for (int i = 0; i < NROW; ++i) {
         if (oneRow && i != rowToFit) {
            continue;
         }
         for (int j = 0; j < NCOL; ++j) {
            double value = gainMap->GetBinContent(j+1,NROW-1-i+1);
            double chi2  = chi2Map->GetBinContent(j+1,NROW-1-i+1);
            fout << setiosflags(std::ios::fixed)
                 << setprecision(3)
                 << setw(5)
                 << left
                 << value
                 << " "
                 << chi2
                 << endl;
         }
      }
      fout.close();
   }

   f1->Close();
}

