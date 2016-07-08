//-----------------------------------------------------------------------------
// File          : LogMemory.cpp
// Author        : Maciej Kwiatkowski <mkwiatko@slac.stanford.edu>
// Created       : 07/01/2016
// Project       : Epix
//-----------------------------------------------------------------------------
// Description :
//-----------------------------------------------------------------------------
// This file is part of 'SLAC Generic DAQ Software'.
// It is subject to the license terms in the LICENSE.txt file found in the 
// top-level directory of this distribution and at: 
//    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
// No part of 'SLAC Generic DAQ Software', including this file, 
// may be copied, modified, propagated, or distributed except according to 
// the terms contained in the LICENSE.txt file.
// Proprietary and confidential to SLAC.
//-----------------------------------------------------------------------------
// Modification history :
// 07/01/2016: created
//-----------------------------------------------------------------------------
#include <LogMemory.h>
#include <Register.h>
#include <RegisterLink.h>
#include <Variable.h>
#include <Command.h>
#include <sstream>
#include <iostream>
#include <string>
#include <iomanip>
using namespace std;

// Constructor
LogMemory::LogMemory ( uint32_t linkConfig, uint32_t baseAddress, uint32_t index, Device *parent, uint32_t addrSize ) : 
   Device(linkConfig,baseAddress,"LogMemory",index,parent) {

   // Description
   desc_ = "Firmware Version object.";

   // Create Registers: name, address
   addRegister(new Register("MemInfo", baseAddress_ + 0x00*addrSize, 1));
   addVariable(new Variable("MemPointer", Variable::Status));
   getVariable("MemPointer")->setDescription("Start of buffer");
   addVariable(new Variable("MemLength", Variable::Status));
   getVariable("MemLength")->setDescription("Length of buffer");
   
   addRegister(new Register("MemoryLow",    baseAddress_ + 0x01*addrSize, 512));
   addVariable(new Variable("MemoryLow", Variable::Status));
   getVariable("MemoryLow")->setDescription("Low buffer");
      
   addRegister(new Register("MemoryHigh",    baseAddress_ + 0x201*addrSize, 511));
   addVariable(new Variable("MemoryHigh", Variable::Status));
   getVariable("MemoryHigh")->setDescription("High buffer");

}

// Deconstructor
LogMemory::~LogMemory ( ) { }

// Process Commands
void LogMemory::command(string name, string arg) {
   Device::command(name, arg);
}

// Method to read status registers and update variables
void LogMemory::readStatus ( ) {
   Device::readStatus();
   REGISTER_LOCK
   string tmp;
   
   readRegister(getRegister("MemInfo"));
   getVariable("MemPointer")->setInt(getRegister("MemInfo")->get(0,0xFFFF));
   getVariable("MemLength")->setInt(getRegister("MemInfo")->get(16,0xFFFF));

   readRegister(getRegister("MemoryLow"));
   tmp = string((char *)(getRegister("MemoryLow")->data()));
   getVariable("MemoryLow")->set(tmp);
   
   readRegister(getRegister("MemoryHigh"));
   tmp = string((char *)(getRegister("MemoryHigh")->data()));
   getVariable("MemoryHigh")->set(tmp);

   REGISTER_UNLOCK
}

//read buffer
char* LogMemory::getBuffer() {
   
   unsigned int ptr, len;
   string tmp;
   
   
   REGISTER_LOCK
   
   readRegister(getRegister("MemInfo"));
   ptr = getRegister("MemInfo")->get(0,0xFFFF);
   len = getRegister("MemInfo")->get(16,0xFFFF);

   readRegister(getRegister("MemoryLow"));
   tmp = string((char *)(getRegister("MemoryLow")->data()));
   
   readRegister(getRegister("MemoryHigh"));
   tmp += string((char *)(getRegister("MemoryHigh")->data()));
   
   if (len <= 4091) {
      memcpy(memory_, tmp.c_str(), len);
   }
   else {
      memcpy(memory_, tmp.c_str()+ptr, 4091-ptr+1);
      memcpy(memory_+(4091-ptr+1), tmp.c_str(), 4092-(4091-ptr+1));
   }

   REGISTER_UNLOCK
   
   ptr_ = ptr;
   len_ = len;
   
   return memory_;
}

unsigned int LogMemory::getSize() {
   return len_;
}

