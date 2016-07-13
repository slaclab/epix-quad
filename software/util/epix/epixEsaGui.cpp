//-----------------------------------------------------------------------------
// File          : epixGui.cpp
// Author        : Ryan Herbst  <rherbst@slac.stanford.edu>
// Created       : 05/14/2013
// Project       : EPIX
//-----------------------------------------------------------------------------
// Description :
// Server application for GUI
//-----------------------------------------------------------------------------
// Copyright (c) 2013 by SLAC. All rights reserved.
// Proprietary and confidential to SLAC.
//-----------------------------------------------------------------------------
// Modification history :
// 05/14/2013: created
//----------------------------------------------------------------------------
#include <PgpCardG3Link.h>
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
   int           port;
   stringstream  cmd;

   if ( argc > 1 ) defFile = argv[1];
   else defFile = "xml/esa_1.xml";

   // Catch signals
   signal (SIGINT,&sigTerm);

   try {
      PgpCardG3Link   pgpLink;
      EpixEsaControl  epix(&pgpLink,defFile,EPIX100A, 0x01000000, 1);
      //UdpLink       udpLink; 
      //EpixControl   epix(&udpLink,defFile);
      int           pid;

      // Setup top level device
      epix.setDebug(true);

      // Create and setup PGP link
      pgpLink.setMaxRxTx(550000);
      pgpLink.setDebug(true);
      pgpLink.open("/dev/PgpCardG3_0");
      pgpLink.enableSharedMemory("epix",1);
      pgpLink.setDataMask( (LANE0|VC0) | (LANE0|VC2) );
      usleep(100);

      cout << "Created PGP Link" << endl;

      // Create and setup PGP link
      //udpLink.setMaxRxTx(550000);
      //udpLink.setDebug(true);
      //udpLink.open(8090,1,"127.0.0.1");
      //udpLink.enableSharedMemory("epix",1);
      //usleep(100);

      // Setup control server
      //cntrlServer.setDebug(true);
      cntrlServer.enableSharedMemory("epix",1);
      port = cntrlServer.startListen(0);
      cntrlServer.setSystem(&epix);
      cout << "Control id = 1" << endl;

      cout << "Created control server" << endl;

      //Write out only the event data, no XML
      pgpLink.setXmlStore(false);

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

