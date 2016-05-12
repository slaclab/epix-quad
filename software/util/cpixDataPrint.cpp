//-----------------------------------------------------------------------------
// File          : cspadGui.cpp
// Author        : Ryan Herbst  <rherbst@slac.stanford.edu>
// Created       : 04/12/2011
// Project       : CSPAD
//-----------------------------------------------------------------------------
// Description :
// Server application for GUI
//-----------------------------------------------------------------------------
// Copyright (c) 2011 by SLAC. All rights reserved.
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
#define PIX_THRESHOLD 50

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
      //unsigned long int bytes = 0;

      dread_ = new DataRead;
      event_ = new Data;

      dread_->openShared("epix",1);
      
      printf("Waiting for data\n");
      
      while (!stop) {
         
         if ( dread_->next(event_)) {
           
           
            // do something with data:
            dsize_ = event_->size(); // 32 bit values
            
            if (dsize_>HEADER_SIZE+FOOTER_SIZE+1) {
               printf("Payload size %d 32-bit words. Packet size %d 32-bit words. Acq %d, seq %d, cnt%c\n", dsize_-(HEADER_SIZE+FOOTER_SIZE+1), dsize_, event_->data()[1], event_->data()[2], (event_->data()[HEADER_SIZE]&0xf0)!=0?'A':'B');
               string fileName = "/u1/mkwiatko/CPIX_data.bin";
               frameFile.open (fileName.c_str(), ios::out | ios::binary);
               frameFile.write ((char*)event_->data(), dsize_*4);
               frameFile.close();
            }
            else {
               printf("Empty packet size %d 32-bit words. Acq %d, seq %d\n", dsize_, event_->data()[1], event_->data()[2]);
            }
            
            for (int x = HEADER_SIZE+1, i=1; x < event_->size() - FOOTER_SIZE; x++, i++) {
               //if (i < 4) {
               //   cout << "0x" << hex << setw(4) << setfill('0') << (event_->data()[x]&0x0000ffff) << "    ";
               //   cout << "0x" << hex << setw(4) << setfill('0') << ((event_->data()[x]&0xffff0000)>>16) << "    ";
               //}
               
               printf("%c", ((event_->data()[x]&0x0000ffff)>PIX_THRESHOLD?'1':'0') );
               printf("%c", (((event_->data()[x]&0xffff0000)>>16)>PIX_THRESHOLD?'1':'0') );
               
               if (!(i%24)) 
                  printf("\n");
               
            }
            if (dsize_>HEADER_SIZE+FOOTER_SIZE+1)
               cout << endl;
            
            
            
            

            
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

