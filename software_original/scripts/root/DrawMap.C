void DrawMap(char *filename, bool invert_rows=false) {
   ifstream fin(filename);

   TProfile2D *map = new TProfile2D(filename,"map",96,-0.5,95.5,96,-0.5,95.5);

   for (int row = 0; row < 96; ++row) {
      for (int col = 0; col < 96; ++col) {
         float value;
         fin >> value;
         if (invert_rows) {
            map->Fill(col,95-row,value);
         } else {
            map->Fill(col,row,value);
         }
      }
   }

   TCanvas *C = new TCanvas();
   gStyle->SetOptStat(0);
   map->Draw("colz");
   map->GetZaxis()->SetRangeUser(10,14);
}


void DrawMap2(char *filename, char *filename2) {
   ifstream fin(filename);
   ifstream fin2(filename2);

   TProfile2D *map = new TProfile2D(filename,"map",96,-0.5,95.5,96,-0.5,95.5);

   for (int row = 0; row < 96; ++row) {
      for (int col = 0; col < 96; ++col) {
         float value;
         fin >> value;
         float value2;
         fin2 >> value2;
         map->Fill(col,row,value*value2);
      }
   }

   TCanvas *C = new TCanvas();
   map->Draw("colz");
}

void MakeTrees(char *filename, char *filename2) {
   ifstream fin(filename);
   ifstream fin2(filename2);

   int row = 0;
   int col = 0;
   float me = 0;
   float gabriel = 0;
   TTree *tree = new TTree("tree","tree");
   tree->Branch("row",&row,"row/I");
   tree->Branch("col",&col,"col/I");
   tree->Branch("g1",&me,"g1/F");
   tree->Branch("g2",&gabriel,"g2/F");


   for (row = 0; row < 96; ++row) {
      for (col = 0; col < 96; ++col) {
         fin >> me;
         fin2 >> gabriel;
         tree->Fill();
      }
   }

}
