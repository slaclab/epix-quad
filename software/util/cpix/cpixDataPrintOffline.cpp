//-----------------------------------------------------------------------------
// File          : cspadGui.cpp
// Author        : Ryan Herbst  <rherbst@slac.stanford.edu>
// Created       : 04/12/2011
// Project       : CSPAD
//-----------------------------------------------------------------------------
// Description :
// Server application for GUI
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
// 04/12/2011: created
//----------------------------------------------------------------------------
#include <PgpLink.h>
#include <ControlServer.h>
#include <Device.h>
#include <iomanip>
#include <fstream>
#include <iostream>
#include <signal.h>
#include <pthread.h>
#include <Data.h>
#include <DataRead.h>

using namespace std;

#define HEADER_SIZE (14)
#define FOOTER_SIZE (1)

#define FRAME_SIZE (1168)
#define ACQ_OFFSET (1)
#define SEQ_OFFSET (2)



int main (int argc, char **argv) {
   
   streampos size;
   char * memblock;

   try {

      ifstream frameFile;
      //unsigned long int bytes = 0;
      
      frameFile.open ("/u1/mkwiatko/CPIX_TESTS/05162016_testNo2/CPIX_051616_cntB_Pulser_339.bin", ios::in|ios::binary|ios::ate);
      
      if (frameFile.is_open())
      {
         size = frameFile.tellg();
         memblock = new char [size];
         frameFile.seekg (0, ios::beg);
         frameFile.read (memblock, size);
         frameFile.close();
         
         //printf("size %d\n", size);
         
         //for (int i=0; i<20 && (i+1)*FRAME_SIZE*4 <= size; i++) {
         for (int i=0; i<20; i++) {
            
            printf("Frame %d, acqCnt %d, seqCnt %d\n", i, ((uint*)memblock)[i*FRAME_SIZE+ACQ_OFFSET], ((uint*)memblock)[i*FRAME_SIZE+SEQ_OFFSET]);
            
         }
         
         
         
         cout << "the entire file content is in memory" << endl;
   
         delete[] memblock;
      }
      else cout << "Unable to open file" << endl;
      
      
   } catch ( string error ) {
      cout << "Caught Error: " << endl;
      cout << error << endl;
   }
}

