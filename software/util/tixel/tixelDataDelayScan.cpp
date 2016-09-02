//-----------------------------------------------------------------------------
// File          : cpixPulserScan.cpp
// Author        : Maciej Kwiatkowski  <mkwiatko@slac.stanford.edu>
// Created       : 04/12/2011
// Project       : CSPAD
//-----------------------------------------------------------------------------
// Description :
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

using namespace std;


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
      string        defFile = "xml/tixel_1.xml";
      uint          baseAddress;
      uint          addrSize;
      unsigned int  frames;
      unsigned int  goodFrames;
      unsigned int  badFrames;
      unsigned int  timeoutFrames;
      unsigned int  codeErrors[32];
      int           delay;
      
      
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

      EpixControl   epix(pgpLink,defFile,TIXELP, baseAddress, addrSize);
      
      epix.command("SetDefaults", "");
      
      epix.setDebug(false);
      
      
      epix.device("digFpga",0)->writeSingle("AutoRunPeriod", 10000000);
      epix.device("digFpga",0)->writeSingle("AutoRunEnable", 1);
      
      
      for (delay=0; delay<=31; delay++) {
         
         epix.device("digFpga",0)->device("DigFpgaTixel",0)->writeSingle("tixelAsic1DoutDelay", delay);
         epix.device("digFpga",0)->device("DigFpgaTixel",0)->writeSingle("tixelAsic1DoutResync", 1);
         epix.device("digFpga",0)->device("DigFpgaTixel",0)->writeSingle("tixelErrorRst", 1);
         epix.device("digFpga",0)->device("DigFpgaTixel",0)->writeSingle("tixelAsic1DoutResync", 0);
         epix.device("digFpga",0)->device("DigFpgaTixel",0)->writeSingle("tixelErrorRst", 0);
         
         frames = 0;
         
         while (frames<100) {
            
            goodFrames = epix.device("digFpga",0)->device("DigFpgaTixel",0)->readSingle("tixelAsic1FramesGood");
            badFrames = epix.device("digFpga",0)->device("DigFpgaTixel",0)->readSingle("tixelAsic1FrameErr");
            timeoutFrames = epix.device("digFpga",0)->device("DigFpgaTixel",0)->readSingle("tixelAsic1TimeoutErr");
            codeErrors[delay] = epix.device("digFpga",0)->device("DigFpgaTixel",0)->readSingle("tixelAsic1CodeErr");
            
            frames = goodFrames + badFrames + timeoutFrames;
            
         }
         
         printf("Delay %d has %d code errors in %d frames and %d good frames\n", delay, codeErrors[delay], frames, goodFrames);
         
      }
      
      epix.device("digFpga",0)->writeSingle("AutoRunEnable", 0);
      
      exit(0);
      

   } catch ( string error ) {
      cout << "Caught Error: " << endl;
      cout << error << endl;
   }
}

