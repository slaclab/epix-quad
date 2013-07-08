//-----------------------------------------------------------------------------
// File          : DigFpga.cpp
// Author        : Ryan Herbst  <rherbst@slac.stanford.edu>
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
#include <DigFpga.h>
#include <EpixAsic.h>
#include <Ad9252.h>
#include <Register.h>
#include <Variable.h>
#include <Command.h>
#include <sstream>
#include <iostream>
#include <string>
#include <iomanip>
using namespace std;

// Constructor
DigFpga::DigFpga ( uint destination, uint index, Device *parent ) : 
                   Device(destination,0,"digFpga",index,parent) {
   stringstream tmp;
   uint         x;

   // Description
   desc_ = "Digital FPGA Object.";

   // Setup registers & variables
   addRegister(new Register("Version", 0x01000000));
   addVariable(new Variable("Version", Variable::Status));
   getVariable("Version")->setDescription("FPGA version field");

   addRegister(new Register("RunTrigEnable", 0x01000001));
   addVariable(new Variable("RunTrigEnable", Variable::Configuration));
   getVariable("RunTrigEnable")->setDescription("Run Trigger Enable");
   getVariable("RunTrigEnable")->setTrueFalse();

   addRegister(new Register("RunTrigDelay", 0x01000002));
   addVariable(new Variable("RunTrigDelay", Variable::Configuration));
   getVariable("RunTrigDelay")->setDescription("Run Trigger Delay");
   getVariable("RunTrigDelay")->setRange(0,0x7FFFFFFF);

   addRegister(new Register("DaqTrigEnable", 0x01000003));
   addVariable(new Variable("DaqTrigEnable", Variable::Configuration));
   getVariable("DaqTrigEnable")->setDescription("Daq Trigger Enable");
   getVariable("DaqTrigEnable")->setTrueFalse();

   addRegister(new Register("DaqTrigDelay", 0x01000004));
   addVariable(new Variable("DaqTrigDelay", Variable::Configuration));
   getVariable("DaqTrigDelay")->setDescription("Daq Trigger Delay");
   getVariable("DaqTrigDelay")->setRange(0,0x7FFFFFFF);

   addRegister(new Register("AcqCount", 0x01000005));
   addVariable(new Variable("AcqCount", Variable::Status));
   getVariable("AcqCount")->setDescription("Acquisition Counter");

   addRegister(new Register("AcqCountRst", 0x01000006));

   addRegister(new Register("DacSetting", 0x01000007));
   addVariable(new Variable("DacSetting", Variable::Configuration));
   getVariable("DacSetting")->setDescription("DAC Setting");
   getVariable("DacSetting")->setRange(0,0xFFFF);

   addRegister(new Register("PowerEnable", 0x01000008));

   addVariable(new Variable("AnalogPowerEnable", Variable::Configuration));
   getVariable("AnalogPowerEnable")->setDescription("Analog Power Enable");
   getVariable("AnalogPowerEnable")->setRange(0,0xFFFF);

   addVariable(new Variable("DigitalPowerEnable", Variable::Configuration));
   getVariable("DigitalPowerEnable")->setDescription("Digital Power Enable");
   getVariable("DigitalPowerEnable")->setRange(0,0xFFFF);

   for (x=0; x < 16; x++) {
      tmp.str("");
      tmp << "AdcValue" << dec << setw(2) << setfill('0') << x;

      addRegister(new Register(tmp.str(), 0x01000010 + x));

      addVariable(new Variable(tmp.str(), Variable::Status));
      getVariable("DigitalPowerEnable")->setDescription(tmp.str());
   }

   addCommand(new Command("MasterReset"));
   getCommand("MasterReset")->setDescription("Master Board Reset");

   addCommand(new Command("AcqCountReset"));
   getCommand("AcqCountReset")->setDescription("Acquisition Count Reset");

   // Add sub-devices
   addDevice(new   Ad9252(destination, 0x01008000, 0, this));
   addDevice(new   Ad9252(destination, 0x0100A000, 1, this));
   addDevice(new   Ad9252(destination, 0x0100C000, 2, this));
   addDevice(new EpixAsic(destination, 0x01800000, 0, this));
   addDevice(new EpixAsic(destination, 0x01900000, 1, this));
   addDevice(new EpixAsic(destination, 0x01A00000, 2, this));
   addDevice(new EpixAsic(destination, 0x01B00000, 3, this));

   getVariable("Enabled")->setHidden(true);
}

// Deconstructor
DigFpga::~DigFpga ( ) { }

// Method to process a command
void DigFpga::command ( string name, string arg) {
   stringstream tmp;

   // Command is local
   if ( name == "MasterReset" ) {
      REGISTER_LOCK
      writeRegister(getRegister("Version"),true,false);
      REGISTER_UNLOCK
   }
   else if ( name == "AcqCountReset" ) {
      REGISTER_LOCK
      writeRegister(getRegister("AcqCountReset"),true,true);
      REGISTER_UNLOCK
   }
   else Device::command(name, arg);
}

// Method to read status registers and update variables
void DigFpga::readStatus ( ) {
   stringstream tmp;
   uint         x;

   REGISTER_LOCK

   readRegister(getRegister("Version"));
   getVariable("Version")->setInt(getRegister("Version")->get());

   readRegister(getRegister("AcqCount"));
   getVariable("AcqCount")->setInt(getRegister("AcqCount")->get());

   for (x=0; x < 16; x++) {
      tmp.str("");
      tmp << "AdcValue" << dec << setw(2) << setfill('0') << x;

      readRegister(getRegister(tmp.str()));
      getVariable(tmp.str())->setInt(getRegister(tmp.str())->get());
   }

   // Sub devices
   Device::readStatus();
   REGISTER_UNLOCK
}

// Method to read configuration registers and update variables
void DigFpga::readConfig ( ) {
   REGISTER_LOCK

   readRegister(getRegister("RunTrigEnable"));
   getVariable("RunTrigEnable")->setInt(getRegister("RunTrigEnable")->get(0,0x1));

   readRegister(getRegister("RunTrigDelay"));
   getVariable("RunTrigDelay")->setInt(getRegister("RunTrigDelay")->get());

   readRegister(getRegister("DaqTrigEnable"));
   getVariable("DaqTrigEnable")->setInt(getRegister("DaqTrigEnable")->get(0,0x1));

   readRegister(getRegister("DaqTrigDelay"));
   getVariable("DaqTrigDelay")->setInt(getRegister("DaqTrigDelay")->get());

   readRegister(getRegister("DacSetting"));
   getVariable("DacSetting")->setInt(getRegister("DacSetting")->get(0,0xFFFF));

   readRegister(getRegister("PowerEnable"));
   getVariable("AnalogPowerEnable")->setInt(getRegister("PowerEnable")->get(0,0x1));
   getVariable("DigitalPowerEnable")->setInt(getRegister("PowerEnable")->get(1,0x1));

   // Sub devices
   Device::readConfig();
   REGISTER_UNLOCK
}

// Method to write configuration registers
void DigFpga::writeConfig ( bool force ) {
   REGISTER_LOCK

   getRegister("RunTrigEnable")->set(getVariable("RunTrigEnable")->getInt(),0,0x1);
   writeRegister(getRegister("RunTrigEnable"),force);

   getRegister("RunTrigDelay")->set(getVariable("RunTrigDelay")->getInt());
   writeRegister(getRegister("RunTrigDelay"),force);

   getRegister("DaqTrigEnable")->set(getVariable("DaqTrigEnable")->getInt(),0,0x1);
   writeRegister(getRegister("DaqTrigEnable"),force);

   getRegister("DaqTrigEnable")->set(getVariable("DaqTrigDelay")->getInt());
   writeRegister(getRegister("DaqTrigDelay"),force);

   getRegister("DacSetting")->set(getVariable("DacSetting")->getInt(),0,0xFFFF);
   writeRegister(getRegister("DacSetting"),force);

   getRegister("AnalogPowerEnable")->set(getVariable("AnalogPowerEnable")->getInt(),0,0x1);
   getRegister("DigitalPowerEnable")->set(getVariable("DigitalPowerEnable")->getInt(),1,0x1);
   writeRegister(getRegister("PowerEnable"),force);

   // Sub devices
   Device::writeConfig(force);
   REGISTER_UNLOCK
}

// Verify hardware state of configuration
void DigFpga::verifyConfig ( ) {
   REGISTER_LOCK

   verifyRegister(getRegister("RunTrigEnable"));
   verifyRegister(getRegister("RunTrigDelay"));
   verifyRegister(getRegister("DaqTrigEnable"));
   verifyRegister(getRegister("DaqTrigDelay"));
   verifyRegister(getRegister("DacSetting"));
   verifyRegister(getRegister("AnalogPowerEnable"));
   verifyRegister(getRegister("DigitalPowerEnable"));

   Device::verifyConfig();
   REGISTER_UNLOCK
}

