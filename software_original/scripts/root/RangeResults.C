#include "TH2F.h"
#include "TGraph.h"
#include "TGraph2D.h"
#include <iostream>
#include <fstream>

using namespace std;

void RangeResults(char *file = "temp.txt", int buffer = 100) {
   int adc_max = pow(2,14)-1;
   int adc_min = 0;
   int vref_adj = 1500;
   int eff_max = adc_max-buffer-vref_adj;
   int eff_min = buffer;

   TGraph *graph = new TGraph();
   TGraph2D *graph2 = new TGraph2D();
   int npoints = 0;
   TH2F *range = new TH2F("range","S2D Optimization:S2D_DAC setting:S2D_GR setting",32,-0.5,31.5,16,-0.5,15.5);
   range->GetXaxis()->SetTitle("S2D_DAC setting [counts]");
   range->GetYaxis()->SetTitle("S2D_GR setting [counts]");

   ifstream fin(file);
   int this_dac, this_gr, this_max, this_min;
   float this_max_rms, this_min_rms;
   float best_quality = 0, best_max, best_min;
   int best_dac, best_gr;
   while (fin >> this_dac >> this_gr >> this_max >> this_min >> this_max_rms >> this_min_rms) {
//      int high = this_max < eff_max ? this_max : eff_max;
//      int low  = this_min > eff_min ? this_min : eff_min;
//      int range = eff_high - eff_low;
      int high = abs(this_max - eff_max);
      int low  = abs(this_min - eff_min);
      int bin = range->FindBin(this_dac,this_gr);
      int ideal_offset = (eff_max+eff_min) / 2 - vref_adj/2;
      int ideal_range = eff_max - eff_min;
      int this_offset = (this_max + this_min)/2;
      int this_range  = this_max - this_min;
      float quality = sqrt(pow(this_offset - ideal_offset,2) + pow(this_range-ideal_range,2));
      if (this_max < eff_max && this_min > eff_min) {
         if (npoints == 0 || quality < best_quality) {
            best_dac = this_dac;
            best_gr = this_gr;
            best_max = this_max;
            best_min = this_min;
            best_quality = quality;
         }
         graph->SetPoint(npoints,(this_max+this_min)/2,this_max-this_min);
         //graph->SetPoint(npoints,this_offset-ideal_offset,this_range-ideal_range);
         //graph->SetPoint(npoints,npoints,quality);
         graph2->SetPoint(npoints,this_dac,this_gr,quality);
         range->SetBinContent(bin,quality);
         npoints++;
      }
   }
   fin.close();

   cout << "Optimum found at: " << endl;
   cout << "\t GR: " << best_gr << endl;
   cout << "\tDAC: " << best_dac << endl;
   cout << "\tMax: " << best_max << endl;
   cout << "\tMin: " << best_min << endl;
   cout << "\tOff: " << (best_max+best_min)/2 << endl;


   gStyle->SetOptStat(0);
//   range->Draw("colz");
   graph->SetMarkerStyle(8);
   TCanvas *C = new TCanvas();
   graph2->Draw("contz");
   gPad->Update();
   graph2->SetTitle("S2D Optimization");
   graph2->GetXaxis()->SetTitle("S2D_DAC setting");
   graph2->GetYaxis()->SetTitle("S2D_GR setting");
   gPad->Update();
   C->Print("Chip1_S2D.gif");
//   TCanvas *C2 = new TCanvas();
//   graph->Draw("AP");

   //Maximum bin:
   int max_dac, max_gr, dummy;
   range->GetMaximumBin(max_dac,max_gr,dummy);
   cout << "-----" << endl;
   cout << "max: " << range->GetMaximum() << endl;
   cout << "dac: " << range->GetXaxis()->GetBinCenter(max_dac) << endl;
   cout << "gr : " << range->GetXaxis()->GetBinCenter(max_gr) << endl;
   int min_dac, min_gr;
   range->GetMinimumBin(min_dac,min_gr,dummy);
   cout << "-----" << endl;
   cout << "min: " << range->GetMinimum() << endl;
   cout << "dac: " << range->GetXaxis()->GetBinCenter(min_dac) << endl;
   cout << "gr : " << range->GetXaxis()->GetBinCenter(min_gr) << endl;
}
