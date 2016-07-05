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
   
   uint addr = 0x20000000;
   uint data = 0;
   

   master = new AxiMasterSim;
   if ( ! master->open(0) ) {
      printf("Failed to open sim master\n");
      return 1;
   }
   
   

   master->setVerbose(0);
   
   printf("Writing pwdn reg\n");
   master->write(0x20004000,0xff);
   printf("Writing pwdn reg done\n");
   printf("Reading pwdn reg\n");
   data = master->read(0x20004000);
   printf("Reading pwdn reg done %d\n", data);
   
   printf("Writing %d\n", addr);
   master->write(addr,data);  
   printf("Writing done %d\n", addr);
      
   printf("Reading %d\n", addr);
   master->read(addr);
   printf("Reading done %d\n", addr);
   
   addr = 0x20000800;
   
   printf("Writing %d\n", addr);
   master->write(addr,data);  
   printf("Writing done %d\n", addr);
      
   printf("Reading %d\n", addr);
   master->read(addr);
   printf("Reading done %d\n", addr);
   
   addr = 0x20001000;
   
   printf("Writing %d\n", addr);
   master->write(addr,data);  
   printf("Writing done %d\n", addr);
      
   printf("Reading %d\n", addr);
   master->read(addr);
   printf("Reading done %d\n", addr);
   
   
   
}

