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
unsigned int writeReg(PgpLink *link, unsigned int reg, unsigned int val);

int main (int argc, char **argv) {
   PgpLink  pgpLink;

   try {

      // Create and setup PGP link
      pgpLink.setMaxRxTx(500000);
      pgpLink.setDebug(true);
      pgpLink.open("/dev/pgpcard0");
      usleep(100);

      while (1) {
         int command;
         cout << "--------------------------------" << endl;
         cout << "Read (0) / write (1) / exit(2): ";
         cin >> command;
         if (command < 0 || command > 2) {
            cout << "Invalid command." << endl;
         } else if (command == 2) {
            break;
         } else {
            cout << "Enter register number: ";
            unsigned int reg = 0;
            char reg_str[32];
            cin >> reg_str;
            int match = sscanf(reg_str,"0x%x",&reg);
            if (match < 1) {
               match = sscanf(reg_str,"%d",&reg);
               if (match < 1) {
                  cout << "Invalid register!" << endl;
                  continue;
               }
            }
            if (command == 0) {
               unsigned int value = readReg(&pgpLink,reg);   
               cout << "Register " << reg << " ";
               cout << "(0x" << hex << reg << dec << ") = ";
               cout << value << " ";
               cout << "(0x" << hex << value << dec << ")" << endl;
            }
            if (command == 1) {
               unsigned int value;
               char val_str[32];
               cout << "Enter value: ";
               cin >> val_str;
               int match = sscanf(val_str,"0x%x",&value);
               if (match < 1) {
                  match = sscanf(val_str,"%d",&value);
                  if (match < 1) {
                     cout << "Invalid register!" << endl;
                     continue;
                  }
               }
               writeReg(&pgpLink,reg,value);
            }
         }
      }
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

unsigned int writeReg(PgpLink *link, unsigned int reg, unsigned int val) {
   char reg_str[64];
   reg |= 0x01000000;
   sprintf(reg_str,"0x%08x",reg);
   Register thisReg(reg_str, reg);
   thisReg.set(val);
   link->queueRegister(0,&thisReg,true,true); 
   cout << "Status = " << thisReg.status() << endl;
   return thisReg.get();
}


