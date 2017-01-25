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
#include <PgpCardG3Link.h>
#include <MultDestPgpG3.h>
#include <MultLink.h>
#include <EpixEsaControl.h>
#include <ControlServer.h>
#include <Device.h>
#include <iomanip>
#include <fstream>
#include <iostream>
#include <signal.h>

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
   string        pgpFile;
   int           c, port;
   int           pflag = 0;
   int           fflag = 0;
   stringstream  cmd;
   
   defFile = "xml/esa_1.xml";
   pgpFile = "/dev/PgpCardG3_0";
   
   while ((c = getopt (argc, argv, "f:p:")) != -1) {
      switch (c)
      {
         case 'f':
            fflag = 1;
            defFile = optarg;
            break;
         
         case 'p':
            pflag = 1;
            pgpFile = optarg;
            break;
      }
   }
   
   if (pflag == 0)
      cout << "Using " << pgpFile << " as default PGP device file. Use -p option to change." << endl;
   if (fflag == 0)
      cout << "Using " << defFile << " as default configuration xml file. Use -f option to change." << endl;

   // Catch signals
   signal (SIGINT,&sigTerm);

   try {
      
      
      MultLink     *pgpLink;
      MultDestPgpG3     *dest;  
      
      int           pid;
      uint          baseAddress;
      uint          addrSize;
      
      // Create and setup PGP link
      baseAddress = 0x00000000;
      addrSize = 4;
      dest = new MultDestPgpG3(pgpFile);
      dest->addDataSource(0x00000000); // VC0 - acq data
      dest->addDataSource(0x02000000); // VC2 - oscilloscope
      dest->addDataSource(0x03000000); // VC3 - monitoring
      pgpLink = new MultLink();
      pgpLink->setDebug(true);
      pgpLink->setMaxRxTx(0x800000);
      pgpLink->open(1,dest);
      pgpLink->enableSharedMemory("epix",1);   
      pgpLink->setXmlStore(false);
      
      usleep(100);

      cout << "Created PGP Link" << endl;
      
      EpixEsaControl  epix(pgpLink,defFile,EPIX100A, baseAddress, addrSize, dest);
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

