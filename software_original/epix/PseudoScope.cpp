//-----------------------------------------------------------------------------
// File          : PseudoScope.cpp
// Author        : Kurtis Nishimura (adapted from Ryan Herbst's frameowrk)
// Created       : 03/21/2014
// Project       : ePix
//-----------------------------------------------------------------------------
// Description :
// Pseudo-oscilloscope 
//-----------------------------------------------------------------------------
// Copyright (c) 2014 by SLAC. All rights reserved.
// Proprietary and confidential to SLAC.
//-----------------------------------------------------------------------------
// Modification history :
// 03/21/2014: created
//-----------------------------------------------------------------------------
#include <PseudoScope.h>
#include <Register.h>
#include <Variable.h>
#include <Command.h>
#include <sstream>
#include <iostream>
#include <string>
#include <iomanip>
using namespace std;

// Constructor
PseudoScope::PseudoScope ( uint destination, uint baseAddress, uint index, Device *parent ) : 
                        Device(destination,baseAddress,"PseudoScope",index,parent) {

   // Description
   desc_ = "Virtual Oscilloscope object.";


   addRegister(new Register("Arm",            baseAddress_ + 0x50));
   addRegister(new Register("Trig",           baseAddress_ + 0x51));

   addRegister(new Register("Settings1",      baseAddress_ + 0x52));
   addVariable(new Variable("Enable",           Variable::Configuration));
   addVariable(new Variable("TriggerEdge",      Variable::Configuration));
   addVariable(new Variable("TriggerChannel",   Variable::Configuration));
   addVariable(new Variable("TriggerMode",      Variable::Configuration));
   addVariable(new Variable("TriggerThreshold", Variable::Configuration));

   addRegister(new Register("Settings2",      baseAddress_ + 0x53));
   addVariable(new Variable("TriggerOffset",    Variable::Configuration));
   addVariable(new Variable("TriggerHoldoff",   Variable::Configuration));

   addRegister(new Register("Settings3",      baseAddress_ + 0x54));
   addVariable(new Variable("TraceLength",      Variable::Configuration));
   addVariable(new Variable("SkipSamples",      Variable::Configuration));

   addRegister(new Register("Settings4",      baseAddress_ + 0x55));
   addVariable(new Variable("InputChannelA",    Variable::Configuration));
   addVariable(new Variable("InputChannelB",    Variable::Configuration));

   // Add command for scope arm and trigger
   addCommand(new Command("Arm"));
   addCommand(new Command("Trig")); 


   variables_["Enable"]->setTrueFalse();

   vector<string> edgeSettings;
   edgeSettings.resize(2);
   edgeSettings[0] = "Falling";
   edgeSettings[1] = "Rising";
   variables_["TriggerEdge"]->setEnums(edgeSettings);

   vector<string> trigModes;
   trigModes.resize(4);
   trigModes[0] = "NeverArm";
   trigModes[1] = "ManualArm";
   trigModes[2] = "FrameArm";
   trigModes[3] = "AutoRearm";
   variables_["TriggerMode"]->setEnums(trigModes);

   vector<string> trigCh;
   trigCh.resize(16);
   trigCh[ 0] = "Manual";
   trigCh[ 1] = "AdcThreshA";
   trigCh[ 2] = "AdcThreshB";
   trigCh[ 3] = "acqStart";
   trigCh[ 4] = "AsicAcq";
   trigCh[ 5] = "AsicR0";
   trigCh[ 6] = "AsicRoClk";
   trigCh[ 7] = "AsicPpmat";
   trigCh[ 8] = "AsicPpbe";
   trigCh[ 9] = "AsicSync";
   trigCh[10] = "AsicGr";
   trigCh[11] = "AsicSaciSel(0)";
   trigCh[12] = "AsicSaciSel(1)";
   trigCh[13] = "AsicSaciSel(2)";
   trigCh[14] = "AsicSaciSel(3)";
   trigCh[15] = "Unused";
   variables_["TriggerChannel"]->setEnums(trigCh);

   vector<string> inCh;
   inCh.resize(20);
   inCh[ 0] = "U1(0)";
   inCh[ 1] = "U1(1)";
   inCh[ 2] = "U1(2)";
   inCh[ 3] = "U1(3)";
   inCh[ 4] = "U2(0)";
   inCh[ 5] = "U2(1)";
   inCh[ 6] = "U2(2)";
   inCh[ 7] = "U2(3)";
   inCh[ 8] = "U3(0)";
   inCh[ 9] = "U3(1)";
   inCh[10] = "U3(2)";
   inCh[11] = "U3(3)";
   inCh[12] = "U4(0)";
   inCh[13] = "U4(1)";
   inCh[14] = "U4(2)";
   inCh[15] = "U4(3)";
   inCh[16] = "U1(TPS)";
   inCh[17] = "U2(TPS)";
   inCh[18] = "U3(TPS)";
   inCh[19] = "U4(TPS)";
   variables_["InputChannelA"]->setEnums(inCh);
   variables_["InputChannelB"]->setEnums(inCh);

   setInt("Enabled",0);  
}

// Deconstructor
PseudoScope::~PseudoScope ( ) { }

// Method to handle commands
void PseudoScope::command ( string name, string arg ) {
   // Command is local
   if  ( name == "Arm" ) {  
      REGISTER_LOCK
      writeRegister(getRegister("Arm"),true,false);
      REGISTER_UNLOCK
   }   
   else if (name == "Trig") {
      REGISTER_LOCK
      writeRegister(getRegister("Trig"),true,false);
      REGISTER_UNLOCK
   } 
}

// Method to read configuration registers
void PseudoScope::readConfig ( ) {

   REGISTER_LOCK

   //virtual oscilloscope registers
   readRegister(getRegister("Settings1"));
   getVariable("Enable")->setInt(getRegister("Settings1")->get(0,0x1));
   getVariable("TriggerEdge")->setInt(getRegister("Settings1")->get(1,0x1));
   getVariable("TriggerChannel")->setInt(getRegister("Settings1")->get(2,0xF));
   getVariable("TriggerMode")->setInt(getRegister("Settings1")->get(6,0x3));
   getVariable("TriggerThreshold")->setInt(getRegister("Settings1")->get(16,0xFFFF));

   readRegister(getRegister("Settings2"));
   getVariable("TriggerOffset")->setInt(getRegister("Settings2")->get(13,0x1FFF));
   getVariable("TriggerHoldoff")->setInt(getRegister("Settings2")->get(0,0x1FFF));

   readRegister(getRegister("Settings3"));
   getVariable("TraceLength")->setInt(getRegister("Settings3")->get(0,0x1FFF));
   getVariable("SkipSamples")->setInt(getRegister("Settings3")->get(13,0x1FFF));

   readRegister(getRegister("Settings4"));
   getVariable("InputChannelA")->setInt(getRegister("Settings4")->get(0,0x1F));
   getVariable("InputChannelB")->setInt(getRegister("Settings4")->get(5,0x1F));

   REGISTER_UNLOCK

}

// Method to write configuration registers
void PseudoScope::writeConfig ( bool force ) {

   REGISTER_LOCK

   //Virtual oscilloscope registers
   getRegister("Settings1")->set(getVariable("Enable")->getInt(),0,0x1);
   getRegister("Settings1")->set(getVariable("TriggerEdge")->getInt(),1,0x1);
   getRegister("Settings1")->set(getVariable("TriggerChannel")->getInt(),2,0xF);
   getRegister("Settings1")->set(getVariable("TriggerMode")->getInt(),6,0x3);
   getRegister("Settings1")->set(getVariable("TriggerThreshold")->getInt(),16,0xFFFF);
   writeRegister(getRegister("Settings1"),force);
   
   getRegister("Settings2")->set(getVariable("TriggerOffset")->getInt(),13,0x1FFF);
   getRegister("Settings2")->set(getVariable("TriggerHoldoff")->getInt(),0,0x1FFF);
   writeRegister(getRegister("Settings2"),force);

   getRegister("Settings3")->set(getVariable("TraceLength")->getInt(),0,0x1FFF);
   getRegister("Settings3")->set(getVariable("SkipSamples")->getInt(),13,0x1FFF);
   writeRegister(getRegister("Settings3"),force);

   getRegister("Settings4")->set(getVariable("InputChannelA")->getInt(),0,0x1F);
   getRegister("Settings4")->set(getVariable("InputChannelB")->getInt(),5,0x1F);
   writeRegister(getRegister("Settings4"),force);

   REGISTER_UNLOCK
}

