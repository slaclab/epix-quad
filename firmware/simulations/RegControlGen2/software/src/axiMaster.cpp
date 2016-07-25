//////////////////////////////////////////////////////////////////////////////
// This file is part of 'SLAC Firmware Standard Library'.
// It is subject to the license terms in the LICENSE.txt file found in the 
// top-level directory of this distribution and at: 
//    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
// No part of 'SLAC Firmware Standard Library', including this file, 
// may be copied, modified, propagated, or distributed except according to 
// the terms contained in the LICENSE.txt file.
//////////////////////////////////////////////////////////////////////////////
#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <string.h>
#include <unistd.h>
#include <time.h>
#include <sys/mman.h>
#include <iostream>
#include <iomanip>
#include "../lib/AxiSlaveSim.h"
#include "../lib/AxiMasterSim.h"
using namespace std;
 
int main(int argc, char **argv) {
   
   AxiMasterSim  *master;
   uint multiPixelData0       = (0x00080002)<<2;
   uint multiPixelData1       = (0x00080003)<<2;
   uint multiPixelData2       = (0x00080004)<<2;
   uint multiPixelData3       = (0x00080005)<<2;
   uint asicMaskAddr          = (0x0000000D)<<2;
   uint saciRowStopAddr       = (0x00801012)<<2;
   uint saciRowStopAddr2      = (0x00801013)<<2;
   uint rdout1                = 0;
   

   master = new AxiMasterSim;
   if ( ! master->open(0) ) {
      printf("Failed to open sim master\n");
      return 1;
   }


   master->setVerbose(0);

   usleep(100); 
   
   //master->write(saciRowStopAddr,0x55);  
   //master->write(saciRowStopAddr2,0xaa);  
   //rdout1 = master->read(saciRowStopAddr);
   //printf("WR:0x55 RD:%X\n", rdout1);
   
   master->write(asicMaskAddr,0xF);
   master->write(multiPixelData0,0x0);
   master->write(multiPixelData1,0x1);
   master->write(multiPixelData2,0x2);
   master->write(multiPixelData3,0x3); 
   
   do {
      master->write(saciRowStopAddr,0x55);  
      rdout1 = master->read(saciRowStopAddr);
      printf("WR:0x55 RD:%X\n", rdout1);
   }
   while (1);
   
   
   
}

