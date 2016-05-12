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
   EpixControl epix(&pgpLink,"",EPIX10KP, 0x01000000, 1);

   try {

      // Create and setup PGP link
      pgpLink.setMaxRxTx(500000);
      pgpLink.setDebug(true);
      pgpLink.open("/dev/pgpcard1");
      pgpLink.enableSharedMemory("epix",1);
      usleep(100);
      epix.setDebug(true);//("DebugEnable", "True");

      int epixIndex = 0;

      // Test
      cout << "--------READING FPGA VERSION---------" << endl;
      cout << "Fpga Version: 0x" << hex << setw(8) << setfill('0') << epix.device("digFpga",0)->readSingle("Version") << endl;
      epix.device("digFpga",0)->device("epix10kAsic",epixIndex)->set("Enabled","True");
      //
      string exit_str = "x";
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
               unsigned int value = 0xBEEF;
   			   value = epix.device("digFpga",0)->device("epix10kAsic",epixIndex)->readSingle(reg_name.c_str());
   			   unsigned int dec_value = value & 0xFFFF;
			      cout << "READBACK: " << dec << dec_value << " | 0x" << hex << setw(2) << setfill('0') << value << endl;
            }
            if (command == 1) {
               cout << "Enter register name: ";
               string reg_name;
               cin >> reg_name;
               unsigned int value;
               cout << "Enter value to write: ";
               cin >> hex >> value;
               cout << "WRITING." << endl;
               epix.device("digFpga",0)->device("epix10kAsic",epixIndex)->writeSingle(reg_name.c_str(),value);
            }
         }
      }

   } catch ( string error ) {
      cout << "Caught Error: " << endl;
      cout << error << endl;
   }
}

