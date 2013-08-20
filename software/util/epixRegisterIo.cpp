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
   EpixControl epix(&pgpLink,"");

   try {

      // Create and setup PGP link
      pgpLink.setMaxRxTx(500000);
      pgpLink.setDebug(true);
      pgpLink.open("/dev/pgpcard1");
      pgpLink.enableSharedMemory("epix",1);
      usleep(100);
      epix.setDebug(true);//("DebugEnable", "True");

      // Test
      cout << "--------READING FPGA VERSION---------" << endl;
      cout << "Fpga Version: 0x" << hex << setw(8) << setfill('0') << epix.device("digFpga",0)->readSingle("Version") << endl;
      epix.device("digFpga",0)->device("epixAsic",0)->set("Enabled","True");
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
			   unsigned int value = epix.device("digFpga",0)->device("epixAsic",0)->readSingle(reg_name.c_str());
			   value &= 0xFFFF;
			   //			   cout << "READBACK: 0x" << hex << setw(8) << setfill('0') << epix.device("digFpga",0)->device("epixAsic",0)->readSingle(reg_name.c_str()) << endl;
			   cout << "READBACK: " << dec << value << " | 0x" << hex << setw(2) << setfill('0') << epix.device("digFpga",0)->device("epixAsic",0)->readSingle(reg_name.c_str()) << endl;
            }
            if (command == 1) {
               cout << "Enter register name: ";
               string reg_name;
               cin >> reg_name;
               unsigned int value;
               cout << "Enter value to write: ";
               cin >> hex >> value;
               cout << "WRITING." << endl;
               epix.device("digFpga",0)->device("epixAsic",0)->writeSingle(reg_name.c_str(),value);
			   //               epix.device("digFpga",0)->device("epixAsic",0)->readRegister(epix.device("digFpga",0)->device("epixAsic",0)->getRegister(reg_name.c_str()));
			   //               epix.device("digFpga",0)->device("epixAsic",0)->readRegister(epix.device("digFpga",0)->device("epixAsic",0)->getRegister(reg_name.c_str()));
			   //               cout << "READBACK: 0x" << hex << setw(8) << setfill('0') << epix.device("digFpga",0)->device("epixAsic",0)->readSingle(reg_name.c_str()) << endl;
			   //               cout << "READBACK: 0x" << hex << setw(8) << setfill('0') << epix.device("digFpga",0)->device("epixAsic",0)->readSingle(reg_name.c_str()) << endl;
            }
         }
      }

      //cout << "Fgga Version: 0x" << hex << setw(8) << setfill('0') << kpix.device("cntrlFpga",0)->readSingle("ClockSelectA") << endl;
      //cout << "Fgga Version: 0x" << hex << setw(8) << setfill('0') << kpix.device("cntrlFpga",0)->readSingle("ClockSelectB") << endl;
      //cout << "Kpix Version: 0x" << hex << setw(8) << setfill('0') << kpix.device("cntrlFpga",0)->device("kpixAsic",4)->readSingle("Status") << endl;
      //kpix.device("cntrlFpga",0)->device("kpixAsic",1)->set("Enabled", "True");
      //      cout << "Kpix Version: 0x" << hex << setw(8) << setfill('0') << kpix.device("cntrlFpga",0)->device("kpixAsic",1)->readSingle("Status") << endl;
      //kpix.device("cntrlFpga",0)->device("kpixAsic",1)->writeSingle("TimerB", 0x50505050); 
      //cout << "Write TimerB" << hex << setw(8) << setfill('0') << kpix.device("cntrlFpga",0)->device("kpixAsic",1)->readSingle("TimerB") << endl;

      // kpix.device("cntrlFpga",0)->device("kpixAsic",1)->writeSingle("Control", 0x50505050); 
      //cout << "Write TimerB" << hex << setw(8) << setfill('0') << kpix.device("cntrlFpga",0)->device("kpixAsic",1)->readSingle("Control") << endl;

      //kpix.device("cntrlFpga",0)->device("kpixAsic",1)->writeSingle("Config", 0x50505050); 
      //cout << "Write TimerB" << hex << setw(8) << setfill('0') << kpix.device("cntrlFpga",0)->device("kpixAsic",1)->readSingle("Config") << endl;


     //cout << "Kpix Version: 0x" << hex << setw(8) << setfill('0') << kpix.device("cntrlFpga",0)->device("kpixAsic",0)->readSingle("Status") << endl;

   } catch ( string error ) {
      cout << "Caught Error: " << endl;
      cout << error << endl;
   }
}

