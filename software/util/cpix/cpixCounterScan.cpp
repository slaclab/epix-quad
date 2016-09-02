//-----------------------------------------------------------------------------
// File          : cpixCounterScan.cpp
// Author        : Maciej Kwiatkowski  <mkwiatko@slac.stanford.edu>
// Created       : 04/12/2011
// Project       : CSPAD
//-----------------------------------------------------------------------------
// Description :
// Test procedure to scan the full range of the CPIX counters. It keeps the 
// acquisition time window constant by increasing the trigger frequency and 
// inreasing the Nruns (counts) number accordingly
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
#include <math.h>

using namespace std;

#define HEADER_SIZE 14
#define FOOTER_SIZE 1

#define EVENTS_PER_FRAME 5
#define FRAMES_PER_STEP 4

#define NRUNS_START 100
#define NRUNS_STOP 32700
#define NRUNS_STEP 100

#define TIME_WINDOW_FREQ 10  //10Hz

#define MATRIX_TRM_START 0x7
#define MATRIX_TEST_BIT 0x0
#define MATRIX_TEST_ROW 10
#define MATRIX_TEST_COL 7

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
      string        defFile = "xml/cpix_1_async_mode_cnt_scan.xml";
      uint          baseAddress;
      uint          addrSize;
      unsigned int  value;
      int           cntAevent;
      int           cntBevent;
      int           cntAframe;
      int           cntBframe;
      int           matrixTrm;
      
      int nRuns;
      int fSet;
      
      baseAddress = 0x00000000;
      addrSize = 4;
      dest = new MultDestPgp("/dev/pgpcard0");
      dest->addDataSource(0x00000000); // VC0 - acq data
      dest->addDataSource(0x02000000); // VC2 - oscilloscope
      pgpLink = new MultLink();
      pgpLink->setDebug(false);
      pgpLink->setMaxRxTx(0x800000);
      pgpLink->open(1,dest);
      pgpLink->enableSharedMemory("epix",1);   
      usleep(100);

      cout << "Created PGP Link" << endl;

      EpixControl   epix(pgpLink,defFile,CPIXP, baseAddress, addrSize);
      epix.setDebug(false);
      epix.command("SetDefaults", "");

      DataRead  *dread_;
      Data      *event_;
      uint       dsize_;
      //unsigned long int bytes = 0;

      dread_ = new DataRead;
      event_ = new Data;

      dread_->openShared("epix",1);
      
      matrixTrm = MATRIX_TRM_START;
      
      //stop auto run to config the matrix
      epix.device("digFpga",0)->writeSingle("AutoRunEnable", 0);
      
      //set the initial matrix config
      printf("Setting matrich config bits to 0x%X\n", MATRIX_TEST_BIT | (matrixTrm<<2));
      epix.device("digFpga",0)->device("CpixPAsic",0)->writeSingle("PrepareMultiConfig", 0);
      epix.device("digFpga",0)->device("CpixPAsic",0)->writeSingle("WriteMatrixData", MATRIX_TEST_BIT | (matrixTrm<<2) );
      epix.device("digFpga",0)->device("CpixPAsic",0)->writeSingle("CmdPrepForRead", 0);
      
      //set selected column and row if required
      if (MATRIX_TEST_ROW > 0 && MATRIX_TEST_ROW <= 47) {
         epix.device("digFpga",0)->device("CpixPAsic",0)->writeSingle("PrepareMultiConfig", 0);
         epix.device("digFpga",0)->device("CpixPAsic",0)->writeSingle("RowCounter", MATRIX_TEST_ROW);
         epix.device("digFpga",0)->device("CpixPAsic",0)->writeSingle("WriteRowData", 0x1 | (matrixTrm<<2));
      }
      if (MATRIX_TEST_COL > 0 && MATRIX_TEST_COL <= 47) {
         epix.device("digFpga",0)->device("CpixPAsic",0)->writeSingle("PrepareMultiConfig", 0);
         epix.device("digFpga",0)->device("CpixPAsic",0)->writeSingle("ColCounter", MATRIX_TEST_COL);
         epix.device("digFpga",0)->device("CpixPAsic",0)->writeSingle("WriteColData", 0x1 | (matrixTrm<<2));
      }
      
      
      //set the initial Nruns and the trigger frequency
      
      nRuns = NRUNS_START;
      fSet = (int)round((1.0 / (TIME_WINDOW_FREQ * nRuns)) / 0.00000001);
      
      epix.device("digFpga",0)->device("DigFpgaCpix",0)->writeSingle("cpixNRuns", nRuns);
      epix.device("digFpga",0)->writeSingle("AutoRunPeriod", fSet);
      printf("Nruns set to %d\n", nRuns);
      printf("Auto run period set to %d\n", fSet);
      
      //start auto run when done
      epix.device("digFpga",0)->writeSingle("AutoRunEnable", 1);
      
      
      time_t current_time;
      struct tm * time_info;
      char timeString[128];

      time(&current_time);
      time_info = localtime(&current_time);

      strftime(timeString, 128, "%m%d%y", time_info);
      
      ofstream frameFile;
      
      printf("Waiting for data\n");
      
      cntAevent = 0;
      cntBevent = 0;
      
      cntAframe = 0;
      cntBframe = 0;
      
      while (!stop) {
         
         if ( dread_->next(event_)) {
           
            
            // do something with data:
            dsize_ = event_->size(); // 32 bit values
            
            if (dsize_==1168) {
               
               //print packet size
               printf("Payload size %d 32-bit words. Packet size %d 32-bit words. Acq %d, seq %d, ASIC %d, cnt%c\n", dsize_-(HEADER_SIZE+FOOTER_SIZE+1), dsize_, event_->data()[1], event_->data()[2], (event_->data()[HEADER_SIZE]&0xf), (event_->data()[HEADER_SIZE]&0xf0)!=0?'A':'B');
            
               //print a couple of pixels
               for (int x = HEADER_SIZE+1, i=0; x < event_->size() - FOOTER_SIZE; x++, i++) {
                  if (i < 4) {
                     cout << "0x" << hex << setw(4) << setfill('0') << (event_->data()[x]&0x0000ffff) << "    ";
                     cout << "0x" << hex << setw(4) << setfill('0') << ((event_->data()[x]&0xffff0000)>>16) << "    ";
                  }
               }
               
               //Not empty frame was received
               if (dsize_>HEADER_SIZE+FOOTER_SIZE+1) {
                  
                  cout << endl;
                  
                  //Frame with cntA was received
                  if ((event_->data()[HEADER_SIZE]&0xf0)!=0) {
                     cntAevent++;
                     if (!(cntAevent%EVENTS_PER_FRAME)) {
                        if (cntAframe < FRAMES_PER_STEP) {
                           // save the file
                           ostringstream cnvN;
                           cnvN << nRuns;
                           string fileName = "/u1/mkwiatko/CPIX_" + string(timeString) + "_cntA_nRuns_" + cnvN.str() + ".bin";
                           frameFile.open (fileName.c_str(), ios::out | ios::binary | ios::app);
                           frameFile.write ((char*)event_->data(), dsize_*4);
                           frameFile.close();
                           // move the nRuns to the next value
                           cntAframe++;
                        }
                     }
                  }
                  //Frame with cntB was received
                  else {
                     cntBevent++;
                     if (!(cntBevent%EVENTS_PER_FRAME)) {
                        if (cntBframe < FRAMES_PER_STEP) {
                           // save the file
                           ostringstream cnvN;
                           cnvN << nRuns;
                           string fileName = "/u1/mkwiatko/CPIX_" + string(timeString) + "_cntB_nRuns_" + cnvN.str() + ".bin";
                           frameFile.open (fileName.c_str(), ios::out | ios::binary | ios::app);
                           frameFile.write ((char*)event_->data(), dsize_*4);
                           frameFile.close();
                           // move the threshold to the next value
                           cntBframe++;
                        }
                     }
                  }
                  
                  if (cntAframe >= FRAMES_PER_STEP-1 && cntBframe >= FRAMES_PER_STEP-1) {
                     epix.device("digFpga",0)->writeSingle("AutoRunEnable", 0);
                     cntAframe = 0;
                     cntBframe = 0;
                     nRuns += NRUNS_STEP;
                     fSet = (int)round((1.0 / (TIME_WINDOW_FREQ * nRuns)) / 0.00000001);
                     epix.device("digFpga",0)->device("DigFpgaCpix",0)->writeSingle("cpixNRuns", nRuns);
                     epix.device("digFpga",0)->writeSingle("AutoRunPeriod", fSet);
                     printf("Nruns set to %d\n", nRuns);
                     printf("Auto run period set to %d\n", fSet);
                     epix.device("digFpga",0)->writeSingle("AutoRunEnable", 1);
                  }
                  
                  
               }
               
               if (nRuns > NRUNS_STOP) {
                  printf("Testing finished!\n");
                  break;
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

