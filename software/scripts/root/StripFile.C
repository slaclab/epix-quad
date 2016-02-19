#include <fstream>
#include <string>
#include <iostream>
#include "TH1F.h"

#define WORD_HEADER 0x01234567
#define EVENT_SIZE 100

using namespace std;

int debug = 0;

void StripFile(char *file_in, char *file_out) {

   ifstream fin(file_in);
   ofstream fout(file_out);
   int nevents = 0;

   while (fin && nevents < 1000) {
      UInt_t size;
      fin.read((char*) &size,sizeof(UInt_t));
      if (fin) {
         UInt_t *buffer = new UInt_t[size];
         fin.read((char*) buffer, sizeof(UInt_t)*size);
         fout.write((char *) buffer, sizeof(UInt_t)*size);
         delete [] buffer;
         nevents++;
         if (nevents%100 == 0) {
            cout << "Wrote event " << nevents << endl;
         }
      }
   }

   fin.close();
   fout.close();

}
