//-----------------------------------------------------------------------------
// File          : DigFpgaCpix.cpp // Author        : Ryan Herbst  <rherbst@slac.stanford.edu>
// Created       : 06/07/2013
// Project       : Digital FPGA
//-----------------------------------------------------------------------------
// Description :
// Digital FPGA container
//-----------------------------------------------------------------------------
// Copyright (c) 2013 by SLAC. All rights reserved.
// Proprietary and confidential to SLAC.
//-----------------------------------------------------------------------------
// Modification history :
// 06/07/2013: created
//-----------------------------------------------------------------------------
#include <DigFpgaCpix.h>
#include <Register.h>
#include <Variable.h>
#include <Command.h>
#include <sstream>
#include <iostream>
#include <string>
#include <iomanip>

#define CLOCK_PERIOD_IN_US (0.010)

using namespace std;

// Constructor
DigFpgaCpix::DigFpgaCpix ( uint destination, uint baseAddress, uint index, Device *parent, uint addrSize ) : Device(destination, baseAddress, "DigFpgaCpix", index, parent) {

   // Description
   desc_ = "Digital Cpix FPGA Object.";

   addRegister(new Register("cpixRunToAcq", baseAddress_ + addrSize*0x0, 1)); 
   addVariable(new Variable("cpixRunToAcq", Variable::Configuration));
   getVariable("cpixRunToAcq")->setDescription("Delay in between the run trigger and the beginning of ACQ pulse");
   getVariable("cpixRunToAcq")->setComp(0,CLOCK_PERIOD_IN_US,0,"us");
      
   addRegister(new Register("cpixR0ToAcq", baseAddress_ + addrSize*0x1, 1)); 
   addVariable(new Variable("cpixR0ToAcq", Variable::Configuration));
   getVariable("cpixR0ToAcq")->setDescription("Delay in between the end of R0 and the beginning of ACQ pulse");
   getVariable("cpixR0ToAcq")->setComp(0,CLOCK_PERIOD_IN_US,0,"us");   
   
   addRegister(new Register("cpixAcqWidth", baseAddress_ + addrSize*0x2, 1)); 
   addVariable(new Variable("cpixAcqWidth", Variable::Configuration));
   getVariable("cpixAcqWidth")->setDescription("Width of ACQ pulse");
   getVariable("cpixAcqWidth")->setComp(0,CLOCK_PERIOD_IN_US,0,"us");   
   
   addRegister(new Register("cpixAcqToCnt", baseAddress_ + addrSize*0x3, 1)); 
   addVariable(new Variable("cpixAcqToCnt", Variable::Configuration));
   getVariable("cpixAcqToCnt")->setDescription("Delay in between the beginning of ACQ pulse and the strobe selecting CntA or CntB");
   getVariable("cpixAcqToCnt")->setComp(0,CLOCK_PERIOD_IN_US,0,"us");   
   
   addRegister(new Register("cpixSyncWidth", baseAddress_ + addrSize*0x4, 1)); 
   addVariable(new Variable("cpixSyncWidth", Variable::Configuration));
   getVariable("cpixSyncWidth")->setDescription("Width of Sync pulse");
   getVariable("cpixSyncWidth")->setComp(0,CLOCK_PERIOD_IN_US,0,"us");   
   
   addRegister(new Register("cpixSROWidth", baseAddress_ + addrSize*0x5, 1)); 
   addVariable(new Variable("cpixSROWidth", Variable::Configuration));
   getVariable("cpixSROWidth")->setDescription("Width of SRO pulse");
   getVariable("cpixSROWidth")->setComp(0,CLOCK_PERIOD_IN_US,0,"us");   
   
   addRegister(new Register("cpixNRuns", baseAddress_ + addrSize*0x6, 1)); 
   addVariable(new Variable("cpixNRuns", Variable::Configuration));
   getVariable("cpixNRuns")->setDescription("Number of counting runs in the acquisition");
   getVariable("cpixNRuns")->setComp(0,CLOCK_PERIOD_IN_US,0,"us");   
   
   addRegister(new Register("cpixCntAnotB", baseAddress_ + addrSize*0x7, 1)); 
   addVariable(new Variable("cpixCntAnotB", Variable::Configuration));
   getVariable("cpixCntAnotB")->setDescription("32 bit sequence of CntA or CntB counting. Bit set to 1 activates CntA.");
   
   addRegister(new Register("cpixSyncMode", baseAddress_ + addrSize*0x8, 1)); 
   addVariable(new Variable("cpixSyncMode", Variable::Configuration));
   getVariable("cpixSyncMode")->setDescription("cpixSyncMode.");
   
   addRegister(new Register("cpixAsicPinControl", baseAddress_ + addrSize*0x9, 1)); 
   addVariable(new Variable("cpixEnACntrl", Variable::Configuration));
   getVariable("cpixEnACntrl")->setDescription("Enable manual control of EnA pin.");
   getVariable("cpixEnACntrl")->setTrueFalse();
   addVariable(new Variable("cpixEnBCntrl", Variable::Configuration));
   getVariable("cpixEnBCntrl")->setDescription("Enable manual control of EnB pin.");
   getVariable("cpixEnBCntrl")->setTrueFalse();
   
   addRegister(new Register("cpixAsicPins", baseAddress_ + addrSize*0xA, 1)); 
   addVariable(new Variable("cpixEnAValue", Variable::Configuration));
   getVariable("cpixEnAValue")->setDescription("Set EnA pin value.");
   getVariable("cpixEnAValue")->setTrueFalse();
   addVariable(new Variable("cpixEnBValue", Variable::Configuration));
   getVariable("cpixEnBValue")->setDescription("Set EnB pin value.");
   getVariable("cpixEnBValue")->setTrueFalse();
   
   addRegister(new Register("cpixErrorRst", baseAddress_ + addrSize*0x100, 1)); 
   addVariable(new Variable("cpixErrorRst", Variable::Configuration));
   getVariable("cpixErrorRst")->setDescription("Reset ASIC error counters.");
   getVariable("cpixErrorRst")->setTrueFalse();
   
   addRegister(new Register("cpixForceFrameRead", baseAddress_ + addrSize*0x101, 1)); 
   addVariable(new Variable("cpixForceFrameRead", Variable::Configuration));
   getVariable("cpixForceFrameRead")->setDescription("Force reading ASIC data frame even with errors.");
   getVariable("cpixForceFrameRead")->setTrueFalse();
   
   addRegister(new Register("cpixAsic0InSync", baseAddress_ + addrSize*0x200, 1));
   addVariable(new Variable("cpixAsic0InSync", Variable::Status));
   getVariable("cpixAsic0InSync")->setDescription("ASIC0 data output in sync bit");
   getVariable("cpixAsic0InSync")->setTrueFalse();
   
   addRegister(new Register("cpixAsic0FrameErr", baseAddress_ + addrSize*0x201, 1));
   addVariable(new Variable("cpixAsic0FrameErr", Variable::Status));
   getVariable("cpixAsic0FrameErr")->setDescription("ASIC0 data output frame error counter");
   
   addRegister(new Register("cpixAsic0CodeErr", baseAddress_ + addrSize*0x202, 1));
   addVariable(new Variable("cpixAsic0CodeErr", Variable::Status));
   getVariable("cpixAsic0CodeErr")->setDescription("ASIC0 data output code error counter");
   
   addRegister(new Register("cpixAsic0TimeoutErr", baseAddress_ + addrSize*0x203, 1));
   addVariable(new Variable("cpixAsic0TimeoutErr", Variable::Status));
   getVariable("cpixAsic0TimeoutErr")->setDescription("ASIC0 data output timeout error counter");
   
   addRegister(new Register("cpixAsic0DoutResync", baseAddress_ + addrSize*0x204, 1));
   addVariable(new Variable("cpixAsic0DoutResync", Variable::Configuration));
   getVariable("cpixAsic0DoutResync")->setDescription("Resync ASIC0 digital output");
   getVariable("cpixAsic0DoutResync")->setTrueFalse();
   
   addRegister(new Register("cpixAsic0DoutDelay", baseAddress_ + addrSize*0x205, 1));
   addVariable(new Variable("cpixAsic0DoutDelay", Variable::Configuration));
   getVariable("cpixAsic0DoutDelay")->setDescription("Adjust ASIC0 digital output delay");
   
   addRegister(new Register("cpixAsic0FramesGood", baseAddress_ + addrSize*0x206, 1));
   addVariable(new Variable("cpixAsic0FramesGood", Variable::Status));
   getVariable("cpixAsic0FramesGood")->setDescription("ASIC0 good frames counter counter");
   
   addRegister(new Register("cpixAsic1InSync", baseAddress_ + addrSize*0x300, 1));
   addVariable(new Variable("cpixAsic1InSync", Variable::Status));
   getVariable("cpixAsic1InSync")->setDescription("ASIC1 data output in sync bit");
   getVariable("cpixAsic1InSync")->setTrueFalse();
   
   addRegister(new Register("cpixAsic1FrameErr", baseAddress_ + addrSize*0x301, 1));
   addVariable(new Variable("cpixAsic1FrameErr", Variable::Status));
   getVariable("cpixAsic1FrameErr")->setDescription("ASIC1 data output frame error counter");
   
   addRegister(new Register("cpixAsic1CodeErr", baseAddress_ + addrSize*0x302, 1));
   addVariable(new Variable("cpixAsic1CodeErr", Variable::Status));
   getVariable("cpixAsic1CodeErr")->setDescription("ASIC1 data output code error counter");
   
   addRegister(new Register("cpixAsic1TimeoutErr", baseAddress_ + addrSize*0x303, 1));
   addVariable(new Variable("cpixAsic1TimeoutErr", Variable::Status));
   getVariable("cpixAsic1TimeoutErr")->setDescription("ASIC1 data output timeout error counter");
   
   addRegister(new Register("cpixAsic1DoutResync", baseAddress_ + addrSize*0x304, 1));
   addVariable(new Variable("cpixAsic1DoutResync", Variable::Configuration));
   getVariable("cpixAsic1DoutResync")->setDescription("Resync ASIC1 digital output");
   getVariable("cpixAsic1DoutResync")->setTrueFalse();
   
   addRegister(new Register("cpixAsic1DoutDelay", baseAddress_ + addrSize*0x305, 1));
   addVariable(new Variable("cpixAsic1DoutDelay", Variable::Configuration));
   getVariable("cpixAsic1DoutDelay")->setDescription("Adjust ASIC1 digital output delay");
   
   addRegister(new Register("cpixAsic1FramesGood", baseAddress_ + addrSize*0x306, 1));
   addVariable(new Variable("cpixAsic1FramesGood", Variable::Status));
   getVariable("cpixAsic1FramesGood")->setDescription("ASIC1 good frames counter counter");
   
}

// Deconstructor
DigFpgaCpix::~DigFpgaCpix ( ) { }

// Method to process a command
void DigFpgaCpix::command ( string name, string arg) {
   
   Device::command(name, arg);
}

// Method to read status registers and update variables
void DigFpgaCpix::readStatus ( ) {
   
   REGISTER_LOCK
   
   readRegister(getRegister("cpixAsic0InSync"));
   getVariable("cpixAsic0InSync")->setInt(getRegister("cpixAsic0InSync")->get());
   
   readRegister(getRegister("cpixAsic0FrameErr"));
   getVariable("cpixAsic0FrameErr")->setInt(getRegister("cpixAsic0FrameErr")->get());
   
   readRegister(getRegister("cpixAsic0CodeErr"));
   getVariable("cpixAsic0CodeErr")->setInt(getRegister("cpixAsic0CodeErr")->get());
   
   readRegister(getRegister("cpixAsic0TimeoutErr"));
   getVariable("cpixAsic0TimeoutErr")->setInt(getRegister("cpixAsic0TimeoutErr")->get());
   
   readRegister(getRegister("cpixAsic0FramesGood"));
   getVariable("cpixAsic0FramesGood")->setInt(getRegister("cpixAsic0FramesGood")->get());
   
   readRegister(getRegister("cpixAsic1InSync"));
   getVariable("cpixAsic1InSync")->setInt(getRegister("cpixAsic1InSync")->get());
   
   readRegister(getRegister("cpixAsic1FrameErr"));
   getVariable("cpixAsic1FrameErr")->setInt(getRegister("cpixAsic1FrameErr")->get());
   
   readRegister(getRegister("cpixAsic1CodeErr"));
   getVariable("cpixAsic1CodeErr")->setInt(getRegister("cpixAsic1CodeErr")->get());
   
   readRegister(getRegister("cpixAsic1TimeoutErr"));
   getVariable("cpixAsic1TimeoutErr")->setInt(getRegister("cpixAsic1TimeoutErr")->get());
   
   readRegister(getRegister("cpixAsic1FramesGood"));
   getVariable("cpixAsic1FramesGood")->setInt(getRegister("cpixAsic1FramesGood")->get());
   
   REGISTER_UNLOCK
   
   Device::readStatus();
}

// Method to read configuration registers and update variables
void DigFpgaCpix::readConfig ( ) {

   REGISTER_LOCK

   readRegister(getRegister("cpixRunToAcq"));
   getVariable("cpixRunToAcq")->setInt(getRegister("cpixRunToAcq")->get());
   
   readRegister(getRegister("cpixR0ToAcq"));
   getVariable("cpixR0ToAcq")->setInt(getRegister("cpixR0ToAcq")->get());
   
   readRegister(getRegister("cpixAcqWidth"));
   getVariable("cpixAcqWidth")->setInt(getRegister("cpixAcqWidth")->get());
   
   readRegister(getRegister("cpixAcqToCnt"));
   getVariable("cpixAcqToCnt")->setInt(getRegister("cpixAcqToCnt")->get());
   
   readRegister(getRegister("cpixSyncWidth"));
   getVariable("cpixSyncWidth")->setInt(getRegister("cpixSyncWidth")->get());
   
   readRegister(getRegister("cpixSROWidth"));
   getVariable("cpixSROWidth")->setInt(getRegister("cpixSROWidth")->get());
   
   readRegister(getRegister("cpixNRuns"));
   getVariable("cpixNRuns")->setInt(getRegister("cpixNRuns")->get());
   
   readRegister(getRegister("cpixCntAnotB"));
   getVariable("cpixCntAnotB")->setInt(getRegister("cpixCntAnotB")->get());
   
   readRegister(getRegister("cpixErrorRst"));
   getVariable("cpixErrorRst")->setInt(getRegister("cpixErrorRst")->get());
   
   readRegister(getRegister("cpixForceFrameRead"));
   getVariable("cpixForceFrameRead")->setInt(getRegister("cpixForceFrameRead")->get());
   
   readRegister(getRegister("cpixSyncMode"));
   getVariable("cpixSyncMode")->setInt(getRegister("cpixSyncMode")->get());
   
   readRegister(getRegister("cpixAsicPinControl"));
   getVariable("cpixEnACntrl")->setInt(getRegister("cpixAsicPinControl")->get(5,0x1));
   getVariable("cpixEnBCntrl")->setInt(getRegister("cpixAsicPinControl")->get(6,0x1));
   
   readRegister(getRegister("cpixAsicPins"));
   getVariable("cpixEnAValue")->setInt(getRegister("cpixAsicPins")->get(5,0x1));
   getVariable("cpixEnBValue")->setInt(getRegister("cpixAsicPins")->get(6,0x1));
   
   readRegister(getRegister("cpixAsic0DoutResync"));
   getVariable("cpixAsic0DoutResync")->setInt(getRegister("cpixAsic0DoutResync")->get());
   
   readRegister(getRegister("cpixAsic0DoutDelay"));
   getVariable("cpixAsic0DoutDelay")->setInt(getRegister("cpixAsic0DoutDelay")->get());
   
   readRegister(getRegister("cpixAsic1DoutResync"));
   getVariable("cpixAsic1DoutResync")->setInt(getRegister("cpixAsic1DoutResync")->get());
   
   readRegister(getRegister("cpixAsic1DoutDelay"));
   getVariable("cpixAsic1DoutDelay")->setInt(getRegister("cpixAsic1DoutDelay")->get());
   
   REGISTER_UNLOCK
   
   // Sub devices
   Device::readConfig();
}

// Method to write configuration registers
void DigFpgaCpix::writeConfig ( bool force ) {

   REGISTER_LOCK

   getRegister("cpixRunToAcq")->set(getVariable("cpixRunToAcq")->getInt());
   writeRegister(getRegister("cpixRunToAcq"),force);
   
   getRegister("cpixR0ToAcq")->set(getVariable("cpixR0ToAcq")->getInt());
   writeRegister(getRegister("cpixR0ToAcq"),force);
   
   getRegister("cpixAcqWidth")->set(getVariable("cpixAcqWidth")->getInt());
   writeRegister(getRegister("cpixAcqWidth"),force);
   
   getRegister("cpixAcqToCnt")->set(getVariable("cpixAcqToCnt")->getInt());
   writeRegister(getRegister("cpixAcqToCnt"),force);
   
   getRegister("cpixSyncWidth")->set(getVariable("cpixSyncWidth")->getInt());
   writeRegister(getRegister("cpixSyncWidth"),force);
   
   getRegister("cpixSROWidth")->set(getVariable("cpixSROWidth")->getInt());
   writeRegister(getRegister("cpixSROWidth"),force);
   
   getRegister("cpixNRuns")->set(getVariable("cpixNRuns")->getInt());
   writeRegister(getRegister("cpixNRuns"),force);
   
   getRegister("cpixCntAnotB")->set(getVariable("cpixCntAnotB")->getInt());
   writeRegister(getRegister("cpixCntAnotB"),force);
   
   getRegister("cpixErrorRst")->set(getVariable("cpixErrorRst")->getInt());
   writeRegister(getRegister("cpixErrorRst"),force);
   
   getRegister("cpixForceFrameRead")->set(getVariable("cpixForceFrameRead")->getInt());
   writeRegister(getRegister("cpixForceFrameRead"),force);
   
   getRegister("cpixSyncMode")->set(getVariable("cpixSyncMode")->getInt());
   writeRegister(getRegister("cpixSyncMode"),force);
   
   getRegister("cpixAsicPinControl")->set(getVariable("cpixEnACntrl")->getInt(),5,0x1);
   getRegister("cpixAsicPinControl")->set(getVariable("cpixEnBCntrl")->getInt(),6,0x1);
   writeRegister(getRegister("cpixAsicPinControl"),force);
   
   getRegister("cpixAsicPins")->set(getVariable("cpixEnAValue")->getInt(),5,0x1);
   getRegister("cpixAsicPins")->set(getVariable("cpixEnBValue")->getInt(),6,0x1);
   writeRegister(getRegister("cpixAsicPins"),force);
   
   getRegister("cpixAsic0DoutResync")->set(getVariable("cpixAsic0DoutResync")->getInt());
   writeRegister(getRegister("cpixAsic0DoutResync"),force);
   
   getRegister("cpixAsic0DoutDelay")->set(getVariable("cpixAsic0DoutDelay")->getInt());
   writeRegister(getRegister("cpixAsic0DoutDelay"),force);
   
   getRegister("cpixAsic1DoutResync")->set(getVariable("cpixAsic1DoutResync")->getInt());
   writeRegister(getRegister("cpixAsic1DoutResync"),force);
   
   getRegister("cpixAsic1DoutDelay")->set(getVariable("cpixAsic1DoutDelay")->getInt());
   writeRegister(getRegister("cpixAsic1DoutDelay"),force);
   
   REGISTER_UNLOCK
   
   // Sub devices
   Device::writeConfig(force);
}

// Verify hardware state of configuration
void DigFpgaCpix::verifyConfig ( ) {
   REGISTER_LOCK
   
   verifyRegister(getRegister("cpixRunToAcq"));
   verifyRegister(getRegister("cpixR0ToAcq"));
   verifyRegister(getRegister("cpixAcqWidth"));
   verifyRegister(getRegister("cpixAcqToCnt"));
   verifyRegister(getRegister("cpixSyncWidth"));
   verifyRegister(getRegister("cpixSROWidth"));
   verifyRegister(getRegister("cpixNRuns"));
   verifyRegister(getRegister("cpixCntAnotB"));
   verifyRegister(getRegister("cpixErrorRst"));
   verifyRegister(getRegister("cpixForceFrameRead"));
   verifyRegister(getRegister("cpixSyncMode"));
   verifyRegister(getRegister("cpixAsicPinControl"));
   verifyRegister(getRegister("cpixAsicPins"));
   verifyRegister(getRegister("cpixAsic0DoutResync"));
   verifyRegister(getRegister("cpixAsic0DoutDelay"));
   verifyRegister(getRegister("cpixAsic1DoutResync"));
   verifyRegister(getRegister("cpixAsic1DoutDelay"));
   
   REGISTER_UNLOCK
   
   // Sub devices
   Device::verifyConfig();
}

