//-----------------------------------------------------------------------------
// File          : DigFpga.cpp // Author        : Ryan Herbst  <rherbst@slac.stanford.edu>
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
#include "EpixUtility.h"
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

   addRegister(new Register("AcqCountReset", 0x01000006));

   addRegister(new Register("DacSetting", 0x01000007));
   addVariable(new Variable("DacSetting", Variable::Configuration));
   getVariable("DacSetting")->setDescription("DAC Setting");
   getVariable("DacSetting")->setRange(0,0xFFFF);

   addRegister(new Register("PowerEnable", 0x01000008));

   addVariable(new Variable("AnalogPowerEnable", Variable::Configuration));
   getVariable("AnalogPowerEnable")->setDescription("Analog Power Enable");
   getVariable("AnalogPowerEnable")->setRange(0,0x1);

   addVariable(new Variable("DigitalPowerEnable", Variable::Configuration));
   getVariable("DigitalPowerEnable")->setDescription("Digital Power Enable");
   getVariable("DigitalPowerEnable")->setRange(0,0x1);

   addRegister(new Register("AsicPins", 0x01000029));

   addVariable(new Variable("AsicGR", Variable::Configuration));
   getVariable("AsicGR")->setDescription("ASIC Global Reset");
   getVariable("AsicGR")->setRange(0,0x0001);
   addVariable(new Variable("AsicAcq", Variable::Configuration));
   getVariable("AsicAcq")->setDescription("ASIC Acq Signal");
   getVariable("AsicAcq")->setRange(0,0x0001);
   addVariable(new Variable("AsicR0", Variable::Configuration));
   getVariable("AsicR0")->setDescription("ASIC R0 Signal");
   getVariable("AsicR0")->setRange(0,0x0001);
   addVariable(new Variable("AsicPpmat", Variable::Configuration));
   getVariable("AsicPpmat")->setDescription("ASIC Ppmat Signal");
   getVariable("AsicPpmat")->setRange(0,0x0001);
   addVariable(new Variable("AsicPpbe", Variable::Configuration));
   getVariable("AsicPpbe")->setDescription("ASIC Ppbe Signal");
   getVariable("AsicPpbe")->setRange(0,0x0001);
   addVariable(new Variable("AsicRoClk", Variable::Configuration));
   getVariable("AsicRoClk")->setDescription("ASIC RO Clock Signal");
   getVariable("AsicRoClk")->setRange(0,0x0001);

   addRegister(new Register("AsicPinControl", 0x0100002A));

   addVariable(new Variable("AsicGRControl", Variable::Configuration));
   getVariable("AsicGRControl")->setDescription("Manual ASIC Global Reset Enabled");
   getVariable("AsicGRControl")->setRange(0,0x1);
   addVariable(new Variable("AsicAcqControl", Variable::Configuration));
   getVariable("AsicAcqControl")->setDescription("Manual ASIC Acq Enabled");
   getVariable("AsicAcqControl")->setRange(0,0x1);
   addVariable(new Variable("AsicR0Control", Variable::Configuration));
   getVariable("AsicR0Control")->setDescription("Manual ASIC R0 Enabled");
   getVariable("AsicR0Control")->setRange(0,0x1);
   addVariable(new Variable("AsicPpmatControl", Variable::Configuration));
   getVariable("AsicPpmatControl")->setDescription("Manual ASIC Ppmat Enabled");
   getVariable("AsicPpmatControl")->setRange(0,0x1);
   addVariable(new Variable("AsicPpbeControl", Variable::Configuration));
   getVariable("AsicPpbeControl")->setDescription("Manual ASIC Ppbe Enabled");
   getVariable("AsicPpbeControl")->setRange(0,0x1);
   addVariable(new Variable("AsicRoClkControl", Variable::Configuration));
   getVariable("AsicRoClkControl")->setDescription("Manual ASIC RO Clock Enabled");
   getVariable("AsicRoClkControl")->setRange(0,0x1);
   addVariable(new Variable("prepulseR0En", Variable::Configuration));
   getVariable("prepulseR0En")->setDescription("Prepuls R0 Enable");
   getVariable("prepulseR0En")->setRange(0,0x1);
 
   for (x=0; x < 8; x++) {
      tmp.str("");
      tmp << "AdcValue" << dec << setw(2) << setfill('0') << x;

      addRegister(new Register(tmp.str(), 0x01000100 + x));

      addVariable(new Variable(tmp.str(), Variable::Status));
      getVariable(tmp.str())->setDescription(tmp.str());
   }

   getVariable("AdcValue04")->setComp(0,-.0261,95.116,"C");
   getVariable("AdcValue06")->setComp(0,-.0261,95.116,"C");
   getVariable("AdcValue07")->setComp(0,.0287,-23.5,"%RH");

   addRegister(new Register("LocalTemp", 0x01000106));
   addVariable(new Variable("LocalTemp", Variable::Status));
   getVariable("LocalTemp")->setDescription("Local temp in degrees C");
   addRegister(new Register("acqToAsicR0Delay", 0x01000020));

   addRegister(new Register("Humidity", 0x01000107));
   addVariable(new Variable("Humidity", Variable::Status));
   getVariable("Humidity")->setDescription("Humidity in percent RH");

   addRegister(new Register("acqToAsicR0Delay", 0x01000020)); 
   addVariable(new Variable("acqToAsicR0Delay", Variable::Configuration));
   getVariable("acqToAsicR0Delay")->setDescription("");
   getVariable("acqToAsicR0Delay")->setRange(0,0xFFFF);
   getVariable("acqToAsicR0Delay")->setComp(0,.008,0,"us");

   addRegister(new Register("asicR0ToAsicAcq", 0x01000021));
   addVariable(new Variable("asicR0ToAsicAcq", Variable::Configuration));
   getVariable("asicR0ToAsicAcq")->setDescription("");
   getVariable("asicR0ToAsicAcq")->setRange(0,0xFFFF);
   getVariable("asicR0ToAsicAcq")->setComp(0,.008,0,"us");

   
   addRegister(new Register("asicAcqWidth", 0x01000022));
   addVariable(new Variable("asicAcqWidth", Variable::Configuration));
   getVariable("asicAcqWidth")->setDescription("");
   getVariable("asicAcqWidth")->setRange(0,0xFFFF);
   getVariable("asicAcqWidth")->setComp(0,.008,0,"us");

   addRegister(new Register("asicAcqLToPPmatL", 0x01000023));
   addVariable(new Variable("asicAcqLToPPmatL", Variable::Configuration));
   getVariable("asicAcqLToPPmatL")->setDescription("");
   getVariable("asicAcqLToPPmatL")->setRange(0,0xFFFF);
   getVariable("asicAcqLToPPmatL")->setComp(0,.008,0,"us");

   addRegister(new Register("asicRoClkHalfT", 0x01000024));
   addVariable(new Variable("asicRoClkHalfT", Variable::Configuration));
   getVariable("asicRoClkHalfT")->setDescription("");
   getVariable("asicRoClkHalfT")->setRange(0,0xFFFF);

   addRegister(new Register("adcReadsPerPixel", 0x01000025));
   addVariable(new Variable("adcReadsPerPixel", Variable::Configuration));
   getVariable("adcReadsPerPixel")->setDescription("");
   getVariable("adcReadsPerPixel")->setRange(0,0xFFFF);

   addRegister(new Register("adcClkHalfT", 0x01000026));
   addVariable(new Variable("adcClkHalfT", Variable::Configuration));
   getVariable("adcClkHalfT")->setDescription("Half Period of ADC Clock");
   getVariable("adcClkHalfT")->setRange(0,0xFFFF);

   addRegister(new Register("totalPixelsToRead", 0x01000027));
   addVariable(new Variable("totalPixelsToRead", Variable::Configuration));
   getVariable("totalPixelsToRead")->setDescription("");
   getVariable("totalPixelsToRead")->setRange(0,0xFFFF);

   addRegister(new Register("saciClkBit", 0x01000028));
   addVariable(new Variable("saciClkBit", Variable::Configuration));
   getVariable("saciClkBit")->setDescription("Bit of 125 MHz counter to use for SACI clock");
   getVariable("saciClkBit")->setRange(0,0x0007);

   addRegister(new Register("asicR0Width", 0x0100002B));
   addVariable(new Variable("asicR0Width", Variable::Configuration));
   getVariable("asicR0Width")->setDescription("Width of R0 low pulse");
   getVariable("asicR0Width")->setRange(0,0xFFFF);
   getVariable("asicR0Width")->setComp(0,.008,0,"us");

   addRegister(new Register("adcPipelineDelay", 0x0100002C));
   addVariable(new Variable("adcPipelineDelay", Variable::Configuration));
   getVariable("adcPipelineDelay")->setDescription("Number of samples to delay ADC reads");
   getVariable("adcPipelineDelay")->setRange(0,0xFF);

   addRegister(new Register("adcChannelToRead", 0x0100002D));
   addVariable(new Variable("adcChannelToRead", Variable::Configuration));
   getVariable("adcChannelToRead")->setDescription("ADC channel to read out");
   getVariable("adcChannelToRead")->setRange(0,0xFF);

   addRegister(new Register("prepulseR0Width", 0x0100002E));
   addVariable(new Variable("prepulseR0Width", Variable::Configuration));
   getVariable("prepulseR0Width")->setDescription("Width of R0 low prepulse");
   getVariable("prepulseR0Width")->setRange(0,0xFFFF);
   getVariable("prepulseR0Width")->setComp(0,.008,0,"us");

   addRegister(new Register("prepulseR0Delay", 0x0100002F));
   addVariable(new Variable("prepulseR0Delay", Variable::Configuration));
   getVariable("prepulseR0Delay")->setDescription("Delay of R0 low prepulse");
   getVariable("prepulseR0Delay")->setRange(0,0xFFFF);
   getVariable("prepulseR0Delay")->setComp(0,.008,0,"us");

   addRegister(new Register("digitalCardId0",0x01000030));
   addRegister(new Register("digitalCardId1",0x01000031));
   addVariable(new Variable("digitalCardId0", Variable::Status));
   addVariable(new Variable("digitalCardId1", Variable::Status));
   getVariable("digitalCardId0")->setDescription("Digital Card Serial Number (low 32 bits)");
   getVariable("digitalCardId1")->setDescription("Digital Card Serial Number (high 32 bits)");

   addRegister(new Register("analogCardId0",0x01000032));
   addRegister(new Register("analogCardId1",0x01000033));
   addVariable(new Variable("analogCardId0", Variable::Status));
   addVariable(new Variable("analogCardId1", Variable::Status));
   getVariable("analogCardId0")->setDescription("Analog Card Serial Number (low 32 bits)");
   getVariable("analogCardId1")->setDescription("Analog Card Serial Number (high 32 bits)");
  
   addVariable(new Variable("analogCRC", Variable::Status)); 
   getVariable("analogCRC")->setTrueFalse();
   addVariable(new Variable("digitalCRC", Variable::Status)); 
   getVariable("digitalCRC")->setTrueFalse();

   addRegister(new Register("EepromWriteAddr", 0x01000034));
   addVariable(new Variable("EepromWriteAddr", Variable::Configuration));
   getVariable("EepromWriteAddr")->setRange(0,0xF);
   addRegister(new Register("EepromDataIn0", 0x01000035));
   addVariable(new Variable("EepromDataIn0", Variable::Configuration));
   addRegister(new Register("EepromDataIn1", 0x01000036));
   addVariable(new Variable("EepromDataIn1", Variable::Configuration));
   addRegister(new Register("EepromReadAddr", 0x01000037));
   addVariable(new Variable("EepromReadAddr", Variable::Configuration));
   addVariable(new Variable("EepromAddr", Variable::Status));
	getVariable("EepromReadAddr")->setRange(0,0xF);
   addRegister(new Register("EepromDataOut0", 0x01000038));
   addVariable(new Variable("EepromDataOut0", Variable::Status));
	addRegister(new Register("EepromDataOut1", 0x01000039));
   addVariable(new Variable("EepromDataOut1", Variable::Status));  
   addCommand(new Command("MasterReset"));
   getCommand("MasterReset")->setDescription("Master Board Reset");

   addCommand(new Command("AcqCountReset"));
   getCommand("AcqCountReset")->setDescription("Acquisition Count Reset");

   addCommand(new Command("EpixRun",0x0));
   getCommand("EpixRun")->setDescription("Sends a single software run command");

   addCommand(new Command("WriteData"));
   getCommand("WriteData")->setDescription("Write data to EEPROM");

   addCommand(new Command("ReadData"));
   getCommand("ReadData")->setDescription("Read data from EEPROM");

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
   else if ( name == "WriteData" ) {
      REGISTER_LOCK
      writeRegister(getRegister("EepromDataIn0"),true,true);
      writeRegister(getRegister("EepromDataIn1"),true,true);
      writeRegister(getRegister("EepromWriteAddr"),true,true);
      REGISTER_UNLOCK
   }
   else if ( name == "ReadData" ) {
      REGISTER_LOCK
      writeRegister(getRegister("EepromReadAddr"),true,true);
      getVariable("EepromAddr")->setInt(getRegister("EepromReadAddr")->get()/8);
   	//readRegister(getRegister("EepromDataOut0"));
	   //readRegister(getRegister("EepromDataOut1"));
	   //getVariable("EepromDataOut0")->setInt(getRegister("EepromDataOut0")->get());
		//getVariable("EepromDataOut1")->setInt(getRegister("EepromDataOut1")->get());
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

   for (x=0; x < 8; x++) {
      tmp.str("");
      tmp << "AdcValue" << dec << setw(2) << setfill('0') << x;

      readRegister(getRegister(tmp.str()));
      getVariable(tmp.str())->setInt(getRegister(tmp.str())->get());
   }
   

   bool temp;
   readRegister(getRegister("digitalCardId0"));
   getVariable("digitalCardId0")->setInt(getRegister("digitalCardId0")->get());
   readRegister(getRegister("digitalCardId1"));
   getVariable("digitalCardId1")->setInt(getRegister("digitalCardId1")->get());
   temp = crc(getVariable("digitalCardId1")->getInt(),getVariable("digitalCardId0")->getInt());
   getVariable("digitalCRC")->setInt(temp);

   readRegister(getRegister("analogCardId0"));
   getVariable("analogCardId0")->setInt(getRegister("analogCardId0")->get());
   readRegister(getRegister("analogCardId1"));
   getVariable("analogCardId1")->setInt(getRegister("analogCardId1")->get());
   temp = crc(getVariable("analogCardId1")->getInt(),getVariable("analogCardId0")->getInt());
   getVariable("analogCRC")->setInt(temp);

 

   uint y;
   readRegister(getRegister("LocalTemp"));
   y=getRegister("LocalTemp")->get();
   getVariable("LocalTemp")->setIntDec(.000006*y*y-.0489*y+112.26);

   readRegister(getRegister("EepromDataOut0"));
   readRegister(getRegister("EepromDataOut1"));
   getVariable("EepromDataOut0")->setInt(getRegister("EepromDataOut0")->get());
	getVariable("EepromDataOut1")->setInt(getRegister("EepromDataOut1")->get());
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

   readRegister(getRegister("AsicPins"));
   getVariable("AsicGR")->setInt(getRegister("AsicPins")->get(0,0x1));
   getVariable("AsicAcq")->setInt(getRegister("AsicPins")->get(1,0x1));
   getVariable("AsicR0")->setInt(getRegister("AsicPins")->get(2,0x1));
   getVariable("AsicPpmat")->setInt(getRegister("AsicPins")->get(3,0x1));
   getVariable("AsicPpbe")->setInt(getRegister("AsicPins")->get(4,0x1));
   getVariable("AsicRoClk")->setInt(getRegister("AsicPins")->get(5,0x1));

   readRegister(getRegister("AsicPinControl"));
   getVariable("AsicGRControl")->setInt(getRegister("AsicPinControl")->get(0,0x1));
   getVariable("AsicAcqControl")->setInt(getRegister("AsicPinControl")->get(1,0x1));
   getVariable("AsicR0Control")->setInt(getRegister("AsicPinControl")->get(2,0x1));
   getVariable("AsicPpmatControl")->setInt(getRegister("AsicPinControl")->get(3,0x1));
   getVariable("AsicPpbeControl")->setInt(getRegister("AsicPinControl")->get(4,0x1));
   getVariable("AsicRoClkControl")->setInt(getRegister("AsicPinControl")->get(5,0x1));
   getVariable("prepulseR0En")->setInt(getRegister("AsicPinControl")->get(6,0x1));

   readRegister(getRegister("acqToAsicR0Delay"));
   getVariable("acqToAsicR0Delay")->setInt(getRegister("acqToAsicR0Delay")->get(0,0xFFFFFFFF));

   readRegister(getRegister("asicR0ToAsicAcq"));
   getVariable("asicR0ToAsicAcq")->setInt(getRegister("asicR0ToAsicAcq")->get(0,0xFFFFFFFF));

   readRegister(getRegister("asicAcqWidth"));
   getVariable("asicAcqWidth")->setInt(getRegister("asicAcqWidth")->get(0,0xFFFFFFFF));

   readRegister(getRegister("asicAcqLToPPmatL"));
   getVariable("asicAcqLToPPmatL")->setInt(getRegister("asicAcqLToPPmatL")->get(0,0xFFFFFFFF));

   readRegister(getRegister("asicRoClkHalfT"));
   getVariable("asicRoClkHalfT")->setInt(getRegister("asicRoClkHalfT")->get(0,0xFFFFFFFF));

   readRegister(getRegister("adcReadsPerPixel"));
   getVariable("adcReadsPerPixel")->setInt(getRegister("adcReadsPerPixel")->get(0,0xFFFFFFFF));

   readRegister(getRegister("adcClkHalfT"));
   getVariable("adcClkHalfT")->setInt(getRegister("adcClkHalfT")->get(0,0xFFFFFFFF));

   getVariable("EepromReadAddr")->setInt(getRegister("EepromReadAddr")->get(0,0xFFFFFFFF)/8);

   getVariable("EepromWriteAddr")->setInt(getRegister("EepromWriteAddr")->get(0,0xFFFFFFFF)/8);

   getVariable("EepromDataIn0")->setInt(getRegister("EepromDataIn0")->get(0,0xFFFFFFFF));

   getVariable("EepromDataIn1")->setInt(getRegister("EepromDataIn1")->get(0,0xFFFFFFFF));

   readRegister(getRegister("saciClkBit"));
   getVariable("saciClkBit")->setInt(getRegister("saciClkBit")->get(0,0x7));

   readRegister(getRegister("asicR0Width"));
   getVariable("asicR0Width")->setInt(getRegister("asicR0Width")->get(0,0xFFFFFFFF));

   readRegister(getRegister("adcPipelineDelay"));
   getVariable("adcPipelineDelay")->setInt(getRegister("adcPipelineDelay")->get(0,0xFF));

   readRegister(getRegister("adcChannelToRead"));
   getVariable("adcChannelToRead")->setInt(getRegister("adcChannelToRead")->get(0,0xFF));

   readRegister(getRegister("prepulseR0Width"));
   getVariable("prepulseR0Width")->setInt(getRegister("prepulseR0Width")->get(0,0xFFFF));

   readRegister(getRegister("prepulseR0Delay"));
   getVariable("prepulseR0Delay")->setInt(getRegister("prepulseR0Delay")->get(0,0xFFFF));

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

   getRegister("PowerEnable")->set(getVariable("AnalogPowerEnable")->getInt(),0,0x1);
   getRegister("PowerEnable")->set(getVariable("DigitalPowerEnable")->getInt(),1,0x1);
   writeRegister(getRegister("PowerEnable"),force);

   getRegister("AsicPins")->set(getVariable("AsicGR")->getInt(),0,0x1);
   getRegister("AsicPins")->set(getVariable("AsicAcq")->getInt(),1,0x1);
   getRegister("AsicPins")->set(getVariable("AsicR0")->getInt(),2,0x1);
   getRegister("AsicPins")->set(getVariable("AsicPpmat")->getInt(),3,0x1);
   getRegister("AsicPins")->set(getVariable("AsicPpbe")->getInt(),4,0x1);
   getRegister("AsicPins")->set(getVariable("AsicRoClk")->getInt(),5,0x1);
   writeRegister(getRegister("AsicPins"),force);

   getRegister("AsicPinControl")->set(getVariable("AsicGRControl")->getInt(),0,0x1);
   getRegister("AsicPinControl")->set(getVariable("AsicAcqControl")->getInt(),1,0x1);
   getRegister("AsicPinControl")->set(getVariable("AsicR0Control")->getInt(),2,0x1);
   getRegister("AsicPinControl")->set(getVariable("AsicPpmatControl")->getInt(),3,0x1);
   getRegister("AsicPinControl")->set(getVariable("AsicPpbeControl")->getInt(),4,0x1);
   getRegister("AsicPinControl")->set(getVariable("AsicRoClkControl")->getInt(),5,0x1);
   getRegister("AsicPinControl")->set(getVariable("prepulseR0En")->getInt(),6,0x1);
   writeRegister(getRegister("AsicPinControl"),force);

   getRegister("acqToAsicR0Delay")->set(getVariable("acqToAsicR0Delay")->getInt(),0,0xFFFFFFFF);
   writeRegister(getRegister("acqToAsicR0Delay"),force);

   getRegister("asicR0ToAsicAcq")->set(getVariable("asicR0ToAsicAcq")->getInt(),0,0xFFFFFFFF);
   writeRegister(getRegister("asicR0ToAsicAcq"),force);

   getRegister("asicAcqWidth")->set(getVariable("asicAcqWidth")->getInt(),0,0xFFFFFFFF);
   writeRegister(getRegister("asicAcqWidth"),force);

   getRegister("asicRoClkHalfT")->set(getVariable("asicRoClkHalfT")->getInt(),0,0xFFFFFFFF);
   writeRegister(getRegister("asicRoClkHalfT"),force);

   getRegister("asicAcqLToPPmatL")->set(getVariable("asicAcqLToPPmatL")->getInt(),0,0xFFFFFFFF);
   writeRegister(getRegister("asicAcqLToPPmatL"),force);

   getRegister("asicRoClkHalfT")->set(getVariable("asicRoClkHalfT")->getInt(),0,0xFFFFFFFF);
   writeRegister(getRegister("asicRoClkHalfT"),force);

   getRegister("adcReadsPerPixel")->set(getVariable("adcReadsPerPixel")->getInt(),0,0xFFFFFFFF);
   writeRegister(getRegister("adcReadsPerPixel"),force);

   getRegister("adcClkHalfT")->set(getVariable("adcClkHalfT")->getInt(),0,0xFFFFFFFF);
   writeRegister(getRegister("adcClkHalfT"),force);

   getRegister("EepromReadAddr")->set(8*getVariable("EepromReadAddr")->getInt(),0,0xFFFFFFFF);

   getRegister("EepromWriteAddr")->set(8*getVariable("EepromWriteAddr")->getInt(),0,0xFFFFFFFF);

   getRegister("EepromDataIn0")->set(getVariable("EepromDataIn0")->getInt(),0,0xFFFFFFFF);
  
   getRegister("EepromDataIn1")->set(getVariable("EepromDataIn1")->getInt(),0,0xFFFFFFFF);

   getRegister("saciClkBit")->set(getVariable("saciClkBit")->getInt(),0,0x7);
   writeRegister(getRegister("saciClkBit"),force);

   getRegister("asicR0Width")->set(getVariable("asicR0Width")->getInt(),0,0xFFFFFFFF);
   writeRegister(getRegister("asicR0Width"),force);

   getRegister("adcPipelineDelay")->set(getVariable("adcPipelineDelay")->getInt(),0,0xFF);
   writeRegister(getRegister("adcPipelineDelay"),force);

   getRegister("adcChannelToRead")->set(getVariable("adcChannelToRead")->getInt(),0,0xFF);
   writeRegister(getRegister("adcChannelToRead"),force);

   getRegister("prepulseR0Width")->set(getVariable("prepulseR0Width")->getInt(),0,0xFFFF);
   writeRegister(getRegister("prepulseR0Width"),force);

   getRegister("prepulseR0Width")->set(getVariable("prepulseR0Width")->getInt(),0,0xFFFF);
   writeRegister(getRegister("prepulseR0Width"),force);

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
   verifyRegister(getRegister("PowerEnable"));
   verifyRegister(getRegister("adcClkHalfT"));
   verifyRegister(getRegister("adcClkHalfT"));
   verifyRegister(getRegister("adcClkHalfT"));
   verifyRegister(getRegister("adcClkHalfT"));
   verifyRegister(getRegister("adcClkHalfT"));
   verifyRegister(getRegister("adcClkHalfT"));
   verifyRegister(getRegister("adcClkHalfT"));
   Device::verifyConfig();
   REGISTER_UNLOCK
}

