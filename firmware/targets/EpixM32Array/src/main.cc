//////////////////////////////////////////////////////////////////////////////
// This file is part of 'CPIX Development Firmware'.
// It is subject to the license terms in the LICENSE.txt file found in the 
// top-level directory of this distribution and at: 
//    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
// No part of 'CPIX Development Firmware', including this file, 
// may be copied, modified, propagated, or distributed except according to 
// the terms contained in the LICENSE.txt file.
//////////////////////////////////////////////////////////////////////////////
#include <stdio.h>
#include <string.h>
#include "xil_types.h"
#include "xil_io.h"
#include "microblaze_sleep.h"
#include "xil_printf.h"
#include "regs.h"
#include "ssi_printf.h"

#define FRM_DLY_START 12
#define FRM_DLY_STOP 18


void epixInit(void);
unsigned int adcAlign(unsigned int, unsigned int);

int main() { 
   
   unsigned int i, res, req = 0;
   
   ssi_printf_init(LOG_MEM_OFFSET, 1024*4);
   
   while (1) {
      
      //initialize
      epixInit();
      ssi_printf("ADC REQ %d\n", req);
      
      // only monitoring ADC in use with tixel or cpix
      res = adcAlign(2,  4);
      
      //align ADCs
      for (res = 0, i = 0; i <= 1; i++)
         res |= (adcAlign(i,  8)<<i);
      
      // set success or fail
      if (res == 3)
         Xil_Out32(EPIX_ADC_ALIGN_REG, 0x00000002);   //ack, no fail
      else 
         Xil_Out32(EPIX_ADC_ALIGN_REG, 0x00000006);   //ack, fail
      
      //wait until ADC alignment requested
      while (1) {
         
         MB_Sleep(200);
         
         // poll ADC align request bit
         if ((Xil_In32(EPIX_ADC_ALIGN_REG)&0x00000001) != 0) {
            Xil_Out32(EPIX_ADC_ALIGN_REG, 0x00000001);
            req++;
            break;
         }
         
      }
      
   }
   
   
   return 0;
}

void epixInit() {
   
   //set ADC clock to 50 MHz
   Xil_Out32( EPIX_ADCCLK_REG, 0x1);
   // disable the power supply
   //Xil_Out32( EPIX_PWR_REG, 0x0);
   // enable the power supply
   Xil_Out32( EPIX_PWR_REG, 0x7);
   // let the power settle
   MB_Sleep(2000);
   
   // Perform ADC soft reset
   Xil_Out32( ADC0_PWRMOD_REG, 3);
   Xil_Out32( ADC1_PWRMOD_REG, 3);
   MB_Sleep(10);
   Xil_Out32( ADC0_PWRMOD_REG, 0);
   Xil_Out32( ADC1_PWRMOD_REG, 0);
   
   //power down not used ADCs
   Xil_Out32( ADC2_PWRMOD_REG, 1);
   
   // Switch ADC default data format to offset binary
   Xil_Out32( ADC0_OUTMOD_REG, 0);
   Xil_Out32( ADC1_OUTMOD_REG, 0);
   
}

unsigned int adcAlign(unsigned int adcNo, unsigned int maxCh) {
   
   unsigned int delay, adcCh, debugSample, fail = 0;
   int firstDly;
   int lastDly;
   
   //set the frame delay and poll the lock register
   for (delay = FRM_DLY_START; delay <= FRM_DLY_STOP; delay++) {
      //set the frame delay
      Xil_Out32(frmDlyAdc[adcNo], delay | (0x1<<5));
      //reset lock fall out counter
      Xil_Out32(cntLocRstAdc[adcNo], 1);
      Xil_Out32(cntLocRstAdc[adcNo], 0);
      //wait
      MB_Sleep(100);
      //check if locked bit is 1 and lock fall out counter is 0
      if (Xil_In32(frmLocAdc[adcNo]) == 0x10000) {
         //log message
         ssi_printf("ADC%d FRM DLY%d OK\n", adcNo, delay);
         break;
      }
      else if (delay == FRM_DLY_STOP) {
         fail |= 1;
         //log message
         ssi_printf("ADC%d FRM FAIL; FRM REG 0x%X\n", adcNo, Xil_In32(frameAdc[adcNo]));
      }
   }
   
   //enable ADC mixed bit frequency test pattern
   Xil_Out32(tstModeAdc[adcNo], 0xC);
   //set the data mask
   Xil_Out32(ADC_TEST_MASK_REG, 0x3FFF);
   //set the pattern
   Xil_Out32(ADC_TEST_PATT_REG, 0x2867);
   //set the number of samples to test
   Xil_Out32(ADC_TEST_SMPL_REG, 50000);
   //set the timeout
   Xil_Out32(ADC_TEST_TOUT_REG, 100);
   
   //align every channel
   for (adcCh = 0; adcCh < maxCh; adcCh++) {
      firstDly = -1;
      lastDly = -1;
      for (delay = 0; delay <= 31; delay++) {
         //set channel's data delay
         Xil_Out32(dataDlyChAdc[adcNo][adcCh], delay | (0x1<<5));
         //select channel to test
         Xil_Out32(ADC_TEST_CHAN_REG, adcNo*8+adcCh);
         //run the test
         Xil_Out32(ADC_TEST_REQ_REG, 1);
         Xil_Out32(ADC_TEST_REQ_REG, 0);
         
         //wait for the number of samples to be compared to the selected test pattern
         //wait until success or failure
         while (Xil_In32( ADC_TEST_PASS_REG) != 1 && Xil_In32( ADC_TEST_FAIL_REG) != 1);
         
         // the code below is to find the first and the last delay setting that passed the test
         if (Xil_In32( ADC_TEST_PASS_REG) == 1) {
            if (firstDly == -1)
               firstDly = delay;
            if (delay == 31)
               lastDly = delay;
         }
         else {
            //read debug sample register
            debugSample = Xil_In32(debugAdc[adcNo][adcCh]);
            if (firstDly != -1 && lastDly == -1) {
               lastDly = delay-1;
            }
         }
      }
      
      if (firstDly == -1 || lastDly == -1) {
         fail |= 1;                                                              // channel failed
         //log message
         ssi_printf("ADC%d CH%d FAIL; DBGS 0x%X\n", adcNo, adcCh, debugSample);
      }
      else {
         Xil_Out32(dataDlyChAdc[adcNo][adcCh], ((lastDly-firstDly)/2+firstDly) | (0x1<<5));   // set the delay in the middle
         //log message
         ssi_printf("ADC%d CH%d DLY%d OK\n", adcNo, adcCh, (lastDly-firstDly)/2+firstDly);
      }
      
   }
   
   //disable ADC mixed bit frequency test pattern
   Xil_Out32(tstModeAdc[adcNo], 0x0);
   
   if (fail == 0)
      return 1;
   else
      return 0;
   
}
