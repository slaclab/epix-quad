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
#include "xtmrctr.h"
#include "xparameters.h"
#include "xil_printf.h"
#include "regs.h"
#include "ssi_printf.h"

#define CLEAR_ASIC_MATRIX_ON_STARTUP 1
#define FRM_DLY_START 12
#define FRM_DLY_STOP 18
#define TIMER_1SEC_INTEVAL 129687500


void hwInit(void);
void adcInit(void);
void findAsics(void);
void asicInit(void);
uint32_t adcAlign(uint32_t, uint32_t);
volatile uint32_t timer;

static XTmrCtr  tmrctr;
static XIntc intc;

void calibReqHandler(void * data) {
   uint32_t * request = (uint32_t *)data;
   
   Xil_Out32(EPIX_ADC_ALIGN_REG, 0x00000000);
 
   (*request) = 1; 
   
   XIntc_Acknowledge(&intc, 0);
}


void timerIntHandler(void * data, unsigned char num ) {
   uint32_t * request = (uint32_t *)data;
   
   (*request) = 1; 
   
   XIntc_Acknowledge(&intc, 8);
   
}

void waitTimer(u32 timerInterval) {
   // clear interrupt flag
   timer = 0;
   // set interval
   XTmrCtr_SetResetValue(&tmrctr,0,timerInterval); 
   // start timer
   XTmrCtr_Start(&tmrctr,0);
   // wait for timer to roll
   while (timer == 0);
}

int main() { 
   
   uint32_t res, i, adcReqNo = 0;
   volatile uint32_t adcReq = 0;
   timer = 0;
   
   XTmrCtr_Initialize(&tmrctr,0); 
   
   XIntc_Initialize(&intc,XPAR_AXI_INTC_0_DEVICE_ID);
   microblaze_enable_interrupts();
   XIntc_Connect(&intc,0,(XInterruptHandler)calibReqHandler,(void*)&adcReq);
   XIntc_Connect(&intc,8,XTmrCtr_InterruptHandler,&tmrctr);
   XIntc_Start(&intc,XIN_REAL_MODE);
   XIntc_Enable(&intc,8);
   
   XTmrCtr_SetHandler(&tmrctr,timerIntHandler,(void*)&timer);
   XTmrCtr_SetOptions(&tmrctr,0,XTC_DOWN_COUNT_OPTION | XTC_INT_MODE_OPTION );
   
   waitTimer(TIMER_1SEC_INTEVAL);
   XIntc_Enable(&intc,0);
   
   ssi_printf_init(LOG_MEM_OFFSET, 1024*4);
   
   //initialize
   hwInit();
   adcInit();
   findAsics();
   asicInit();
   
   while (1) {
      
      
      ssi_printf("ADC REQ %d\n", adcReqNo);
      
      //align ADCs
      for (res = 0, i = 0; i <= 2; i++)
         res |= (adcAlign(i,  (i!=2?8:4))<<i);   //ADC number 2 has only 4 channels in use
      
      // set success or fail
      if (res == 7)
         Xil_Out32(EPIX_ADC_ALIGN_REG, 0x00000002);   //ack, no fail
      else 
         Xil_Out32(EPIX_ADC_ALIGN_REG, 0x00000006);   //ack, fail
      
      //wait until ADC alignment requested
      while (1) {
         
         // poll ADC align request flag
         if (adcReq) {
            //reset ADCs
            adcInit();
            //check installed asics
            findAsics();
            adcReq = 0;
            adcReqNo++;
            break;
         }
         
      }
      
   }
   
   
   return 0;
}

void hwInit() {
   // clear out ADC status flags
   Xil_Out32(EPIX_ADC_ALIGN_REG, 0x00000000);
   // enable the power supply
   Xil_Out32( EPIX_PWR_REG, 0x7);
   // let the power settle
   waitTimer(TIMER_1SEC_INTEVAL);
}

void adcInit() {
   
   // Perform ADC soft reset
   Xil_Out32( ADC0_PWRMOD_REG, 3);
   Xil_Out32( ADC1_PWRMOD_REG, 3);
   Xil_Out32( ADC2_PWRMOD_REG, 3);
   waitTimer(TIMER_1SEC_INTEVAL/100);
   Xil_Out32( ADC0_PWRMOD_REG, 0);
   Xil_Out32( ADC1_PWRMOD_REG, 0);
   Xil_Out32( ADC2_PWRMOD_REG, 0);
   
   // Switch ADC default data format to offset binary
   Xil_Out32( ADC0_OUTMOD_REG, 0);
   Xil_Out32( ADC1_OUTMOD_REG, 0);
   Xil_Out32( ADC2_OUTMOD_REG, 0);
   
}


void findAsics(void) {
   
   uint32_t i, dm, test, mask;
   mask = 0;
   
   //find installed ASICs by testing the digital monitor register
   for (i = 0; i <= 3; i++) {
      dm = Xil_In32( cfg4Asic[i]);
      Xil_Out32( cfg4Asic[i], 0x5A);
      test = Xil_In32( cfg4Asic[i]);
      ssi_printf("ASIC%d write 0x5A read 0x%X\n", i, test);
      if ((test&0xFF) == 0x5A) 
         mask |= (1<<i);
      Xil_Out32( cfg4Asic[i], dm);
   }
   
   Xil_Out32( EPIX_ASIC_MASK_REG, mask);
   ssi_printf("ASIC mask 0x%X\n", mask);
   
}

void asicInit(void) {
   
   uint32_t mask, i;
#if CLEAR_ASIC_MATRIX_ON_STARTUP
   uint32_t col;
#endif
   
   mask = Xil_In32(EPIX_ASIC_MASK_REG);
   
   //Disable digital monitors to let the carrier ID readout
   //Enable SLVDS termination resistors
   //Clear matrix configuration bits
   
   for (i = 0; i <= 3; i++) {
      if (mask&(1<<i)) {
         Xil_Out32( cfg6Asic[i], 0x10);
#if CLEAR_ASIC_MATRIX_ON_STARTUP
         for (col = 0; col < 96; col++ ) {
            Xil_Out32( prepMultCfgAsic[i], 0x0);
            Xil_Out32( colCntAsic[i], col);
            Xil_Out32( wrColAsic[i], 0x0);
         }
         Xil_Out32( prepRdAsic[i], 0x0);
#endif
      }
   }
}

uint32_t adcAlign(uint32_t adcNo, uint32_t maxCh) {
   
   uint32_t delay, adcCh, fail = 0;
   uint32_t debugSample = 0;
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
      waitTimer(TIMER_1SEC_INTEVAL/10);
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
