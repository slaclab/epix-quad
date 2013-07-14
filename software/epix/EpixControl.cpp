//-----------------------------------------------------------------------------
// File          : EpixControl.cpp
// Author        : Ryan Herbst  <rherbst@slac.stanford.edu>
// Created       : 06/06/2013
// Project       : EPIX System 
//-----------------------------------------------------------------------------
// Description :
// EPIX Control Top Level
//-----------------------------------------------------------------------------
// Copyright (c) 2013 by SLAC. All rights reserved.
// Proprietary and confidential to SLAC.
//-----------------------------------------------------------------------------
// Modification history :
// 06/06/2013: created
//-----------------------------------------------------------------------------
#include <EpixControl.h>
#include <DigFpga.h>
#include <Register.h>
#include <Variable.h>
#include <Command.h>
#include <CommLink.h>
#include <sstream>
#include <iostream>
#include <string>
#include <iomanip>
using namespace std;

// Constructor
EpixControl::EpixControl ( CommLink *commLink, string defFile ) : System("EpixControl",commLink) {

   // Description
   desc_ = "Epix Control";
   
   // Data mask, lane 0, vc 0
   commLink->setDataMask(0x11);

   if ( defFile == "" ) defaults_ = "xml/defaults.xml";
   else defaults_ = defFile;

   // Add sub-devices
   addDevice(new DigFpga(0, 0, this));
}

// Deconstructor
EpixControl::~EpixControl ( ) { }

//! Method to return state string
string EpixControl::localState ( ) {
   string loc = "";

   loc = "System Ready To Take Data.\n";

   return(loc);
}

//! Method to perform soft reset
void EpixControl::softReset ( ) {
   System::softReset();

   device("digFpga",0)->command("AcqCountReset","");
}

//! Method to perform hard reset
void EpixControl::hardReset ( ) {
   bool gotVer = false;
   uint count = 0;

   System::hardReset();

   device("digFpga",0)->command("MasterReset","");
   do {
      sleep(1);
      try { 
         gotVer = true;
         device("digFpga",0)->readSingle("Version");
      } catch ( string err ) { 
         if ( count > 5 ) {
            gotVer = true;
            throw(string("EpixControl::hardReset -> Error contacting fpga"));
         }
         else {
            count++;
            gotVer = false;
         }
      }
   } while ( !gotVer );
}


void EpixControl::setRunState ( string state ) {
   device("digFpga",0)->setRunCommand("EpixRun");
   System::setRunState(state);
}

