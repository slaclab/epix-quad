//-----------------------------------------------------------------------------
// File          : cpixThresholdScan.cpp
// Author        : Maciej Kwiatkowski  <mkwiatko@slac.stanford.edu>
// Created       : 04/12/2011
// Project       : CSPAD
//-----------------------------------------------------------------------------
// Description :
//-----------------------------------------------------------------------------
// Copyright (c) 2011 by SLAC. All rights reserved.
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

using namespace std;

#define HEADER_SIZE 14
#define FOOTER_SIZE 1

#define EVENTS_PER_FRAME 1
#define FRAMES_PER_THRESHOLD 32
#define COMP_TH1_START 0
#define COMP_TH2_START 0
#define COMP_TH1_STOP 46
#define COMP_TH2_STOP 46
#define MATRIX_TRM_START 0x0
#define MATRIX_TRM_STOP 0xF
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
      string        defFile = "xml/cpix_1_async_mode.xml";
      uint          baseAddress;
      uint          addrSize;
      unsigned int  value;
      int           cntAevent;
      int           cntBevent;
      int           cntAframe;
      int           cntBframe;
      int           compTh1DAC;
      int           compTh2DAC;
      int           matrixTrm;
      
      
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
      
      compTh1DAC = COMP_TH1_START;
      compTh2DAC = COMP_TH2_START;
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
      
      //set initial ASIC thresholds
      printf("Threshold (A) compTh1DAC changed to %d\n", compTh1DAC);
      printf("Threshold (B) compTh2DAC changed to %d\n", compTh2DAC);
      value = epix.device("digFpga",0)->device("CpixPAsic",0)->readSingle("Config1");
      epix.device("digFpga",0)->device("CpixPAsic",0)->writeSingle("Config1", (value&0xffffffC0)|(compTh1DAC&0x3F));
      value = epix.device("digFpga",0)->device("CpixPAsic",0)->readSingle("Config12");
      epix.device("digFpga",0)->device("CpixPAsic",0)->writeSingle("Config12",(value&0xffffffC0)|(compTh2DAC&0x3F));
      
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
            
            if (dsize_>HEADER_SIZE+FOOTER_SIZE+1) 
               printf("Payload size %d 32-bit words. Packet size %d 32-bit words. Acq %d, seq %d, cnt%c, %d\n", dsize_-(HEADER_SIZE+FOOTER_SIZE+1), dsize_, event_->data()[1], event_->data()[2], (event_->data()[HEADER_SIZE]&0xf0)!=0?'A':'B', (event_->data()[HEADER_SIZE]&0xf0)!=0?cntAevent:cntBevent);
            else
               printf("Empty packet size %d 32-bit words. Acq %d, seq %d\n", dsize_, event_->data()[1], event_->data()[2]);
            
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
                  if (!(cntAevent%EVENTS_PER_FRAME)  && compTh1DAC < COMP_TH1_STOP) {
                     // save the file
                     ostringstream cnvTh;
                     ostringstream cnvMTrm;
                     cnvTh << compTh1DAC;
                     cnvMTrm << matrixTrm;
                     string fileName = "/u1/mkwiatko/CPIX_" + string(timeString) + "_cntA_Thr_" + cnvTh.str() + "_MatrixTrm_" + cnvMTrm.str() + ".bin";
                     frameFile.open (fileName.c_str(), ios::out | ios::binary | ios::app);
                     frameFile.write ((char*)event_->data(), dsize_*4);
                     frameFile.close();
                     // move the threshold to the next value
                     if (cntAframe >= FRAMES_PER_THRESHOLD-1) {
                        cntAframe = 0;
                        compTh1DAC++;
                     }
                     else {
                        cntAframe++;
                     }
                     printf("Threshold (A) compTh1DAC changed to %d\n", compTh1DAC);
                     value = epix.device("digFpga",0)->device("CpixPAsic",0)->readSingle("Config1");
                     epix.device("digFpga",0)->device("CpixPAsic",0)->writeSingle("Config1", (value&0xffffffC0)|(compTh1DAC&0x3F));    //test only ASIC 0 (CpixPAsic, 0)
                  }
               }
               //Frame with cntB was received
               else {
                  cntBevent++;
                  if (!(cntBevent%EVENTS_PER_FRAME)  && compTh2DAC < COMP_TH2_STOP) {
                     // save the file
                     ostringstream cnvTh;
                     ostringstream cnvMTrm;
                     cnvTh << compTh2DAC;
                     cnvMTrm << matrixTrm;
                     string fileName = "/u1/mkwiatko/CPIX_" + string(timeString) + "_cntB_Thr_" + cnvTh.str() + "_MatrixTrm_" + cnvMTrm.str() + ".bin";
                     frameFile.open (fileName.c_str(), ios::out | ios::binary | ios::app);
                     frameFile.write ((char*)event_->data(), dsize_*4);
                     frameFile.close();
                     // move the threshold to the next value
                     if (cntBframe >= FRAMES_PER_THRESHOLD-1) {
                        cntBframe = 0;
                        compTh2DAC++;
                     }
                     else {
                        cntBframe++;
                     }
                     printf("Threshold (B) compTh2DAC changed to %d\n", compTh2DAC);
                     value = epix.device("digFpga",0)->device("CpixPAsic",0)->readSingle("Config12");
                     epix.device("digFpga",0)->device("CpixPAsic",0)->writeSingle("Config12",(value&0xffffffC0)|(compTh2DAC&0x3F));    //test only ASIC 0 (CpixPAsic, 0)
                  }
               }
            }
            
            
            if (compTh1DAC >= COMP_TH1_STOP && compTh2DAC >= COMP_TH2_STOP) {
               
               if (matrixTrm < MATRIX_TRM_STOP) {
                  matrixTrm++;
                  printf("Setting matrich config bits to 0x%X\n", MATRIX_TEST_BIT | (matrixTrm<<2));
                  //stop auto run to config the matrix
                  epix.device("digFpga",0)->writeSingle("AutoRunEnable", 0);
                  //set the initial matrix config
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
                  //reset thresholds for the next test run
                  compTh1DAC = COMP_TH1_START;
                  compTh2DAC = COMP_TH2_START;
                  //set initial ASIC thresholds
                  printf("Threshold (A) compTh1DAC changed to %d\n", compTh1DAC);
                  printf("Threshold (B) compTh2DAC changed to %d\n", compTh2DAC);
                  value = epix.device("digFpga",0)->device("CpixPAsic",0)->readSingle("Config1");
                  epix.device("digFpga",0)->device("CpixPAsic",0)->writeSingle("Config1", (value&0xffffffC0)|(compTh1DAC&0x3F));
                  value = epix.device("digFpga",0)->device("CpixPAsic",0)->readSingle("Config12");
                  epix.device("digFpga",0)->device("CpixPAsic",0)->writeSingle("Config12",(value&0xffffffC0)|(compTh2DAC&0x3F));
                  //start auto run when done
                  epix.device("digFpga",0)->writeSingle("AutoRunEnable", 1);
               }
               else {
                  printf("Testing finished!\n");
                  break;
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

