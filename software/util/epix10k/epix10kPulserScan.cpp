//-----------------------------------------------------------------------------
// File          : epix10kPulserScan.cpp
// Author        : Maciej Kwiatkowski  <mkwiatko@slac.stanford.edu>
// Created       : 08/10/2016
// Project       : Epix10k
//-----------------------------------------------------------------------------
// Description :
//-----------------------------------------------------------------------------
// Copyright (c) 2011 by SLAC. All rights reserved.
// Proprietary and confidential to SLAC.
//-----------------------------------------------------------------------------
// Modification history :
// 08/10/2016: created
//----------------------------------------------------------------------------
#include <PgpLink.h>
#include <MultDestPgp.h>
#include <MultLink.h>
#include <EpixControl.h>
#include <ControlServer.h>
#include <Device.h>
#include <iomanip>
#include <fstream>
#include <iostream>
#include <signal.h>
#include <string>
#include <pthread.h>
#include <Data.h>
#include <DataRead.h>

using namespace std;

#define ASIC_NO 3
#define FRAMES_PER_FILE 1

#define PULSER_START 0
#define PULSER_STOP 1023
#define PULSER_STEP 1

#define MATRIX_TEST_BIT 0x1

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
      
      MultLink     *pgpLink;
      MultDest     *dest;  
      string        defFile = "xml/epix10kp_u1_u4.xml";
      uint          baseAddress;
      uint          addrSize;
      unsigned int  value;
      int           pulser;
      
      
      baseAddress = 0x00000000;
      addrSize = 4;
      dest = new MultDestPgp("/dev/pgpcard0");
      dest->addDataSource(0x00000000); // VC0 - acq data
      pgpLink = new MultLink();
      pgpLink->setDebug(false);
      pgpLink->setMaxRxTx(0x800000);
      pgpLink->open(1,dest);
      pgpLink->enableSharedMemory("epix",1);   
      usleep(100);

      cout << "Created PGP Link" << endl;

      EpixControl   epix(pgpLink, defFile, EPIX10KP, baseAddress, addrSize);
      epix.setDebug(false);
      epix.command("SetDefaults", "");

      DataRead  *dread_;
      Data      *event_;
      uint       dsize_;
      uint       frameCnt;
      
      //unsigned long int bytes = 0;

      dread_ = new DataRead;
      event_ = new Data;

      dread_->openShared("epix",1);
      
      pulser = PULSER_START;
      
      //stop auto run to config the matrix
      epix.device("digFpga",0)->writeSingle("AutoRunEnable", 0);
      
      //set the initial matrix config
      printf("Setting matrix config bits to 0x%X\n", MATRIX_TEST_BIT);
      for (int i=0; i < 48; i++){
         epix.device("digFpga",0)->device("epix10kpAsic",ASIC_NO)->writeSingle("PrepareMultiConfig", 0);
         epix.device("digFpga",0)->device("epix10kpAsic",ASIC_NO)->writeSingle("ColCounter", i);
         epix.device("digFpga",0)->device("epix10kpAsic",ASIC_NO)->writeSingle("WriteColData", MATRIX_TEST_BIT);
      }
      epix.device("digFpga",0)->device("epix10kpAsic",ASIC_NO)->writeSingle("CmdPrepForRead", 0);
      
      
      //enable test bit
      value = epix.device("digFpga",0)->device("epix10kpAsic",ASIC_NO)->readSingle("Config3");
      epix.device("digFpga",0)->device("epix10kpAsic",ASIC_NO)->writeSingle("Config3", value | (1<<12)); 
      
      //set pulser here
      printf("Pulser changed to %d\n", pulser);
      value = epix.device("digFpga",0)->device("epix10kpAsic",ASIC_NO)->readSingle("Config3");
      epix.device("digFpga",0)->device("epix10kpAsic",ASIC_NO)->writeSingle("Config3", (value&0xfffffC00)|(pulser&0x3FF)); 
      
      //start auto run when done
      epix.device("digFpga",0)->writeSingle("AutoRunPeriod", 833333);  //120Hz
      epix.device("digFpga",0)->writeSingle("AutoRunEnable", 1);
      epix.device("digFpga",0)->writeSingle("AutoDaqEnable", 1);
      
      
      time_t current_time;
      struct tm * time_info;
      char timeString[128];

      time(&current_time);
      time_info = localtime(&current_time);

      strftime(timeString, 128, "%m%d%y", time_info);
      
      ofstream frameFile;
      
      printf("Waiting for data\n");
      
      while (!stop) {
         
         if ( dread_->next(event_) ) {
            
            dsize_ = event_->size(); // 32 bit values
            
            if (dsize_ == 19595) {
               
               
               //print packet size
               //printf("Packet size %d 32-bit words. Acq %d, seq %d\n", dsize_, (event_->data()[1])&0xFFF, event_->data()[2]);
               
               //Frame with cntA was received
               if (frameCnt <= FRAMES_PER_FILE-1) {
                  frameCnt++;
                  // save the file
                  ostringstream cnvMPul;
                  cnvMPul << pulser;
                  string fileName = "/u1/mkwiatko/EPIX10kp_" + string(timeString) + "_Pulser_" + cnvMPul.str() + ".bin";
                  frameFile.open (fileName.c_str(), ios::out | ios::binary | ios::app);
                  frameFile.write ((char*)event_->data(), dsize_*4);
                  frameFile.close();                  
               }
               // else if all frames are saved
               // move settings as requested
               else {
                  
                  //stop auto run to config the ASIC
                  epix.device("digFpga",0)->writeSingle("AutoRunEnable", 0);
                  
                  frameCnt=0;
                  
                  //move the pulser if not last
                  if (pulser < PULSER_STOP && pulser+PULSER_STEP <= 1023) {
                     pulser+=PULSER_STEP;
                     
                     //set pulser here
                     printf("Pulser changed to %d\n", pulser);
                     value = epix.device("digFpga",0)->device("epix10kpAsic",ASIC_NO)->readSingle("Config3");
                     epix.device("digFpga",0)->device("epix10kpAsic",ASIC_NO)->writeSingle("Config3", (value&0xfffffC00)|(pulser&0x3FF)); 
                     
                  }
                  else {
                     // all pulser steps are done
                     printf("Testing finished!\n");
                     break;
                  }
                  
                  epix.device("digFpga",0)->writeSingle("AutoRunEnable", 1);
                  
               }
               
            }
            else {
               printf("Wrong size packet %d 32-bit words.\n", dsize_);
            }
            
            //timespec tv;
            //tv.tv_sec = 0;
            //tv.tv_nsec = 1000000;
            //nanosleep(&tv,0);

         }
         
         
      }
      
      exit(0);
      

   } catch ( string error ) {
      cout << "Caught Error: " << endl;
      cout << error << endl;
   }
}

