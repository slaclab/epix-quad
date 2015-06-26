//-----------------------------------------------------------------------------
// File          : PrbsRx.cpp
// Author        : Ben Reese <bareese@slac.stanford.edu>
// Created       : 11/14/2013
// Project       : HPS SVT
//-----------------------------------------------------------------------------
// Description :
// Device container for AxiVersion.vhd
//-----------------------------------------------------------------------------
// Copyright (c) 2013 by SLAC. All rights reserved.
// Proprietary and confidential to SLAC.
//-----------------------------------------------------------------------------
// Modification history :
// 11/14/2013: created
//-----------------------------------------------------------------------------
#include <PrbsRx.h>
#include <Register.h>
#include <Variable.h>
#include <Command.h>
#include <sstream>
#include <iostream>
#include <string>
#include <iomanip>
using namespace std;

// Constructor
PrbsRx::PrbsRx ( uint destination, uint baseAddress, uint index, Device *parent ) : 
                        Device(destination,baseAddress,"PrbsRx",index,parent) {

   // Description
   desc_ = "Firmware Version object.";

   // Create Registers: name, address
   addRegister(new Register("MissedPacketCount",   baseAddress_ + 0x00));
   addRegister(new Register("LengthErrorCount",    baseAddress_ + 0x01));
   addRegister(new Register("EofeErrorCount", baseAddress_ + 0x02));
   addRegister(new Register("DataBusErrorCount",  baseAddress_ + 0x03));
   addRegister(new Register("WordStrbErrorCount",  baseAddress_ + 0x04));
   addRegister(new Register("BitStrbErrorCount",   baseAddress_ + 0x05));
   addRegister(new Register("RxFifoOverflowCount",   baseAddress_ + 0x06));
   addRegister(new Register("RxFifoPauseCount",    baseAddress_ + 0x07));
   addRegister(new Register("TxFifoOverflowCount",    baseAddress_ + 0x08));
   addRegister(new Register("TxFifoPauseCount",    baseAddress_ + 0x09));
   addRegister(new Register("Dummy",    baseAddress_ + 0x0a));

   addRegister(new Register("Status",    baseAddress_ + 0x70));
   addRegister(new Register("PacketLength",    baseAddress_ + 0x71));
   addRegister(new Register("PacketRate",    baseAddress_ + 0x72));
   addRegister(new Register("BitErrorCount",    baseAddress_ + 0x73));
   addRegister(new Register("WordErrorCount",    baseAddress_ + 0x74));   
   
   addRegister(new Register("RolloverEnable", baseAddress_ + 0xF0));
   addRegister(new Register("CountReset", baseAddress_ + 0xF0));


   // Variables
   Variable* v;

   v = getVariable("Enabled");
   v->set("True");
   v->setHidden(true);

   v = new Variable("MissedPacketCount", Variable::Status);
   v->setDescription("Number of missed packets");
   addVariable(v);

   v = new Variable("LengthErrorCount", Variable::Status);
   v->setDescription("Number of packets that were the wrong length");
   addVariable(v);

   v = new Variable("EofeErrorCount", Variable::Status);
   v->setDescription("Number of EOFE errors");
   addVariable(v);

   v = new Variable("DataBusErrorCount", Variable::Status);
   v->setDescription("Number of data bus errors");
   addVariable(v);

   v = new Variable("WordStrbErrorCount", Variable::Status);
   v->setDescription("Number of word errors");
   addVariable(v);
   
   v = new Variable("BitStrbErrorCount", Variable::Status);
   v->setDescription("Number of bit errors");
   addVariable(v);
   
   v = new Variable("RxFifoOverflowCount", Variable::Status);
   v->setDescription("");
   addVariable(v);
   
   v = new Variable("RxFifoPauseCount", Variable::Status);
   v->setDescription("");
   addVariable(v);
   
   v = new Variable("TxFifoOverflowCount", Variable::Status);
   v->setDescription("");
   addVariable(v);
   
   v = new Variable("TxFifoPauseCount", Variable::Status);
   v->setDescription("");
   addVariable(v);

   v = new Variable("Dummy", Variable::Configuration);
   v->setDescription("");
   v->setPerInstance(true);
   addVariable(v);
   
   v = new Variable("PacketLength", Variable::Status);
   v->setDescription("");
   addVariable(v);
   
   
   v = new Variable("PacketRate", Variable::Status);
   v->setDescription("");
   addVariable(v);
   
   
   v = new Variable("BitErrorCount", Variable::Status);
   v->setDescription("");
   addVariable(v);
   
   
   v = new Variable("WordErrorCount", Variable::Status);
   v->setDescription("");
   addVariable(v);
   
   
   v = new Variable("RolloverEnable", Variable::Configuration);
   v->setDescription("");
   v->setPerInstance(true);
   addVariable(v);
   
   //Commands
   Command *c;

   c = new Command("ResetCounters");
   c->setDescription("Reset all the error and rate counters");
   addCommand(c);

}

// Deconstructor
PrbsRx::~PrbsRx ( ) { }

// Process Commands
void PrbsRx::command(string name, string arg) {
   Register *r;
   if (name == "ResetCounters") {
      REGISTER_LOCK
      r = getRegister("CountReset");
      r->set(0x1);
      writeRegister(r, true, false);
      REGISTER_UNLOCK
   }
}

// Method to read status registers and update variables
void PrbsRx::readStatus ( ) {
   REGISTER_LOCK
         
   readStatusRegisterVariable("MissedPacketCount");
   readStatusRegisterVariable("LengthErrorCount");
   readStatusRegisterVariable("EofeErrorCount");
   readStatusRegisterVariable("DataBusErrorCount");
   readStatusRegisterVariable("WordStrbErrorCount");
   readStatusRegisterVariable("BitStrbErrorCount");
   readStatusRegisterVariable("RxFifoOverflowCount");
   readStatusRegisterVariable("RxFifoPauseCount");
   readStatusRegisterVariable("TxFifoOverflowCount");
   readStatusRegisterVariable("TxFifoPauseCount");
   readStatusRegisterVariable("PacketLength");
   readStatusRegisterVariable("PacketRate");
   readStatusRegisterVariable("BitErrorCount");
   readStatusRegisterVariable("WordErrorCount");
         
   REGISTER_UNLOCK
}

void PrbsRx::readConfig ( ) {
   REGISTER_LOCK

   readRegister(getRegister("RolloverEnable"));
   getVariable("RolloverEnable")->setInt(getRegister("RolloverEnable")->get());

   readRegister(getRegister("Dummy"));
   getVariable("Dummy")->setInt(getRegister("Dummy")->get());

   REGISTER_UNLOCK
}

// Method to write configuration registers
void PrbsRx::writeConfig ( bool force ) {
   REGISTER_LOCK

   // Set registers
   getRegister("RolloverEnable")->set(getVariable("RolloverEnable")->getInt());
   writeRegister(getRegister("RolloverEnable"), force);

   getRegister("Dummy")->set(getVariable("Dummy")->getInt());
   writeRegister(getRegister("Dummy"), force);

   REGISTER_UNLOCK
}

void PrbsRx::readStatusRegisterVariable(string name) {
   // Read registers
   readRegister(getRegister(name));
   getVariable(name)->setInt(getRegister(name)->get());
}
