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

   uint runTriggerDelayAddr  = 0x01000002;
   
   uint          rdout = 0;
   

   master = new AxiMasterSim;
   if ( ! master->open(0) ) {
      printf("Failed to open sim master\n");
      return 1;
   }


   master->setVerbose(0);

   usleep(100);
   master->write(runTriggerDelayAddr,9000);

   master->setVerbose(0);
   
   rdout = master->read(runTriggerDelayAddr);
   
   printf("Read %d\n", rdout);
   
}

