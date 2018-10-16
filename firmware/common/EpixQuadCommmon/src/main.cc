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

#define TIMER_10MS_INTEVAL  1000000
#define TIMER_50MS_INTEVAL  5000000
#define TIMER_250MS_INTEVAL 25000000
#define TIMER_500MS_INTEVAL 50000000
#define TIMER_750MS_INTEVAL 75000000
#define TIMER_1SEC_INTEVAL 100000000

#define ADC_STARTUP_RETRY 500


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

enum PwrState {PWR_IDLE_S, PWR_WAIT_S, PWR_DONE_S};
enum AdcState {ADC_IDLE_S, ADC_WAIT_S, ADC_DONE_S};

void sensorsHandler(void * data) {
   uint32_t * request = (uint32_t *)data;
   static enum PwrState pwrState = PWR_IDLE_S;
   static enum AdcState adcState = ADC_IDLE_S;
   static uint8_t pwrReg = 0;
   static uint8_t adcChn = 0;
   uint32_t regIn, regIn1;
   uint8_t snapCmd;
   uint32_t convCmd;
   (*request) = 0; 
   
   if (Xil_In32(QUADMON_ENABLE) != 0) {
      
      /* ----------------------------------------------------------
       * ASIC Acq synchronous readout of LTC2945 power monitors
       * ---------------------------------------------------------*/
      
      // wait for measurement
      if (pwrState == PWR_WAIT_S) {
         // poll ADC busy flag
         // change state if ADC done
         regIn  = Xil_In32(MON_I2C_BUS_PWR1);
         regIn1 = Xil_In32(MON_I2C_BUS_PWR2);
         if( (regIn&0x8) == 0 && (regIn1&0x8) == 0 )
            pwrState = PWR_DONE_S;
      }
      
      // get results 
      if (pwrState == PWR_DONE_S) {
         
         // save results
         regIn = (Xil_In32(MON_I2C_BUS_PWR1+pwrRegAddr[pwrReg]*4) & 0xFF);
         regIn <<= 8;
         regIn |= (Xil_In32(MON_I2C_BUS_PWR1+pwrRegAddr[pwrReg]*4+4) & 0xFF);
         regIn >>= 4;
         Xil_Out32(QUADMON_SENSOR_REG+pwrReg*4, regIn);
         
         regIn = (Xil_In32(MON_I2C_BUS_PWR2+pwrRegAddr[pwrReg]*4) & 0xFF);
         regIn <<= 8;
         regIn |= (Xil_In32(MON_I2C_BUS_PWR2+pwrRegAddr[pwrReg]*4+4) & 0xFF);
         regIn >>= 4;
         Xil_Out32(QUADMON_SENSOR_REG+(pwrReg+3)*4, regIn);
         
         // switch to channel
         if (pwrReg < 2)
            pwrReg++;
         else
            pwrReg=0;
         
         // change state to IDLE
         pwrState = PWR_IDLE_S;
      }
      
      // send snapshot command
      if (pwrState == PWR_IDLE_S) {
         // send snapshot commands to two power monitors
         snapCmd = 0x85 | (pwrReg << 5);
         Xil_Out32(MON_I2C_BUS_PWR1, snapCmd);
         Xil_Out32(MON_I2C_BUS_PWR2, snapCmd);
         
         // change state
         pwrState = PWR_WAIT_S;
      }
      
      /* ----------------------------------------------------------
       * ASIC Acq synchronous readout of LTC2497 ADC (LDO temperatures)
       * ---------------------------------------------------------*/
      
      // wait for measurement
      if (adcState == ADC_WAIT_S) {
         // poll the FPGA fabric counter
         // change state if ADC done
         if( Xil_In32(QUADMON_SENSOR_CNT) == 0 )
            adcState = ADC_DONE_S;
      }
      
      // get results 
      if (adcState == ADC_DONE_S) {
         
         // save results
         regIn = (Xil_In32(MON_I2C_BUS_ADC) & 0xFFFF);
         Xil_Out32(QUADMON_SENSOR_REG+(adcChn+6)*4, regIn);
         
         // switch to channel
         if (adcChn < 15)
            adcChn++;
         else
            adcChn=0;
         
         // change state to IDLE
         adcState = ADC_IDLE_S;
      }
      
      // send channel conversion command
      if (adcState == ADC_IDLE_S) {
         // send snapshot commands to two power monitors
         convCmd = 0xB0 | (adcChn & 0xF);
         convCmd |= ((convCmd<<8) | (convCmd<<16) | (convCmd<<24));
         Xil_Out32(MON_I2C_BUS_ADC, convCmd);
         
         // start FPGA fabric timer (150 ms conversion cycle)
         Xil_Out32(QUADMON_SENSOR_CNT, 20000000);
         
         // change state
         adcState = ADC_WAIT_S;
      }
      
   }
   
   
   XIntc_Acknowledge(&intc, 2);
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

void adcStartup(int adc) {
   
   int j;
   uint32_t regIn = 0;
   
   // Apply pre-trained delays
   for (j=0; j<9; j++) {
      Xil_Out32(adcDelayAddr[adc][j], (512+adcDelays[adc][j]));
   }
   
   // Reset ADC
   Xil_Out32(adcPdwnModeAddr[adc], 0x3);
   waitTimer(TIMER_10MS_INTEVAL);
   Xil_Out32(adcPdwnModeAddr[adc], 0x0);
   
   // Reset FPGA deserializers
   Xil_Out32(SYSTEM_ADCCLKRST, 1<<adc);
   waitTimer(TIMER_10MS_INTEVAL);
   
   // Enable offset binary output
   regIn = Xil_In32(adcOutModeAddr[adc]);
   regIn &= ~(0x1);
   Xil_Out32(adcOutModeAddr[adc], regIn);
   
}

uint32_t adcTest(int adc) {
   int channel;
   uint32_t failed = 0;
   uint32_t failedCh = 0;
   uint32_t regIn = 0;
   
   // set up ADC tester
   Xil_Out32(ADC_TEST_MASK, 0x3FFF);
   Xil_Out32(ADC_TEST_PATT, 0x2867);
   Xil_Out32(ADC_TEST_SMPL, 10000);
   Xil_Out32(ADC_TEST_TOUT, 10000);
   
   // Enable mixed frequency test pattern
   regIn = Xil_In32(adcOutTestModeAddr[adc]);
   regIn |= 0x0C;
   Xil_Out32(adcOutTestModeAddr[adc], regIn);
   
   // test all channels
   failedCh = 0;
   for (channel=0; channel<8; channel++) {
      // request channel test
      Xil_Out32(ADC_TEST_CHAN, adc*8+channel);
      Xil_Out32(ADC_TEST_REQ, 0x1);
      Xil_Out32(ADC_TEST_REQ, 0x0);
      // wait completed
      while (Xil_In32(ADC_TEST_PASS) != 0x1 && Xil_In32(ADC_TEST_FAIL) != 0x1);
      // set flag
      if (Xil_In32(ADC_TEST_FAIL) == 0x1) {
         failed |= 1;
         failedCh |= (0x1<<channel);
      }
      
   }
   // set test status for channel
   Xil_Out32(SYSTEM_ADCCHANFAIL+adc*4, failedCh);
   
   // Disable mixed frequency test pattern
   regIn = Xil_In32(adcOutTestModeAddr[adc]);
   regIn &= ~(0x0F);
   Xil_Out32(adcOutTestModeAddr[adc], regIn);
   
   return failed;
   
}

void clearTestResult() {
   // clear test status flags
   Xil_Out32(SYSTEM_ADCTESTDONE, 0x0);
   Xil_Out32(SYSTEM_ADCTESTFAIL, 0x0);
}

void setTestResult(uint32_t failed) {
   // set test status flags
   if (failed != 0)
      Xil_Out32(SYSTEM_ADCTESTFAIL, 0x1);
   else
      Xil_Out32(SYSTEM_ADCTESTFAIL, 0x0);
   Xil_Out32(SYSTEM_ADCTESTDONE, 0x1);
   
}

void asicPwrOff() {
   // pre-configure (disable ASIC power)
   Xil_Out32(SYSTEM_ANAEN, 0x0);
   Xil_Out32(SYSTEM_DIGEN, 0x0);
}

void asicPwrOn() {
   // pre-configure (enable ASIC power)
   Xil_Out32(SYSTEM_DIGEN, 0x1);
   Xil_Out32(SYSTEM_ANAEN, 0x1);
}

void findAsics(void) {
   
   uint32_t i, dm, test, mask;
   mask = 0;
   
   //find installed ASICs by testing the digital monitor register
   for (i = 0; i <= 15; i++) {
      dm = Xil_In32( cfg4Asic[i]);
      Xil_Out32( cfg4Asic[i], 0x5A);
      test = Xil_In32( cfg4Asic[i]);
      if ((test&0xFF) == 0x5A) 
         mask |= (1<<i);
      Xil_Out32( cfg4Asic[i], dm);
   }
   mask |= 0xAAAA0000;
   Xil_Out32( SYSTEM_ASICMASK, mask);
   
}

void initAsics(void) {
   
   uint32_t mask, reg, i;
   
   mask = Xil_In32(SYSTEM_ASICMASK);
   
   for (i = 0; i <= 15; i++) {
      if (mask&(1<<i)) {
         //Disable digital monitors to let the carrier ID readout
         reg = Xil_In32( cfg6Asic[i]);
         reg &= ~(0x3);
         Xil_Out32( cfg6Asic[i], reg);
         //Enable SLVDS termination resistors and rset on Sync pin
         reg = Xil_In32( cfg10Asic[i]);
         reg |= 0x30;
         Xil_Out32( cfg10Asic[i], reg);
      }
   }
}

int main() { 
   
   volatile uint32_t adcStartupInt = 0;
   volatile uint32_t adcTestInt = 0;
   volatile uint32_t sensorsInt = 0;
   uint32_t failed = 0;
   uint32_t tryCnt = 0;
   int i;
   
   XTmrCtr_Initialize(&tmrctr,0);   
   
   XIntc_Initialize(&intc,XPAR_AXI_INTC_0_DEVICE_ID);
   microblaze_enable_interrupts();
   XIntc_Connect(&intc,0,(XInterruptHandler)adcStartupIntHandler,(void*)&adcStartupInt);
   XIntc_Connect(&intc,1,(XInterruptHandler)adcTestIntHandler,(void*)&adcTestInt);
   XIntc_Connect(&intc,2,(XInterruptHandler)sensorsHandler,(void*)&sensorsInt);
   XIntc_Connect(&intc,8,XTmrCtr_InterruptHandler,&tmrctr);
   XIntc_Start(&intc,XIN_REAL_MODE);
   XIntc_Enable(&intc,0);
   XIntc_Enable(&intc,1);
   XIntc_Enable(&intc,8);
   
   XTmrCtr_SetHandler(&tmrctr,timerIntHandler,(void*)&timer);
   XTmrCtr_SetOptions(&tmrctr,0,XTC_DOWN_COUNT_OPTION | XTC_INT_MODE_OPTION );
   
   // Enable DCDCs
   Xil_Out32(SYSTEM_DCDCEN, 0xf);
   
   // pre-configure (disable DDR memory power and clock)
   Xil_Out32(SYSTEM_VTTEN, 0x0);
   
   //enable ASIC power
   asicPwrOn();
   
   // wait for power to settle
   waitTimer(TIMER_500MS_INTEVAL);   
   
   // detect ASICs
   findAsics();
   
   // initialize ASIC core settings
   initAsics();
   
   // re-read carrier ID after ASIC's DMs are disabled
   Xil_Out32( SYSTEM_IDRST, 0x1);
   
   // do initial power on ADC startup
   clearTestResult();
   failed = 0;
   for (i=0; i<10; i++) {
      tryCnt = 0;
      do {
         // do the initial ADC startup
         adcStartup(i);
         // do the initial ADC test
         failed &= ~(1<<i);
         failed |= (adcTest(i))<<i;
         // retry N times
         tryCnt++;
      } while ((failed & (1<<i)) != 0 and tryCnt < ADC_STARTUP_RETRY);
   }
   setTestResult(failed);
   
   // enable sensors interrupt after initial startup
   XIntc_Enable(&intc,2);
   
   while (1) {
      
      // redo ADC startup when power is toggled or requested by user
      // poll ADC startup interrupt flag
      if (adcStartupInt) {
         // clear interrupt flag
         adcStartupInt = 0;
         // call ADC startup routine
         // retry N times
         clearTestResult();
         failed = 0;
         for (i=0; i<10; i++) {
            tryCnt = 0;
            do {
               // do the initial ADC startup
               adcStartup(i);
               // do the initial ADC test
               failed &= ~(1<<i);
               failed |= (adcTest(i))<<i;
               // retry N times
               tryCnt++;
            } while ((failed & (1<<i)) != 0 and tryCnt < ADC_STARTUP_RETRY);
         }
         setTestResult(failed);
      }
      
      // poll ADC test interrupt flag
      if (adcTestInt) {
         // clear interrupt flag
         adcTestInt = 0;
         // call ADC test routine
         clearTestResult();
         failed = 0;
         for (i=0; i<10; i++)
            failed |= adcTest(i);
         setTestResult(failed);
      }
      
   }
   
   
   return 0;
}

