//////////////////////////////////////////////////////////////////////////////
// This file is part of 'EPIX Development Firmware'.
// It is subject to the license terms in the LICENSE.txt file found in the 
// top-level directory of this distribution and at: 
//    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
// No part of 'EPIX Development Firmware', including this file, 
// may be copied, modified, propagated, or distributed except according to 
// the terms contained in the LICENSE.txt file.
//////////////////////////////////////////////////////////////////////////////

#include <stdio.h>
#include <string.h>
#include "xil_types.h"
#include "xil_io.h"
#include "xintc.h"
#include "xparameters.h"
#include "microblaze_sleep.h"
#include "xil_printf.h"
#include "ssi_printf.h"
#include "xtmrctr.h"
#include "regs.h"
#include "adcDelays.h"

#define TIMER_250MS_INTEVAL 25000000
#define TIMER_500MS_INTEVAL 50000000
#define TIMER_750MS_INTEVAL 75000000
#define TIMER_1SEC_INTEVAL 100000000


static XIntc    intc;
static XTmrCtr  tmrctr;



typedef struct timerStruct {
   uint32_t counter;
   uint32_t flag;
} timerStructType;


volatile timerStructType timer = {0, 0};

void adcStartupIntHandler(void * data) {
   uint32_t * request = (uint32_t *)data;
 
   (*request) = 1; 
   
   XIntc_Acknowledge(&intc, 0);
}

void adcTestIntHandler(void * data) {
   uint32_t * request = (uint32_t *)data;
 
   (*request) = 1; 
   
   XIntc_Acknowledge(&intc, 1);
}

void timerIntHandler(void * data, unsigned char num ) {
   timerStructType * timer = (timerStructType *)data;
   
   timer->counter++; 
   timer->flag = 1; 
   
   XIntc_Acknowledge(&intc, 8);
   
}

void waitTimer(u32 timerInterval) {
   // clear interrupt flag
   timer.flag = 0;
   // set interval
   XTmrCtr_SetResetValue(&tmrctr,0,timerInterval); 
   // start timer
   XTmrCtr_Start(&tmrctr,0);
   // wait for timer to roll
   while (timer.flag == 0);
}

int adcStartup() {
   
   int i, j;
   uint32_t regIn = 0;
   
   // Enable DCDCs
   Xil_Out32(SYSTEM_DCDCEN, 0xf);
   waitTimer(TIMER_500MS_INTEVAL);
   
   // Reset ADCs
   for (i=0; i<10; i++) {
      Xil_Out32(adcPdwnModeAddr[i], 0x3);
   }
   waitTimer(TIMER_500MS_INTEVAL);
   for (i=0; i<10; i++) {
      Xil_Out32(adcPdwnModeAddr[i], 0x0);
   }
   waitTimer(TIMER_500MS_INTEVAL);
   
   // Reset FPGA deserializers
   Xil_Out32(SYSTEM_ADCCLKRST, 0x1);
   Xil_Out32(SYSTEM_ADCCLKRST, 0x0);
   waitTimer(TIMER_500MS_INTEVAL);
   
   // Apply pre-trained delays
   for (i=0; i<10; i++) {
      for (j=0; j<9; j++) {
         Xil_Out32(adcDelayAddr[i][j], (512+adcDelays[i][j]));
      }
   }
   
   // Enable offset binary output
   for (i=0; i<10; i++) {
      regIn = Xil_In32(adcOutModeAddr[i]);
      regIn &= ~(0x1);
      Xil_Out32(adcOutModeAddr[i], regIn);
   }
}

int main() { 
   
   volatile uint32_t adcStartupInt = 0;
   volatile uint32_t adcTestInt = 0;
   
   XTmrCtr_Initialize(&tmrctr,0);   
   
   XIntc_Initialize(&intc,XPAR_U_CORE_U_CPU_U_MICROBLAZE_AXI_INTC_0_DEVICE_ID);
   microblaze_enable_interrupts();
   XIntc_Connect(&intc,0,(XInterruptHandler)adcStartupIntHandler,(void*)&adcStartupInt);
   XIntc_Connect(&intc,1,(XInterruptHandler)adcTestIntHandler,(void*)&adcTestInt);
   XIntc_Connect(&intc,8,XTmrCtr_InterruptHandler,&tmrctr);
   XIntc_Start(&intc,XIN_REAL_MODE);
   XIntc_Enable(&intc,0);
   XIntc_Enable(&intc,1);
   XIntc_Enable(&intc,8);
   
   XTmrCtr_SetHandler(&tmrctr,timerIntHandler,(void*)&timer);
   XTmrCtr_SetOptions(&tmrctr,0,XTC_DOWN_COUNT_OPTION | XTC_INT_MODE_OPTION );
   
   // wait for power to settle
   waitTimer(TIMER_1SEC_INTEVAL);
   // do the initial ADC startup
   adcStartup();
   
   while (1) {
      
      // redo ADC startup when power is toggled or requested by user
      // poll ADC startup interrupt flag
      if (adcStartupInt) {
         // clear interrupt flag
         adcStartupInt = 0;
         // call ADC startup routine
         adcStartup();
      }
      
      // poll ADC test interrupt flag
      if (adcTestInt) {
         // clear interrupt flag
         adcTestInt = 0;
         // call ADC test routine
         
      }
      
   }
   
   
   return 0;
}

