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

#define HEADER_SIZE 14
#define FOOTER_SIZE 1

// Run flag for sig catch
bool stop;

// Function to catch cntrl-c
void sigTerm (int) { 
   cout << "Got Signal!" << endl;
   stop = true; 
}


int main (int argc, char **argv) {
   
   stop = false;
   
   // Catch signals
   signal (SIGINT,&sigTerm);

   try {

      DataRead  *dread_;
      Data      *event_;
      uint       dsize_;
      uint       pixelData[16][48*48];
      uint       pixelDataCorr[48*48];
      uint       acqNo;
      uint       rdOutNo;
      ofstream frameFile;
      //unsigned long int bytes = 0;

      dread_ = new DataRead;
      event_ = new Data;

      dread_->openShared("epix",1);
      
      printf("Waiting for data\n");
      
      acqNo = 0;
      
      while (!stop) {
         
         if ( dread_->next(event_)) {
            
            dsize_ = event_->size(); // 32 bit values
            
            if (dsize_==1168+1152) {
               
               
               // merge data frames after all are read out 
               // and print it
               if (acqNo != 0 && acqNo != event_->data()[1]) {
                  for (uint i = 0; i <= rdOutNo; i++)
                     for (int x = 0; x < 48*48; x++) {
                        
                        if (i == 0) {
                           pixelDataCorr[x] = pixelData[i][x];
                        }
                        else {
                           if ((pixelDataCorr[x]&0x000f0000) != 0) {
                              pixelDataCorr[x] &= 0xfff0ff00;
                              pixelDataCorr[x] |= (pixelData[i][x]&0x000f00ff);
                           }
                           else if ((pixelDataCorr[x]&0x0f000000) != 0) {
                              pixelDataCorr[x] &= 0xf0ff00ff;
                              pixelDataCorr[x] |= (pixelData[i][x]&0x0f00ff00);
                           }
                        }
                     }
                  
                  // print the content
                  for (int x = 0, i=1; x < 48*48; x++, i++) {
                     
                     printf("%4.4X", (pixelDataCorr[x]&0xffff0000)>>16);
                     
                     if (!(i%48)) 
                        printf("\n");
                  }
                  
               }
               
               rdOutNo = (event_->data()[HEADER_SIZE]&0xf0)>>4;
               acqNo = event_->data()[1];
               
               //print packet size info
               printf("Payload size %d 32-bit words. Packet size %d 32-bit words. Acq %d, seq %d, ASIC %d, rdoutNo %d\n", dsize_-(HEADER_SIZE+FOOTER_SIZE+1), dsize_, event_->data()[1], event_->data()[2], (event_->data()[HEADER_SIZE]&0xf), rdOutNo);
               
               // save data frames
               for (int x = HEADER_SIZE+1, i=0; x < event_->size() - FOOTER_SIZE; x++, i++)
                  pixelData[rdOutNo][i] = event_->data()[x];
               
               
               
            }
            else if (dsize_ >= HEADER_SIZE) {
               printf("Wrong size packet %d 32-bit words. Acq %d, seq %d, ASIC %d, cnt%c\n", dsize_, event_->data()[1], event_->data()[2], (event_->data()[HEADER_SIZE]&0xf), (event_->data()[HEADER_SIZE]&0xf0)!=0?'A':'B');
            }
            else {
               printf("Wrong size packet %d 32-bit words.\n", dsize_);
            }

         }
      }
      
      exit(0);
      

   } catch ( string error ) {
      cout << "Caught Error: " << endl;
      cout << error << endl;
   }
}

