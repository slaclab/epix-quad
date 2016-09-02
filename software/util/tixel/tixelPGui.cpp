//-----------------------------------------------------------------------------
// File          : epixGui.cpp
// Author        : Ryan Herbst  <rherbst@slac.stanford.edu>
// Created       : 05/14/2013
// Project       : EPIX
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
// 05/14/2013: created
//----------------------------------------------------------------------------
#include <PgpLink.h>
#include <UdpLink.h>

#include <MultDestPgp.h>
#include <MultLink.h>
#include <EpixControl.h>
#include <ControlServer.h>
#include <Device.h>
#include <iomanip>
#include <fstream>
#include <iostream>
#include <signal.h>

#define USE_MULTLINK 1

#define LANE0  0x10
#define LANE1  0x20
#define LANE2  0x40
#define LANE3  0x80

#define VC0    0x01
#define VC1    0x02
#define VC2    0x04
#define VC3    0x08

using namespace std;

// Run flag for sig catch
bool stop;

// Function to catch cntrl-c
void sigTerm (int) { 
   cout << "Got Signal!" << endl;
   stop = true; 
}

int main (int argc, char **argv) {
   ControlServer cntrlServer;
   string        defFile;
   int           port;
   stringstream  cmd;

   if ( argc > 1 ) defFile = argv[1];
   else defFile = "";

   // Catch signals
   signal (SIGINT,&sigTerm);

   try {
      
#if USE_MULTLINK
      MultLink     *pgpLink;
      MultDest     *dest;  
#else
      PgpLink       *pgpLink; 
#endif
      int           pid;
      uint          baseAddress;
      uint          addrSize;
      
      // Create and setup PGP link
#if USE_MULTLINK
      baseAddress = 0x00000000;
      addrSize = 4;
      dest = new MultDestPgp("/dev/pgpcard0");
      dest->addDataSource(0x00000000); // VC0 - acq data
      dest->addDataSource(0x02000000); // VC2 - oscilloscope
      dest->addDataSource(0x03000000); // VC3 - monitoring
      pgpLink = new MultLink();
      pgpLink->setDebug(true);
      pgpLink->setMaxRxTx(0x800000);
      pgpLink->open(1,dest);
      pgpLink->enableSharedMemory("epix",1);   
      pgpLink->setXmlStore(false);
#else
      baseAddress = 0x01000000;
      addrSize = 1;
      pgpLink = new PgpLink();
      pgpLink->setMaxRxTx(550000);
      pgpLink->setDebug(true);
      pgpLink->open("/dev/pgpcard0");
      pgpLink->enableSharedMemory("epix",1);
      //Write out only the event data, no XML
      pgpLink->setXmlStore(false);
      pgpLink->setDataMask( (LANE0|VC0) | (LANE0|VC2) );
#endif
      usleep(100);

      cout << "Created PGP Link" << endl;

      EpixControl   epix(pgpLink,defFile,TIXELP, baseAddress, addrSize);
      epix.setDebug(true);
      
      // Setup control server
      //cntrlServer.setDebug(true);
      cntrlServer.enableSharedMemory("epix",1);
      port = cntrlServer.startListen(0);
      cntrlServer.setSystem(&epix);
      cout << "Control id = 1" << endl;

      cout << "Created control server" << endl;

      // Fork and start gui
      stop = false;
      switch (pid = fork()) {

         // Error
         case -1:
            cout << "Error occured in fork!" << endl;
            return(1);
            break;

         // Child
         case 0:
            usleep(100);
            cout << "Starting GUI" << endl;
            cmd.str("");
            cmd << "cntrlGui localhost " << dec << port;
            system(cmd.str().c_str());
            cout << "GUI stopped" << endl;
            kill(getppid(),SIGINT);
            break;

         // Server
         default:
            cout << "Starting server at port " << dec << port << endl;
            while ( ! stop ) cntrlServer.receive(100);
            cntrlServer.stopListen();
            cout << "Stopped server" << endl;
            break;
      }

   } catch ( string error ) {
      cout << "Caught Error: " << endl;
      cout << error << endl;
      cntrlServer.stopListen();
   }
}

