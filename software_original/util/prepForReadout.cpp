//-----------------------------------------------------------------------------
// File          : cspadGui.cpp
// Author        : Ryan Herbst  <rherbst@slac.stanford.edu>
// Created       : 04/12/2011
// Project       : CSPAD
//-----------------------------------------------------------------------------
// Description :
// Server application for GUI
//-----------------------------------------------------------------------------
// Copyright (c) 2011 by SLAC. All rights reserved.
// Proprietary and confidential to SLAC.
//-----------------------------------------------------------------------------
// Modification history :
// 04/12/2011: created
//----------------------------------------------------------------------------
#include <PgpLink.h>
#include <ControlServer.h>
#include <Device.h>
#include <Register.h>
#include <iomanip>
#include <fstream>
#include <iostream>
#include <signal.h>
using namespace std;

unsigned int readReg(PgpLink *link, unsigned int reg);
unsigned int writeReg(PgpLink *link, unsigned int reg, unsigned int val, bool wait = true);

int main (int argc, char **argv) {
   PgpLink  pgpLink;

   try {

      // Create and setup PGP link
      pgpLink.setMaxRxTx(500000);
      pgpLink.setDebug(true);
      pgpLink.open("/dev/pgpcard0");
      usleep(100);

      writeReg(&pgpLink,0x800000,0);
      writeReg(&pgpLink,0x900000,0);
      writeReg(&pgpLink,0xA00000,0);
      writeReg(&pgpLink,0xB00000,0);

      pgpLink.close();
   } catch ( string error ) {
      cout << "Caught Error: " << endl;
      cout << error << endl;
   }
}

unsigned int readReg(PgpLink *link, unsigned int reg) {
   char reg_str[64];
   reg |= 0x01000000;
   sprintf(reg_str,"0x%08x",reg);
   Register thisReg(reg_str, reg);
   link->queueRegister(0,&thisReg,false,true); 
   cout << "Status = " << thisReg.status() << endl;
   return thisReg.get();
}

unsigned int writeReg(PgpLink *link, unsigned int reg, unsigned int val, bool wait) {
   char reg_str[64];
   reg |= 0x01000000;
   sprintf(reg_str,"0x%08x",reg);
   Register thisReg(reg_str, reg);
   thisReg.set(val);
   link->queueRegister(0,&thisReg,true,wait); 
   cout << "Status = " << thisReg.status() << endl;
   return thisReg.get();
}


