//-----------------------------------------------------------------------------
// File          : Ad9252.cpp
// Author        : Ryan Herbst  <rherbst@slac.stanford.edu>
// Created       : 04/12/2011
// Project       : Heavy Photon Tracker
//-----------------------------------------------------------------------------
// Description :
// AD9252 ADC
//-----------------------------------------------------------------------------
// Copyright (c) 2011 by SLAC. All rights reserved.
// Proprietary and confidential to SLAC.
//-----------------------------------------------------------------------------
// Modification history :
// 04/12/2011: created
//-----------------------------------------------------------------------------
#include <Ad9252.h>
#include <Register.h>
#include <Variable.h>
#include <sstream>
#include <iostream>
#include <string>
#include <iomanip>
using namespace std;

// Constructor
Ad9252::Ad9252 ( uint destination, uint baseAddress, uint index, Device *parent ) : 
                        Device(destination,baseAddress,"ad9252",index,parent) {

   // Description
   desc_ = "AD9252 ADC object.";

   // Create Registers: name, address
   addRegister(new Register("ChipPortConfig",  baseAddress_ + 0x00, 1));
   addRegister(new Register("ChipId",          baseAddress_ + 0x01, 1));
   addRegister(new Register("ChipGrade",       baseAddress_ + 0x02, 1));
   addRegister(new Register("DeviceIndex2",    baseAddress_ + 0x04, 1));
   addRegister(new Register("DeviceIndex1",    baseAddress_ + 0x05, 1));
   addRegister(new Register("Modes",           baseAddress_ + 0x08, 1));
   addRegister(new Register("Clock",           baseAddress_ + 0x09, 1));
   addRegister(new Register("TestIo",          baseAddress_ + 0x0D, 1));
   addRegister(new Register("OutputMode",      baseAddress_ + 0x14, 1));
   addRegister(new Register("OutputAdjust",    baseAddress_ + 0x15, 1));
   addRegister(new Register("OutputPhase",     baseAddress_ + 0x16, 1));
   addRegister(new Register("UserPatt1Lsb",    baseAddress_ + 0x19, 1));
   addRegister(new Register("UserPatt1Msb",    baseAddress_ + 0x1A, 1));
   addRegister(new Register("UserPatt2Lsb",    baseAddress_ + 0x1B, 1));
   addRegister(new Register("UserPatt2Msb",    baseAddress_ + 0x1C, 1));
   addRegister(new Register("SerialControl",   baseAddress_ + 0x21, 1));
   addRegister(new Register("SerialControl",   baseAddress_ + 0x21, 1));
   addRegister(new Register("SerialChStat",    baseAddress_ + 0x22, 1));
   addRegister(new Register("DeviceUpdate",    baseAddress_ + 0xFF, 1));

   // Variables
   addVariable(new Variable("ConfigEn", Variable::Configuration));
   getVariable("ConfigEn")->setDescription("Set to 'True' to enable register writes to ADC.");
   getVariable("ConfigEn")->setTrueFalse();
   getVariable("ConfigEn")->set("False");

   addVariable(new Variable("ChipId", Variable::Status));
   getVariable("ChipId")->setDescription("Read only chip ID value.");

   addVariable(new Variable("ChipGrade", Variable::Status));
   getVariable("ChipGrade")->setDescription("Read only chip grade value.");

   addVariable(new Variable("PowerDownMode", Variable::Configuration));
   getVariable("PowerDownMode")->setDescription("Set power mode of device.");
   vector<string> powerDownModes;
   powerDownModes.resize(4);
   powerDownModes[0]   = "ChipRun";
   powerDownModes[1]   = "FullPowerDown";
   powerDownModes[2]   = "Standby";
   powerDownModes[3]   = "Reset";
   getVariable("PowerDownMode")->setEnums(powerDownModes);

   addVariable(new Variable("DutyCycleStabilizer", Variable::Configuration));
   getVariable("DutyCycleStabilizer")->setDescription("Turns on internal duty cycle stabilizer. (default=True).");
   getVariable("DutyCycleStabilizer")->setTrueFalse();

   addVariable(new Variable("UserTestMode", Variable::Configuration));
   getVariable("UserTestMode")->setDescription("Sets user test mode of all channels.");
   vector<string> userTestModes;
   userTestModes.resize(4);
   userTestModes[0]    = "Off";
   userTestModes[1]    = "OnSingleAlt";
   userTestModes[2]    = "OnSingleOnce";
   userTestModes[3]    = "OnAlternateOnce";
   getVariable("UserTestMode")->setEnums(userTestModes);

   addVariable(new Variable("ResetPnLongGen", Variable::Configuration));
   getVariable("ResetPnLongGen")->setDescription("Reset PN long gen test mode.");
   getVariable("ResetPnLongGen")->setTrueFalse();

   addVariable(new Variable("ResetPnShortGen", Variable::Configuration));
   getVariable("ResetPnShortGen")->setDescription("Reset PN short gen test mode.");
   getVariable("ResetPnShortGen")->setTrueFalse();

   addVariable(new Variable("OutputTestMode", Variable::Configuration));
   getVariable("OutputTestMode")->setDescription("Set output test mode.");
   vector<string> outputTestModes;
   outputTestModes.resize(16);
   outputTestModes[0]  = "Off";
   outputTestModes[1]  = "MidscaleShort";
   outputTestModes[2]  = "PosFsShort";
   outputTestModes[3]  = "NegFsShort";
   outputTestModes[4]  = "Checkerboard";
   outputTestModes[5]  = "Pn23Seq";
   outputTestModes[6]  = "Pn9Seq";
   outputTestModes[7]  = "OneZeroWord";
   outputTestModes[8]  = "UserInput";
   outputTestModes[9]  = "OneZeroBit";
   outputTestModes[10] = "Sync1x";
   outputTestModes[11] = "OneBitHigh";
   outputTestModes[12] = "MixedBitFreq";
   outputTestModes[13] = "Unused13";
   outputTestModes[14] = "Unused14";
   outputTestModes[15] = "Unused15";
   getVariable("OutputTestMode")->setEnums(outputTestModes);

   addVariable(new Variable("OutputMode", Variable::Configuration));
   getVariable("OutputMode")->setDescription("Set output mode of device. Default=LVDS.");
   vector<string> outputModes;
   outputModes.resize(2);
   outputModes[0]      = "LvdsAnsi-644";
   outputModes[1]      = "LvdsLowPower";
   getVariable("OutputMode")->setEnums(outputModes);

   addVariable(new Variable("OutputInvert", Variable::Configuration));
   getVariable("OutputInvert")->setDescription("Enable output inversion.");
   getVariable("OutputInvert")->setTrueFalse();

   addVariable(new Variable("OutputFormat", Variable::Configuration));
   getVariable("OutputFormat")->setDescription("Set output format. binary or two's complement.");
   vector<string> outputFormats;
   outputFormats.resize(2);
   outputFormats[0]    = "OffsetBinary";
   outputFormats[1]    = "TwosCompliment";
   getVariable("OutputFormat")->setEnums(outputFormats);

   addVariable(new Variable("OutputTermDrive", Variable::Configuration));
   getVariable("OutputTermDrive")->setDescription("Set output driver termination.");
   vector<string> outputTerms;
   outputTerms.resize(4);
   outputTerms[0]      = "None";
   outputTerms[1]      = "Ohm200";
   outputTerms[2]      = "Ohm100";
   outputTerms[3]      = "Ohm100";
   getVariable("OutputTermDrive")->setEnums(outputTerms);

   addVariable(new Variable("DcoFcoDrive2x", Variable::Configuration));
   getVariable("DcoFcoDrive2x")->setDescription("Set DCO and DCO output drive strength.");
   getVariable("DcoFcoDrive2x")->setTrueFalse();

   addVariable(new Variable("OutputPhase", Variable::Configuration));
   getVariable("OutputPhase")->setDescription("Set output phase adjustment.");
   vector<string> outputPhases;
   outputPhases.resize(16);
   outputPhases[0]     = "Deg0";
   outputPhases[1]     = "Deg60";
   outputPhases[2]     = "Deg120";
   outputPhases[3]     = "Deg180";
   outputPhases[4]     = "Unused1";
   outputPhases[5]     = "Deg300";
   outputPhases[6]     = "Deg360";
   outputPhases[7]     = "Unused2";
   outputPhases[8]     = "Deg480";
   outputPhases[9]     = "Deg540";
   outputPhases[10]    = "Deg600";
   outputPhases[11]    = "Deg660";
   outputPhases[12]    = "Unused12";
   outputPhases[13]    = "Unused13";
   outputPhases[14]    = "Unused14";
   outputPhases[15]    = "Unused15";
   getVariable("OutputPhase")->setEnums(outputPhases);

   addVariable(new Variable("UserPattern1", Variable::Configuration));
   getVariable("UserPattern1")->setDescription("Set user test pattern 1 data.");

   addVariable(new Variable("UserPattern2", Variable::Configuration));
   getVariable("UserPattern2")->setDescription("Set user test pattern 2 data.");

   addVariable(new Variable("SerialLsbFirst", Variable::Configuration));
   getVariable("SerialLsbFirst")->setDescription("Set LSB first mode of device.");
   getVariable("SerialLsbFirst")->setTrueFalse();

   addVariable(new Variable("LowEncodeRate", Variable::Configuration));
   getVariable("LowEncodeRate")->setDescription("Set low rate less than 10mbs mode.");
   getVariable("LowEncodeRate")->setTrueFalse();

   addVariable(new Variable("SerialBits", Variable::Configuration));
   getVariable("SerialBits")->setDescription("Set number of serial bits.");
   vector<string> serialBits;
   serialBits.resize(8);
   serialBits[0]       = "Bits-14";
   serialBits[1]       = "Bits-8";
   serialBits[2]       = "Bits-10";
   serialBits[3]       = "Bits-12";
   serialBits[4]       = "Bits-14";
   serialBits[5]       = "Unused5";
   serialBits[6]       = "Unused6";
   serialBits[7]       = "Unused7";
   getVariable("SerialBits")->setEnums(serialBits);

   addVariable(new Variable("ChanPowerDown", Variable::Configuration));
   getVariable("ChanPowerDown")->setDescription("Set channel power down.");
   getVariable("ChanPowerDown")->setTrueFalse();

   setInt("Enabled",0);  
}

// Deconstructor
Ad9252::~Ad9252 ( ) { }

// Method to read status registers and update variables
void Ad9252::readStatus ( ) {
   REGISTER_LOCK

   // Read registers
   readRegister(getRegister("ChipId"));
   getVariable("ChipId")->setInt(getRegister("ChipId")->get());

   readRegister(getRegister("ChipGrade"));
   getVariable("ChipGrade")->setInt(getRegister("ChipGrade")->get(4,0x7));

   REGISTER_UNLOCK
}

// Method to read configuration registers and update variables
void Ad9252::readConfig ( ) {

   int tmpVal;
   
   REGISTER_LOCK
   
   readRegister(getRegister("Modes"));
   getVariable("PowerDownMode")->setInt(getRegister("Modes")->get(0,0x3));
   
   readRegister(getRegister("Clock"));
   getVariable("DutyCycleStabilizer")->setInt(getRegister("Clock")->get(0,0x1));
   
   readRegister(getRegister("TestIo"));
   getVariable("UserTestMode")->setInt(getRegister("TestIo")->get(6,0x3));
   getVariable("ResetPnLongGen")->setInt(getRegister("TestIo")->get(5,0x1));
   getVariable("ResetPnShortGen")->setInt(getRegister("TestIo")->get(4,0x1));
   getVariable("OutputTestMode")->setInt(getRegister("TestIo")->get(0,0xf));
   
   readRegister(getRegister("OutputMode"));
   getVariable("OutputMode")->setInt(getRegister("OutputMode")->get(6,0x1));
   getVariable("OutputInvert")->setInt(getRegister("OutputMode")->get(2,0x1));
   getVariable("OutputFormat")->setInt(getRegister("OutputMode")->get(0,0x1));
   
   readRegister(getRegister("OutputAdjust"));
   getVariable("OutputTermDrive")->setInt(getRegister("OutputAdjust")->get(4,0x3));
   getVariable("DcoFcoDrive2x")->setInt(getRegister("OutputAdjust")->get(0,0x1));
   
   readRegister(getRegister("OutputPhase"));
   getVariable("OutputPhase")->setInt(getRegister("OutputPhase")->get(0,0xF));

   readRegister(getRegister("UserPatt1Msb"));
   tmpVal = (getRegister("UserPatt1Msb")->get(0,0xFF)) << 8;
   readRegister(getRegister("UserPatt1Lsb"));
   tmpVal |= getRegister("UserPatt1Lsb")->get(0,0xFF);
   getVariable("UserPattern1")->setInt(tmpVal);
   
   readRegister(getRegister("UserPatt2Msb"));
   tmpVal = (getRegister("UserPatt2Msb")->get(0,0xFF)) << 8;
   readRegister(getRegister("UserPatt2Lsb"));
   tmpVal |= getRegister("UserPatt2Lsb")->get(0,0xFF);
   getVariable("UserPattern2")->setInt(tmpVal);
   
   readRegister(getRegister("SerialControl"));
   getVariable("SerialLsbFirst")->setInt(getRegister("SerialControl")->get(7,0x1));
   getVariable("LowEncodeRate")->setInt(getRegister("SerialControl")->get(3,0x1));
   getVariable("SerialBits")->setInt(getRegister("SerialControl")->get(0,0x7));
   
   readRegister(getRegister("SerialChStat"));
   getVariable("ChanPowerDown")->setInt(getRegister("SerialChStat")->get(0,0x1));
   
   REGISTER_UNLOCK
}

// Method to write configuration registers
void Ad9252::writeConfig ( bool force ) {

   // Writing is enabled?
   if ( getVariable("ConfigEn")->get() == "False" ) return;

   REGISTER_LOCK

   // Set registers
   getRegister("ChipPortConfig")->set(1,3,0x1);
   getRegister("ChipPortConfig")->set(1,4,0x1);
   writeRegister(getRegister("ChipPortConfig"),force);

   getRegister("DeviceIndex1")->set(0x3F);
   writeRegister(getRegister("DeviceIndex1"),force);

   getRegister("DeviceIndex2")->set(0x0F);
   writeRegister(getRegister("DeviceIndex2"),force);

   getRegister("Modes")->set(getVariable("PowerDownMode")->getInt(),0,0x3);
   writeRegister(getRegister("Modes"),force);

   getRegister("Clock")->set(getVariable("DutyCycleStabilizer")->getInt(),0,0x1);
   writeRegister(getRegister("Clock"),force);

   getRegister("TestIo")->set(getVariable("UserTestMode")->getInt(),6,0x3);
   getRegister("TestIo")->set(getVariable("ResetPnLongGen")->getInt(),5,0x1);
   getRegister("TestIo")->set(getVariable("ResetPnShortGen")->getInt(),4,0x1);
   getRegister("TestIo")->set(getVariable("OutputTestMode")->getInt(),0,0xf);
   writeRegister(getRegister("TestIo"),force);

   getRegister("OutputMode")->set(getVariable("OutputMode")->getInt(),6,0x1);
   getRegister("OutputMode")->set(getVariable("OutputInvert")->getInt(),2,0x1);
   getRegister("OutputMode")->set(getVariable("OutputFormat")->getInt(),0,0x1);
   writeRegister(getRegister("OutputMode"),force);

   getRegister("OutputAdjust")->set(getVariable("OutputTermDrive")->getInt(),4,0x3);
   getRegister("OutputAdjust")->set(getVariable("DcoFcoDrive2x")->getInt(),0,0x1);
   writeRegister(getRegister("OutputAdjust"),force);

   getRegister("OutputPhase")->set(getVariable("OutputPhase")->getInt(),0,0xF);
   writeRegister(getRegister("OutputPhase"),force);

   getRegister("UserPatt1Lsb")->set(getVariable("UserPattern1")->getInt()&0xFF);
   writeRegister(getRegister("UserPatt1Lsb"),force);

   getRegister("UserPatt1Msb")->set((getVariable("UserPattern1")->getInt()>>8)&0xFF);
   writeRegister(getRegister("UserPatt1Msb"),force);

   getRegister("UserPatt2Lsb")->set(getVariable("UserPattern2")->getInt()&0xFF);
   writeRegister(getRegister("UserPatt2Lsb"),force);

   getRegister("UserPatt2Msb")->set((getVariable("UserPattern2")->getInt()>>8)&0xFF);
   writeRegister(getRegister("UserPatt2Msb"),force);

   getRegister("SerialControl")->set(getVariable("SerialLsbFirst")->getInt(),7,0x1);
   getRegister("SerialControl")->set(getVariable("LowEncodeRate")->getInt(),3,0x1);
   getRegister("SerialControl")->set(getVariable("SerialBits")->getInt(),0,0x7);
   writeRegister(getRegister("SerialControl"),force);

   getRegister("SerialChStat")->set(getVariable("ChanPowerDown")->getInt(),0,0x1);
   writeRegister(getRegister("SerialChStat"),force);

   getRegister("DeviceUpdate")->set(0x1);
   writeRegister(getRegister("DeviceUpdate"),true);
   REGISTER_UNLOCK
}

