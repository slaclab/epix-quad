//-----------------------------------------------------------------------------
// File          : DigFpgaTixel.cpp // Author        : Ryan Herbst  <rherbst@slac.stanford.edu>
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
#include <DigFpgaTixel.h>
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
DigFpgaTixel::DigFpgaTixel ( uint destination, uint baseAddress, uint index, Device *parent, uint addrSize ) : Device(destination, baseAddress, "DigFpgaTixel", index, parent) {

   // Description
   desc_ = "Digital Tixel FPGA Object.";

   addRegister(new Register("tixelRunToR0", baseAddress_ + addrSize*0x0, 1)); 
   addVariable(new Variable("tixelRunToR0", Variable::Configuration));
   getVariable("tixelRunToR0")->setDescription("");
   getVariable("tixelRunToR0")->setComp(0,CLOCK_PERIOD_IN_US,0,"us");
      
   addRegister(new Register("tixelR0ToStart", baseAddress_ + addrSize*0x1, 1)); 
   addVariable(new Variable("tixelR0ToStart", Variable::Configuration));
   getVariable("tixelR0ToStart")->setDescription("");
   getVariable("tixelR0ToStart")->setComp(0,CLOCK_PERIOD_IN_US,0,"us");   
   
   addRegister(new Register("tixelStartToTpulse", baseAddress_ + addrSize*0x2, 1)); 
   addVariable(new Variable("tixelStartToTpulse", Variable::Configuration));
   getVariable("tixelStartToTpulse")->setDescription("Width of ACQ pulse");
   getVariable("tixelStartToTpulse")->setComp(0,CLOCK_PERIOD_IN_US,0,"us");   
   
   addRegister(new Register("tixelTpulseToAcq", baseAddress_ + addrSize*0x3, 1)); 
   addVariable(new Variable("tixelTpulseToAcq", Variable::Configuration));
   getVariable("tixelTpulseToAcq")->setDescription("");
   getVariable("tixelTpulseToAcq")->setComp(0,CLOCK_PERIOD_IN_US,0,"us");   
   
   addRegister(new Register("tixelSyncMode", baseAddress_ + addrSize*0x4, 1)); 
   addVariable(new Variable("tixelSyncMode", Variable::Configuration));
   getVariable("tixelSyncMode")->setDescription(""); 
   
   addRegister(new Register("tixelAsicPinControl", baseAddress_ + addrSize*0x9, 1)); 
   addVariable(new Variable("tixelGlblRstCntrl", Variable::Configuration));
   getVariable("tixelGlblRstCntrl")->setDescription("Enable manual control of GlblRst pin.");
   getVariable("tixelGlblRstCntrl")->setTrueFalse();
   addVariable(new Variable("tixelAcqCntrl", Variable::Configuration));
   getVariable("tixelAcqCntrl")->setDescription("Enable manual control of Acq pin.");
   getVariable("tixelAcqCntrl")->setTrueFalse();
   addVariable(new Variable("tixelR0Cntrl", Variable::Configuration));
   getVariable("tixelR0Cntrl")->setDescription("Enable manual control of R0 pin.");
   getVariable("tixelR0Cntrl")->setTrueFalse();
   addVariable(new Variable("tixelTpulseCntrl", Variable::Configuration));
   getVariable("tixelTpulseCntrl")->setDescription("Enable manual control of Tpulse pin.");
   getVariable("tixelTpulseCntrl")->setTrueFalse();
   addVariable(new Variable("tixelStartCntrl", Variable::Configuration));
   getVariable("tixelStartCntrl")->setDescription("Enable manual control of Start pin.");
   getVariable("tixelStartCntrl")->setTrueFalse();
   addVariable(new Variable("tixelPpmatCntrl", Variable::Configuration));
   getVariable("tixelPpmatCntrl")->setDescription("Enable manual control of PPMAT pin.");
   getVariable("tixelPpmatCntrl")->setTrueFalse();
   addVariable(new Variable("tixelPpbeCntrl", Variable::Configuration));
   getVariable("tixelPpbeCntrl")->setDescription("Enable manual control of PPBE pin.");
   getVariable("tixelPpbeCntrl")->setTrueFalse();
   
   addRegister(new Register("tixelAsicPins", baseAddress_ + addrSize*0xA, 1)); 
   addVariable(new Variable("tixelGlblRstValue", Variable::Configuration));
   getVariable("tixelGlblRstValue")->setDescription("Set GlblRst pin value.");
   getVariable("tixelGlblRstValue")->setTrueFalse();
   addVariable(new Variable("tixelAcqValue", Variable::Configuration));
   getVariable("tixelAcqValue")->setDescription("Set ACQ pin value.");
   getVariable("tixelAcqValue")->setTrueFalse();
   addVariable(new Variable("tixelR0Value", Variable::Configuration));
   getVariable("tixelR0Value")->setDescription("Set R0 pin value.");
   getVariable("tixelR0Value")->setTrueFalse();
   addVariable(new Variable("tixelTpulseValue", Variable::Configuration));
   getVariable("tixelTpulseValue")->setDescription("Set Tpulse pin value.");
   getVariable("tixelTpulseValue")->setTrueFalse();
   addVariable(new Variable("tixelStartValue", Variable::Configuration));
   getVariable("tixelStartValue")->setDescription("Set Start pin value.");
   getVariable("tixelStartValue")->setTrueFalse();
   addVariable(new Variable("tixelPpmatValue", Variable::Configuration));
   getVariable("tixelPpmatValue")->setDescription("Set PPMAT pin value.");
   getVariable("tixelPpmatValue")->setTrueFalse();
   addVariable(new Variable("tixelPpbeValue", Variable::Configuration));
   getVariable("tixelPpbeValue")->setDescription("Set PPBE pin value.");
   getVariable("tixelPpbeValue")->setTrueFalse();
   
   addRegister(new Register("tixelErrorRst", baseAddress_ + addrSize*0x100, 1)); 
   addVariable(new Variable("tixelErrorRst", Variable::Configuration));
   getVariable("tixelErrorRst")->setDescription("Reset ASIC error counters.");
   getVariable("tixelErrorRst")->setTrueFalse();
   
   addRegister(new Register("tixelForceFrameRead", baseAddress_ + addrSize*0x101, 1)); 
   addVariable(new Variable("tixelForceFrameRead", Variable::Configuration));
   getVariable("tixelForceFrameRead")->setDescription("Force reading ASIC data frame even with errors.");
   getVariable("tixelForceFrameRead")->setTrueFalse();
   
   addRegister(new Register("tixelAsic0InSync", baseAddress_ + addrSize*0x200, 1));
   addVariable(new Variable("tixelAsic0InSync", Variable::Status));
   getVariable("tixelAsic0InSync")->setDescription("ASIC0 data output in sync bit");
   getVariable("tixelAsic0InSync")->setTrueFalse();
   
   addRegister(new Register("tixelAsic0FrameErr", baseAddress_ + addrSize*0x201, 1));
   addVariable(new Variable("tixelAsic0FrameErr", Variable::Status));
   getVariable("tixelAsic0FrameErr")->setDescription("ASIC0 data output frame error counter");
   
   addRegister(new Register("tixelAsic0CodeErr", baseAddress_ + addrSize*0x202, 1));
   addVariable(new Variable("tixelAsic0CodeErr", Variable::Status));
   getVariable("tixelAsic0CodeErr")->setDescription("ASIC0 data output code error counter");
   
   addRegister(new Register("tixelAsic0TimeoutErr", baseAddress_ + addrSize*0x203, 1));
   addVariable(new Variable("tixelAsic0TimeoutErr", Variable::Status));
   getVariable("tixelAsic0TimeoutErr")->setDescription("ASIC0 data output timeout error counter");
   
   addRegister(new Register("tixelAsic0DoutResync", baseAddress_ + addrSize*0x204, 1));
   addVariable(new Variable("tixelAsic0DoutResync", Variable::Configuration));
   getVariable("tixelAsic0DoutResync")->setDescription("Resync ASIC0 digital output");
   getVariable("tixelAsic0DoutResync")->setTrueFalse();
   
   addRegister(new Register("tixelAsic0DoutDelay", baseAddress_ + addrSize*0x205, 1));
   addVariable(new Variable("tixelAsic0DoutDelay", Variable::Configuration));
   getVariable("tixelAsic0DoutDelay")->setDescription("Adjust ASIC0 digital output delay");
   
   addRegister(new Register("tixelAsic0FramesGood", baseAddress_ + addrSize*0x206, 1));
   addVariable(new Variable("tixelAsic0FramesGood", Variable::Status));
   getVariable("tixelAsic0FramesGood")->setDescription("ASIC0 good frames counter counter");
   
   addRegister(new Register("tixelAsic1InSync", baseAddress_ + addrSize*0x300, 1));
   addVariable(new Variable("tixelAsic1InSync", Variable::Status));
   getVariable("tixelAsic1InSync")->setDescription("ASIC1 data output in sync bit");
   getVariable("tixelAsic1InSync")->setTrueFalse();
   
   addRegister(new Register("tixelAsic1FrameErr", baseAddress_ + addrSize*0x301, 1));
   addVariable(new Variable("tixelAsic1FrameErr", Variable::Status));
   getVariable("tixelAsic1FrameErr")->setDescription("ASIC1 data output frame error counter");
   
   addRegister(new Register("tixelAsic1CodeErr", baseAddress_ + addrSize*0x302, 1));
   addVariable(new Variable("tixelAsic1CodeErr", Variable::Status));
   getVariable("tixelAsic1CodeErr")->setDescription("ASIC1 data output code error counter");
   
   addRegister(new Register("tixelAsic1TimeoutErr", baseAddress_ + addrSize*0x303, 1));
   addVariable(new Variable("tixelAsic1TimeoutErr", Variable::Status));
   getVariable("tixelAsic1TimeoutErr")->setDescription("ASIC1 data output timeout error counter");
   
   addRegister(new Register("tixelAsic1DoutResync", baseAddress_ + addrSize*0x304, 1));
   addVariable(new Variable("tixelAsic1DoutResync", Variable::Configuration));
   getVariable("tixelAsic1DoutResync")->setDescription("Resync ASIC1 digital output");
   getVariable("tixelAsic1DoutResync")->setTrueFalse();
   
   addRegister(new Register("tixelAsic1DoutDelay", baseAddress_ + addrSize*0x305, 1));
   addVariable(new Variable("tixelAsic1DoutDelay", Variable::Configuration));
   getVariable("tixelAsic1DoutDelay")->setDescription("Adjust ASIC1 digital output delay");
   
   addRegister(new Register("tixelAsic1FramesGood", baseAddress_ + addrSize*0x306, 1));
   addVariable(new Variable("tixelAsic1FramesGood", Variable::Status));
   getVariable("tixelAsic1FramesGood")->setDescription("ASIC1 good frames counter counter");
   
}

// Deconstructor
DigFpgaTixel::~DigFpgaTixel ( ) { }

// Method to process a command
void DigFpgaTixel::command ( string name, string arg) {
   
   Device::command(name, arg);
}

// Method to read status registers and update variables
void DigFpgaTixel::readStatus ( ) {
   
   REGISTER_LOCK
   
   readRegister(getRegister("tixelAsic0InSync"));
   getVariable("tixelAsic0InSync")->setInt(getRegister("tixelAsic0InSync")->get());
   
   readRegister(getRegister("tixelAsic0FrameErr"));
   getVariable("tixelAsic0FrameErr")->setInt(getRegister("tixelAsic0FrameErr")->get());
   
   readRegister(getRegister("tixelAsic0CodeErr"));
   getVariable("tixelAsic0CodeErr")->setInt(getRegister("tixelAsic0CodeErr")->get());
   
   readRegister(getRegister("tixelAsic0TimeoutErr"));
   getVariable("tixelAsic0TimeoutErr")->setInt(getRegister("tixelAsic0TimeoutErr")->get());
   
   readRegister(getRegister("tixelAsic0FramesGood"));
   getVariable("tixelAsic0FramesGood")->setInt(getRegister("tixelAsic0FramesGood")->get());
   
   readRegister(getRegister("tixelAsic1InSync"));
   getVariable("tixelAsic1InSync")->setInt(getRegister("tixelAsic1InSync")->get());
   
   readRegister(getRegister("tixelAsic1FrameErr"));
   getVariable("tixelAsic1FrameErr")->setInt(getRegister("tixelAsic1FrameErr")->get());
   
   readRegister(getRegister("tixelAsic1CodeErr"));
   getVariable("tixelAsic1CodeErr")->setInt(getRegister("tixelAsic1CodeErr")->get());
   
   readRegister(getRegister("tixelAsic1TimeoutErr"));
   getVariable("tixelAsic1TimeoutErr")->setInt(getRegister("tixelAsic1TimeoutErr")->get());
   
   readRegister(getRegister("tixelAsic1FramesGood"));
   getVariable("tixelAsic1FramesGood")->setInt(getRegister("tixelAsic1FramesGood")->get());
   
   REGISTER_UNLOCK
   
   Device::readStatus();
}

// Method to read configuration registers and update variables
void DigFpgaTixel::readConfig ( ) {

   REGISTER_LOCK

   readRegister(getRegister("tixelRunToR0"));
   getVariable("tixelRunToR0")->setInt(getRegister("tixelRunToR0")->get());
   
   readRegister(getRegister("tixelR0ToStart"));
   getVariable("tixelR0ToStart")->setInt(getRegister("tixelR0ToStart")->get());
   
   readRegister(getRegister("tixelStartToTpulse"));
   getVariable("tixelStartToTpulse")->setInt(getRegister("tixelStartToTpulse")->get());
   
   readRegister(getRegister("tixelTpulseToAcq"));
   getVariable("tixelTpulseToAcq")->setInt(getRegister("tixelTpulseToAcq")->get());
   
   readRegister(getRegister("tixelSyncMode"));
   getVariable("tixelSyncMode")->setInt(getRegister("tixelSyncMode")->get());
   
   readRegister(getRegister("tixelErrorRst"));
   getVariable("tixelErrorRst")->setInt(getRegister("tixelErrorRst")->get());
   
   readRegister(getRegister("tixelForceFrameRead"));
   getVariable("tixelForceFrameRead")->setInt(getRegister("tixelForceFrameRead")->get());
   
   readRegister(getRegister("tixelAsicPinControl"));
   getVariable("tixelGlblRstCntrl")->setInt(getRegister("tixelAsicPinControl")->get(0,0x1));
   getVariable("tixelAcqCntrl")->setInt(getRegister("tixelAsicPinControl")->get(1,0x1));
   getVariable("tixelR0Cntrl")->setInt(getRegister("tixelAsicPinControl")->get(2,0x1));
   getVariable("tixelTpulseCntrl")->setInt(getRegister("tixelAsicPinControl")->get(3,0x1));
   getVariable("tixelStartCntrl")->setInt(getRegister("tixelAsicPinControl")->get(4,0x1));
   getVariable("tixelPpmatCntrl")->setInt(getRegister("tixelAsicPinControl")->get(5,0x1));
   getVariable("tixelPpbeCntrl")->setInt(getRegister("tixelAsicPinControl")->get(6,0x1));
   
   readRegister(getRegister("tixelAsicPins"));
   getVariable("tixelGlblRstValue")->setInt(getRegister("tixelAsicPins")->get(0,0x1));
   getVariable("tixelAcqValue")->setInt(getRegister("tixelAsicPins")->get(1,0x1));
   getVariable("tixelR0Value")->setInt(getRegister("tixelAsicPins")->get(2,0x1));
   getVariable("tixelTpulseValue")->setInt(getRegister("tixelAsicPins")->get(3,0x1));
   getVariable("tixelStartValue")->setInt(getRegister("tixelAsicPins")->get(4,0x1));
   getVariable("tixelPpmatValue")->setInt(getRegister("tixelAsicPins")->get(5,0x1));
   getVariable("tixelPpbeValue")->setInt(getRegister("tixelAsicPins")->get(6,0x1));
   
   readRegister(getRegister("tixelAsic0DoutResync"));
   getVariable("tixelAsic0DoutResync")->setInt(getRegister("tixelAsic0DoutResync")->get());
   
   readRegister(getRegister("tixelAsic0DoutDelay"));
   getVariable("tixelAsic0DoutDelay")->setInt(getRegister("tixelAsic0DoutDelay")->get());
   
   readRegister(getRegister("tixelAsic1DoutResync"));
   getVariable("tixelAsic1DoutResync")->setInt(getRegister("tixelAsic1DoutResync")->get());
   
   readRegister(getRegister("tixelAsic1DoutDelay"));
   getVariable("tixelAsic1DoutDelay")->setInt(getRegister("tixelAsic1DoutDelay")->get());
   
   REGISTER_UNLOCK
   
   // Sub devices
   Device::readConfig();
}

// Method to write configuration registers
void DigFpgaTixel::writeConfig ( bool force ) {

   REGISTER_LOCK

   getRegister("tixelRunToR0")->set(getVariable("tixelRunToR0")->getInt());
   writeRegister(getRegister("tixelRunToR0"),force);
   
   getRegister("tixelR0ToStart")->set(getVariable("tixelR0ToStart")->getInt());
   writeRegister(getRegister("tixelR0ToStart"),force);
   
   getRegister("tixelStartToTpulse")->set(getVariable("tixelStartToTpulse")->getInt());
   writeRegister(getRegister("tixelStartToTpulse"),force);
   
   getRegister("tixelTpulseToAcq")->set(getVariable("tixelTpulseToAcq")->getInt());
   writeRegister(getRegister("tixelTpulseToAcq"),force);
   
   getRegister("tixelSyncMode")->set(getVariable("tixelSyncMode")->getInt());
   writeRegister(getRegister("tixelSyncMode"),force);
   
   getRegister("tixelErrorRst")->set(getVariable("tixelErrorRst")->getInt());
   writeRegister(getRegister("tixelErrorRst"),force);
   
   getRegister("tixelForceFrameRead")->set(getVariable("tixelForceFrameRead")->getInt());
   writeRegister(getRegister("tixelForceFrameRead"),force);
   
   getRegister("tixelAsicPinControl")->set(getVariable("tixelGlblRstCntrl")->getInt(),0,0x1);
   getRegister("tixelAsicPinControl")->set(getVariable("tixelAcqCntrl")->getInt(),1,0x1);
   getRegister("tixelAsicPinControl")->set(getVariable("tixelR0Cntrl")->getInt(),2,0x1);
   getRegister("tixelAsicPinControl")->set(getVariable("tixelTpulseCntrl")->getInt(),3,0x1);
   getRegister("tixelAsicPinControl")->set(getVariable("tixelStartCntrl")->getInt(),4,0x1);
   getRegister("tixelAsicPinControl")->set(getVariable("tixelPpmatCntrl")->getInt(),5,0x1);
   getRegister("tixelAsicPinControl")->set(getVariable("tixelPpbeCntrl")->getInt(),6,0x1);
   writeRegister(getRegister("tixelAsicPinControl"),force);
   
   getRegister("tixelAsicPins")->set(getVariable("tixelGlblRstValue")->getInt(),0,0x1);
   getRegister("tixelAsicPins")->set(getVariable("tixelAcqValue")->getInt(),1,0x1);
   getRegister("tixelAsicPins")->set(getVariable("tixelR0Value")->getInt(),2,0x1);
   getRegister("tixelAsicPins")->set(getVariable("tixelTpulseValue")->getInt(),3,0x1);
   getRegister("tixelAsicPins")->set(getVariable("tixelStartValue")->getInt(),4,0x1);
   getRegister("tixelAsicPins")->set(getVariable("tixelPpmatValue")->getInt(),5,0x1);
   getRegister("tixelAsicPins")->set(getVariable("tixelPpbeValue")->getInt(),6,0x1);
   writeRegister(getRegister("tixelAsicPins"),force);
   
   getRegister("tixelAsic0DoutResync")->set(getVariable("tixelAsic0DoutResync")->getInt());
   writeRegister(getRegister("tixelAsic0DoutResync"),force);
   
   getRegister("tixelAsic0DoutDelay")->set(getVariable("tixelAsic0DoutDelay")->getInt());
   writeRegister(getRegister("tixelAsic0DoutDelay"),force);
   
   getRegister("tixelAsic1DoutResync")->set(getVariable("tixelAsic1DoutResync")->getInt());
   writeRegister(getRegister("tixelAsic1DoutResync"),force);
   
   getRegister("tixelAsic1DoutDelay")->set(getVariable("tixelAsic1DoutDelay")->getInt());
   writeRegister(getRegister("tixelAsic1DoutDelay"),force);
   
   REGISTER_UNLOCK
   
   // Sub devices
   Device::writeConfig(force);
}

// Verify hardware state of configuration
void DigFpgaTixel::verifyConfig ( ) {
   REGISTER_LOCK
   
   verifyRegister(getRegister("tixelRunToR0"));
   verifyRegister(getRegister("tixelR0ToStart"));
   verifyRegister(getRegister("tixelStartToTpulse"));
   verifyRegister(getRegister("tixelTpulseToAcq"));
   verifyRegister(getRegister("tixelSyncMode"));
   verifyRegister(getRegister("tixelErrorRst"));
   verifyRegister(getRegister("tixelForceFrameRead"));
   verifyRegister(getRegister("tixelAsicPinControl"));
   verifyRegister(getRegister("tixelAsicPins"));
   verifyRegister(getRegister("tixelAsic0DoutResync"));
   verifyRegister(getRegister("tixelAsic0DoutDelay"));
   verifyRegister(getRegister("tixelAsic1DoutResync"));
   verifyRegister(getRegister("tixelAsic1DoutDelay"));
   
   REGISTER_UNLOCK
   
   // Sub devices
   Device::verifyConfig();
}

