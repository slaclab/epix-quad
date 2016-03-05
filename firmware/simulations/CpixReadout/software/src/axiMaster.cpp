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
   uint runTriggerDelayAddr   = (0x00000002)<<2;
   uint asicMaskAddr          = (0x0000000D)<<2;
   uint saciRowStopAddr       = (0x00801012)<<2;
   uint saciConfig22Addr      = (0x00801016)<<2;
   uint rdout1                = 0;
   uint rdout2                = 0;
   

   master = new AxiMasterSim;
   if ( ! master->open(0) ) {
      printf("Failed to open sim master\n");
      return 1;
   }


   master->setVerbose(0);

   usleep(100);
   
   
   master->write(asicMaskAddr,0xF);
   master->write(runTriggerDelayAddr,9000);
   
   master->write(saciRowStopAddr,0x55);  
   master->write(saciConfig22Addr,0xaa);  
   
   do {
      rdout1 = master->read(saciRowStopAddr);
      rdout2 = master->read(saciConfig22Addr);
      printf("Read: 0x55=%X 0xAA=%X\n", rdout1, rdout2);
   }
   while (1);
   
   
   
}

