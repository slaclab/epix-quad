//-----------------------------------------------------------------------------
// File          : epixFirmwareLoader.cpp
// Author        : Ryan Herbst  <rherbst@slac.stanford.edu>
// Created       : 04/12/2011
// Project       : CSPAD
//-----------------------------------------------------------------------------
// Description :
// Server application for GUI
//-----------------------------------------------------------------------------
// This file is part of 'EPIX Development Softare'.
// It is subject to the license terms in the LICENSE.txt file found in the 
// top-level directory of this distribution and at: 
//    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
// No part of 'EPIX Development Softare', including this file, 
// may be copied, modified, propagated, or distributed except according to 
// the terms contained in the LICENSE.txt file.
// Proprietary and confidential to SLAC.
//-----------------------------------------------------------------------------
// Modification history :
// 04/12/2011: created
//----------------------------------------------------------------------------
#include <PgpLink.h>
#include <UdpLink.h>
#include <MultDestPgp.h>
#include <MultLink.h>
#include <EpixControl.h>
#include <AxiMicronN25Q.h>
#include <AxiVersion.h>
#include <Device.h>
#include <iomanip>
#include <fstream>
#include <iostream>
#include <signal.h>
using namespace std;

#define USE_MULTLINK 1

#define LANE0  0x10
#define LANE1  0x20
#define LANE2  0x40
#define LANE3  0x80

#define VC0    0x01
#define VC1    0x02
#define VC2    0x04
#define VC3    0x08

int main (int argc, char **argv) {
   
   AxiMicronN25Q * prom;
   AxiVersion    * fpga;
   string          pathToFile;
   
   // Check for .mcs file path
   if ( argc > 1 ){ 
      pathToFile = argv[1];
   }else{ 
      printf("\n############################\n");
      printf("usage: %s MCS_PATH\n", argv[0]);
      printf("\tMCS_PATH: File path to the .mcs file to be loaded\n");
      printf("############################\n");   
      return(1);
   }

   try {

      // Create and setup PGP link
#if USE_MULTLINK
      MultLink     *pgpLink;
      MultDest     *dest;  
#else
      PgpLink       *pgpLink; 
#endif
      uint          baseAddress;
      uint          addrSize;
      
      // Create and setup PGP link
#if USE_MULTLINK
      baseAddress = 0x00000000;
      addrSize = 4;
      dest = new MultDestPgp("/dev/pgpcard0");
      dest->addDataSource(0x00000000); // VC0 - acq data
      //dest->addDataSource(0x02000000); // VC2 - oscilloscope
      pgpLink = new MultLink();
      pgpLink->setDebug(false);
      pgpLink->setMaxRxTx(0x800000);
      pgpLink->open(1,dest);
      pgpLink->enableSharedMemory("epix",1);
      pgpLink->setXmlStore(false);
#else
      baseAddress = 0x01000000;
      addrSize = 1;
      pgpLink = new PgpLink();
      pgpLink->setMaxRxTx(550000);
      pgpLink->setDebug(true);
      pgpLink->open("/dev/pgpcard0");
      pgpLink->enableSharedMemory("epix",1);
      //Write out only the event data, no XML
      pgpLink->setXmlStore(false);
      pgpLink->setDataMask( (LANE0|VC0) | (LANE0|VC2) );
#endif
      
      usleep(100);

      cout << "Created PGP Link" << endl;

      EpixControl * epix = new EpixControl(pgpLink,"",EPIX100A, baseAddress, addrSize);
      epix->setDebug(false);
      
      prom   = (AxiMicronN25Q*)(epix->device("digFpga",0)->device("AxiMicronN25Q",0));
      fpga   =    (AxiVersion*)(epix->device("digFpga",0)->device("AxiVersion",0));
      
      // Set the path to the FPGA's .mcs file
      prom->setFilePath(pathToFile); 

      // Check if the .mcs file exists
      if(!prom->fileExist()){
         cout << "Error opening: " << pathToFile << endl;
         return(1);      
      }    
      
      // Get & Set the FPGA's PROM code size
      prom->setPromSize(prom->getPromSize(pathToFile)); 

      // Erase the FPGA's PROM
      prom->eraseBootProm();  
    
      // Write the .mcs file to the FPGA's PROM
      if(!prom->writeBootProm()){
         cout << "Error in AxiMicronN25Q->writeBootProm() function" << endl;
         return(1);      
      } 
      // Compare the .mcs file with the FPGA's PROM
      if(!prom->verifyBootProm()) {
         cout << "Error in AxiMicronN25Q->verifyBootProm() function" << endl;
         return(1);      
      }  
      
      // Display Reminder
      prom->rebootReminder(false); 

      // Reboot the FPGA
      fpga->command("FpgaReload","");
      sleep(1);
      
      return(0);

   } catch ( string error ) {
      cout << "Caught Error: " << endl;
      cout << error << endl;
   }
}

