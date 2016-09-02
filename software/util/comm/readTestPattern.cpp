//-----------------------------------------------------------------------------
// File          : readExample.cpp
// Author        : Ryan Herbst  <rherbst@slac.stanford.edu>
// Created       : 12/02/2011
// Project       : Kpix DAQ
//-----------------------------------------------------------------------------
// Description :
// Read data example
//-----------------------------------------------------------------------------
// This file is part of 'EPIX Development Softare'.
// It is subject to the license terms in the LICENSE.txt file found in the 
// top-level directory of this distribution and at: 
//    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
// No part of 'EPIX Development Softare', including this file, 
// may be copied, modified, propagated, or distributed except according to 
// the terms contained in the LICENSE.txt file.
// Proprietary and confidential to SLAC.
//-----------------------------------------------------------------------------
// Modification history :
// 12/02/2011: created
//----------------------------------------------------------------------------
#include <iomanip>
#include <fstream>
#include <iostream>
#include <Data.h>
#include <DataRead.h>
using namespace std;

int main (int argc, char **argv) {
   DataRead   dataRead;
   Data  event;
   uint       x;

   // Check args
   if ( argc != 2 ) {
      cout << "Usage: readExample filename" << endl;
      return(1);
   }

   // Attempt to open data file
   if ( ! dataRead.open(argv[1]) ) return(2);

   // Process each event
   while ( dataRead.next(&event) ) {
     cout <<  endl << endl << "Got Data Size" << event.size() << endl;
     for (x = 0; x < event.size(); x++) {
       if (x < 8) {
         cout << "HEADER: 0x" << hex << setw(8) << setfill('0') << event.data()[x] << endl;
       } else {
         unsigned short int data0 = (event.data()[x] & 0xFFFF);
         unsigned short int data1 = ((event.data()[x] >> 16) & 0xFFFF);
         unsigned short int ch0 = data0 >> 8;
         unsigned short int row0 = (data0 >> 7) & 0x1;
         unsigned short int adc0 = data0 & 0x7F;
         unsigned short int ch1 = data1 >> 8;
         unsigned short int row1 = (data1 >> 7) & 0x1;
         unsigned short int adc1 = data1 & 0x7F;
         cout << dec << ch1 << "\t" << row1 << "\t" << adc1 << endl;
         cout << dec << ch0 << "\t" << row0 << "\t" << adc0 << endl;
       }
     }
      
   }

   // Dump config
   dataRead.dumpConfig();
   dataRead.dumpStatus();

   return(0);
}

