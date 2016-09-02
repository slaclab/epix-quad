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

#define PACKET_SIZE 17

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
      ofstream frameFile;

      dread_ = new DataRead;
      event_ = new Data;

      dread_->openShared("epix",1);
      
      printf("Waiting for data\n");
      
      while (!stop) {
         
         if ( dread_->next(event_)) {
            
            dsize_ = event_->size(); // 32 bit values
            
            if (dsize_==PACKET_SIZE) {
               
               if ((event_->data()[0]&0xF) == 0x3) {    // check if VC=3
                  
                  printf("Received size %d, sequence no %d\n", dsize_, (event_->data()[2]));

                  printf("Temperature 1 [C]: %f\n", (double)((int)event_->data()[8])/100);
                  printf("Temperature 2 [C]: %f\n", (double)((int)event_->data()[9])/100);
                  printf("Humidity [%%]: %f\n", (double)(event_->data()[10])/100);
                  printf("ASIC analog current [mA]: %d\n", (event_->data()[11]));
                  printf("ASIC digital current [mA]: %d\n", (event_->data()[12]));
                  printf("ASIC guad ring current [uA]: %d\n", (event_->data()[13]));
                  printf("Analog input voltage [mV]: %d\n", (event_->data()[14]));
                  printf("Digital input voltage [mV]: %d\n", (event_->data()[15]));
               }
            }
            
            timespec tv;
            tv.tv_sec = 0;
            tv.tv_nsec = 1000000;
            nanosleep(&tv,0);

         }
      }
      
      exit(0);
      

   } catch ( string error ) {
      cout << "Caught Error: " << endl;
      cout << error << endl;
   }
}

