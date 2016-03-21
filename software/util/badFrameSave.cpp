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
#include <EpixControl.h>
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
      
      time_t current_time;
      struct tm * time_info;
      char timeString[128];
      ofstream myfile;

      DataRead  *dread_;
      Data      *event_;
      uint       dsize_;

      dread_ = new DataRead;
      event_ = new Data;
      unsigned int epixData;

      dread_->openShared("epix",1);
      
      printf("Waiting for data\n");
      
      //while (bytes < 20000000) {
      while (!stop) {
         
         if ( dread_->next(event_)) {
           
            // do something with data:
            dsize_ = event_->size(); // 32 bit values

            if (dsize_ < 272651) {
               cout << "Got packet of size " << dsize_ << " words" << endl;
               
               time(&current_time);
               time_info = localtime(&current_time);
               strftime(timeString, 128, "%m%d%y%k%M", time_info);
               string fileName = "/u1/mkwiatko/EPIX_bad_frame_" + string(timeString) + ".bin";
               myfile.open (fileName.c_str(), ios::out | ios::binary);
               
               for (int x = 0; x < event_->size(); x++) {
                  epixData = event_->data()[x];
                  myfile.write ((char*)&epixData, sizeof(epixData));
               }
               
               myfile.close();
               
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

