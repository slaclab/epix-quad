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

#define TIMER_3MS_INTEVAL   300000
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

uint8_t ltc2945ReadByte(uint8_t i2cAddr, uint8_t regAddr) {
   Xil_Out32(MON_I2C_I2CADDR, i2cAddr);
   Xil_Out32(MON_I2C_ENDIANNESS, 0x0);
   Xil_Out32(MON_I2C_REPSTART, 0x1);
   Xil_Out32(MON_I2C_REGADDR, regAddr);   // reg addr
   Xil_Out32(MON_I2C_REGADDRSIZE, 0x0);   // 1 byte address
   Xil_Out32(MON_I2C_REGADDRSKIP, 0x0);   // do not skip address
   Xil_Out32(MON_I2C_REGDATASIZE, 0x0);   // 1 byte to read
   Xil_Out32(MON_I2C_REGOP, 0x0);         // 0 - read op
   Xil_Out32(MON_I2C_REGREQ, 0x1);        // 1 - request
   // poll request
   while(Xil_In32(MON_I2C_REGREQ) == 0x1);
   return Xil_In32(MON_I2C_REGRDDATA);
}

uint8_t ltc2945WriteByte(uint8_t i2cAddr, uint8_t regAddr, uint8_t regData) {
   Xil_Out32(MON_I2C_I2CADDR, i2cAddr);
   Xil_Out32(MON_I2C_ENDIANNESS, 0x0);
   Xil_Out32(MON_I2C_REPSTART, 0x1);
   Xil_Out32(MON_I2C_REGADDR, regAddr);   // reg addr
   Xil_Out32(MON_I2C_REGADDRSIZE, 0x0);   // 1 byte address
   Xil_Out32(MON_I2C_REGADDRSKIP, 0x0);   // do not skip address
   Xil_Out32(MON_I2C_REGDATASIZE, 0x0);   // 1 byte to write
   Xil_Out32(MON_I2C_REGWRDATA, regData); // byte to write
   Xil_Out32(MON_I2C_REGOP, 0x1);         // 1 - write op
   Xil_Out32(MON_I2C_REGREQ, 0x1);        // 1 - request
   // poll request
   while(Xil_In32(MON_I2C_REGREQ) == 0x1);
   return Xil_In32(MON_I2C_REGFAIL);
}

uint8_t ltc2497ReadAdcChannel(uint8_t i2cAddr, uint32_t * adcData) {
   Xil_Out32(MON_I2C_I2CADDR, i2cAddr);
   Xil_Out32(MON_I2C_ENDIANNESS, 0x1);
   Xil_Out32(MON_I2C_REPSTART, 0x0);
   Xil_Out32(MON_I2C_REGADDR, 0x0);       // reg addr
   Xil_Out32(MON_I2C_REGADDRSIZE, 0x0);   // 1 byte address
   Xil_Out32(MON_I2C_REGADDRSKIP, 0x1);   // skip address
   Xil_Out32(MON_I2C_REGDATASIZE, 0x2);   // 3 bytes to read
   Xil_Out32(MON_I2C_REGOP, 0x0);         // 0 - read op
   Xil_Out32(MON_I2C_REGREQ, 0x1);        // 1 - request
   // poll request
   while(Xil_In32(MON_I2C_REGREQ) == 0x1);
   *adcData = Xil_In32(MON_I2C_REGRDDATA) & 0xFFFFFF;
   return Xil_In32(MON_I2C_REGFAIL);
}

void ltc2497TrigAdcChannel(uint8_t i2cAddr, uint16_t adcChannel) {
   Xil_Out32(MON_I2C_I2CADDR, i2cAddr);
   Xil_Out32(MON_I2C_ENDIANNESS, 0x1);
   Xil_Out32(MON_I2C_REPSTART, 0x0);
   Xil_Out32(MON_I2C_REGADDR, 0x0);       // reg addr
   Xil_Out32(MON_I2C_REGADDRSIZE, 0x0);   // 1 byte address
   Xil_Out32(MON_I2C_REGADDRSKIP, 0x1);   // skip address
   Xil_Out32(MON_I2C_REGDATASIZE, 0x1);   // 2 bytes to write
   Xil_Out32(MON_I2C_REGWRDATA, adcChannel); // bytes to write
   Xil_Out32(MON_I2C_REGOP, 0x1);         // 1 - write op
   Xil_Out32(MON_I2C_REGREQ, 0x1);        // 1 - request
   // poll request
   while(Xil_In32(MON_I2C_REGREQ) == 0x1);
}

uint8_t finisarReadWord(uint8_t i2cAddr, uint8_t regAddr, uint16_t * regData) {
   Xil_Out32(MON_I2C_I2CADDR, i2cAddr);
   Xil_Out32(MON_I2C_ENDIANNESS, 0x1);
   Xil_Out32(MON_I2C_REPSTART, 0x0);
   Xil_Out32(MON_I2C_REGADDR, regAddr);    // reg addr
   Xil_Out32(MON_I2C_REGADDRSIZE, 0x0);   // 1 byte address
   Xil_Out32(MON_I2C_REGADDRSKIP, 0x0);   // do not skip address
   Xil_Out32(MON_I2C_REGDATASIZE, 0x1);   // 2 bytes to read
   Xil_Out32(MON_I2C_REGOP, 0x0);         // 0 - read op
   Xil_Out32(MON_I2C_REGREQ, 0x1);        // 1 - request
   // poll request
   while(Xil_In32(MON_I2C_REGREQ) == 0x1);
   *regData = Xil_In32(MON_I2C_REGRDDATA) & 0xFFFF;
   return Xil_In32(MON_I2C_REGFAIL);
}

void sensorsHandler(void * data) {
   uint32_t * request = (uint32_t *)data;
   static enum PwrState pwrState = PWR_IDLE_S;
   static enum AdcState adcState = ADC_IDLE_S;
   static uint8_t pwrReg = 0;
   static uint8_t adcChn = 0;
   uint32_t regIn, regIn1;
   uint16_t regIn2;
   uint8_t snapCmd;
   uint16_t convCmd;
   (*request) = 0; 
   
   if (Xil_In32(QUADMON_ENABLE) != 0) {
      
      /* ----------------------------------------------------------
       * ASIC Acq synchronous readout of LTC2945 power monitors
       * ---------------------------------------------------------*/
      
      // wait for measurement
      if (pwrState == PWR_WAIT_S) {
         // poll ADC busy flag
         // change state if ADC done
         regIn = ltc2945ReadByte(I2CADDR_LTC2945_DIG, 0x0);    // 0x0 is control reg
         regIn1 = ltc2945ReadByte(I2CADDR_LTC2945_ANA, 0x0);   // 0x0 is control reg
         if( (regIn&0x8) == 0 && (regIn1&0x8) == 0 )
            pwrState = PWR_DONE_S;
      }
      
      // get results 
      if (pwrState == PWR_DONE_S) {
         
         // save results
         regIn = ltc2945ReadByte(I2CADDR_LTC2945_DIG, pwrRegAddr[pwrReg]);
         regIn <<= 8;
         regIn |= ltc2945ReadByte(I2CADDR_LTC2945_DIG, pwrRegAddr[pwrReg]+1);
         regIn >>= 4;
         Xil_Out32(QUADMON_SENSOR_REG+pwrReg*4, regIn);
         
         regIn = ltc2945ReadByte(I2CADDR_LTC2945_ANA, pwrRegAddr[pwrReg]);
         regIn <<= 8;
         regIn |= ltc2945ReadByte(I2CADDR_LTC2945_ANA, pwrRegAddr[pwrReg]+1);
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
         ltc2945WriteByte(I2CADDR_LTC2945_DIG, 0x0, snapCmd);
         ltc2945WriteByte(I2CADDR_LTC2945_ANA, 0x0, snapCmd);
         
         // change state
         pwrState = PWR_WAIT_S;
      }
      
      /* ----------------------------------------------------------
       * ASIC Acq synchronous readout of LTC2497 ADC (LDO temperatures)
       * ---------------------------------------------------------*/
      
      // wait for measurement
      if (adcState == ADC_WAIT1_S) {
         // poll the FPGA fabric counter
         // change state if ADC done
         regIn = Xil_In32(QUADMON_SENSOR_CNT);
         if( regIn == 0 )
            adcState = ADC_READ_S;
      }
      
      // get results 
      if (adcState == ADC_READ_S) {
         
         // save results
         if(ltc2497ReadAdcChannel(I2CADDR_LTC2497, &regIn) == 0) {
            Xil_Out32(QUADMON_SENSOR_REG+(adcChn+6)*4, (regIn>>6));
            
            // switch to channel
            if (adcChn < 15)
               adcChn++;
            else
               adcChn=0;
            
            // start FPGA fabric timer (150 ms conversion cycle)
            Xil_Out32(QUADMON_SENSOR_CNT, 15000000);
            
            // change state to ADC_WAIT2_S
            adcState = ADC_WAIT2_S;
            
         }
         
      }
      
      // wait for measurement
      if (adcState == ADC_WAIT2_S) {
         // poll the FPGA fabric counter
         // change state if ADC done
         regIn = Xil_In32(QUADMON_SENSOR_CNT);
         if( regIn == 0 )
            adcState = ADC_IDLE_S;
      }
      
      // send channel conversion command
      if (adcState == ADC_IDLE_S) {
         // trigger ADC channel conversion
         convCmd = 0xB0 | (adcChMap[adcChn] & 0xF);
         convCmd <<= 8;
         //convCmd |= (convCmd<<8);
         ltc2497TrigAdcChannel(I2CADDR_LTC2497, convCmd);
         
         // start FPGA fabric timer (150 ms conversion cycle)
         Xil_Out32(QUADMON_SENSOR_CNT, 15000000);
         
         // change state
         adcState = ADC_WAIT1_S;
      }
      
      /* ----------------------------------------------------------
       * Read Finisar Optical Transceiver Diagnostics
       * ---------------------------------------------------------*/
      if(finisarReadWord(I2CADDR_FINISAR, 96, &regIn2) == 0)   // temperature
         Xil_Out32(QUADMON_SENSOR_REG+22*4, regIn2);
      if(finisarReadWord(I2CADDR_FINISAR, 98, &regIn2) == 0)   // voltage
         Xil_Out32(QUADMON_SENSOR_REG+23*4, regIn2);
      if(finisarReadWord(I2CADDR_FINISAR, 102, &regIn2) == 0)  // TX power
         Xil_Out32(QUADMON_SENSOR_REG+24*4, regIn2);
      if(finisarReadWord(I2CADDR_FINISAR, 104, &regIn2) == 0)  // RX power
         Xil_Out32(QUADMON_SENSOR_REG+25*4, regIn2);
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

void adcInit(int adc) {
   
   int j;
   
   // Apply pre-trained delays
   for (j=0; j<9; j++) {
      Xil_Out32(adcDelayAddr[adc][j], (512+adcDelays[adc][j]));
   }
   
}

void adcReset(int adc) {
   
   uint32_t regIn = 0;
   
   // Reset FPGA deserializers
   Xil_Out32(SYSTEM_ADCCLKRST, 1<<adc);
   waitTimer(TIMER_10MS_INTEVAL);
   Xil_Out32(SYSTEM_ADCCLKRST, 0);
   waitTimer(TIMER_10MS_INTEVAL);
   
   // Reset ADC
   regIn = Xil_In32(adcPdwnModeAddr[adc]);
   regIn |= 0x3;
   Xil_Out32(adcPdwnModeAddr[adc], regIn);
   waitTimer(TIMER_10MS_INTEVAL);
   
   regIn = Xil_In32(adcPdwnModeAddr[adc]);
   regIn &= ~(0x03);
   Xil_Out32(adcPdwnModeAddr[adc], regIn);
   waitTimer(TIMER_10MS_INTEVAL);
   
   // Enable offset binary output
   regIn = Xil_In32(adcOutModeAddr[adc]);
   regIn &= ~(0x1);
   Xil_Out32(adcOutModeAddr[adc], regIn);
   waitTimer(TIMER_10MS_INTEVAL);
   
}

uint32_t adcTest(int adc, int pattern) {
   int channel;
   uint32_t failedCh = 0;
   uint32_t regIn = 0;
   
   // set up ADC tester
   Xil_Out32(ADC_TEST_MASK, 0x3FFF);
   if (pattern==0)
      Xil_Out32(ADC_TEST_PATT, 0x2867);
   else
      Xil_Out32(ADC_TEST_PATT, 0x2000);
   Xil_Out32(ADC_TEST_SMPL, 10000);
   Xil_Out32(ADC_TEST_TOUT, 10000);
   
   // Enable mixed frequency test pattern
   regIn = Xil_In32(adcOutTestModeAddr[adc]);
   if (pattern==0)
      regIn |= 0x0C;
   else
      regIn |= 0x01;
   Xil_Out32(adcOutTestModeAddr[adc], regIn);
   
   // test all channels
   failedCh = 0;
   for (channel=0; channel<8; channel++) {
      // request channel test
      Xil_Out32(ADC_TEST_CHAN, adc*8+channel);
      Xil_Out32(ADC_TEST_REQ, 0x1);
      Xil_Out32(ADC_TEST_REQ, 0x0);
      // wait completed
      while (Xil_In32(ADC_TEST_PASS) != 0x1 && Xil_In32(ADC_TEST_FAIL) != 0x1) {
         waitTimer(TIMER_3MS_INTEVAL);
      };
      // set flag
      if (Xil_In32(ADC_TEST_FAIL) == 0x1) {
         failedCh |= (0x1<<channel);
      }
      
   }
   
   // Disable mixed frequency test pattern
   regIn = Xil_In32(adcOutTestModeAddr[adc]);
   regIn &= ~(0x0F);
   Xil_Out32(adcOutTestModeAddr[adc], regIn);
   
   return failedCh;
   
}

void adcStartup(int skipReset) {
   
   uint32_t passed = 0;
   uint32_t failed = 0;
   uint32_t tryCnt = 0;
   int i;
   
   // clear test status flags
   Xil_Out32(SYSTEM_ADCTESTDONE, 0x0);
   Xil_Out32(SYSTEM_ADCTESTFAIL, 0x0);
   
   // load trained delays
   if (skipReset == 0)
      for (i=0; i<10; i++)
         adcInit(i);
   
   // test and reset ADCs as needed
   passed = 0;
   for (i=0; i<10; i++) {
      tryCnt = 0;
      do {
         failed = 0;
         failed |= adcTest(i,0);
         failed |= adcTest(i,1);
         // set test status for channel
         Xil_Out32(SYSTEM_ADCCHANFAIL+i*4, failed);
         tryCnt++;
         if (failed == 0) {
            passed |= (1<<i);
            break;
         }
         else if (skipReset == 1) {
            break;
         }
         else {
            // load trained delays one every 10 resets
            // this is for wrong power sequence (DVDD first)
            if ((tryCnt%10) == 0)
               adcInit(i);
            // reset ADCs
            adcReset(i);
         }
      } while (tryCnt < ADC_STARTUP_RETRY);
   }
   
   // set result flags
   if (passed == 0x3FF)
      Xil_Out32(SYSTEM_ADCTESTFAIL, 0x0);
   else
      Xil_Out32(SYSTEM_ADCTESTFAIL, 0x1);
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
   
   // preset ADC and ASIC clock frequencies
   // this should always be changed together
   Xil_Out32(RDOUT_ADC_PIPELINE, 0xAAAA005A);
   Xil_Out32(ACQ_ASIC_ROCLK_H,   0xAAAA0005);
   
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
   for (i = 0; i < 10; i++)
      adcReset(i);
   adcStartup(0);
   
   // enable sensors interrupt after initial startup
   XIntc_Enable(&intc,2);
   
   while (1) {
      
      // redo ADC startup when power is toggled or requested by user
      // poll ADC startup interrupt flag
      if (adcStartupInt) {
         // clear interrupt flag
         adcStartupInt = 0;
         // call ADC startup routine
         adcStartup(0);
      }
      
      // poll ADC test interrupt flag
      if (adcTestInt) {
         // clear interrupt flag
         adcTestInt = 0;
         // call ADC test routine
         adcStartup(1);
      }
      
   }
   
   
   return 0;
}

