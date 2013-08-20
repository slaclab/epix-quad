#include <fstream>
#include <string>
#include <iostream>
#include "TH1F.h"

#define WORD_HEADER 0x01234567
#define EVENT_SIZE 100

using namespace std;

int debug = 0;

void StripFile(char *file_in) {

   TH1F *hist = new TH1F("hist","hist",1000,8000,9000);

   ifstream fin(file_in);

   UInt_t current_word;
   fin.read((char*) &current_word,sizeof(UInt_t));

   while (fin) {
      while (current_word != WORD_HEADER && fin) {
         //Read next byte and shift in to the word
         UChar_t next_byte;
         fin.read((char*) &next_byte,sizeof(UChar_t));
         current_word = (current_word >> 8) | (next_byte << 24);
      }
      if (!fin) {
         break;
      }
      UInt_t data_words[EVENT_SIZE];
      fin.read((char *) data_words,sizeof(UInt_t)*EVENT_SIZE);

      for (int i = 0; i < EVENT_SIZE; ++i) {
         hist->Fill(data_words[i]);
      }

      if (debug) {
         cout << "----------" << endl;
         for (int i = 0; i < EVENT_SIZE; ++i) {
            char output[16];
            sprintf(output,"%08x",data_words[i]);
            cout << output << endl;
         }
         cout << "----------" << endl;
      }

      fin.read((char *) &current_word,sizeof(UInt_t));
   }

   hist->Draw();

}
