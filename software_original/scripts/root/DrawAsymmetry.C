#include "TFile.h"
#include "TTree.h"
#include "TBranch.h"
#include "TH1F.h"
#include "TGraph.h"
#include "TMultiGraph.h"

double MeasureAsymmetry(char *filename, int chToUse, bool usePercent);

void AsymAll(char *fileOut) {
   TFile *fOut = new TFile(fileOut,"RECREATE");
   TTree *tree = new TTree("tree","Summary Tree");
   int thisCh = 0;
   int acq = 0;
   int pulse = 0;
   double asym = 0;
   double asymPct = 0;
   tree->Branch("ch",&thisCh,"ch/I");
   tree->Branch("acq",&acq,"acq/I");
   tree->Branch("pulse",&pulse,"pulse/I");
   tree->Branch("asym",&asym,"asym/D");
   tree->Branch("asymPct",&asymPct,"asymPct/D");

//   int nCh = 4;
//   int chList[4] = {0,4,8,12};
   int nCh = 1;
   int chList[1] = {12};
   
//   TMultiGraph *allGraphs = new TMultiGraph();

   for (int ch = 0; ch < nCh; ++ch) {
//      TGraph *gr = new TGraph(5);
//      for (acq = 50; acq <= 200; acq += 10) {
      for (acq = 200; acq <= 200; acq += 10) {
//         for (pulse = 200; pulse <= 1000; pulse += 200) {
         for (pulse = 200; pulse <= 1000; pulse += 200) {
            cout << "Processing ch " << ch << " acq " << acq << " pulse " << pulse << endl;
            thisCh = chList[ch];
            char filename[1024];
            //sprintf(filename,"data_rdpc84/20140128/card6.acq%03d.pulse%d.root",acq,pulse);
            sprintf(filename,"data_rdpc84/20140129/cardS1.acq%03d.pulse%d.root",acq,pulse);
            asym = MeasureAsymmetry(filename,thisCh,false);
            asymPct = MeasureAsymmetry(filename,thisCh,true);
            //gr->SetPoint(pulse/200,pulse,asym);
            tree->Fill();
         }
//         gr->SetMarkerStyle(20+ch);
//         allGraphs->Add(gr);   
      }
   } 

//   allGraphs->Draw("APL");
   fOut->Write();
 
}

double MeasureAsymmetry(char *filename, int chToUse, bool usePercent) {
   TFile *f1 = new TFile(filename);
   TTree *tree = (TTree *) f1->Get("tree");
   int event = 0;
   int col = 0;
   int row = 0;
   int ch = 0;
   float adc = 0;

   tree->SetBranchAddress("event",&event);
   tree->SetBranchAddress("col",&col);
   tree->SetBranchAddress("row",&row);
   tree->SetBranchAddress("ch",&ch);
   tree->SetBranchAddress("adc",&adc);

   TH1F *coarse = new TH1F("coarse","coarse",200,1000,15000);
   for (int i = 0; i < tree->GetEntries(); ++i) {
      tree->GetEntry(i);
      if (ch != chToUse) continue;
      coarse->Fill(adc);
   }

   double coarseMax = coarse->GetBinCenter(coarse->GetMaximumBin());
   
   TH1F *fineOdd  = new TH1F("fineOdd","fineOdd",1001,coarseMax-500,coarseMax+500);
   TH1F *fineEven = new TH1F("fineEven","fineEven",1001,coarseMax-500,coarseMax+500);

   for (int i = 0; i < tree->GetEntries(); ++i) {
      tree->GetEntry(i);
      if (ch != chToUse) continue;
      if (col%2 == 0) {
         fineEven->Fill(adc);
      } else {
         fineOdd->Fill(adc);
      }
   }

   double evenMax = fineEven->GetBinCenter(fineEven->GetMaximumBin());
   double oddMax = fineOdd->GetBinCenter(fineOdd->GetMaximumBin());
   double difference = oddMax - evenMax;
   
   if (usePercent) {
      difference = (oddMax - evenMax) / (oddMax + evenMax);
   }
/*
   delete fineOdd;
   delete fineEven;
   delete coarse;
   f1->Close();
*/

   return difference;
}

