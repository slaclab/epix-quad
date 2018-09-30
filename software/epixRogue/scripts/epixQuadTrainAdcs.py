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
from time import gmtime, strftime
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

parser.add_argument(
    "--ver", 
    type     = argBool,
    required = False,
    default  = False,
    help     = "Verbose output",
)  

parser.add_argument(
    "--diff", 
    type     = argBool,
    required = False,
    default  = True,
    help     = "Report difference to last training",
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


QuadTop.SystemRegs.enable.set(True)
QuadTop.Ad9249Tester.enable.set(True)
for adc in range(10):
   QuadTop.Ad9249Readout[adc].enable.set(True)
   QuadTop.Ad9249Config[adc].enable.set(True)


fileName = strftime("%Y%m%d%H%M%S", time.gmtime()) + '_adcDelays.h'
f = open(fileName, 'w')

f.write('static int adcDelays[10][9] = {\n')

print('Initializing ADCs ...')

print('Enable DCDCs')
QuadTop.SystemRegs.DcDcEnable.set(0xF)
time.sleep(1.0)


print('Assert digital reset')
# Reset ADCs
for adc in range(10):
   QuadTop.Ad9249Config[adc].InternalPdwnMode.set(3)
   time.sleep(0.01)
   QuadTop.Ad9249Config[adc].InternalPdwnMode.set(0)
time.sleep(1.0)


print('Reset ISERDESE3')
# Reset deserializers
QuadTop.SystemRegs.AdcClkRst.set(True)
QuadTop.SystemRegs.AdcClkRst.set(False)
time.sleep(1.0)


print('Initialization done')

if args.diff:
   
   print('Enable DCDCs')
   QuadTop.SystemRegs.DcDcEnable.set(0x0)
   print('Disable DCDCs')
   QuadTop.SystemRegs.DcDcEnable.set(0xF)
   time.sleep(1.0)
   
   print('Reset microblaze startup for diff')
   # Reset deserializers
   QuadTop.SystemRegs.AdcReqStart.set(True)
   QuadTop.SystemRegs.AdcReqStart.set(False)
   time.sleep(15.0)
   print('startup done')


prevDly = 0

# Train frame delay in all ADCs
for adc in range(10):
   
   f.write('    {')
   
   lockData = pd.DataFrame(columns=['Start', 'Count'])
   lockStart = 0
   lockCounter = 0
   lockIndex = 0
   locked = 0
   test = [0] * 512
   frameDlySet = -1
   if args.diff:
      prevDly = QuadTop.Ad9249Readout[adc].FrameDelay.get()
   for delay in range(512):
      # Set frame delay
      QuadTop.Ad9249Readout[adc].FrameDelay.set(0x200+delay)
      # Reset lost lock counter
      QuadTop.Ad9249Readout[adc].LostLockCountReset()
      # Wait 1 ms
      time.sleep(0.001)
      # Check lock status
      lostLockCountReg = QuadTop.Ad9249Readout[adc].LostLockCount.get()
      lockedReg = QuadTop.Ad9249Readout[adc].Locked.get()
      
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
      
      if (lostLockCountReg == 0) and (lockedReg == 1):
         test[delay] = 1
   
   if args.ver:
      print(lockData)
      print(test)
   
   if len(lockData) > 0:
      maxCount = lockData['Count'].max()
      maxIndex = lockData['Count'].idxmax()
      frameDlySet = lockData.loc[maxIndex]['Start'] + round(maxCount/2)
      QuadTop.Ad9249Readout[adc].FrameDelay.set(0x200+frameDlySet)
      
      if args.diff:
         print('ADC[%d] frame delay set to %d (diff %d)'%(adc, frameDlySet, frameDlySet-prevDly))
      else:
         print('ADC[%d] frame delay set to %d'%(adc, frameDlySet))
   else:
      print('ADC[%d] frame delay failed %x'%(adc,  QuadTop.Ad9249Readout[adc].AdcFrame.get()))
      
   f.write('%d, ' %(frameDlySet))
   
   channel = 0
   
   # enable mixed bit frequency pattern
   QuadTop.Ad9249Config[adc].OutputTestMode.set(12)
   # set the pattern tester
   QuadTop.Ad9249Tester.TestDataMask.set(0x3FFF)
   QuadTop.Ad9249Tester.TestPattern.set(0x2867)
   QuadTop.Ad9249Tester.TestSamples.set(10000)
   QuadTop.Ad9249Tester.TestTimeout.set(10000)
   for channel in range(8):
      passData = pd.DataFrame(columns=['Start', 'Count'])
      passStart = 0
      passCounter = 0
      passIndex = 0
      passed = 0
      test = [0] * 512
      chanDlySet = -1
      if args.diff:
         prevDly = QuadTop.Ad9249Readout[adc].ChannelDelay[channel].get()
      for delay in range(512):
         # Set channel delay
         QuadTop.Ad9249Readout[adc].ChannelDelay[channel].set(0x200+delay)
         # sSet tester channel and start testing
         QuadTop.Ad9249Tester.TestChannel.set(adc*8+channel)
         QuadTop.Ad9249Tester.TestRequest.set(True)
         QuadTop.Ad9249Tester.TestRequest.set(False)
         # Check result
         while (QuadTop.Ad9249Tester.TestPassed.get() != True) and (QuadTop.Ad9249Tester.TestFailed.get() != True):
            pass
         testPassed = QuadTop.Ad9249Tester.TestPassed.get()
         if testPassed == True:
            test[delay] = 1
         
         # Find and save pass intervals (start index and length count)
         if (testPassed == True) and (passed == 0):
            passed = 1
            passStart = delay
            
         if ((testPassed == False) or (delay == 511)) and (passed == 1):
            passed = 0
            passData.loc[passIndex] = [passStart, passCounter]
            passCounter = 0
            passIndex = passIndex + 1
         
         if passed == 1:
            passCounter = passCounter + 1
      
      if args.ver:
         print(passData)
         print(test)
      if len(passData) > 0:
         maxCount = passData['Count'].max()
         maxIndex = passData['Count'].idxmax()
         chanDlySet = passData.loc[maxIndex]['Start'] + round(maxCount/2)
         QuadTop.Ad9249Readout[adc].ChannelDelay[channel].set(0x200+chanDlySet)
         if args.diff:
            print('ADC[%d] Ch[%d] delay set to %d (diff %d)'%(adc, channel, chanDlySet, chanDlySet-prevDly))
         else:
            print('ADC[%d] Ch[%d] delay set to %d'%(adc, channel, chanDlySet))
      else:
         print('ADC[%d] Ch[%d] failed %x'%(adc, channel,  QuadTop.Ad9249Readout[adc].AdcChannel[channel].get()))
      
      if channel == 7 and adc == 9:
         f.write('%d}\n' %(chanDlySet))
      elif channel == 7:
         f.write('%d},\n' %(chanDlySet))
      else:
         f.write('%d, ' %(chanDlySet))

f.write('};')
f.write('\n')
f.close()
   
#QuadTop.SystemRegs.DcDcEnable.set(0x0)


QuadTop.stop()
exit()