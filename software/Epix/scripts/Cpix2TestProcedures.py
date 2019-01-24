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

try:
    from PyQt5.QtWidgets import *
    from PyQt5.QtCore    import *
    from PyQt5.QtGui     import *
except ImportError:
    from PyQt4.QtCore    import *
    from PyQt4.QtGui     import *


#################################################################

# helper function to read yaml settings and print them as register settings
def printAsic1AsyncModeRegisters():
   with open('yml/cpix2_ASIC1_testOnCounterA.yml') as f:
      # use safe_load instead load
      dataMap = yaml.safe_load(f)
      
   Cpix2FpgaRegisters = dataMap['ePixBoard']['Cpix2']['Cpix2FpgaRegisters']
   for key, value in Cpix2FpgaRegisters.items():
      print('ePixBoard.Cpix2.Cpix2FpgaRegisters.%s.set(%s)'%(key, value))

   TriggerRegisters  = dataMap['ePixBoard']['Cpix2']['TriggerRegisters']
   for key, value in TriggerRegisters.items():
      print('ePixBoard.Cpix2.TriggerRegisters.%s.set(%s)'%(key, value))

   Cpix2Asic1  = dataMap['ePixBoard']['Cpix2']['Cpix2Asic1']
   for key, value in Cpix2Asic1.items():
      print('ePixBoard.Cpix2.Cpix2Asic1.%s.set(%s)'%(key, value))

   Asic0Deserializer = dataMap['ePixBoard']['Cpix2']['Asic0Deserializer']
   for key, value in Asic0Deserializer.items():
      print('ePixBoard.Cpix2.Asic0Deserializer.%s.set(%s)'%(key, value))

   Asic1Deserializer = dataMap['ePixBoard']['Cpix2']['Asic1Deserializer']
   for key, value in Asic1Deserializer.items():
      print('ePixBoard.Cpix2.Asic1Deserializer.%s.set(%s)'%(key, value))

   Asic0PktRegisters = dataMap['ePixBoard']['Cpix2']['Asic0PktRegisters']
   for key, value in Asic0PktRegisters.items():
      print('ePixBoard.Cpix2.Asic0PktRegisters.%s.set(%s)'%(key, value))

   Asic1PktRegisters = dataMap['ePixBoard']['Cpix2']['Asic1PktRegisters']
   for key, value in Asic1PktRegisters.items():
      print('ePixBoard.Cpix2.Asic1PktRegisters.%s.set(%s)'%(key, value))


# unfold yaml settings to hardcode in case the file is lost
def setAsic1AsyncModeRegisters():
   ePixBoard.Cpix2.Cpix2FpgaRegisters.enable.set(True)
   ePixBoard.Cpix2.Cpix2FpgaRegisters.R0Polarity.set(True)
   ePixBoard.Cpix2.Cpix2FpgaRegisters.R0Delay.set(0)
   ePixBoard.Cpix2.Cpix2FpgaRegisters.R0Width.set(0)
   ePixBoard.Cpix2.Cpix2FpgaRegisters.GlblRstPolarity.set(True)
   ePixBoard.Cpix2.Cpix2FpgaRegisters.AcqPolarity.set(False)
   ePixBoard.Cpix2.Cpix2FpgaRegisters.AcqDelay1.set(6)
   ePixBoard.Cpix2.Cpix2FpgaRegisters.AcqWidth1.set(8)
   ePixBoard.Cpix2.Cpix2FpgaRegisters.EnAPattern.set(0x0)
   ePixBoard.Cpix2.Cpix2FpgaRegisters.EnAPolarity.set(True)
   ePixBoard.Cpix2.Cpix2FpgaRegisters.EnADelay.set(0)
   ePixBoard.Cpix2.Cpix2FpgaRegisters.EnAWidth.set(0)
   ePixBoard.Cpix2.Cpix2FpgaRegisters.ReqTriggerCnt.set(8)
   ePixBoard.Cpix2.Cpix2FpgaRegisters.EnAllFrames.set(False)
   ePixBoard.Cpix2.Cpix2FpgaRegisters.EnSingleFrame.set(False)
   ePixBoard.Cpix2.Cpix2FpgaRegisters.PPbePolarity.set(True)
   ePixBoard.Cpix2.Cpix2FpgaRegisters.PPbeDelay.set(0)
   ePixBoard.Cpix2.Cpix2FpgaRegisters.PPbeWidth.set(0)
   ePixBoard.Cpix2.Cpix2FpgaRegisters.PpmatPolarity.set(True)
   ePixBoard.Cpix2.Cpix2FpgaRegisters.PpmatDelay.set(0)
   ePixBoard.Cpix2.Cpix2FpgaRegisters.PpmatWidth.set(0)
   ePixBoard.Cpix2.Cpix2FpgaRegisters.FastSyncPolarity.set(False)
   ePixBoard.Cpix2.Cpix2FpgaRegisters.FastSyncDelay.set(0)
   ePixBoard.Cpix2.Cpix2FpgaRegisters.FastSyncWidth.set(0)
   ePixBoard.Cpix2.Cpix2FpgaRegisters.SyncPolarity.set(False)
   ePixBoard.Cpix2.Cpix2FpgaRegisters.SyncDelay.set(1000000)
   ePixBoard.Cpix2.Cpix2FpgaRegisters.SyncWidth.set(1)
   ePixBoard.Cpix2.Cpix2FpgaRegisters.SaciSyncPolarity.set(False)
   ePixBoard.Cpix2.Cpix2FpgaRegisters.SaciSyncDelay.set(0)
   ePixBoard.Cpix2.Cpix2FpgaRegisters.SaciSyncWidth.set(0)
   ePixBoard.Cpix2.Cpix2FpgaRegisters.SR0Polarity.set(False)
   ePixBoard.Cpix2.Cpix2FpgaRegisters.SR0Delay1.set(10000)
   ePixBoard.Cpix2.Cpix2FpgaRegisters.SR0Width1.set(5)
   ePixBoard.Cpix2.Cpix2FpgaRegisters.SR0Delay2.set(300000)
   ePixBoard.Cpix2.Cpix2FpgaRegisters.SR0Width2.set(5)
   ePixBoard.Cpix2.Cpix2FpgaRegisters.SerialReSyncPolarity.set(False)
   ePixBoard.Cpix2.Cpix2FpgaRegisters.SerialReSyncDelay.set(0)
   ePixBoard.Cpix2.Cpix2FpgaRegisters.SerialReSyncWidth.set(0)
   ePixBoard.Cpix2.Cpix2FpgaRegisters.Vid.set(1)
   ePixBoard.Cpix2.Cpix2FpgaRegisters.AsicWfEnOut.set(0x1fff)
   ePixBoard.Cpix2.Cpix2FpgaRegisters.ResetCounters.set(False)
   ePixBoard.Cpix2.Cpix2FpgaRegisters.AsicPwrEnable.set(True)
   ePixBoard.Cpix2.Cpix2FpgaRegisters.AsicPwrManual.set(True)
   ePixBoard.Cpix2.Cpix2FpgaRegisters.AsicPwrManualDig.set(True)
   ePixBoard.Cpix2.Cpix2FpgaRegisters.AsicPwrManualAna.set(True)
   ePixBoard.Cpix2.Cpix2FpgaRegisters.AsicPwrManualIo.set(True)
   ePixBoard.Cpix2.Cpix2FpgaRegisters.AsicPwrManualFpga.set(True)
   ePixBoard.Cpix2.Cpix2FpgaRegisters.VguardDacSetting.set(0)
   ePixBoard.Cpix2.Cpix2FpgaRegisters.Cpix2DebugSel1.set(0)
   ePixBoard.Cpix2.Cpix2FpgaRegisters.Cpix2DebugSel2.set(0)
   ePixBoard.Cpix2.Cpix2FpgaRegisters.AdcClkHalfT.set(1)
   ePixBoard.Cpix2.Cpix2FpgaRegisters.StartupReq.set(False)
   ePixBoard.Cpix2.TriggerRegisters.enable.set(True)
   ePixBoard.Cpix2.TriggerRegisters.RunTriggerEnable.set(True)
   ePixBoard.Cpix2.TriggerRegisters.RunTriggerDelay.set(0)
   ePixBoard.Cpix2.TriggerRegisters.DaqTriggerEnable.set(False)
   ePixBoard.Cpix2.TriggerRegisters.DaqTriggerDelay.set(0)
   ePixBoard.Cpix2.TriggerRegisters.AutoRunEn.set(True)
   ePixBoard.Cpix2.TriggerRegisters.AutoDaqEn.set(True)
   ePixBoard.Cpix2.TriggerRegisters.AutoTrigPeriod.set(480)
   ePixBoard.Cpix2.TriggerRegisters.PgpTrigEn.set(False)
   ePixBoard.Cpix2.TriggerRegisters.AcqCountReset.set(False)
   ePixBoard.Cpix2.Cpix2Asic1.enable.set(True)
   ePixBoard.Cpix2.Cpix2Asic1.CompTH1_DAC.set(31)
   ePixBoard.Cpix2.Cpix2Asic1.PulserSync.set(True)
   ePixBoard.Cpix2.Cpix2Asic1.PLL_RO_Reset.set(False)
   ePixBoard.Cpix2.Cpix2Asic1.PLL_RO_Itune.set(2)
   ePixBoard.Cpix2.Cpix2Asic1.PLL_RO_KVCO.set(4)
   ePixBoard.Cpix2.Cpix2Asic1.PLL_RO_filt1a.set(True)
   ePixBoard.Cpix2.Cpix2Asic1.Pulser.set(0)
   ePixBoard.Cpix2.Cpix2Asic1.Pbit.set(False)
   ePixBoard.Cpix2.Cpix2Asic1.atest.set(False)
   ePixBoard.Cpix2.Cpix2Asic1.test.set(True)
   ePixBoard.Cpix2.Cpix2Asic1.Sba_test.set(False)
   ePixBoard.Cpix2.Cpix2Asic1.Hrtest.set(False)
   ePixBoard.Cpix2.Cpix2Asic1.PulserR.set(False)
   ePixBoard.Cpix2.Cpix2Asic1.DM1.set(2)
   ePixBoard.Cpix2.Cpix2Asic1.DM2.set(2)
   ePixBoard.Cpix2.Cpix2Asic1.Pulser_DAC.set(3)
   ePixBoard.Cpix2.Cpix2Asic1.Monost_Pulser.set(7)
   ePixBoard.Cpix2.Cpix2Asic1.DM1en.set(True)
   ePixBoard.Cpix2.Cpix2Asic1.DM2en.set(True)
   ePixBoard.Cpix2.Cpix2Asic1.emph_bd.set(4)
   ePixBoard.Cpix2.Cpix2Asic1.emph_bc.set(0)
   ePixBoard.Cpix2.Cpix2Asic1.VREF_DAC.set(8)
   ePixBoard.Cpix2.Cpix2Asic1.VrefLow.set(3)
   ePixBoard.Cpix2.Cpix2Asic1.TPS_MUX.set(0)
   ePixBoard.Cpix2.Cpix2Asic1.RO_Monost.set(3)
   ePixBoard.Cpix2.Cpix2Asic1.TPS_GR.set(3)
   ePixBoard.Cpix2.Cpix2Asic1.cout.set(False)
   ePixBoard.Cpix2.Cpix2Asic1.ckc.set(False)
   ePixBoard.Cpix2.Cpix2Asic1.mod.set(True)
   ePixBoard.Cpix2.Cpix2Asic1.PP_OCB_S2D.set(True)
   ePixBoard.Cpix2.Cpix2Asic1.OCB.set(3)
   ePixBoard.Cpix2.Cpix2Asic1.Monost.set(3)
   ePixBoard.Cpix2.Cpix2Asic1.fastPP_enable.set(True)
   ePixBoard.Cpix2.Cpix2Asic1.Preamp.set(5)
   ePixBoard.Cpix2.Cpix2Asic1.Pixel_FB.set(0)
   ePixBoard.Cpix2.Cpix2Asic1.Vld1_b.set(1)
   ePixBoard.Cpix2.Cpix2Asic1.CompTH2_DAC.set(0)
   ePixBoard.Cpix2.Cpix2Asic1.Vtrim_b.set(3)
   ePixBoard.Cpix2.Cpix2Asic1.tc.set(0)
   ePixBoard.Cpix2.Cpix2Asic1.S2D.set(3)
   ePixBoard.Cpix2.Cpix2Asic1.S2D_DAC_Bias.set(3)
   ePixBoard.Cpix2.Cpix2Asic1.TPS_DAC.set(17)
   ePixBoard.Cpix2.Cpix2Asic1.PLL_RO_filt1b.set(2)
   ePixBoard.Cpix2.Cpix2Asic1.PLL_RO_filter2.set(2)
   ePixBoard.Cpix2.Cpix2Asic1.PLL_RO_divider.set(0)
   ePixBoard.Cpix2.Cpix2Asic1.test_BE.set(False)
   ePixBoard.Cpix2.Cpix2Asic1.DigRO_disable.set(False)
   ePixBoard.Cpix2.Cpix2Asic1.DelEXEC.set(False)
   ePixBoard.Cpix2.Cpix2Asic1.DelCCKreg.set(False)
   ePixBoard.Cpix2.Cpix2Asic1.RO_rst_en.set(True)
   ePixBoard.Cpix2.Cpix2Asic1.SLVDSbit.set(True)
   ePixBoard.Cpix2.Cpix2Asic1.Pix_Count_T.set(True)
   ePixBoard.Cpix2.Cpix2Asic1.Pix_Count_sel.set(False)
   ePixBoard.Cpix2.Cpix2Asic1.RowStop.set(47)
   ePixBoard.Cpix2.Cpix2Asic1.ColumnStop.set(47)
   #ePixBoard.Cpix2.Cpix2Asic1.CHIP ID.set(0)
   ePixBoard.Cpix2.Cpix2Asic1.DCycle_DAC.set(25)
   ePixBoard.Cpix2.Cpix2Asic1.DCycle_en.set(True)
   ePixBoard.Cpix2.Cpix2Asic1.DCycle_bypass.set(False)
   ePixBoard.Cpix2.Cpix2Asic1.MSBCompTH1_DAC.set(4)
   ePixBoard.Cpix2.Cpix2Asic1.MSBCompTH2_DAC.set(14)
   ePixBoard.Cpix2.Asic0Deserializer.enable.set(True)
   ePixBoard.Cpix2.Asic0Deserializer.Resync.set(False)
   ePixBoard.Cpix2.Asic0Deserializer.SerDesDelay.set(10)
   ePixBoard.Cpix2.Asic0Deserializer.DelayEn.set(True)
   ePixBoard.Cpix2.Asic1Deserializer.enable.set(True)
   ePixBoard.Cpix2.Asic1Deserializer.Resync.set(False)
   ePixBoard.Cpix2.Asic1Deserializer.SerDesDelay.set(10)
   ePixBoard.Cpix2.Asic1Deserializer.DelayEn.set(True)
   ePixBoard.Cpix2.Asic0PktRegisters.enable.set(True)
   ePixBoard.Cpix2.Asic0PktRegisters.TestMode.set(False)
   ePixBoard.Cpix2.Asic0PktRegisters.ResetCounters.set(False)
   ePixBoard.Cpix2.Asic1PktRegisters.enable.set(True)
   ePixBoard.Cpix2.Asic1PktRegisters.TestMode.set(False)
   ePixBoard.Cpix2.Asic1PktRegisters.ResetCounters.set(False)

def asic1SetPixel(x, y, val):
   ePixBoard.Cpix2.Cpix2Asic1.RowCounter.set(y)
   ePixBoard.Cpix2.Cpix2Asic1.ColCounter.set(x)
   ePixBoard.Cpix2.Cpix2Asic1.WritePixelData.set(val)
   print('Set ASIC 1 pixel (%d, %d) to %d'%(x,y,val))
   


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

# Get the arguments
args = parser.parse_args()

#################################################################


if ( args.type == 'pgp-gen3' ):
    # Create the PGP interfaces for ePix camera
    pgpVc0 = rogue.hardware.pgp.PgpCard(args.pgp,args.l,0) # Data & cmds
    pgpVc1 = rogue.hardware.pgp.PgpCard(args.pgp,args.l,1) # Registers for ePix board
    pgpVc2 = rogue.hardware.pgp.PgpCard(args.pgp,args.l,2) # PseudoScope
    pgpVc3 = rogue.hardware.pgp.PgpCard(args.pgp,args.l,3) # Monitoring (Slow ADC)
    print("PGP Card Version: %x" % (pgpVc0.getInfo().version))
elif ( args.type == 'kcu1500' ):
    # Create the PGP interfaces for ePix hr camera
    pgpVc0 = rogue.hardware.data.DataCard(args.pgp,(0*32)+0) # Data & cmds
    pgpVc1 = rogue.hardware.data.DataCard(args.pgp,(0*32)+1) # Registers for ePix board
    pgpVc2 = rogue.hardware.data.DataCard(args.pgp,(0*32)+2) # PseudoScope
    pgpVc3 = rogue.hardware.data.DataCard(args.pgp,(0*32)+3) # Monitoring (Slow ADC)
elif ( args.type == 'simulation' ):
    pgpVc0 = pr.interfaces.simulation.StreamSim(host='localhost', dest=0, uid=2, ssi=True)
    pgpVc1 = pr.interfaces.simulation.StreamSim(host='localhost', dest=1, uid=2, ssi=True)
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
        pyrogue.RunControl.__init__(self,name,'Run Controller Cpix2',  rates={1:'1 Hz', 2:'2 Hz', 4:'4 Hz', 8:'8 Hz', 10:'10 Hz', 30:'30 Hz', 60:'60 Hz', 120:'120 Hz'})
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

        while (self.runState.get(read=False) == 'Running'): 
            delay = 1.0 / ({value: key for key,value in self.runRate.enum.items()}[self._runRate]) 
            time.sleep(delay) 
            #self._root.ssiPrbsTx.oneShot() 
            cmd.sendCmd(0, 0)
  
            self._runCount += 1 
            if self._last != int(time.time()): 
                self._last = int(time.time()) 
                self.runCount._updated() 
            
##############################
# Set base
##############################
class EpixBoard(pyrogue.Root):
    def __init__(self, guiTop, cmd, dataWriter, srp, **kwargs):
        super().__init__(name = 'ePixBoard', description = 'Cpix2 Board', **kwargs)
        self.add(dataWriter)
        self.guiTop = guiTop

        # Add Devices
        self.add(fpga.Cpix2(name='Cpix2', offset=0, memBase=srp, hidden=False, enabled=True))

        @self.command()
        def Trigger():       
            self.Cpix2.Cpix2FpgaRegisters.EnSingleFrame.post(True)
            #pulserAmpliture = self.Cpix2.Cpix2Asic1.Pulser.get()
            #if pulserAmpliture == 1023:
            #    pulserAmpliture = 0
            #else:
            #    pulserAmpliture += 1
            #self.Cpix2.Cpix2Asic1.Pulser.set(pulserAmpliture)
            self.runControl.runCount.set(self.runControl.runCount.get()) 
            #print("run control", self.runControl.runCount.get())


        self.add(pyrogue.RunControl(name = 'runControl', description='Run Controller cPix2', cmd=self.Trigger, rates={1:'1 Hz', 2:'2 Hz', 4:'4 Hz', 8:'8 Hz', 10:'10 Hz', 30:'30 Hz', 60:'60 Hz', 120:'120 Hz'}))
        #set timeout value
        #self.setTimeout(10)

        


# Create GUI
appTop = QApplication(sys.argv)
#guiTop = pyrogue.gui.GuiTop(group = 'Cpix2Gui')
#ePixBoard = EpixBoard(guiTop, cmd, dataWriter, srp)
ePixBoard = EpixBoard(0, cmd, dataWriter, srp)
ePixBoard.start(pollEn=args.pollEn, initRead = args.initRead, timeout=3.0)


# simple pulser scan for my purpose
if args.test == 1:
   
   if os.path.isdir(args.dir):
      
      print('Setting camera registers')
      setAsic1AsyncModeRegisters()
      
      acqTime = ePixBoard.Cpix2.TriggerRegisters.AutoTrigPeriod.get() * 10 * ePixBoard.Cpix2.Cpix2FpgaRegisters.ReqTriggerCnt.get()
      print('Acquisition time set is %d ns' %acqTime)
      rdoutTime = (
         ePixBoard.Cpix2.Cpix2FpgaRegisters.SR0Delay1.get() +
         ePixBoard.Cpix2.Cpix2FpgaRegisters.SR0Width1.get() +
         ePixBoard.Cpix2.Cpix2FpgaRegisters.SR0Delay2.get() +
         ePixBoard.Cpix2.Cpix2FpgaRegisters.SR0Width2.get()) * 10 * 2
      print('Readout time set is %d ns' %rdoutTime)
      syncTime = (
         ePixBoard.Cpix2.Cpix2FpgaRegisters.SyncDelay.get() +
         ePixBoard.Cpix2.Cpix2FpgaRegisters.SyncWidth.get()) * 10
      print('Sync time set is %d ns' %syncTime)
      saciSyncTime = (
         ePixBoard.Cpix2.Cpix2FpgaRegisters.SaciSyncDelay.get() +
         ePixBoard.Cpix2.Cpix2FpgaRegisters.SaciSyncWidth.get()) * 10
      print('SACI sync time set is %d ns' %saciSyncTime)
      totalTime = acqTime + max([rdoutTime, syncTime, saciSyncTime])
      totalTimeSec = (totalTime*1e-9)
      print('Total time set is %f seconds' %totalTimeSec)
      print('Maximum frame rate is %f fps' %(1.0/totalTimeSec))
      
      
      # resync ASIC
      print('Synchronizing ASIC 1')
      rsyncTry = 1
      ePixBoard.Cpix2.Asic1Deserializer.Resync.set(True)
      time.sleep(1)
      while rsyncTry < 10 and ePixBoard.Cpix2.Asic1Deserializer.Locked.get() == False:
         rsyncTry = rsyncTry + 1
         ePixBoard.Cpix2.Asic1Deserializer.Resync.set(True)
         time.sleep(1)
      if ePixBoard.Cpix2.Asic1Deserializer.Locked.get() == False:
         print('Failed to synchronize ASIC 1 after %d tries'%rsyncTry)
         exit()
      else:
         print('ASIC 1 synchronized after %d tries'%rsyncTry)
      
      print('Clearing ASIC 1 matrix')
      ePixBoard.Cpix2.Cpix2Asic1.ClearMatrix()
      print('Setting ASIC 1 pixel region to test')
      for x in range(2,5):
         for y in range(2,5):
            asic1SetPixel(x, y, 1)
      
      print('Open data file')
      ePixBoard.dataWriter.dataFile.set(args.dir + '/test12345.dat')
      ePixBoard.dataWriter.open.set(True)
      
      print('Run acquisition and save data')
      for pulserVal in range(1024):
         ePixBoard.Cpix2.Cpix2Asic1.Pulser.set(pulserVal)
         time.sleep(totalTimeSec+totalTimeSec*0.1)
         ePixBoard.Trigger()
      
      print('Close data file')
      ePixBoard.dataWriter.open.set(False)
   
   else:
      print('Directory %s does not exist'%args.dir)
   

# threshold TH1 scan on noise
if args.test == 2:
   
   framesPerThreshold = 20
   
   
   if os.path.isdir(args.dir):
      
      print('Setting camera registers')
      setAsic1AsyncModeRegisters()
      
      acqTime = ePixBoard.Cpix2.TriggerRegisters.AutoTrigPeriod.get() * 10 * ePixBoard.Cpix2.Cpix2FpgaRegisters.ReqTriggerCnt.get()
      print('Acquisition time set is %d ns' %acqTime)
      rdoutTime = (
         ePixBoard.Cpix2.Cpix2FpgaRegisters.SR0Delay1.get() +
         ePixBoard.Cpix2.Cpix2FpgaRegisters.SR0Width1.get() +
         ePixBoard.Cpix2.Cpix2FpgaRegisters.SR0Delay2.get() +
         ePixBoard.Cpix2.Cpix2FpgaRegisters.SR0Width2.get()) * 10 * 2
      print('Readout time set is %d ns' %rdoutTime)
      syncTime = (
         ePixBoard.Cpix2.Cpix2FpgaRegisters.SyncDelay.get() +
         ePixBoard.Cpix2.Cpix2FpgaRegisters.SyncWidth.get()) * 10
      print('Sync time set is %d ns' %syncTime)
      saciSyncTime = (
         ePixBoard.Cpix2.Cpix2FpgaRegisters.SaciSyncDelay.get() +
         ePixBoard.Cpix2.Cpix2FpgaRegisters.SaciSyncWidth.get()) * 10
      print('SACI sync time set is %d ns' %saciSyncTime)
      totalTime = acqTime + max([rdoutTime, syncTime, saciSyncTime])
      totalTimeSec = (totalTime*1e-9)
      print('Total time set is %f seconds' %totalTimeSec)
      print('Maximum frame rate is %f fps' %(1.0/totalTimeSec))
      
      
      # resync ASIC
      print('Synchronizing ASIC 1')
      rsyncTry = 1
      ePixBoard.Cpix2.Asic1Deserializer.Resync.set(True)
      time.sleep(1)
      while rsyncTry < 10 and ePixBoard.Cpix2.Asic1Deserializer.Locked.get() == False:
         rsyncTry = rsyncTry + 1
         ePixBoard.Cpix2.Asic1Deserializer.Resync.set(True)
         time.sleep(1)
      if ePixBoard.Cpix2.Asic1Deserializer.Locked.get() == False:
         print('Failed to synchronize ASIC 1 after %d tries'%rsyncTry)
         exit()
      else:
         print('ASIC 1 synchronized after %d tries'%rsyncTry)
      
      print('Clearing ASIC 1 matrix')
      ePixBoard.Cpix2.Cpix2Asic1.ClearMatrix()
      
      print('Disabling pulser')
      ePixBoard.Cpix2.Cpix2Asic1.Pulser.set(0)
      ePixBoard.Cpix2.Cpix2Asic1.test.set(False)
      ePixBoard.Cpix2.Cpix2Asic1.atest.set(False)
      
      print('Setting TH2 to maximum')
      ePixBoard.Cpix2.Cpix2Asic1.MSBCompTH2_DAC.set(15) # 4 bit corse
      ePixBoard.Cpix2.Cpix2Asic1.CompTH2_DAC.set(63) # 6 bit fine
      
      print('Setting TH1 to minimum')
      ePixBoard.Cpix2.Cpix2Asic1.MSBCompTH1_DAC.set(0) # 4 bit corse
      ePixBoard.Cpix2.Cpix2Asic1.CompTH1_DAC.set(0) # 6 bit fine
      
      # dummy readout to flush
      time.sleep(totalTimeSec+totalTimeSec*0.1)
      ePixBoard.Trigger()
      
      
      for th1Msb in range(16):
         for th1Lsb in range(64):
            print('Acquiring %d frames with TH1Msb=%d, TH1Lsb=%d' %(framesPerThreshold, th1Msb, th1Lsb))
            ePixBoard.dataWriter.dataFile.set(args.dir + '/TH1MSB' + '{:02d}'.format(th1Msb) + '_TH1LSB' + '{:02d}'.format(th1Lsb) + '.dat')
            ePixBoard.dataWriter.open.set(True)
            for frm in range(framesPerThreshold+1):
               ePixBoard.Cpix2.Cpix2Asic1.MSBCompTH1_DAC.set(th1Msb) # 4 bit corse
               ePixBoard.Cpix2.Cpix2Asic1.CompTH1_DAC.set(th1Lsb) # 6 bit fine
               time.sleep(totalTimeSec+totalTimeSec*0.1)
               ePixBoard.Trigger()
            ePixBoard.dataWriter.open.set(False)
   
   else:
      print('Directory %s does not exist'%args.dir)
      

# Close window and stop polling
ePixBoard.stop()
exit()


