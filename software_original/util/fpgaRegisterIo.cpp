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
#include <EpixControl.h>
#include <ControlServer.h>
#include <Device.h>
#include <iomanip>
#include <fstream>
#include <iostream>
#include <signal.h>
using namespace std;

int main (int argc, char **argv) {
   PgpLink  pgpLink;
   EpixControl epix(&pgpLink,"",EPIX100P);

   try {

      // Create and setup PGP link
      pgpLink.setMaxRxTx(550000);
      pgpLink.setDebug(true);
      pgpLink.open("/dev/pgpcard0");
      pgpLink.enableSharedMemory("epix",1);
      usleep(100);
      epix.setDebug(true);//("DebugEnable", "True");

      // Test
      cout << "--------READING FPGA VERSION---------" << endl;
      cout << "Fpga Version: 0x" << hex << setw(8) << setfill('0') << epix.device("digFpga",0)->readSingle("Version") << endl;
      //
      while (1) {
         int command;
         cout << "--------------------------------" << endl;
         cout << "Read (0) / write (1) / exit(2): ";
         cin >> command;
         if (command == 2) {
            break;
         } else {
            if (command == 0) {
               cout << "Enter register name: ";
               string reg_name;
               cin >> reg_name;
               cout << "READBACK: 0x" << hex << setw(8) << setfill('0') << epix.device("digFpga",0)->readSingle(reg_name.c_str()) << endl;
            }
            if (command == 1) {
               cout << "Enter register name: ";
               string reg_name;
               cin >> reg_name;
               unsigned int value;
               cout << "Enter value to write: ";
               cin >> value;
               cout << "WRITING." << endl;
               epix.device("digFpga",0)->writeSingle(reg_name.c_str(),value);
               cout << "READBACK: 0x" << hex << setw(8) << setfill('0') << epix.device("digFpga",0)->readSingle(reg_name.c_str()) << endl;
            }
         }
      }

   } catch ( string error ) {
      cout << "Caught Error: " << endl;
      cout << error << endl;
   }
}

