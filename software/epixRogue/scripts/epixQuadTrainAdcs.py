#!/usr/bin/env python3
##############################################################################
## This file is part of 'EPIX'.
## It is subject to the license terms in the LICENSE.txt file found in the 
## top-level directory of this distribution and at: 
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
## No part of 'EPIX', including this file, 
## may be copied, modified, propagated, or distributed except according to 
## the terms contained in the LICENSE.txt file.
##############################################################################

import sys
import pyrogue as pr
import pyrogue.gui
import rogue
import argparse
import ePixQuad as quad
import time
import pandas as pd

# rogue.Logging.setLevel(rogue.Logging.Warning)
# rogue.Logging.setFilter("pyrogue.SrpV3",rogue.Logging.Debug)
# rogue.Logging.setLevel(rogue.Logging.Debug)

#################################################################

# Set the argument parser
parser = argparse.ArgumentParser()

# Convert str to bool
argBool = lambda s: s.lower() in ['true', 't', 'yes', '1']

# Add arguments
parser.add_argument(
    "--pollEn", 
    type     = argBool,
    required = False,
    default  = False,
    help     = "Enable auto-polling",
) 

parser.add_argument(
    "--initRead", 
    type     = argBool,
    required = False,
    default  = False,
    help     = "Enable read all variables at start",
)  

# Get the arguments
args = parser.parse_args()

#################################################################

# Set base
QuadTop = quad.Top(hwType='pgp2b')    

# Start the system
QuadTop.start(
    pollEn   = args.pollEn,
    initRead = args.initRead,
    timeout  = 5.0,    
)

#fileName = 'ADC_Frame_Delays_DeviceDna' + hex(QuadTop.AxiVersion.DeviceDna.get()) + '.csv'
#f = open(fileName, 'a')

QuadTop.SystemRegs.DcDcEnable.set(0xF)
time.sleep(1.0)

# Train frame delay in all ADCs
for i in range(10):
   lockData = pd.DataFrame(columns=['Start', 'Count'])
   lockStart = 0
   lockCounter = 0
   lockIndex = 0
   locked = 0
   #test = [0] * 512
   for delay in range(512):
      # Set frame delay
      QuadTop.Ad9249Readout[i].FrameDelay.set(0x200+delay)
      # Reset lost lock counter
      QuadTop.Ad9249Readout[i].LostLockCountReset()
      # Wait 1 ms
      time.sleep(0.001)
      # Check lock status
      lostLockCountReg = QuadTop.Ad9249Readout[i].LostLockCount.get()
      lockedReg = QuadTop.Ad9249Readout[i].Locked.get()
      
      # Find and save lock intervals (start index and length count)
      if (lostLockCountReg == 0) and (lockedReg == 1) and (locked == 0):
         locked = 1
         lockStart = delay
         
      if ((lostLockCountReg != 0) or (lockedReg == 0) or (delay == 511)) and (locked == 1):
         locked = 0
         lockData.loc[lockIndex] = [lockStart, lockCounter]
         lockCounter = 0
         lockIndex = lockIndex + 1
      
      if locked == 1:
         lockCounter = lockCounter + 1
      
      #if (lostLockCountReg == 0) and (lockedReg == 1):
      #   test[delay] = 1
   
   print(lockData)
   #print(test)
   
   maxCount = lockData['Count'].max()
   maxIndex = lockData['Count'].idxmax()
   frameDlySet = lockData.loc[maxIndex]['Start'] + round(maxCount/2)
   print('set %d'%(frameDlySet))
   

#f.write('\n')
#f.close()
   
QuadTop.SystemRegs.DcDcEnable.set(0x0)


##enable all needed devices
#LztsBoard.Lzts.PwrReg.enable.set(True)
#LztsBoard.Lzts.SadcPatternTester.enable.set(True)
#for i in range(4):
#    LztsBoard.Lzts.SlowAdcConfig[i].enable.set(True)
#    LztsBoard.Lzts.SlowAdcReadout[i].enable.set(True)
#for i in range(8):
#    LztsBoard.Lzts.SadcBufferWriter[i].enable.set(True)
#
## find all delay lane registers
#delayRegs = LztsBoard.Lzts.find(name="DelayAdc*")
#dmodeRegs = LztsBoard.Lzts.find(name="DMode*")
#invertRegs = LztsBoard.Lzts.find(name="Invert*")
#convertRegs = LztsBoard.Lzts.find(name="Convert*")
## find all ADC settings registers
#adcRegs8 = LztsBoard.Lzts.find(name="AdcReg_0x0008")
#adcRegsF = LztsBoard.Lzts.find(name="AdcReg_0x000F")
#adcRegs10 = LztsBoard.Lzts.find(name="AdcReg_0x0010")
#adcRegs11 = LztsBoard.Lzts.find(name="AdcReg_0x0011")
#adcRegs15 = LztsBoard.Lzts.find(name="AdcReg_0x0015")
#
##initial configuration for the slow ADC
#LztsBoard.Lzts.PwrReg.EnDcDcAp3V7.set(True)
#LztsBoard.Lzts.PwrReg.EnDcDcAp2V3.set(True)
#LztsBoard.Lzts.PwrReg.EnLdoSlow.set(True)
#LztsBoard.Lzts.PwrReg.SADCCtrl1.set(0)
#LztsBoard.Lzts.PwrReg.SADCCtrl2.set(0)
#LztsBoard.Lzts.PwrReg.SADCRst.set(0xf)
#time.sleep(1.0)
#LztsBoard.Lzts.PwrReg.SADCRst.set(0x0)
#time.sleep(1.0)
#for reg in dmodeRegs:
#   reg.set(0x3)      # deserializer dmode 0x3
#for reg in invertRegs:
#   reg.set(0x0)      # do not invert data for pattern testing
#for reg in convertRegs:
#   reg.set(0x0)      # do not convert data for pattern testing
##for reg in adcRegs8:
##   reg.set(0x10)     # ADC binary data format
#for reg in adcRegsF:
#   reg.set(0x66)     # ADC single pattern
#for reg in adcRegs15:
#   reg.set(0x1)      # ADC DDR mode
#
#LztsBoard.Lzts.SadcPatternTester.Samples.set(0xffff)
#LztsBoard.Lzts.SadcPatternTester.Mask.set(0xffff)
#
#delays = [0 for x in range(512)]
#
#fileName = 'SADC_Delays_DeviceDna' + hex(LztsBoard.Lzts.AxiVersion.DeviceDna.get()) + '.csv'
#f = open(fileName, 'a')
#
##iterate all ADCs
#for adcNo in range(0, 8):
#   # iterate all lanes on 1 ADC channel
#   for lane in range(0, 8):
#      print("ADC %d Lane %d" %(adcNo, lane))
#      # iterate all delays
#      for delay in range(0, 512):
#         # set tester channel
#         LztsBoard.Lzts.SadcPatternTester.Channel.set(adcNo)
#         # set delay
#         delayRegs[lane+adcNo*8].set(delay)
#         
#         pattern = 2**(lane*2)
#         
#         # set pattern output in ADC
#         adcRegs10[int(adcNo/2)].set((pattern&0xFF00)>>8)
#         adcRegs11[int(adcNo/2)].set(pattern&0xFF)
#         # set tester pattern
#         LztsBoard.Lzts.SadcPatternTester.Pattern.set(pattern)
#         # toggle request bit
#         LztsBoard.Lzts.SadcPatternTester.Request.set(False)
#         LztsBoard.Lzts.SadcPatternTester.Request.set(True)
#         # wait until test done
#         while LztsBoard.Lzts.SadcPatternTester.Done.get() != 1:
#            pass
#         passed = not LztsBoard.Lzts.SadcPatternTester.Failed.get()
#         
#         #print(int(passed), end='', flush=True)
#         
#         # shift pattern for next bit test (2 bits per lane)
#         pattern = pattern << 1;
#         
#         # set pattern output in ADC
#         adcRegs10[int(adcNo/2)].set((pattern&0xFF00)>>8)
#         adcRegs11[int(adcNo/2)].set(pattern&0xFF)
#         # set tester pattern
#         LztsBoard.Lzts.SadcPatternTester.Pattern.set(pattern)
#         # toggle request bit
#         LztsBoard.Lzts.SadcPatternTester.Request.set(False)
#         LztsBoard.Lzts.SadcPatternTester.Request.set(True)
#         # wait until test done
#         while LztsBoard.Lzts.SadcPatternTester.Done.get() != 1:
#            pass
#         passed = passed and not LztsBoard.Lzts.SadcPatternTester.Failed.get()
#         #passed = not LztsBoard.Lzts.SadcPatternTester.Failed.get()
#         
#         #print(int(passed), end='', flush=True)
#         
#         delays[delay] = int(passed)
#
#      #print('\n')
#      
#      # find best delay setting
#      lengths = []
#      starts = []
#      stops = []
#      length = 0
#      start = -1
#      started = 0
#      setDelay = 0
#      for i in range(5, 512):
#         # find a vector of ones minimum width 5
#         if delays[i] == 1 and delays[i-1] == 1 and delays[i-2] == 1 and delays[i-3] == 1 and delays[i-4] == 1 and delays[i-5] == 1:
#            started = 1
#            length+=1
#            if start < 0:
#               start = i - 5
#         elif delays[i] == 0 and delays[i-1] == 1 and delays[i-2] == 1 and delays[i-3] == 1 and delays[i-4] == 1 and delays[i-5] == 1:
#            lengths.append(length+5)
#            starts.append(start)
#            stops.append(i-1)
#            length = 0
#            start = -1
#            started = 0
#         elif started == 1 and i == 511:
#            lengths.append(length+5)
#            starts.append(start)
#            stops.append(i-1)
#      
#      # find the longest vector of ones
#      if len(lengths) > 0:
#         index, value = max(enumerate(lengths), key=operator.itemgetter(1))
#         setDelay = int(starts[index]+(stops[index]-starts[index])/2)
#      else:
#         print('ADC %d, Lane %d FAILED!' %(adcNo, lane))
#         setDelay = 0
#      
#      print('Delay %d' %(setDelay))
#      f.write('%d,' %(setDelay))
#      
#      # set best delay
#      delayRegs[lane+adcNo*8].set(setDelay)
#
##close the file
#f.write('\n')
#f.close()
#
#

QuadTop.stop()
exit()