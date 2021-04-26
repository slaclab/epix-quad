#!/usr/bin/env python3
#-----------------------------------------------------------------------------
# Title      : CPix2 board instance
#-----------------------------------------------------------------------------
# File       : epix100aDAQ.py evolved from evalBoard.py
# Author     : Ryan Herbst, rherbst@slac.stanford.edu
# Modified by: Dionisio Doering
# Created    : 2016-09-29
# Last update: 2017-02-01
#-----------------------------------------------------------------------------
# Description:
# Rogue interface to CPix2 board
#-----------------------------------------------------------------------------
# This file is part of the rogue_example software. It is subject to 
# the license terms in the LICENSE.txt file found in the top-level directory 
# of this distribution and at: 
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
# No part of the rogue_example software, including this file, may be 
# copied, modified, propagated, or distributed except according to the terms 
# contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------
import rogue.hardware.pgp
import pyrogue.utilities.prbs
import pyrogue.utilities.fileio

import pyrogue as pr
import pyrogue.interfaces.simulation
import pyrogue.gui
import rogue.interfaces.stream
import surf
import threading
import signal
import atexit
import yaml
import time
import argparse
import sys
import ePixViewer as vi
import ePixQuad as quad
import os
import datetime
from datetime import datetime
import numpy as np



def asicSetPixel(x, y, val):
   addrSize=4
   bankToWrite = int(y/48);
   if (bankToWrite == 0):
      colToWrite = 0x700 + y%48;
   elif (bankToWrite == 1):
      colToWrite = 0x680 + y%48;
   elif (bankToWrite == 2):
      colToWrite = 0x580 + y%48;
   elif (bankToWrite == 3):
      colToWrite = 0x380 + y%48;
   SelectedAsic._rawWrite(0x00006011*addrSize, x)
   SelectedAsic._rawWrite(0x00006013*addrSize, colToWrite)
   SelectedAsic._rawWrite(0x00005000*addrSize, val)
   #print('Set ASIC pixel (%d, %d) to %d'%(x,y,val))

def asicModifyBitPixel(x, y, val, offset, size):
   addrSize=4
   bankToWrite = int(y/48);
   if (bankToWrite == 0):
      colToWrite = 0x700 + y%48;
   elif (bankToWrite == 1):
      colToWrite = 0x680 + y%48;
   elif (bankToWrite == 2):
      colToWrite = 0x580 + y%48;
   elif (bankToWrite == 3):
      colToWrite = 0x380 + y%48;
   SelectedAsic._rawWrite(0x00006011*addrSize, x)
   SelectedAsic._rawWrite(0x00006013*addrSize, colToWrite)
   pix = SelectedAsic._rawRead(0x00005000*addrSize)
   mask = (2**size-1)<<offset
   pix = pix & (~mask & 0xFF)
   pix = pix | ((val<<offset) & mask)
   SelectedAsic._rawWrite(0x00005000*addrSize, pix)
   #print('Set ASIC pixel (%d, %d) to %d'%(x,y,pix))

def setAsicMatrixMaskGrid22(x, y):
   addrSize=4
   SelectedAsic._rawWrite(0x00000000*addrSize,0)
   SelectedAsic._rawWrite(0x00008000*addrSize,0)
   for i in range(176):
      for j in range(192):
         if (i % 2 == x) and (j % 2 == y):
            pass
         else:
            asicModifyBitPixel(i, j, 1, 1, 1)
   SelectedAsic._rawWrite(0x00000000*addrSize,0)

def setAsicMatrixPulseGrid66(x, y):
   addrSize=4
   SelectedAsic._rawWrite(0x00000000*addrSize,0)
   SelectedAsic._rawWrite(0x00008000*addrSize,0)
   for i in range(176):
      for j in range(192):
         if (i % 6 == x) and (j % 6 == y):
            asicModifyBitPixel(i, j, 1, 0, 1)
   SelectedAsic._rawWrite(0x00000000*addrSize,0)
   
def setAsicMatrixPulseGrid88(x, y):
   addrSize=4
   SelectedAsic._rawWrite(0x00000000*addrSize,0)
   SelectedAsic._rawWrite(0x00008000*addrSize,0)
   for i in range(176):
      for j in range(192):
         if (i % 8 == x) and (j % 8 == y):
            asicModifyBitPixel(i, j, 1, 0, 1)
   SelectedAsic._rawWrite(0x00000000*addrSize,0)

def setAsicMatrixPulseGrid66Force(x, y):
   gr_fail = 10
   while gr_fail > 0:
      try:
         print('Set ASIC %d matrix to 66%d%d pulse pattern'%(args.asic,Mask_x,Mask_y))
         setAsicMatrixPulseGrid66(Mask_x,Mask_y)
         gr_fail = 0
      except:
         gr_fail = gr_fail - 1
         if gr_fail == 0:
            raise RuntimeError('Set ASIC %d matrix to 66%d%d pulse pattern - Failed'%(args.asic,Mask_x,Mask_y))
   print('Set ASIC %d matrix to 66%d%d pulse pattern - Done'%(args.asic,Mask_x,Mask_y))

def setAsicThreshold1(threshold):
   print('Setting TH1 to %d'%threshold)
   SelectedAsic.MSBCompTH1_DAC.set(threshold >> 6) # 4 bit MSB
   SelectedAsic.CompTH1_DAC.set(threshold & 0x3F) # 6 bit LSB

def setAsicThreshold2(threshold):
   print('Setting TH2 to %d'%threshold)
   SelectedAsic.MSBCompTH2_DAC.set(threshold >> 6) # 4 bit MSB
   SelectedAsic.CompTH2_DAC.set(threshold & 0x3F) # 6 bit LSB

def setAsicVtrimB(vtrim):
   print('Setting Vtrim_b to %d'%(vtrim))
   SelectedAsic.Vtrim_b2.set(vtrim >> 2) # 6 MSBs
   SelectedAsic.Vtrim_b.set(vtrim & 0x3) # 2 LSBs

def setAsicVtrimBForce(vtrim):
   gr_fail = 10
   while gr_fail > 0:
      try:
         setAsicVtrimB(vtrim)
         gr_fail = 0
      except:
         gr_fail = gr_fail - 1
         if gr_fail == 0:
            raise RuntimeError('Set ASIC %d Vtrim_b %d - Failed'%(args.asic,vtrim))
   print('Set ASIC %d Vtrim_b %d - Done'%(args.asic,vtrim))

def setAsicTrimBits(TrimBits):
   addrSize=4
   print('Setting ASIC %d TrimBits matrix to %x'%(args.asic,(TrimBits<<2)))
   # set all pixels trim bits
   SelectedAsic._rawWrite(0x00008000*addrSize,0)
   SelectedAsic._rawWrite(0x00004000*addrSize,TrimBits<<2)
   
   # verify one pixel that the write matrix worked
   SelectedAsic.RowCounter(1)
   SelectedAsic.ColCounter(1)
   rdBack = SelectedAsic._rawRead(0x00005000*addrSize)
   rdBack = rdBack & 0x3C
   
   if rdBack != TrimBits<<2:
      raise RuntimeError('Failed to set the pixel configuration. Expected %x, read %x'%(TrimBits<<2, rdBack))


def setAsicTrimBitsForce(TrimBits):
   gr_fail = 10
   while gr_fail > 0:
      try:
         setAsicTrimBits(TrimBits)
         gr_fail = 0
      except:
         gr_fail = gr_fail - 1
         if gr_fail == 0:
            raise RuntimeError('Setting ASIC %d TrimBits matrix to %x - Failed'%(args.asic,(TrimBits<<2)))
   print('Setting ASIC %d TrimBits matrix to %x - Done'%(args.asic,(TrimBits<<2)))

#################################################################

# Set the argument parser
parser = argparse.ArgumentParser()

# Convert str to bool
argBool = lambda s: s.lower() in ['true', 't', 'yes', '1']

# Add arguments
parser.add_argument(
    "--type", 
    type     = str,
    required = False,
    default  = 'pgp3_cardG3',
    help     = "Data card type pgp3_cardG3, datadev or simulation)",
)  

parser.add_argument(
    "--pgp", 
    type     = str,
    required = False,
    default  = '/dev/pgpcard_0',
    help     = "PGP devide (default /dev/pgpcard_0)",
)  

parser.add_argument(
    "--l", 
    type     = int,
    required = True,
    help     = "PGP lane number [0 ~ 3]",
)

parser.add_argument(
    "--test", 
    type     = str,
    required = False,
    default  = 'trimBitsData',
    help     = "Test name (options: trimBitsData)",
)

parser.add_argument(
    "--dir", 
    type     = str,
    required = True,
    default  = './',
    help     = "Directory where data files are stored",
)

parser.add_argument(
    "--framesPerThreshold", 
    type     = int,
    required = False,
    default  = 10,
    help     = "Number of frames per threshold",
)





# Get the arguments
args = parser.parse_args()

#################################################################

# Get the arguments
args = parser.parse_args()

# Set base
base = quad.Top(hwType=args.type, dev=args.pgp, lane=args.l, promWrEn=False)    

# Start the system
base.start(
    pollEn   = args.pollEn,
    initRead = args.initRead,
    timeout  = 5.0,    
)


################################################################################
#   Event reader class
#   
################################################################################
class ImgProc(rogue.interfaces.stream.Slave):
   """retrieves data from a file using rogue utilities services"""

   dataWait = threading.Condition()
   
   def __init__(self, reqFrames) :
      rogue.interfaces.stream.Slave.__init__(self)
      self.frameNum = 0
      self.reqFrames = reqFrames
      self.badFrames = 0
      self.frameBuf = np.empty((reqFrames, 176, 192))
      self.rawBuf = np.empty((reqFrames, 176*192))
   
   def acquireData(self):
      self.frameNum = 0
      
   def descrambleImg(self):
      for j in range(self.reqFrames):
         adcImg = self.rawBuf[j].reshape(-1,6)
         for i in range(0,6):
            adcImg2 = adcImg[:,i].reshape(-1,32)
            if i == 0:
               quadrant0sq = adcImg2
            else:
               quadrant0sq = np.concatenate((quadrant0sq,adcImg2),1)
      self.frameBuf[:,:,:] = quadrant0sq
   
   def _acceptFrame(self,frame):
      cframe = bytearray(frame.getPayload())
      frame.read(cframe,0)
      
      if frame.getPayload() == 67596 and self.frameNum < self.reqFrames:
         #self.frameBuf[self.frameNum] = np.frombuffer(cframe, dtype=np.uint16, count=-1, offset=12).reshape(176,192)
         self.rawBuf[self.frameNum] = np.frombuffer(cframe, dtype=np.uint16, count=-1, offset=12)
         self.frameNum = self.frameNum + 1
         #print(self.frameNum)
         if self.frameNum >= self.reqFrames:
            self.dataWait.acquire()
            self.dataWait.notify()
            self.dataWait.release()
      else:
         self.badFrames = self.badFrames + 1




#################################################################

# connect ImageProc
imgProc = ImgProc(args.framesPerThreshold)
pyrogue.streamTap(base.pgpVc0, imgProc)

SelectedAsic = base.Epix10kaSaci[0].Cpix2Asic0



#if args.test == 'trimBitsData':
#   
#   if os.path.isdir(args.dir):
#      
#      Pulser = 319
#      Npulse = 100
#      
#      
#      #check and load config.yml
#      if os.path.isfile(args.dir+'/config.yml'):
#         print('Setting camera registers')
#         base.LoadConfig(args.dir+'/config.yml')
#      else:
#         raise FileNotFoundError('File ' + args.dir+'/config.yml not found')
#      
#      #make dir for data if does not exist
#      if not os.path.isdir(args.dir+'/data'):
#         os.mkdir(args.dir+'/data')
#      
#      SelectedAsic.enable.set(True)
#      base.EpixHR.RegisterControl.enable.set(True)
#      base.EpixHR.TriggerRegisters.enable.set(True)
#      
#      print('Enable only counter A readout')
#      SelectedAsic.Pix_Count_T.set(False)
#      SelectedAsic.Pix_Count_sel.set(False)
#      
#      # disable automatic readout 
#      base.EpixHR.RegisterControl.EnAllFrames.set(False)
#      base.EpixHR.RegisterControl.EnSingleFrame.set(False)
#      
#      # set Npulse
#      base.EpixHR.RegisterControl.ReqTriggerCnt.set(Npulse)
#      
#      # enable run trigger
#      base.EpixHR.TriggerRegisters.RunTriggerEnable.set(True)
#      
#      print('Clearing ASIC %d matrix'%(args.asic))
#      SelectedAsic.ClearMatrix()
#      
#      print('Enabling pulser')
#      SelectedAsic.Pulser.set(Pulser)
#      SelectedAsic.test.set(True)
#      SelectedAsic.atest.set(False)
#      
#      threshold_2 = 1023
#      threshold_1 = 1023
#      setAsicThreshold2(threshold_2)
#      setAsicThreshold1(threshold_1)
#      
#      
#      for VtrimB in range(63,256,64):
#         for TrimBits in range(0,16,1):
#            for Mask_x in range(6):
#               for Mask_y in range(6):
#                  
#                  setAsicVtrimBForce(VtrimB)
#                  setAsicTrimBitsForce(TrimBits)
#                  setAsicMatrixPulseGrid66Force(Mask_x,Mask_y)
#                  
#                  
#                  for threshold_1 in range(900,400,-1):
#                     
#                     setAsicThreshold1(threshold_1)
#                     
#                     # eanble automatic readout 
#                     base.EpixHR.RegisterControl.EnAllFrames.set(True)
#                     base.EpixHR.RegisterControl.EnSingleFrame.set(True)
#                        
#                     # acquire images
#                     imgProc.dataWait.acquire()
#                     imgProc.acquireData()
#                     imgProc.dataWait.wait()
#                     imgProc.descrambleImg()
#                     
#                     # stop triggering data
#                     base.EpixHR.RegisterControl.EnAllFrames.set(False)
#                     base.EpixHR.RegisterControl.EnSingleFrame.set(False)
#                     
#                     # save data
#                     fileName = args.dir + '/data/' + '/ACQ' + '{:04d}'.format(args.framesPerThreshold) + '_VTRIMB' + '{:1d}'.format(VtrimB) + '_TH1' + '{:04d}'.format(threshold_1) + '_TH2' + '{:04d}'.format(threshold_2) + '_P' + '{:04d}'.format(Pulser) + '_N' + '{:05d}'.format(Npulse) + '_TrimBits' + '{:02d}'.format(TrimBits) + '_66' + '{:1d}'.format(Mask_x) + '{:1d}'.format(Mask_y)
#                     np.savez_compressed(fileName, im=imgProc.frameBuf)
#                     print(fileName + ' saved')
#
#   else:
#      print('Directory %s does not exist'%args.dir)
#   
#
   
base.stop()
exit()


############################
##  -> Set Pulser to 319
##  -> Scan VtrimB 0 to 3
##     -> Scan (4) trim bits 0 to 15 values (fine)
##        -> Scan all bit masks 6600 to 6655 (x36)
##           -> Keep TH2 1023, scan TH1 900-400
#if args.test == 7:

############################
## The same as test 7 but scanning th2 and counting in counter B
##  -> Set Pulser to 319
##  -> Scan VtrimB 0 to 3
##     -> Scan (4) trim bits 0 to 15 values (fine)
##        -> Scan all bit masks 6600 to 6655 (x36)
##           -> Keep TH1 1023, scan TH2 900-400
#if args.test == 9:

############################
##  New threshold trim calibration procedure using noise instead of pulser
##  -> Set synchronous mode and count to 1000
##  -> Set pulser DAC 0 (global test not working in prototype)
##  -> Clear matrix to disable pulser
##  -> Count only in counter A (no toggling and single readout) 
##  -> Count over threshold 1 
##  -> Scan VtrimB 0 to 3
##     -> Scan (4) trim bits 0 to 15 values (fine)
##        -> Keep TH2 1023, scan TH1 0-1023
##           -> Acquire 10 frames and do median over each pixel
##              mask pixel if med >= 3
##              replace median value of masked pixel with -1
##              save median only to a binary file (signed int32)
#if args.test == 12:
