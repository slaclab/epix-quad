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

#define LANE0  0x10
#define LANE1  0x20
#define LANE2  0x40
#define LANE3  0x80

#define VC0    0x01
#define VC1    0x02
#define VC2    0x04
#define VC3    0x08

using namespace std;

// Constructor
EpixControl::EpixControl ( CommLink *commLink, string defFile, EpixType epixType ) : System("EpixControl",commLink) {

   // Description
   desc_ = "Epix Control";
   
   // Data mask, lane 0, vc 0 (primary); lane 0, vc 2 (scope)
   commLink->setDataMask( (LANE0|VC0) | (LANE0|VC2) );
//   commLink->setDataMask( (LANE0|VC0) );

   if ( defFile == "" ) defaults_ = "xml/defaults.xml";
   else defaults_ = defFile;

   // Add sub-devices
   addDevice(new DigFpga(0, 0, this, epixType));

   //Set ePix type
   epixType_ = epixType;

   //Add commands
   addCommand(new Command("SoftwareTrigger"));
   getCommand("SoftwareTrigger")->setDescription("Prep for readout and software trigger");

   addCommand(new Command("WriteMatrixData"));
   getCommand("WriteMatrixData")->setDescription("Writes PixelTest and PixelMask to *all* pixels, then issues prepare for readout");

   addCommand(new Command("WritePixelData"));
   getCommand("WritePixelData")->setDescription("Writes PixelTest and PixelMask to *one* pixel");

   addCommand(new Command("WriteRowCounter"));
   getCommand("WriteRowCounter")->setDescription("Special command to write row variable to row counter");

   addCommand(new Command("WriteRowData"));
   getCommand("WriteRowData")->setDescription("Special command to write PixelTest and PixelMask to a row");
   
   addCommand(new Command("WriteColData"));
   getCommand("WriteColData")->setDescription("Special command to write PixelTest and PixelMask to a col");

   addCommand(new Command("PrepForRead"));
   getCommand("PrepForRead")->setDescription("Sends SACI prepare for readout");

}

// Deconstructor
EpixControl::~EpixControl ( ) { }

// Method to process a command
void EpixControl::command ( string name, string arg) {
   stringstream tmp;

   // Command is local
   if ( name == "SoftwareTrigger" ) {
      device("digFpga",0)->command("EpixRun","");
   } else if ( name == "WriteMatrixData" ) {
      for (int asic = 0; asic < NASICS; ++asic) {
         if (epixType_ == EPIX100P) {
            device("digFpga",0)->device("epixAsic",asic)->command("WriteMatrixData","");
         } else if (epixType_ == EPIX100A) {
            device("digFpga",0)->device("epix100aAsic",asic)->command("WriteMatrixData","");
         } else if (epixType_ == EPIX10KP) {
            device("digFpga",0)->device("epix10kAsic",asic)->command("WriteMatrixData","");
         } else if (epixType_ == EPIXS) {
            device("digFpga",0)->device("epixSAsic",asic)->command("WriteMatrixData","");
         } 
      }
   } else if ( name == "WritePixelData" ) {
      for (int asic = 0; asic < NASICS; ++asic) {
         if (epixType_ == EPIX100P) {
            device("digFpga",0)->device("epixAsic",asic)->command("WritePixelData","");
         } else if (epixType_ == EPIX100A) {
            device("digFpga",0)->device("epix100aAsic",asic)->command("WritePixelData","");
         } else if (epixType_ == EPIX10KP) {
            device("digFpga",0)->device("epix10kAsic",asic)->command("WritePixelData","");
         } else if (epixType_ == EPIXS) {
            device("digFpga",0)->device("epixSAsic",asic)->command("WritePixelData","");
         }
      }
   } else if ( name == "WriteRowCounter" ) {
      for (int asic = 0; asic < NASICS; ++asic) {
         if (epixType_ == EPIX100P) {
            device("digFpga",0)->device("epixAsic",asic)->command("WriteRowCounter","");
         } else if (epixType_ == EPIX100A) {
            device("digFpga",0)->device("epix100aAsic",asic)->command("WriteRowCounter","");
         } else if (epixType_ == EPIX10KP) {
            device("digFpga",0)->device("epix10kAsic",asic)->command("WriteRowCounter","");
         } else if (epixType_ == EPIXS) {
            device("digFpga",0)->device("epixSAsic",asic)->command("WriteRowCounter","");
         }
      }
   } else if ( name == "PrepForRead" ) {
      for (int asic = 0; asic < NASICS; ++asic) { 
         if (epixType_ == EPIX100P) {
            device("digFpga",0)->device("epixAsic",asic)->command("PrepForRead","");
         } else if (epixType_ == EPIX100A) {
            device("digFpga",0)->device("epix100aAsic",asic)->command("PrepForRead","");
         } else if (epixType_ == EPIX10KP) {
            device("digFpga",0)->device("epix10kAsic",asic)->command("PrepForRead","");
         } else if (epixType_ == EPIXS) {
            device("digFpga",0)->device("epixSAsic",asic)->command("PrepForRead","");
         }
      }
   } else if ( name == "WriteRowData" ) {
      for (int asic = 0; asic < NASICS; ++asic) {
         if (epixType_ == EPIX100P) {
            device("digFpga",0)->device("epixAsic",asic)->command("WriteRowData","");
         } else if (epixType_ == EPIX100A) {
            device("digFpga",0)->device("epix100aAsic",asic)->command("WriteRowData","");
         } else if (epixType_ == EPIX10KP) {
            device("digFpga",0)->device("epix10kAsic",asic)->command("WriteRowData","");
         } else if (epixType_ == EPIXS) {
            device("digFpga",0)->device("epixSAsic",asic)->command("WriteRowData","");
         }
      }
   } else if ( name == "WriteColData" ) {
      for (int asic = 0; asic < NASICS; ++asic) {
         if (epixType_ == EPIX100P) {
            device("digFpga",0)->device("epixAsic",asic)->command("WriteColData","");
         } else if (epixType_ == EPIX100A) {
            device("digFpga",0)->device("epix100aAsic",asic)->command("WriteColData","");
         } else if (epixType_ == EPIX10KP) {
            device("digFpga",0)->device("epix10kAsic",asic)->command("WriteColData","");
         } else if (epixType_ == EPIXS) {
            device("digFpga",0)->device("epixSAsic",asic)->command("WriteColData","");
         }
      }
   } else System::command(name, arg);
}

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

//! Method to set run state
void EpixControl::setRunState ( string state ) {
   // Set run command
   device("digFpga",0)->setRunCommand("EpixRun");
   System::setRunState(state);
   
}

