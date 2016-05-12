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
#include <MultDestPgp.h>
#include <MultLink.h>
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
#define CONFIG_MASK 1

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
      
       //disable triggers read the matrix
      epix.device("digFpga",0)->writeSingle("RunTrigEnable", 0);
      epix.device("digFpga",0)->writeSingle("DaqTrigEnable", 0);
      
      epix.device("digFpga",0)->device("CpixPAsic",0)->set("Enabled","True");
      
      
      for (int row=0; row<48; row++) {
         for (int col=0; col<48; col++) {
            epix.device("digFpga",0)->device("CpixPAsic",0)->writeSingle("ColCounter", col);
            epix.device("digFpga",0)->device("CpixPAsic",0)->writeSingle("RowCounter", row);
            value = epix.device("digFpga",0)->device("CpixPAsic",0)->readSingle("WritePixelData");
            printf("%c", value&CONFIG_MASK?'1':'0');
         }
         printf("\n");
      }
      
      exit(0);
      

   } catch ( string error ) {
      cout << "Caught Error: " << endl;
      cout << error << endl;
   }
}

