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
#include <PgpLink.h>
#include <UdpLink.h>
#include <EpixControl.h>
#include <ControlServer.h>
#include <Device.h>
#include <iomanip>
#include <fstream>
#include <iostream>
#include <signal.h>
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
      PgpLink       pgpLink; 
      EpixControl   epix(&pgpLink,defFile);
      //UdpLink       udpLink; 
      //EpixControl   epix(&udpLink,defFile);
      int           pid;

      // Setup top level device
      epix.setDebug(true);

      // Create and setup PGP link
      pgpLink.setMaxRxTx(500000);
      pgpLink.setDebug(true);
      pgpLink.open("/dev/pgpcard1");
      pgpLink.enableSharedMemory("epix",1);
      usleep(100);

      // Create and setup PGP link
      //udpLink.setMaxRxTx(500000);
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

