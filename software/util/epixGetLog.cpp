//-----------------------------------------------------------------------------
// File          : epixGetLog.cpp
// Author        : Maciej Kwiatkowski  <mkwiatko@slac.stanford.edu>
// Created       : 04/12/2011
// Project       : CSPAD
//-----------------------------------------------------------------------------
// Description : Dumps the log messages created by Microblaze
//-----------------------------------------------------------------------------
// Copyright (c) 2016 by SLAC. All rights reserved.
// Proprietary and confidential to SLAC.
//-----------------------------------------------------------------------------
// Modification history :
// 07/01/2016: created
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
#include <LogMemory.h>

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
      string        defFile = "";
      uint          baseAddress;
      uint          addrSize;
      
      
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

      EpixControl   epix(pgpLink,defFile,EPIX100A, baseAddress, addrSize);
      
      epix.setDebug(false);
      
      LogMemory * logMem = (LogMemory*)(epix.device("digFpga",0)->device("LogMemory",0));

      
      char* log = logMem->getBuffer();
      
      for(unsigned int i = 0; i < logMem->getSize(); i++)
         printf("%c", log[i]);
      printf("\n");
      
      exit(0);
      

   } catch ( string error ) {
      cout << "Caught Error: " << endl;
      cout << error << endl;
   }
}

