#!/usr/bin/env python3
#-----------------------------------------------------------------------------
# Title      :  board instance
#-----------------------------------------------------------------------------
# File       : epix100aDAQ.py evolved from evalBoard.py
# Author     : Ryan Herbst, rherbst@slac.stanford.edu
# Modified by: Dionisio Doering
# Created    : 2016-09-29
# Last update: 2017-02-01
#-----------------------------------------------------------------------------
# Description:
# Rogue interface to epix board
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
import surf
import threading
import signal
import atexit
import yaml
import time
import argparse
import sys
import testBridge
import ePixViewer as vi
import ePixFpga as fpga
import os
import datetime

try:
    from PyQt5.QtWidgets import *
    from PyQt5.QtCore    import *
    from PyQt5.QtGui     import *
except ImportError:
    from PyQt4.QtCore    import *
    from PyQt4.QtGui     import *


#################################################################
   
def setAsicMatrixGrid88(x, y, pix, dev):
   addrSize=4
   dev._rawWrite(0x00000000*addrSize,0)
   dev._rawWrite(0x00008000*addrSize,0)
   for i in range(175):
      for j in range(192):
         if (i % 8 == x) and (j % 8 == y):
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
    "--type", 
    type     = str,
    required = False,
    default  = 'pgp-gen3',
    help     = "PGP hardware type: pgp-gen3, kcu1500 or simulation",
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
    required = False,
    default  = 0,
    help     = "PGP lane number [0 ~ 3]",
)

parser.add_argument(
    "--test", 
    type     = int,
    required = True,
    default  = 0,
    help     = "Test number",
)

parser.add_argument(
    "--dir", 
    type     = str,
    required = True,
    default  = './',
    help     = "Directory where data files are stored",
)

parser.add_argument(
    "--c", 
    type     = str,
    required = True,
    default  = './',
    help     = "Configuration yml file",
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


if ( args.type == 'pgp-gen3' ):
    # Create the PGP interfaces for ePix camera
    pgpVc1 = rogue.hardware.pgp.PgpCard(args.pgp,args.l,0) # Data & cmds
    pgpVc0 = rogue.hardware.pgp.PgpCard(args.pgp,args.l,1) # Registers for ePix board
    pgpVc2 = rogue.hardware.pgp.PgpCard(args.pgp,args.l,2) # PseudoScope
    pgpVc3 = rogue.hardware.pgp.PgpCard(args.pgp,args.l,3) # Monitoring (Slow ADC)
    print("PGP Card Version: %x" % (pgpVc0.getInfo().version))
elif ( args.type == 'kcu1500' ):
    # Create the PGP interfaces for ePix hr camera
    pgpVc1 = rogue.hardware.data.DataCard(args.pgp,(0*32)+0) # Data & cmds
    pgpVc0 = rogue.hardware.data.DataCard(args.pgp,(0*32)+1) # Registers for ePix board
    pgpVc2 = rogue.hardware.data.DataCard(args.pgp,(0*32)+2) # PseudoScope
    pgpVc3 = rogue.hardware.data.DataCard(args.pgp,(0*32)+3) # Monitoring (Slow ADC)
elif ( args.type == 'simulation' ):
    pgpVc1 = pr.interfaces.simulation.StreamSim(host='localhost', dest=0, uid=2, ssi=True)
    pgpVc0 = pr.interfaces.simulation.StreamSim(host='localhost', dest=1, uid=2, ssi=True)
    pgpVc2 = pr.interfaces.simulation.StreamSim(host='localhost', dest=2, uid=2, ssi=True)
    pgpVc3 = pr.interfaces.simulation.StreamSim(host='localhost', dest=3, uid=2, ssi=True)      
else:
    raise ValueError("Invalid type (%s)" % (args.type) )


# Add data stream to file as channel 1
# File writer
dataWriter = pyrogue.utilities.fileio.StreamWriter(name = 'dataWriter')
pyrogue.streamConnect(pgpVc0, dataWriter.getChannel(0x1))
# Add pseudoscope to file writer
#pyrogue.streamConnect(pgpVc2, dataWriter.getChannel(0x2))
#pyrogue.streamConnect(pgpVc3, dataWriter.getChannel(0x3))

cmd = rogue.protocols.srp.Cmd()
pyrogue.streamConnect(cmd, pgpVc0)

# Create and Connect SRP to VC1 to send commands
srp = rogue.protocols.srp.SrpV0()
pyrogue.streamConnectBiDir(pgpVc1,srp)

#############################################
# Microblaze console printout
#############################################
class MbDebug(rogue.interfaces.stream.Slave):

    def __init__(self):
        rogue.interfaces.stream.Slave.__init__(self)
        self.enable = False

    def _acceptFrame(self,frame):
        if self.enable:
            p = bytearray(frame.getPayload())
            frame.read(p,0)
            print('-------- Microblaze Console --------')
            print(p.decode('utf-8'))

#######################################
# Custom run control
#######################################
class MyRunControl(pyrogue.RunControl):
    def __init__(self,name):
        pyrogue.RunControl.__init__(self,name, description='Run Controller ePix 10ka',  rates={1:'1 Hz', 2:'2 Hz', 4:'4 Hz', 8:'8 Hz', 10:'10 Hz', 30:'30 Hz', 60:'60 Hz', 120:'120 Hz'})
        self._thread = None

    def _setRunState(self,dev,var,value,changed):
        if changed: 
            if self.runState.get(read=False) == 'Running': 
                self._thread = threading.Thread(target=self._run) 
                self._thread.start() 
            else: 
                self._thread.join() 
                self._thread = None 


    def _run(self):
        self.runCount.set(0) 
        self._last = int(time.time()) 
 
 
        while (self.runState.value() == 'Running'): 
            delay = 1.0 / ({value: key for key,value in self.runRate.enum.items()}[self._runRate]) 
            time.sleep(delay) 
            self._root.ssiPrbsTx.oneShot() 
  
            self._runCount += 1 
            if self._last != int(time.time()): 
                self._last = int(time.time()) 
                self.runCount._updated() 

##############################
# Set base
##############################
class EpixBoard(pyrogue.Root):
    def __init__(self, guiTop, cmd, dataWriter, srp, **kwargs):
        super().__init__(name = 'ePixBoard',description = 'ePix 10ka Board', **kwargs)
        #self.add(MyRunControl('runControl'))
        self.add(dataWriter)
        self.guiTop = guiTop

        @self.command()
        def Trigger():
            cmd.sendCmd(0, 0)

        # Add Devices
        self.add(fpga.Epix10ka(name='Epix10ka', offset=0, memBase=srp, hidden=False, enabled=True))
        self.add(pyrogue.RunControl(name = 'runControl', description='Run Controller ePix 10ka', cmd=self.Trigger, rates={1:'1 Hz', 2:'2 Hz', 4:'4 Hz', 8:'8 Hz', 10:'10 Hz', 30:'30 Hz', 60:'60 Hz', 120:'120 Hz'}))

# Create GUI
appTop = QApplication(sys.argv)
ePixBoard = EpixBoard(0, cmd, dataWriter, srp)
ePixBoard.start(pollEn=args.pollEn, initRead = args.initRead, timeout=3.0)


# simple pulser scan
# auto range high to low and medium to low gain
if args.test == 1:
   
   
   
   if os.path.isdir(args.dir):
      
      print('Setting camera registers')
      ePixBoard.ReadConfig(args.c)
      #ePixBoard.setYaml(args.c, True)
      #ePixBoard.setYaml(yaml.safe_load(args.c), True)
      
      print('Set auto-trigger to 120Hz')
      ePixBoard.Epix10ka.EpixFpgaRegisters.AutoRunPeriod.set(833333)
      ePixBoard.Epix10ka.EpixFpgaRegisters.AutoDaqEnable.set(True)
      ePixBoard.Epix10ka.EpixFpgaRegisters.AutoRunEnable.set(False)
      
      print('Set integration time to %d'%(args.acqWidth))
      ePixBoard.Epix10ka.EpixFpgaRegisters.AsicAcqWidth.set(args.acqWidth)
      
      for trbit in range(2):
         
         print('Enable ASICs test')
         ePixBoard.Epix10ka.Epix10kaAsic0.test.set(True)
         ePixBoard.Epix10ka.Epix10kaAsic1.test.set(True)
         #ePixBoard.Epix10ka.Epix10kaAsic2.test.set(True)
         ePixBoard.Epix10ka.Epix10kaAsic3.test.set(True)
         
         print('Enable ASICs atest')
         ePixBoard.Epix10ka.Epix10kaAsic0.atest.set(True)
         ePixBoard.Epix10ka.Epix10kaAsic1.atest.set(True)
         #ePixBoard.Epix10ka.Epix10kaAsic2.atest.set(True)
         ePixBoard.Epix10ka.Epix10kaAsic3.atest.set(True)
         
         if trbit == 1:
            print('Setting trbit to 1 (high to low gain)')
            ePixBoard.Epix10ka.Epix10kaAsic0.trbit.set(True)
            ePixBoard.Epix10ka.Epix10kaAsic1.trbit.set(True)
            #ePixBoard.Epix10ka.Epix10kaAsic2.trbit.set(True)
            ePixBoard.Epix10ka.Epix10kaAsic3.trbit.set(True)
         else:
            print('Setting trbit to 0 (medium to low gain)')
            ePixBoard.Epix10ka.Epix10kaAsic0.trbit.set(False)
            ePixBoard.Epix10ka.Epix10kaAsic1.trbit.set(False)
            #ePixBoard.Epix10ka.Epix10kaAsic2.trbit.set(False)
            ePixBoard.Epix10ka.Epix10kaAsic3.trbit.set(False)
         
         for x in range(8):
            for y in range(8):
               print('Clearing ASICs matrix (auto-range)')
               ePixBoard.Epix10ka.Epix10kaAsic0.ClearMatrix()
               ePixBoard.Epix10ka.Epix10kaAsic1.ClearMatrix()
               #ePixBoard.Epix10ka.Epix10kaAsic2.ClearMatrix()
               ePixBoard.Epix10ka.Epix10kaAsic3.ClearMatrix()
               print('Setting ASICs matrix to %d%d pattern'%(x,y))
               setAsicMatrixGrid88(x, y, 1, ePixBoard.Epix10ka.Epix10kaAsic0)
               setAsicMatrixGrid88(x, y, 1, ePixBoard.Epix10ka.Epix10kaAsic1)
               #setAsicMatrixGrid88(x, y, 1, ePixBoard.Epix10ka.Epix10kaAsic2)
               setAsicMatrixGrid88(x, y, 1, ePixBoard.Epix10ka.Epix10kaAsic3)
               
               print('Reset pulser')
               ePixBoard.Epix10ka.Epix10kaAsic0.PulserR.set(True)
               ePixBoard.Epix10ka.Epix10kaAsic0.PulserR.set(False)
               ePixBoard.Epix10ka.Epix10kaAsic1.PulserR.set(True)
               ePixBoard.Epix10ka.Epix10kaAsic1.PulserR.set(False)
               #ePixBoard.Epix10ka.Epix10kaAsic2.PulserR.set(True)
               #ePixBoard.Epix10ka.Epix10kaAsic2.PulserR.set(False)
               ePixBoard.Epix10ka.Epix10kaAsic3.PulserR.set(True)
               ePixBoard.Epix10ka.Epix10kaAsic3.PulserR.set(False)
               
               print('Open data file')
               ePixBoard.dataWriter.dataFile.set(args.dir + '/calib_acq_width' +  '{:06d}'.format(args.acqWidth) + '_trbit' + '{:1d}'.format(trbit) + '_88' + '{:1d}'.format(x) + '{:1d}'.format(y)  + '.dat')
               ePixBoard.dataWriter.open.set(True)
               
               ePixBoard.Epix10ka.EpixFpgaRegisters.AutoRunEnable.set(True)
               
               time.sleep(30)
               
               ePixBoard.Epix10ka.EpixFpgaRegisters.AutoRunEnable.set(False)
               
               print('Close data file')
               ePixBoard.dataWriter.open.set(False)
         
         
         # acquire dark frames in 5 modes before the pulser scan
         
         print('Disable ASICs test for darks')
         ePixBoard.Epix10ka.Epix10kaAsic0.test.set(False)
         ePixBoard.Epix10ka.Epix10kaAsic1.test.set(False)
         #ePixBoard.Epix10ka.Epix10kaAsic2.test.set(False)
         ePixBoard.Epix10ka.Epix10kaAsic3.test.set(False)
         
         print('Disable ASICs atest for darks')
         ePixBoard.Epix10ka.Epix10kaAsic0.atest.set(False)
         ePixBoard.Epix10ka.Epix10kaAsic1.atest.set(False)
         #ePixBoard.Epix10ka.Epix10kaAsic2.atest.set(False)
         ePixBoard.Epix10ka.Epix10kaAsic3.atest.set(False)
         
         
         print('Open dark file fixed medium')
         ePixBoard.Epix10ka.Epix10kaAsic0.trbit.set(False)
         ePixBoard.Epix10ka.Epix10kaAsic1.trbit.set(False)
         #ePixBoard.Epix10ka.Epix10kaAsic2.trbit.set(False)
         ePixBoard.Epix10ka.Epix10kaAsic3.trbit.set(False)
         ePixBoard.Epix10ka.Epix10kaAsic0.PrepareMultiConfig()
         ePixBoard.Epix10ka.Epix10kaAsic0.WriteMatrixData(12)
         ePixBoard.Epix10ka.Epix10kaAsic1.PrepareMultiConfig()
         ePixBoard.Epix10ka.Epix10kaAsic1.WriteMatrixData(12)
         #ePixBoard.Epix10ka.Epix10kaAsic2.PrepareMultiConfig()
         #ePixBoard.Epix10ka.Epix10kaAsic2.WriteMatrixData(12)
         ePixBoard.Epix10ka.Epix10kaAsic3.PrepareMultiConfig()
         ePixBoard.Epix10ka.Epix10kaAsic3.WriteMatrixData(12)
         ePixBoard.dataWriter.dataFile.set(args.dir + '/calib_acq_width' +  '{:06d}'.format(args.acqWidth) + '_trbit' + '{:1d}'.format(trbit) + '_darkFixedMed.dat')
         ePixBoard.dataWriter.open.set(True)
         ePixBoard.Epix10ka.EpixFpgaRegisters.AutoRunEnable.set(True)
         time.sleep(20)
         ePixBoard.Epix10ka.EpixFpgaRegisters.AutoRunEnable.set(False)
         print('Close data file')
         ePixBoard.dataWriter.open.set(False)
         
         print('Open dark file fixed high')
         ePixBoard.Epix10ka.Epix10kaAsic0.trbit.set(True)
         ePixBoard.Epix10ka.Epix10kaAsic1.trbit.set(True)
         #ePixBoard.Epix10ka.Epix10kaAsic2.trbit.set(True)
         ePixBoard.Epix10ka.Epix10kaAsic3.trbit.set(True)
         ePixBoard.Epix10ka.Epix10kaAsic0.PrepareMultiConfig()
         ePixBoard.Epix10ka.Epix10kaAsic0.WriteMatrixData(12)
         ePixBoard.Epix10ka.Epix10kaAsic1.PrepareMultiConfig()
         ePixBoard.Epix10ka.Epix10kaAsic1.WriteMatrixData(12)
         #ePixBoard.Epix10ka.Epix10kaAsic2.PrepareMultiConfig()
         #ePixBoard.Epix10ka.Epix10kaAsic2.WriteMatrixData(12)
         ePixBoard.Epix10ka.Epix10kaAsic3.PrepareMultiConfig()
         ePixBoard.Epix10ka.Epix10kaAsic3.WriteMatrixData(12)
         ePixBoard.dataWriter.dataFile.set(args.dir + '/calib_acq_width' +  '{:06d}'.format(args.acqWidth) + '_trbit' + '{:1d}'.format(trbit) + '_darkFixedHigh.dat')
         ePixBoard.dataWriter.open.set(True)
         ePixBoard.Epix10ka.EpixFpgaRegisters.AutoRunEnable.set(True)
         time.sleep(20)
         ePixBoard.Epix10ka.EpixFpgaRegisters.AutoRunEnable.set(False)
         print('Close data file')
         ePixBoard.dataWriter.open.set(False)
         
         print('Open dark file fixed low')
         ePixBoard.Epix10ka.Epix10kaAsic0.PrepareMultiConfig()
         ePixBoard.Epix10ka.Epix10kaAsic0.WriteMatrixData(8)
         ePixBoard.Epix10ka.Epix10kaAsic1.PrepareMultiConfig()
         ePixBoard.Epix10ka.Epix10kaAsic1.WriteMatrixData(8)
         #ePixBoard.Epix10ka.Epix10kaAsic2.PrepareMultiConfig()
         #ePixBoard.Epix10ka.Epix10kaAsic2.WriteMatrixData(8)
         ePixBoard.Epix10ka.Epix10kaAsic3.PrepareMultiConfig()
         ePixBoard.Epix10ka.Epix10kaAsic3.WriteMatrixData(8)
         ePixBoard.dataWriter.dataFile.set(args.dir + '/calib_acq_width' +  '{:06d}'.format(args.acqWidth) + '_trbit' + '{:1d}'.format(trbit) + '_darkFixedLow.dat')
         ePixBoard.dataWriter.open.set(True)
         ePixBoard.Epix10ka.EpixFpgaRegisters.AutoRunEnable.set(True)
         time.sleep(20)
         ePixBoard.Epix10ka.EpixFpgaRegisters.AutoRunEnable.set(False)
         print('Close data file')
         ePixBoard.dataWriter.open.set(False)
         
         print('Open dark file auto range high to low')
         ePixBoard.Epix10ka.Epix10kaAsic0.trbit.set(True)
         ePixBoard.Epix10ka.Epix10kaAsic1.trbit.set(True)
         #ePixBoard.Epix10ka.Epix10kaAsic2.trbit.set(True)
         ePixBoard.Epix10ka.Epix10kaAsic3.trbit.set(True)
         ePixBoard.Epix10ka.Epix10kaAsic0.PrepareMultiConfig()
         ePixBoard.Epix10ka.Epix10kaAsic0.WriteMatrixData(0)
         ePixBoard.Epix10ka.Epix10kaAsic1.PrepareMultiConfig()
         ePixBoard.Epix10ka.Epix10kaAsic1.WriteMatrixData(0)
         #ePixBoard.Epix10ka.Epix10kaAsic2.PrepareMultiConfig()
         #ePixBoard.Epix10ka.Epix10kaAsic2.WriteMatrixData(0)
         ePixBoard.Epix10ka.Epix10kaAsic3.PrepareMultiConfig()
         ePixBoard.Epix10ka.Epix10kaAsic3.WriteMatrixData(0)
         ePixBoard.dataWriter.dataFile.set(args.dir + '/calib_acq_width' +  '{:06d}'.format(args.acqWidth) + '_trbit' + '{:1d}'.format(trbit) + '_darkAutoHtoL.dat')
         ePixBoard.dataWriter.open.set(True)
         ePixBoard.Epix10ka.EpixFpgaRegisters.AutoRunEnable.set(True)
         time.sleep(20)
         ePixBoard.Epix10ka.EpixFpgaRegisters.AutoRunEnable.set(False)
         print('Close data file')
         ePixBoard.dataWriter.open.set(False)
         
         print('Open dark file auto range medium to low')
         ePixBoard.Epix10ka.Epix10kaAsic0.trbit.set(False)
         ePixBoard.Epix10ka.Epix10kaAsic1.trbit.set(False)
         #ePixBoard.Epix10ka.Epix10kaAsic2.trbit.set(False)
         ePixBoard.Epix10ka.Epix10kaAsic3.trbit.set(False)
         ePixBoard.Epix10ka.Epix10kaAsic0.PrepareMultiConfig()
         ePixBoard.Epix10ka.Epix10kaAsic0.WriteMatrixData(0)
         ePixBoard.Epix10ka.Epix10kaAsic1.PrepareMultiConfig()
         ePixBoard.Epix10ka.Epix10kaAsic1.WriteMatrixData(0)
         #ePixBoard.Epix10ka.Epix10kaAsic2.PrepareMultiConfig()
         #ePixBoard.Epix10ka.Epix10kaAsic2.WriteMatrixData(0)
         ePixBoard.Epix10ka.Epix10kaAsic3.PrepareMultiConfig()
         ePixBoard.Epix10ka.Epix10kaAsic3.WriteMatrixData(0)
         ePixBoard.dataWriter.dataFile.set(args.dir + '/calib_acq_width' +  '{:06d}'.format(args.acqWidth) + '_trbit' + '{:1d}'.format(trbit) + '_darkAutoMtoL.dat')
         ePixBoard.dataWriter.open.set(True)
         ePixBoard.Epix10ka.EpixFpgaRegisters.AutoRunEnable.set(True)
         time.sleep(20)
         ePixBoard.Epix10ka.EpixFpgaRegisters.AutoRunEnable.set(False)
         print('Close data file')
         ePixBoard.dataWriter.open.set(False)
         
   else:
      print('Directory %s does not exist'%args.dir)


# Close window and stop polling
ePixBoard.stop()
exit()


