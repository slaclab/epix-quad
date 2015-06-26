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
   EpixControl epix(&pgpLink,"",EPIX10KP);

   try {

      // Create and setup PGP link
      pgpLink.setMaxRxTx(500000);
      pgpLink.setDebug(true);
      pgpLink.open("/dev/pgpcard1");
      pgpLink.enableSharedMemory("epix",1);
      usleep(100);
      epix.setDebug(true);//("DebugEnable", "True");

      int epixIndex = 0;
      int epixId    = 0;

      // Test
      cout << "--------READING FPGA VERSION---------" << endl;
      cout << "Fpga Version: 0x" << hex << setw(8) << setfill('0') << epix.device("digFpga",0)->readSingle("Version") << endl;
      //
      string exit_str = "x";
      while (1) {
         cout << "--------------------------------" << endl;
         cout << "Enter chip to program (0-based dec): ";
         cin >> dec >> epixIndex;
         epix.device("digFpga",0)->device("epix10kAsic",epixIndex)->set("Enabled","True");
         cout << "Enter ID to program (hex): ";
         cin >> hex >> epixId;
         epix.device("digFpga",0)->device("epix10kAsic",epixIndex)->writeSingle("ChipId",epixId);
         epix.device("digFpga",0)->device("epix10kAsic",epixIndex)->writeSingle("PrepareWriteChipIdA",0);
         cout << "Apply voltage, return to 2.5 V, and press a key to continue" << endl;
         string temp;
         cin >> temp;
   	   unsigned int value = epix.device("digFpga",0)->device("epix10kAsic",epixIndex)->readSingle("PrepareWriteChipIdB");
   	   value = epix.device("digFpga",0)->device("epix10kAsic",epixIndex)->readSingle("ChipId");
         epix.device("digFpga",0)->device("epix10kAsic",epixIndex)->writeSingle("ChipId",0);
         epix.device("digFpga",0)->device("epix10kAsic",epixIndex)->writeSingle("PrepareWriteChipIdA",0);
   	   value = epix.device("digFpga",0)->device("epix10kAsic",epixIndex)->readSingle("PrepareWriteChipIdB");
   	   value = epix.device("digFpga",0)->device("epix10kAsic",epixIndex)->readSingle("ChipId");
         cout << "Chip id is now: " << hex << value << endl;
      }

   } catch ( string error ) {
      cout << "Caught Error: " << endl;
      cout << error << endl;
   }
}

