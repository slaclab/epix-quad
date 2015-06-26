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

   if (argc != 2) {
      cout << "Please give filename for image map" << endl;
      return 1;
   }

   char *filename = argv[1];
   ifstream fin(filename);
   if (!fin) {
      cout << "Couldn't open " << filename << endl;
      return 1;
   }

   PgpLink  pgpLink;

   try {

      // Create and setup PGP link
      pgpLink.setMaxRxTx(500000);
      pgpLink.setDebug(true);
      pgpLink.open("/dev/pgpcard0");
      usleep(100);

      writeReg(&pgpLink,0x000028,3,true);  //Saci CLK bit to 3
      writeReg(&pgpLink,0x808000,0,true);
      writeReg(&pgpLink,0x908000,0,true);
      writeReg(&pgpLink,0xA08000,0,true);
      writeReg(&pgpLink,0xB08000,0,true);

      for (int row = 0; row < 352*2; ++row) {
         int rowData[384*2] = {0};
         for (int col = 0; col < 384*2; ++col) {
            unsigned int thisData;
            fin >> thisData;
            rowData[col] = thisData;
         }

         for (int col = 0; col < 96; ++col) {
            if (rowData[96*0+col] != 0 || rowData[96*1+col] != 0 || rowData[96*2+col] != 0 || rowData[96*3+col] != 0) {
               writeReg(&pgpLink,0x080000,row,true);
               writeReg(&pgpLink,0x080001,col,true);
               writeReg(&pgpLink,0x080002,rowData[96*0+col],true);
               writeReg(&pgpLink,0x080003,rowData[96*1+col],true);
               writeReg(&pgpLink,0x080004,rowData[96*2+col],true);
               writeReg(&pgpLink,0x080005,rowData[96*3+col],true);
            }
         }
         for (int col = 384; col < 384+96; ++col) {
            if (rowData[96*0+col] != 0 || rowData[96*1+col] != 0 || rowData[96*2+col] != 0 || rowData[96*3+col] != 0) {
               writeReg(&pgpLink,0x080000,row,true);
               writeReg(&pgpLink,0x080001,col,true);
               writeReg(&pgpLink,0x080002,rowData[96*0+col],true);
               writeReg(&pgpLink,0x080003,rowData[96*1+col],true);
               writeReg(&pgpLink,0x080004,rowData[96*2+col],true);
               writeReg(&pgpLink,0x080005,rowData[96*3+col],true);
            }
         }
         cout << "Finished row " << row << " of " << 352*2-1 << endl;
      }
      writeReg(&pgpLink,0x000028,4,true);  //Saci CLK bit back to 4

      writeReg(&pgpLink,0x800000,0,true);
      writeReg(&pgpLink,0x900000,0,true);
      writeReg(&pgpLink,0xA00000,0,true);
      writeReg(&pgpLink,0xB00000,0,true);

      pgpLink.close();
   } catch ( string error ) {
      cout << "Caught Error: " << endl;
      cout << error << endl;
   }

   fin.close();
   return 0;

}

unsigned int readReg(PgpLink *link, unsigned int reg) {
   char reg_str[64];
   reg |= 0x01000000;
   sprintf(reg_str,"0x%08x",reg);
   Register thisReg(reg_str, reg);
   link->queueRegister(0,&thisReg,false,true); 
//   cout << "Status = " << thisReg.status() << endl;
   return thisReg.get();
}

unsigned int writeReg(PgpLink *link, unsigned int reg, unsigned int val, bool wait) {
   char reg_str[64];
   reg |= 0x01000000;
   sprintf(reg_str,"0x%08x",reg);
   Register thisReg(reg_str, reg);
   thisReg.set(val);
   link->queueRegister(0,&thisReg,true,wait); 
//   cout << "Status = " << thisReg.status() << endl;
   return thisReg.get();
}


