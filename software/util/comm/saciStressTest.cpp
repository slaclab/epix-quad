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
   EpixControl epix(&pgpLink,"",EPIX100A, 0x01000000, 1);

   try {

      // Create and setup PGP link
      pgpLink.setMaxRxTx(500000);
      pgpLink.setDebug(true);
      pgpLink.open("/dev/pgpcard0");
      pgpLink.enableSharedMemory("epix",1);
      usleep(100);
      epix.setDebug(false);//("DebugEnable", "True");

      int epixIndex = 1;

      // Test
      cout << "--------READING FPGA VERSION---------" << endl;
      cout << "Fpga Version: 0x" << hex << setw(8) << setfill('0') << epix.device("digFpga",0)->readSingle("Version") << endl;
      epix.device("digFpga",0)->device("epix100aAsic",epixIndex)->set("Enabled","True");
      
      epix.device("digFpga",0)->writeSingle("PowerEnable",7);
      epix.device("digFpga",0)->writeSingle("asicMask",0xf);
      epix.device("digFpga",0)->writeSingle("AutoRunPeriod",833333);
      epix.device("digFpga",0)->writeSingle("RunTrigEnable",0x1);
      epix.device("digFpga",0)->writeSingle("AutoRunEnable",0x1);
      
      epix.device("digFpga",0)->writeSingle("acqToAsicR0Delay",0xbeef);
      
      unsigned int rd_cnt = 0;
      unsigned int avin = 0;
      unsigned int value[2] = {0xBEEF, 0xBEEF};
      unsigned int prev_value[2] = {0xBEEF, 0xBEEF};
      unsigned int mask[2] = {0xFF, 0x1FF};
      unsigned int err_cnt = 0;
      
      unsigned char first = 1;
      
      while (1) {
         
         rd_cnt++;
         
         avin = epix.device("digFpga",0)->readSingle("EnvData07");
         
         //Saci registers
         value[1] = epix.device("digFpga",0)->device("epix100aAsic",epixIndex)->readSingle("RowStopAddr");         
         value[0] = epix.device("digFpga",0)->device("epix100aAsic",epixIndex)->readSingle("Config22");         
              
         //Non Saci registers
         //value[1] = epix.device("digFpga",0)->readSingle("acqToAsicR0Delay"); 
         //value[0] = epix.device("digFpga",0)->readSingle("asicRoClkHalfT");    
         
         
         //usleep(1000);
         
         
         if(first == 1 || rd_cnt%1000 == 0) {
            cout << "Rd0: " << dec << (value[0] & mask[0]) << " | 0x" << hex << setw(2) << setfill('0') << value[0];
            cout << ". Rd1: " << dec << (value[1] & mask[1]) << " | 0x" << hex << setw(2) << setfill('0') << value[1];
            cout << ". Avin: " << (double)avin/1000 << " Err cnt: " << err_cnt << endl;
            //cout << "Readback: " << dec << value[0] & mask[0] << " | 0x" << hex << setw(2) << setfill('0') << value[0] << endl;
         }
         if(prev_value[0] != (value[0] & mask[0]) && first == 0) {
            cout << "Value0 changed to: " << dec << (value[0] & mask[0]) << " | 0x" << hex << setw(2) << setfill('0') << value[0] << endl;
            err_cnt++;
            //break;
         }
         if(prev_value[1] != (value[1] & mask[1]) && first == 0) {
            cout << "Value1 changed to: " << dec << (value[1] & mask[1]) << " | 0x" << hex << setw(2) << setfill('0') << value[1] << endl;
            err_cnt++;
            //break;
         }
         
         first = 0;
         prev_value[0] = value[0] & mask[0];
         prev_value[1] = value[1] & mask[1];
         
         
         
      }

   } catch ( string error ) {
      cout << "Caught Error: " << endl;
      cout << error << endl;
   }
}

