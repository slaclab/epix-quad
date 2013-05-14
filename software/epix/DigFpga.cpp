//-----------------------------------------------------------------------------
// File          : ConFpga.cpp
// Author        : Ryan Herbst  <rherbst@slac.stanford.edu>
// Created       : 05/24/2012
// Project       : Kpix ASIC
//-----------------------------------------------------------------------------
// Description :
// Con FPGA container
//-----------------------------------------------------------------------------
// Copyright (c) 2011 by SLAC. All rights reserved.
// Proprietary and confidential to SLAC.
//-----------------------------------------------------------------------------
// Modification history :
// 05/24/2012: created
//-----------------------------------------------------------------------------
#include <ConFpga.h>
#include <KpixAsic.h>
#include <Register.h>
#include <Variable.h>
#include <Command.h>
#include <sstream>
#include <iostream>
#include <string>
#include <iomanip>
using namespace std;

// Constructor
ConFpga::ConFpga ( uint destination, uint index, uint kpixCount, Device *parent ) : 
                   Device(destination,0,"cntrlFpga",index,parent) {
   stringstream tmp;
   uint         x;

   this->kpixCount = kpixCount;

   // Description
   desc_ = "KPIX Con FPGA Object.";
   //   setDebug(true);

   // Setup registers & variables
   addRegister(new Register("Version", 0x01000000));
   addVariable(new Variable("Version", Variable::Status));
   getVariable("Version")->setDescription("FPGA version field");

   // Clock select register
   addRegister(new Register("ClockSelectA", 0x01000001));
   addRegister(new Register("ClockSelectB", 0x01000002));
   vector<string> clkPeriod;
   clkPeriod.resize(256);
   for (int x=0; x < 256; x++) {
      tmp.str("");
      tmp << dec << ((x+1)*10) << "nS";
      clkPeriod[x] = tmp.str();
   }

   addVariable(new Variable("ClkPeriodIdle", Variable::Configuration));
   getVariable("ClkPeriodIdle")->setDescription("Idle clock period");
   getVariable("ClkPeriodIdle")->setEnums(clkPeriod);

   addVariable(new Variable("ClkPeriodAcq", Variable::Configuration));
   getVariable("ClkPeriodAcq")->setDescription("Acquisition clock period");
   getVariable("ClkPeriodAcq")->setEnums(clkPeriod);

   addVariable(new Variable("ClkPeriodDig", Variable::Configuration));
   getVariable("ClkPeriodDig")->setDescription("Digitization clock period");
   getVariable("ClkPeriodDig")->setEnums(clkPeriod);

   addVariable(new Variable("ClkPeriodRead", Variable::Configuration));
   getVariable("ClkPeriodRead")->setDescription("Readout clock period");
   getVariable("ClkPeriodRead")->setEnums(clkPeriod);

   vector<string> clkPeriodp;
   clkPeriodp.resize(0xFFF);
   for (int x=0; x < 0xFFF; x++) {
      tmp.str("");
      tmp << dec << ((x+1)*10) << "nS";
      clkPeriodp[x] = tmp.str();
   }

   addVariable(new Variable("ClkPeriodPrecharge", Variable::Configuration));
   getVariable("ClkPeriodPrecharge")->setDescription("Precharge clock period");
   getVariable("ClkPeriodPrecharge")->setEnums(clkPeriodp);

   // KPIX debug select register
   addRegister(new Register("DebugSelect", 0x01000003));

   addVariable(new Variable("BncSourceA", Variable::Configuration));
   getVariable("BncSourceA")->setDescription("BNC output A source select");
   vector<string> bncSource;
   bncSource.resize(28);
   bncSource[0]  = "RegClock";
   bncSource[1]  = "RegSel1";
   bncSource[2]  = "RegSel0";
   bncSource[3]  = "PwrUpAcq";
   bncSource[4]  = "ResetLoad";
   bncSource[5]  = "LeakageNull";
   bncSource[6]  = "OffsetNull";
   bncSource[7]  = "ThreashOff";
   bncSource[8]  = "TrigInh";
   bncSource[9]  = "CalStrobe";
   bncSource[10] = "PwrUpAcqDig";
   bncSource[11] = "SelCell";
   bncSource[12] = "DeselAllCells";
   bncSource[13] = "RampPeriod";
   bncSource[14] = "PrechargeBus";
   bncSource[15] = "RegData";
   bncSource[16] = "RegWrEn";
   bncSource[17] = "KpixClk";
   bncSource[18] = "ForceTrig";
   bncSource[19] = "TrigEnable";
   bncSource[20] = "CalStrobeDelay";
   bncSource[21] = "NimA";
   bncSource[22] = "NimB";
   bncSource[23] = "BncA";
   bncSource[24] = "BncB";
   bncSource[25] = "BcPhase";
   bncSource[26] = "TrainNumRst";
   bncSource[27] = "TrainNumClk";
   getVariable("BncSourceA")->setEnums(bncSource);

   addVariable(new Variable("BncSourceB", Variable::Configuration));
   getVariable("BncSourceB")->setDescription("BNC output B source select");
   getVariable("BncSourceB")->setEnums(bncSource);

   // Trigger control register
   addRegister(new Register("TriggerControl", 0x01000004));

   addVariable(new Variable("TrigSource", Variable::Configuration));
   getVariable("TrigSource")->setDescription("External trigger source");
   vector<string> trgSource;
   trgSource.resize(5);
   trgSource[0]  = "None";
   trgSource[1]  = "NimA";
   trgSource[2]  = "NimB";
   trgSource[3]  = "CmosA";
   trgSource[4]  = "CmosB";
   getVariable("TrigSource")->setEnums(trgSource);

   addVariable(new Variable("RunMode", Variable::Configuration));
   getVariable("RunMode")->setDescription("KPIX run command to send");
   vector<string> runMode;
   runMode.resize(2);
   runMode[0]  = "Acquire";
   runMode[1]  = "Calibrate";
   getVariable("RunMode")->setEnums(runMode);

   // Kpix reset register
   addRegister(new Register("KpixReset", 0x01000005));

   // Kpix config register
   addRegister(new Register("KpixConfig", 0x01000006));
   addVariable(new Variable("KpixInputEdge", Variable::Configuration));
   getVariable("KpixInputEdge")->setDescription("Clock edge to capture serial data");
   vector<string> edges;
   edges.resize(2);
   edges[0]  = "Rising Edge";
   edges[1]  = "Falling Edge";
   getVariable("KpixInputEdge")->setEnums(edges);

   addVariable(new Variable("KpixOutputEdge", Variable::Configuration));
   getVariable("KpixOutputEdge")->setDescription("Clock edge to output serial data");
   getVariable("KpixOutputEdge")->setEnums(edges);

   addVariable(new Variable("KpixRxRaw", Variable::Configuration));
   getVariable("KpixRxRaw")->setDescription("Receive every sample regardless of validity");
   getVariable("KpixRxRaw")->setTrueFalse();

   //Timestamp Config Register
   addRegister(new Register("TimestampConfig", 0x01000007));
   addVariable(new Variable("TimestampSource", Variable::Configuration));
   getVariable("TimestampSource")->setDescription("Timestamp Trigger Source");
   getVariable("TimestampSource")->setEnums(trgSource);

   //Acquisition Control Register
   addRegister(new Register("AcquisitionConfig", 0x01000008));
   addVariable(new Variable("AcquisitionTrigger", Variable::Configuration));
   getVariable("AcquisitionTrigger")->setDescription("Acquisition Trigger Source");
   vector<string> acqSrc;
   acqSrc.resize(3);
   acqSrc[0] = "Software";
   acqSrc[1] = "Event Receiver";
   acqSrc[2] = "CmosA";
   getVariable("AcquisitionTrigger")->setEnums(acqSrc);

   //EVR Error Count Register
   addRegister(new Register("EvrErrorCount", 0x01000009));
   addVariable(new Variable("EvrErrorCount", Variable::Status));
   getVariable("EvrErrorCount")->setDescription("Event Receiver Error Count");

   //Allows firmware to be fully reset
   addRegister(new Register("SoftwareReset", 0x0100000A));

   
   // KPIX support registers
   for (uint i=0; i < (kpixCount-1); i++) {

      tmp.str("");
      tmp << "KpixRxMode_" << setw(2) << setfill('0') << dec << i;
      addRegister(new Register(tmp.str(), (0x01000100 + i*5 + 0)));

      tmp.str("");
      tmp << "KpixRxHeaderPerr_" << setw(2) << setfill('0') << dec << i;
      addRegister(new Register(tmp.str(), (0x01000100 + i*5 + 1)));
      addVariable(new Variable(tmp.str(),Variable::Status));
      getVariable(tmp.str())->setDescription("Kpix header parity error count.");

      tmp.str("");
      tmp << "KpixRxDataPerr_" << setw(2) << setfill('0') << dec << i;
      addRegister(new Register(tmp.str(), (0x01000100 + i*5 + 2)));
      addVariable(new Variable(tmp.str(),Variable::Status));
      getVariable(tmp.str())->setDescription("Kpix data parity error count.");

      tmp.str("");
      tmp << "KpixRxMarkerError_" << setw(2) << setfill('0') << dec << i;
      addRegister(new Register(tmp.str(), (0x01000100 + i*5 + 3)));
      addVariable(new Variable(tmp.str(),Variable::Status));
      getVariable(tmp.str())->setDescription("Kpix marker error count.");

      tmp.str("");
      tmp << "KpixRxOverflowError_" << setw(2) << setfill('0') << dec << i;
      addRegister(new Register(tmp.str(), (0x01000100 + i*5 + 4)));
      addVariable(new Variable(tmp.str(),Variable::Status));
      getVariable(tmp.str())->setDescription("Kpix overflow error count.");
   }

   // EVR Module Registers
   uint evrBaseAddr = 0x01200000;
   addRegister(new Register("EvrEnable", evrBaseAddr + 0x00000100));

   addRegister(new Register("EvrDelay", evrBaseAddr + 0x00000101));
   addVariable(new Variable("EvrDelay", Variable::Configuration));
   getVariable("EvrDelay")->setDescription("EVR pulse delay");
   getVariable("EvrDelay")->setComp(0,(1.0/119.0),0,"mS");
   getVariable("EvrDelay")->setRange(0,999999999);

   addRegister(new Register("EvrWidth", evrBaseAddr + 0x00000102));

   addRegister(new Register("EvrOpCode", evrBaseAddr + 0x00000146));
   addVariable(new Variable("EvrOpCode", Variable::Configuration));
   getVariable("EvrOpCode")->setDescription("OpCode for internal EVR trigger");
   vector<string> evrCodes;
   evrCodes.resize(7);
   evrCodes[0] = "120Hz";
   evrCodes[1] = "60Hz";
   evrCodes[2] = "30Hz";
   evrCodes[3] = "10Hz";
   evrCodes[4] = "5Hz";
   evrCodes[5] = "1Hz";
   evrCodes[6] = "1Hz_Alt";
   getVariable("EvrOpCode")->setEnums(evrCodes);
   getVariable("EvrOpCode")->setHidden(true);


   // Commands
   addCommand(new Command("KpixRun",0x0));
   getCommand("KpixRun")->setDescription("Kpix run command");

   addCommand(new Command("KpixHardReset"));
   getCommand("KpixHardReset")->setDescription("Hard KPIX reset command");

   addCommand(new Command("CountReset"));
   getCommand("CountReset")->setDescription("Reset counters");

   addCommand(new Command("FirmwareReset"));
   getCommand("FirmwareReset")->setDescription("Reset the firmware");

   // Add sub-devices
   for (uint i=0; i < kpixCount; i++) 
      addDevice(new KpixAsic(destination,(0x01100000 | ((i<<8) & 0xff00)),i,(i==(kpixCount-1)),this));

   getVariable("Enabled")->setHidden(true);
}

// Deconstructor
ConFpga::~ConFpga ( ) { }

// Method to process a command
void ConFpga::command ( string name, string arg) {
   stringstream tmp;

   // Command is local
   if ( name == "KpixHardReset" ) {
      REGISTER_LOCK
      getRegister("KpixReset")->set(0x1);
      writeRegister(getRegister("KpixReset"),true,true);
      //getRegister("KpixReset")->set(0x0);
      //writeRegister(getRegister("KpixReset"),true,true);
      REGISTER_UNLOCK
   }
   else if ( name == "CountReset" ) {
      REGISTER_LOCK

      for (uint i=0; i < (kpixCount-1); i++) {
         tmp.str("");
         tmp << "KpixRxHeaderPerr_" << setw(2) << setfill('0') << dec << i;
         writeRegister(getRegister(tmp.str()),true,true);

         tmp.str("");
         tmp << "KpixRxDataPerr_" << setw(2) << setfill('0') << dec << i;
         writeRegister(getRegister(tmp.str()),true,true);

         tmp.str("");
         tmp << "KpixRxMarkerError_" << setw(2) << setfill('0') << dec << i;
         writeRegister(getRegister(tmp.str()),true,true);

         tmp.str("");
         tmp << "KpixRxOverflowError_" << setw(2) << setfill('0') << dec << i;
         writeRegister(getRegister(tmp.str()),true,true);
      }
      //writeRegister(getRegister("EvrErrorCount"),true,true);

      REGISTER_UNLOCK
   }
   else if (name == "FirmwareReset") {
      REGISTER_LOCK
      getRegister("SoftwareReset")->set(0x1);
      writeRegister(getRegister("SoftwareReset"), true, false);
      REGISTER_UNLOCK
   }
   else Device::command(name, arg);
}

// Method to read status registers and update variables
void ConFpga::readStatus ( ) {
   stringstream tmp;

   REGISTER_LOCK

   readRegister(getRegister("Version"));
   getVariable("Version")->setInt(getRegister("Version")->get());

   for (uint i=0; i < (kpixCount-1); i++) {
      tmp.str("");
      tmp << "KpixRxHeaderPerr_" << setw(2) << setfill('0') << dec << i;
      readRegister(getRegister(tmp.str()));
      getVariable(tmp.str())->setInt(getRegister(tmp.str())->get());

      tmp.str("");
      tmp << "KpixRxDataPerr_" << setw(2) << setfill('0') << dec << i;
      readRegister(getRegister(tmp.str()));
      getVariable(tmp.str())->setInt(getRegister(tmp.str())->get());

      tmp.str("");
      tmp << "KpixRxMarkerError_" << setw(2) << setfill('0') << dec << i;
      readRegister(getRegister(tmp.str()));
      getVariable(tmp.str())->setInt(getRegister(tmp.str())->get());

      tmp.str("");
      tmp << "KpixRxOverflowError_" << setw(2) << setfill('0') << dec << i;
      readRegister(getRegister(tmp.str()));
      getVariable(tmp.str())->setInt(getRegister(tmp.str())->get());
   }

   //readRegister(getRegister("EvrErrorCount"));
   //getVariable("EvrErrorCount")->setInt(getRegister("EvrErrorCount")->get());

   // Sub devices
   Device::readStatus();
   REGISTER_UNLOCK
}

// Method to read configuration registers and update variables
void ConFpga::readConfig ( ) {
   stringstream tmpA;
   stringstream tmpB;

   REGISTER_LOCK

   readRegister(getRegister("ClockSelectA"));
   getVariable("ClkPeriodIdle")->setInt(getRegister("ClockSelectA")->get(0,0x1F));
   getVariable("ClkPeriodAcq")->setInt(getRegister("ClockSelectA")->get(8,0x1F));
   getVariable("ClkPeriodDig")->setInt(getRegister("ClockSelectA")->get(16,0x1F));
   getVariable("ClkPeriodRead")->setInt(getRegister("ClockSelectA")->get(24,0x1F));

   readRegister(getRegister("ClockSelectB"));
   getVariable("ClkPeriodPrecharge")->setInt(getRegister("ClockSelectB")->get(0,0xFFF));

   readRegister(getRegister("DebugSelect"));
   getVariable("BncSourceA")->setInt(getRegister("DebugSelect")->get(0,0x1F));
   getVariable("BncSourceB")->setInt(getRegister("DebugSelect")->get(8,0x1F));

   readRegister(getRegister("TriggerControl"));
   getVariable("TrigSource")->setInt(getRegister("TriggerControl")->get(0,0x7));
   getVariable("RunMode")->setInt(getRegister("TriggerControl")->get(4,0x1));

   readRegister(getRegister("KpixConfig"));
   getVariable("KpixInputEdge")->setInt(getRegister("KpixConfig")->get(0,0x1));
   getVariable("KpixOutputEdge")->setInt(getRegister("KpixConfig")->get(1,0x1));
   getVariable("KpixRxRaw")->setInt(getRegister("KpixConfig")->get(4,0x1));

   readRegister(getRegister("TimestampConfig"));
   getVariable("TimestampSource")->setInt(getRegister("TimestampConfig")->get(0,0x7));

   readRegister(getRegister("AcquisitionConfig"));
   getVariable("AcquisitionTrigger")->setInt(getRegister("TimestampConfig")->get(0,0x3));

   //readRegister(getRegister("EvrDelay"));
   //getVariable("EvrDelay")->setInt(getRegister("EvrDelay")->get()); //Mask register maybe?

   //readRegister(getRegister("EvrOpCode"));
   //getVariable("EvrOpCode")->setInt(getRegister("EvrOpCode")->get(0,0x7));

   // Sub devices
   Device::readConfig();
   REGISTER_UNLOCK
}

// Method to write configuration registers
void ConFpga::writeConfig ( bool force ) {
   stringstream tmpA;
   stringstream tmpB;

   REGISTER_LOCK

   getRegister("ClockSelectA")->set(getVariable("ClkPeriodIdle")->getInt(),0,0x1F);
   getRegister("ClockSelectA")->set(getVariable("ClkPeriodAcq")->getInt(),8,0x1F);
   getRegister("ClockSelectA")->set(getVariable("ClkPeriodDig")->getInt(),16,0x1F);
   getRegister("ClockSelectA")->set(getVariable("ClkPeriodRead")->getInt(),24,0x1F);
   writeRegister(getRegister("ClockSelectA"),force);

   getRegister("ClockSelectB")->set(getVariable("ClkPeriodPrecharge")->getInt(),0,0xFFF);
   writeRegister(getRegister("ClockSelectB"),force);

   getRegister("DebugSelect")->set(getVariable("BncSourceA")->getInt(),0,0x1F);
   getRegister("DebugSelect")->set(getVariable("BncSourceB")->getInt(),8,0x1F);
   writeRegister(getRegister("DebugSelect"),force);

   getRegister("TriggerControl")->set(getVariable("TrigSource")->getInt(),0,0x7);
   getRegister("TriggerControl")->set(getVariable("RunMode")->getInt(),4,0x1);
   writeRegister(getRegister("TriggerControl"),force);

   getRegister("KpixConfig")->set(getVariable("KpixInputEdge")->getInt(),0,0x1);
   getRegister("KpixConfig")->set(getVariable("KpixInputEdge")->getInt(),1,0x1);
   getRegister("KpixConfig")->set(getVariable("KpixRxRaw")->getInt(),4,0x1);
   getRegister("KpixConfig")->set(((((KpixAsic*)(device("kpixAsic",0)))->channels() / 32)-1),8,0x1F);
   getRegister("KpixConfig")->set((((KpixAsic*)(device("kpixAsic",0)))->getInt("CfgAutoReadDisable")),16,0x1);
   //getRegister("KpixConfig")->set(31,8,0x1F);
   writeRegister(getRegister("KpixConfig"),force);

   getRegister("TimestampConfig")->set(getVariable("TimestampSource")->getInt(),0,0x7);
   writeRegister(getRegister("TimestampConfig"),force);

   getRegister("AcquisitionConfig")->set(getVariable("AcquisitionTrigger")->getInt(),0,0x3);
   writeRegister(getRegister("AcquisitionConfig"),force);

   //getRegister("EvrDelay")->set(getVariable("EvrDelay")->getInt());
   //writeRegister(getRegister("EvrDelay"),force);

   //getRegister("EvrOpCode")->set(getVariable("EvrOpCode")->getInt(),0,0x7);
   //writeRegister(getRegister("EvrOpCode"),force);

   // KPIX support registers
   for (uint i=0; i < (kpixCount-1); i++) {

      tmpA.str("");
      tmpA << "KpixRxMode_" << setw(2) << setfill('0') << dec << i;

      tmpB.str("");
      tmpB << "KpixRxEn_" << setw(2) << setfill('0') << dec << i;
      getRegister(tmpA.str())->set(device("kpixAsic",i)->getInt("Enabled"),0,0x1);

//       tmpB.str("");
//       tmpB << "KpixRxRaw_" << setw(2) << setfill('0') << dec << i;
//       getRegister(tmpA.str())->set(getVariable("KpixRxRaw")->getInt(),1,0x1);

      writeRegister(getRegister(tmpA.str()),force);
   }

   // Sub devices
   Device::writeConfig(force);
   REGISTER_UNLOCK
}

// Verify hardware state of configuration
void ConFpga::verifyConfig ( ) {
   stringstream tmp;

   REGISTER_LOCK
   
   verifyRegister(getRegister("ClockSelectA"));
   verifyRegister(getRegister("ClockSelectB"));
   verifyRegister(getRegister("DebugSelect"));
   verifyRegister(getRegister("TriggerControl"));
   verifyRegister(getRegister("KpixConfig"));
   verifyRegister(getRegister("TimestampConfig"));
   verifyRegister(getRegister("AcquisitionConfig"));
   //verifyRegister(getRegister("EvrDelay"));
   //verifyRegister(getRegister("EvrOpCode"));

   // KPIX support registers
   for (uint i=0; i < (kpixCount-1); i++) {

      tmp.str("");
      tmp << "KpixRxMode_" << setw(2) << setfill('0') << dec << i;
      verifyRegister(getRegister(tmp.str()));
   }

   Device::verifyConfig();
   REGISTER_UNLOCK
}

