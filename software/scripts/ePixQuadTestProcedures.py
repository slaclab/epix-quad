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


def setAsicMatrixGrid22(x, y, pix, dev):
   addrSize=4
   dev._rawWrite(0x00000000*addrSize,0)
   dev._rawWrite(0x00008000*addrSize,0)
   for i in range(175):
      for j in range(192):
         if (i % 2 == x) and (j % 2 == y):
            bankToWrite = int(j/48);
            if (bankToWrite == 0):
               colToWrite = 0x700 + j%48;
            elif (bankToWrite == 1):
               colToWrite = 0x680 + j%48;
            elif (bankToWrite == 2):
               colToWrite = 0x580 + j%48;
            elif (bankToWrite == 3):
               colToWrite = 0x380 + j%48;
            else:
               print('unexpected bank number')
            dev._rawWrite(0x00006013*addrSize, colToWrite)
            dev._rawWrite(0x00006011*addrSize, i)
            dev._rawWrite(0x00005000*addrSize, pix)
   dev._rawWrite(0x00000000*addrSize,0)

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
    "--c", 
    type     = str,
    required = True,
    default  = './',
    help     = "Configuration yml file",
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
    default  = 10240,
    help     = "Number of frames per threshold",
)

parser.add_argument(
    "--acqWidth", 
    type     = int,
    required = False,
    default  = 20000,
    help     = "Acquisition time in 10ns intervals",
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
    pollEn   = False,
    initRead = False,
    timeout  = 5.0,    
)


################################################################################
#   Event reader class
#   
################################################################################
#class ImgProc(rogue.interfaces.stream.Slave):
#   """retrieves data from a file using rogue utilities services"""
#
#   dataWait = threading.Condition()
#   
#   def __init__(self, reqFrames) :
#      rogue.interfaces.stream.Slave.__init__(self)
#      self.frameNum = 0
#      self.reqFrames = reqFrames
#      self.badFrames = 0
#      self.frameBuf = np.empty((reqFrames, 176, 192))
#      self.rawBuf = np.empty((reqFrames, 176*192))
#   
#   def acquireData(self):
#      self.frameNum = 0
#      
#   def descrambleImg(self):
#      for j in range(self.reqFrames):
#         adcImg = self.rawBuf[j].reshape(-1,6)
#         for i in range(0,6):
#            adcImg2 = adcImg[:,i].reshape(-1,32)
#            if i == 0:
#               quadrant0sq = adcImg2
#            else:
#               quadrant0sq = np.concatenate((quadrant0sq,adcImg2),1)
#      self.frameBuf[:,:,:] = quadrant0sq
#   
#   def _acceptFrame(self,frame):
#      cframe = bytearray(frame.getPayload())
#      frame.read(cframe,0)
#      
#      if frame.getPayload() == 1095232 and self.frameNum < self.reqFrames:
#         #self.frameBuf[self.frameNum] = np.frombuffer(cframe, dtype=np.uint16, count=-1, offset=12).reshape(176,192)
#         self.rawBuf[self.frameNum] = np.frombuffer(cframe, dtype=np.uint16, count=-1, offset=12)
#         self.frameNum = self.frameNum + 1
#         #print(self.frameNum)
#         if self.frameNum >= self.reqFrames:
#            self.dataWait.acquire()
#            self.dataWait.notify()
#            self.dataWait.release()
#      else:
#         self.badFrames = self.badFrames + 1




#################################################################

# connect ImageProc
#imgProc = ImgProc(args.framesPerThreshold)
#pyrogue.streamTap(base.pgpVc0, imgProc)

SelectedAsic = base.Epix10kaSaci[0]

#check and load config.yml
base.LoadConfig(args.c)

#if os.path.isfile(args.dir+'/config.yml'):
#   print('Setting camera registers')
#   base.LoadConfig(args.dir+'/config.yml')
#   #base.ReadConfig(args.dir+'/config.yml')
#else:
#   raise FileNotFoundError('File ' + args.dir+'/config.yml not found')

#make dir for data if does not exist
#if not os.path.isdir(args.dir+'/data'):
#   os.mkdir(args.dir+'/data')


print('Set auto-trigger to 60Hz')
base.SystemRegs.TrigEn.set(True)
base.SystemRegs.TrigSrcSel.set(0x3)
base.SystemRegs.AutoTrigEn.set(False)
base.SystemRegs.AutoTrigFreqHz.set(60.0)


print('Set integration time to %d'%(args.acqWidth))
#base.EpixFpgaRegisters.AsicAcqWidth.set(args.acqWidth)
#base.EpixFpgaRegisters.AsicR0ToAsicAcq.set(args.acqWidth)
base.AcqCore.AsicAcqWidth.set(args.acqWidth)
base.AcqCore.AsicR0ToAsicAcq.set(args.acqWidth)

for trbit in range(2):
   
   
   for asicNo in range(16):
      print('Enable ASICs test')
      base.Epix10kaSaci[asicNo].test.set(True)
      print('Enable ASICs atest')
      base.Epix10kaSaci[asicNo].atest.set(True)
      if trbit == 1:
         print('Setting trbit to 1 (high to low gain)')
         base.Epix10kaSaci[asicNo].trbit.set(True)
      else:
         print('Setting trbit to 0 (medium to low gain)')
         base.Epix10kaSaci[asicNo].trbit.set(False)
   
   for x in range(2):
      for y in range(2):
         
         for asicNo in range(16):
            print('Clearing ASICs matrix (auto-range)')
            base.Epix10kaSaci[asicNo].ClearMatrix()
            
            print('Setting ASICs matrix to %d%d pattern'%(x,y))
            setAsicMatrixGrid22(x, y, 1, base.Epix10kaSaci[asicNo])
         
            print('Reset pulser')
            base.Epix10kaSaci[asicNo].PulserR.set(True)
            base.Epix10kaSaci[asicNo].PulserR.set(False)
            
         
         print('Open data file')
         base.dataWriter.dataFile.set(args.dir + '/calib_acq_width' +  '{:06d}'.format(args.acqWidth) + '_trbit' + '{:1d}'.format(trbit) + '_22' + '{:1d}'.format(x) + '{:1d}'.format(y)  + '.dat')
         base.dataWriter.open.set(True)
         
         # eanble automatic readout 
         base.SystemRegs.AutoTrigEn.set(True)
         
         time.sleep(200)
         
         # stop triggering data
         base.SystemRegs.AutoTrigEn.set(False)
         
         print('Close data file')
         base.dataWriter.open.set(False)
         
   
   
   # acquire dark frames in 5 modes before the pulser scan
   
   print('Disable ASICs test for darks')
   for asicNo in range(16):
      base.Epix10kaSaci[asicNo].test.set(False)
      print('Disable ASICs atest for darks')
      base.Epix10kaSaci[asicNo].atest.set(False)
      print('Set ASICs to fixed medium')
      base.Epix10kaSaci[asicNo].trbit.set(False)
      base.Epix10kaSaci[asicNo].PrepareMultiConfig()
      base.Epix10kaSaci[asicNo].WriteMatrixData(12)
   
   
   
   print('Open dark file fixed medium')
   base.dataWriter.dataFile.set(args.dir + '/calib_acq_width' +  '{:06d}'.format(args.acqWidth) + '_trbit' + '{:1d}'.format(trbit) + '_darkFixedMed.dat')
   base.dataWriter.open.set(True)
   # eanble automatic readout 
   base.SystemRegs.AutoTrigEn.set(True)
   time.sleep(40)
   # stop triggering data
   base.SystemRegs.AutoTrigEn.set(False)
   print('Close data file')
   base.dataWriter.open.set(False)
   
   
   
   for asicNo in range(16):
      print('Set ASICs to fixed high')
      base.Epix10kaSaci[asicNo].trbit.set(True)
      base.Epix10kaSaci[asicNo].PrepareMultiConfig()
      base.Epix10kaSaci[asicNo].WriteMatrixData(12)
   
   print('Open dark file fixed high')
   base.dataWriter.dataFile.set(args.dir + '/calib_acq_width' +  '{:06d}'.format(args.acqWidth) + '_trbit' + '{:1d}'.format(trbit) + '_darkFixedHigh.dat')
   base.dataWriter.open.set(True)
   # eanble automatic readout 
   base.SystemRegs.AutoTrigEn.set(True)
   time.sleep(40)
   # stop triggering data
   base.SystemRegs.AutoTrigEn.set(False)
   print('Close data file')
   base.dataWriter.open.set(False)
   
   
   for asicNo in range(16):
      print('Set ASICs to fixed low')
      base.Epix10kaSaci[asicNo].PrepareMultiConfig()
      base.Epix10kaSaci[asicNo].WriteMatrixData(8)
   
   print('Open dark file fixed low')
   base.dataWriter.dataFile.set(args.dir + '/calib_acq_width' +  '{:06d}'.format(args.acqWidth) + '_trbit' + '{:1d}'.format(trbit) + '_darkFixedLow.dat')
   base.dataWriter.open.set(True)
   # eanble automatic readout 
   base.SystemRegs.AutoTrigEn.set(True)
   time.sleep(40)
   # stop triggering data
   base.SystemRegs.AutoTrigEn.set(False)
   print('Close data file')
   base.dataWriter.open.set(False)
   
   
   
   for asicNo in range(16):
      print('Set ASICs to auto range high to low')
      base.Epix10kaSaci[asicNo].trbit.set(True)
      base.Epix10kaSaci[asicNo].PrepareMultiConfig()
      base.Epix10kaSaci[asicNo].WriteMatrixData(0)
   
   print('Open dark file auto range high to low')
   base.dataWriter.dataFile.set(args.dir + '/calib_acq_width' +  '{:06d}'.format(args.acqWidth) + '_trbit' + '{:1d}'.format(trbit) + '_darkAutoHtoL.dat')
   base.dataWriter.open.set(True)
   # eanble automatic readout 
   base.SystemRegs.AutoTrigEn.set(True)
   time.sleep(40)
   # stop triggering data
   base.SystemRegs.AutoTrigEn.set(False)
   print('Close data file')
   base.dataWriter.open.set(False)
   
   
   
   for asicNo in range(16):
      print('Set ASICs to auto range medium to low')
      base.Epix10kaSaci[asicNo].trbit.set(False)
      base.Epix10kaSaci[asicNo].PrepareMultiConfig()
      base.Epix10kaSaci[asicNo].WriteMatrixData(0)
   
   print('Open dark file auto range medium to low')
   base.dataWriter.dataFile.set(args.dir + '/calib_acq_width' +  '{:06d}'.format(args.acqWidth) + '_trbit' + '{:1d}'.format(trbit) + '_darkAutoMtoL.dat')
   base.dataWriter.open.set(True)
   # eanble automatic readout 
   base.SystemRegs.AutoTrigEn.set(True)
   time.sleep(40)
   # stop triggering data
   base.SystemRegs.AutoTrigEn.set(False)
   print('Close data file')
   base.dataWriter.open.set(False)
   
   
   