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

class EventReader(rogue.interfaces.stream.Slave):
   """retrieves data from a file using rogue utilities services"""
   
   def __init__(self, parent) :
      rogue.interfaces.stream.Slave.__init__(self)
      super(EventReader, self).__init__()
      self.enable = True
      self.lastFrame = rogue.interfaces.stream.Frame
      
      self._superRowSize = int(768/2)
      self._NumColPerAdcCh = int(96/2)
      self._superRowSizeInBytes = self._superRowSize * 4
      self.sensorHeight = 712
      
      #self.average = 10
      self.reqFrames = 0
      self.accFrames = 0
      self.pixelSum = 0
      self.pixelAvg = 0
   
   
   def _acceptFrame(self,frame):
   
      
      self.lastFrame = frame
      # reads entire frame
      p = bytearray(self.lastFrame.getPayload())
      self.lastFrame.read(p,0)
   
      VcNum =  p[0] & 0xF
      
      headerBytes = 8 * 4
      pixelOffset = headerBytes + self._superRowSizeInBytes * 3 * 4 + int(self._superRowSizeInBytes/2)
      
      #print(pixelOffset)
   
      if (VcNum == 0 and self.accFrames < self.reqFrames):
         self.pixelSum = self.pixelSum + (((p[pixelOffset+7] << 8) | p[pixelOffset+6]) & 0x3FFF)
         self.accFrames = self.accFrames + 1
         if (PRINT_VERBOSE): 
            for i in range(10):
               print('%d'%( ((p[pixelOffset+i*2+1] << 8) | p[pixelOffset+i*2]) & 0x3FFF ))
      


PRINT_VERBOSE = 0


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
QuadTop = quad.Top(hwType='pgp3_cardG3')    
eventReader = EventReader(QuadTop)
pyrogue.streamTap(QuadTop.pgpVc0, eventReader) 

# Start the system
QuadTop.start(
    pollEn   = args.pollEn,
    initRead = args.initRead,
    timeout  = 5.0,    
)

# enable neeeded devices
QuadTop.SystemRegs.enable.set(True)
QuadTop.RdoutCore.enable.set(True)
QuadTop.AcqCore.enable.set(True)
QuadTop.Epix10kaSaci[13].enable.set(True)

# check ADC startup
if (QuadTop.SystemRegs.AdcTestFailed.get() == True):
   print('ADC Startup failed!')
   QuadTop.stop()
   exit()

# stop if running
QuadTop.SystemRegs.TrigEn.set(False)

# set one pixel in High Gain and Test mode
QuadTop.Epix10kaSaci[13].ClearMatrix()
QuadTop.Epix10kaSaci[13].RowCounter(3)
QuadTop.Epix10kaSaci[13].ColCounter(3)
QuadTop.Epix10kaSaci[13].WritePixelData(0xD)

# pulse one pixel
QuadTop.Epix10kaSaci[13].Pulser.set(0x3FF)
QuadTop.Epix10kaSaci[13].test.set(True)

# set autotrigger
QuadTop.SystemRegs.TrigEn.set(True)
QuadTop.SystemRegs.AutoTrigEn.set(False)  # stop and reset auto trigger counter 
QuadTop.SystemRegs.AutoTrigPer.set(2000000) # 20ms = 50Hz
QuadTop.SystemRegs.TrigSrcSel.set(0x3)

# request 10 frames for average
eventReader.reqFrames = 10

adcPipDly = QuadTop.RdoutCore.AdcPipelineDelay.get()

print('AsicRoClkHalfT is set to %d. AdcPipelineDelay should be re-adjusted for different AsicRoClkHalfT settings'%(QuadTop.AcqCore.AsicRoClkHalfT.get()))
print('AdcPipelineDelay, PixelAvg')
# look for pulsed pixel (maximum)
for i in range(256):
   QuadTop.RdoutCore.AdcPipelineDelay.set(0xAAAA0000 | i)
   QuadTop.SystemRegs.AutoTrigEn.set(True)   # start auto trigger counter
   while(eventReader.accFrames < eventReader.reqFrames):
      pass
   QuadTop.SystemRegs.AutoTrigEn.set(False)  # stop and reset auto trigger counter
   print('%d, %f'%(i, eventReader.pixelSum/eventReader.reqFrames))
   eventReader.pixelSum = 0
   eventReader.accFrames = 0

QuadTop.RdoutCore.AdcPipelineDelay.set(0xAAAA0000 | adcPipDly)

QuadTop.stop()
exit()



