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
#define PRINT_FIRST_PIXELS 0
#define PRINT_ALL_PIXELS_THRESHOLD 0
#define PRINT_ALL_PIXELS_VALUES 1
#define PIXEL_THRESHOLD 10000

// Run flag for sig catch
bool stop;

// Function to catch cntrl-c
void sigTerm (int) { 
   cout << "Got Signal!" << endl;
   stop = true; 
}

char cpixPixelThreshold(int pixel, int pixThreshold) {
   
   if (pixel < pixThreshold)
      return '0';
   else
      return '1';
}


int main (int argc, char **argv) {
   
   stop = false;
   
   // Catch signals
   signal (SIGINT,&sigTerm);

   try {

      DataRead  *dread_;
      Data      *event_;
      uint       dsize_;
      uint       seqNum;
      bool       first;
      ofstream frameFile;
      //unsigned long int bytes = 0;

      dread_ = new DataRead;
      event_ = new Data;

      dread_->openShared("epix",1);
      
      printf("Waiting for data\n");
      
      first = true;
      
      while (!stop) {
         
         if ( dread_->next(event_)) {
           
           
            // do something with data:
            dsize_ = event_->size(); // 32 bit values
            
            if (dsize_==1168) {
               
               
               //drop frames following failed acquisitions
               //it is related to (possibly ASIC bug) the counter not being reset properly after a SACI command
               if(first) {
                  seqNum = event_->data()[2];
                  if ((event_->data()[HEADER_SIZE]&0xf0)==0) // cntB
                     first = false; //make sure to start with good cntA
                  continue;
               }
               if (event_->data()[2] != seqNum+1) {
                  printf("Dropping frame seqNo %d that arrived after frame seqNo %d\n", event_->data()[2], seqNum);
                  if ((event_->data()[HEADER_SIZE]&0xf0)!=0) // cntA
                     first = true; // drop also cntB
                  seqNum = event_->data()[2];
                  continue;
               }
               else {
                  seqNum = event_->data()[2];
               }
               
               
               //print packet size
               printf("Payload size %d 32-bit words. Packet size %d 32-bit words. Acq %d, seq %d, ASIC %d, cnt%c\n", dsize_-(HEADER_SIZE+FOOTER_SIZE+1), dsize_, event_->data()[1], event_->data()[2], (event_->data()[HEADER_SIZE]&0xf), (event_->data()[HEADER_SIZE]&0xf0)!=0?'A':'B');
               string fileName = "/u1/mkwiatko/CPIX_data.bin";
               
               // save last frame
               frameFile.open (fileName.c_str(), ios::out | ios::binary);
               frameFile.write ((char*)event_->data(), dsize_*4);
               frameFile.close();
               
               // print packet content
               for (int x = HEADER_SIZE+1, i=1; x < event_->size() - FOOTER_SIZE; x++, i++) {
                  
                  if (PRINT_FIRST_PIXELS) {
                     if (i < 4) {
                        cout << "0x" << hex << setw(4) << setfill('0') << (event_->data()[x]&0x0000ffff) << "    ";
                        cout << "0x" << hex << setw(4) << setfill('0') << ((event_->data()[x]&0xffff0000)>>16) << "    ";
                     }
                     if (i==4)
                        cout << endl;
                  }
                  else if (PRINT_ALL_PIXELS_THRESHOLD) {
                  
                     printf("%c", cpixPixelThreshold(((event_->data()[x]&0x0000ffff)), PIXEL_THRESHOLD));
                     printf("%c", cpixPixelThreshold(((event_->data()[x]&0xffff0000)>>16), PIXEL_THRESHOLD)); 
                  
                     if (!(i%24)) 
                        printf("\n");
                  }
                  else if (PRINT_ALL_PIXELS_VALUES) {
                  
                     printf("%4.4X", (event_->data()[x]&0x0000ffff));
                     printf("%4.4X", (event_->data()[x]&0xffff0000)>>16);
                  
                     if (!(i%24)) 
                        printf("\n");
                  }
               }
            }
            else if (dsize_ >= HEADER_SIZE) {
               printf("Wrong size packet %d 32-bit words. Acq %d, seq %d, ASIC %d, cnt%c\n", dsize_, event_->data()[1], event_->data()[2], (event_->data()[HEADER_SIZE]&0xf), (event_->data()[HEADER_SIZE]&0xf0)!=0?'A':'B');
            }
            else {
               printf("Wrong size packet %d 32-bit words.\n", dsize_);
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

