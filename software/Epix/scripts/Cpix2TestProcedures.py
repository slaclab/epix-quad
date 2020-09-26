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
import testBridge
import ePixViewer as vi
import ePixFpga as fpga
import os
import datetime
from datetime import datetime
import numpy as np

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
      print('ePixBoard.Cpix2.Cpix2Asic.%s.set(%s)'%(key, value))

   Asic0Deserializer = dataMap['ePixBoard']['Cpix2']['Asic0Deserializer']
   for key, value in Asic0Deserializer.items():
      print('ePixBoard.Cpix2.Asic0Deserializer.%s.set(%s)'%(key, value))

   AsicDeserializer = dataMap['ePixBoard']['Cpix2']['AsicDeserializer']
   for key, value in AsicDeserializer.items():
      print('AsicDeserializer.%s.set(%s)'%(key, value))

   Asic0PktRegisters = dataMap['ePixBoard']['Cpix2']['Asic0PktRegisters']
   for key, value in Asic0PktRegisters.items():
      print('ePixBoard.Cpix2.Asic0PktRegisters.%s.set(%s)'%(key, value))

   Asic1PktRegisters = dataMap['ePixBoard']['Cpix2']['Asic1PktRegisters']
   for key, value in Asic1PktRegisters.items():
      print('ePixBoard.Cpix2.Asic1PktRegisters.%s.set(%s)'%(key, value))


# unfold yaml settings to hardcode in case the file is lost
def setAsicAsyncModeRegisters():
   ePixBoard.Cpix2.Cpix2FpgaRegisters.enable.set(True)
   ePixBoard.Cpix2.Cpix2FpgaRegisters.R0Polarity.set(True)
   ePixBoard.Cpix2.Cpix2FpgaRegisters.R0Delay.set(0)
   ePixBoard.Cpix2.Cpix2FpgaRegisters.R0Width.set(0)
   ePixBoard.Cpix2.Cpix2FpgaRegisters.GlblRstPolarity.set(True)
   ePixBoard.Cpix2.Cpix2FpgaRegisters.AcqPolarity.set(False)
   ePixBoard.Cpix2.Cpix2FpgaRegisters.AcqDelay1.set(6)
   ePixBoard.Cpix2.Cpix2FpgaRegisters.AcqWidth1.set(8)

   ePixBoard.Cpix2.Cpix2FpgaRegisters.EnAPattern.set(0xffffffff)
   ePixBoard.Cpix2.Cpix2FpgaRegisters.EnAPolarity.set(True)
   ePixBoard.Cpix2.Cpix2FpgaRegisters.EnADelay.set(0)
   ePixBoard.Cpix2.Cpix2FpgaRegisters.EnAWidth.set(0)

   ePixBoard.Cpix2.Cpix2FpgaRegisters.EnBPattern.set(0xffffffff)
   ePixBoard.Cpix2.Cpix2FpgaRegisters.EnBPolarity.set(True)
   ePixBoard.Cpix2.Cpix2FpgaRegisters.EnBDelay.set(0)
   ePixBoard.Cpix2.Cpix2FpgaRegisters.EnBWidth.set(0)

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
   Cpix2Asic.enable.set(True)
   Cpix2Asic.CompTH1_DAC.set(31)
   Cpix2Asic.PulserSync.set(True)
   Cpix2Asic.PLL_RO_Reset.set(False)
   Cpix2Asic.PLL_RO_Itune.set(2)
   Cpix2Asic.PLL_RO_KVCO.set(4)
   Cpix2Asic.PLL_RO_filt1a.set(True)
   Cpix2Asic.Pulser.set(0)
   Cpix2Asic.Pbit.set(False)
   Cpix2Asic.atest.set(False)
   Cpix2Asic.test.set(True)
   Cpix2Asic.Sba_test.set(False)
   Cpix2Asic.Hrtest.set(False)
   Cpix2Asic.PulserR.set(False)
   Cpix2Asic.DM1.set(2)
   Cpix2Asic.DM2.set(2)
   Cpix2Asic.Pulser_DAC.set(3)
   Cpix2Asic.Monost_Pulser.set(7)
   Cpix2Asic.DM1en.set(True)
   Cpix2Asic.DM2en.set(True)
   Cpix2Asic.emph_bd.set(4)
   Cpix2Asic.emph_bc.set(0)
   Cpix2Asic.VREF_DAC.set(8)
   Cpix2Asic.VrefLow.set(3)
   Cpix2Asic.TPS_MUX.set(0)
   Cpix2Asic.RO_Monost.set(3)
   Cpix2Asic.TPS_GR.set(3)
   Cpix2Asic.cout.set(False)   # False - do not concatenate counters
   Cpix2Asic.ckc.set(True)     # True - count over TH1 in counter A and over Th2 in counter B
   Cpix2Asic.mod.set(True)     # True - asynchronous mode
   Cpix2Asic.PP_OCB_S2D.set(True)
   Cpix2Asic.OCB.set(3)
   Cpix2Asic.Monost.set(3)
   Cpix2Asic.fastPP_enable.set(True)
   Cpix2Asic.Preamp.set(5)
   Cpix2Asic.Pixel_FB.set(0)
   Cpix2Asic.Vld1_b.set(1)
   Cpix2Asic.CompTH2_DAC.set(0)
   Cpix2Asic.Vtrim_b.set(3)
   Cpix2Asic.tc.set(0)
   Cpix2Asic.S2D.set(3)
   Cpix2Asic.S2D_DAC_Bias.set(3)
   Cpix2Asic.TPS_DAC.set(17)
   Cpix2Asic.PLL_RO_filt1b.set(2)
   Cpix2Asic.PLL_RO_filter2.set(2)
   Cpix2Asic.PLL_RO_divider.set(0)
   Cpix2Asic.test_BE.set(False)
   Cpix2Asic.DigRO_disable.set(False)
   Cpix2Asic.DelEXEC.set(False)
   Cpix2Asic.DelCCKreg.set(False)
   Cpix2Asic.RO_rst_en.set(True)
   Cpix2Asic.SLVDSbit.set(True)
   Cpix2Asic.Pix_Count_T.set(True)
   Cpix2Asic.Pix_Count_sel.set(False)
   Cpix2Asic.RowStop.set(47)
   Cpix2Asic.ColumnStop.set(47)
   #Cpix2Asic.CHIP ID.set(0)
   Cpix2Asic.DCycle_DAC.set(25)
   Cpix2Asic.DCycle_en.set(True)
   Cpix2Asic.DCycle_bypass.set(False)
   Cpix2Asic.MSBCompTH1_DAC.set(4)
   Cpix2Asic.MSBCompTH2_DAC.set(14)

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


# unfold yaml settings to hardcode in case the file is lost
def setAsicSyncModeRegisters():
   ePixBoard.Cpix2.Cpix2FpgaRegisters.enable.set(True)
   ePixBoard.Cpix2.Cpix2FpgaRegisters.R0Polarity.set(False)
   ePixBoard.Cpix2.Cpix2FpgaRegisters.R0Delay.set(4)
   ePixBoard.Cpix2.Cpix2FpgaRegisters.R0Width.set(16)
   ePixBoard.Cpix2.Cpix2FpgaRegisters.GlblRstPolarity.set(True)
   ePixBoard.Cpix2.Cpix2FpgaRegisters.AcqPolarity.set(False)
   ePixBoard.Cpix2.Cpix2FpgaRegisters.AcqDelay1.set(6)
   ePixBoard.Cpix2.Cpix2FpgaRegisters.AcqWidth1.set(8)

   ePixBoard.Cpix2.Cpix2FpgaRegisters.EnAPattern.set(0xffffffff)
   ePixBoard.Cpix2.Cpix2FpgaRegisters.EnAPolarity.set(True)
   ePixBoard.Cpix2.Cpix2FpgaRegisters.EnADelay.set(4)
   ePixBoard.Cpix2.Cpix2FpgaRegisters.EnAWidth.set(4)

   ePixBoard.Cpix2.Cpix2FpgaRegisters.EnBPattern.set(0xffffffff)
   ePixBoard.Cpix2.Cpix2FpgaRegisters.EnBPolarity.set(True)
   ePixBoard.Cpix2.Cpix2FpgaRegisters.EnBDelay.set(4)
   ePixBoard.Cpix2.Cpix2FpgaRegisters.EnBWidth.set(4)

   ePixBoard.Cpix2.Cpix2FpgaRegisters.ReqTriggerCnt.set(1000)
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
   Cpix2Asic.enable.set(True)
   Cpix2Asic.CompTH1_DAC.set(31)
   Cpix2Asic.PulserSync.set(True)
   Cpix2Asic.PLL_RO_Reset.set(False)
   Cpix2Asic.PLL_RO_Itune.set(2)
   Cpix2Asic.PLL_RO_KVCO.set(4)
   Cpix2Asic.PLL_RO_filt1a.set(True)
   Cpix2Asic.Pulser.set(0)
   Cpix2Asic.Pbit.set(False)
   Cpix2Asic.atest.set(False)
   Cpix2Asic.test.set(True)
   Cpix2Asic.Sba_test.set(False)
   Cpix2Asic.Hrtest.set(False)
   Cpix2Asic.PulserR.set(False)
   Cpix2Asic.DM1.set(2)
   Cpix2Asic.DM2.set(2)
   Cpix2Asic.Pulser_DAC.set(3)
   Cpix2Asic.Monost_Pulser.set(7)
   Cpix2Asic.DM1en.set(True)
   Cpix2Asic.DM2en.set(True)
   Cpix2Asic.emph_bd.set(4)
   Cpix2Asic.emph_bc.set(0)
   Cpix2Asic.VREF_DAC.set(8)
   Cpix2Asic.VrefLow.set(3)
   Cpix2Asic.TPS_MUX.set(0)
   Cpix2Asic.RO_Monost.set(3)
   Cpix2Asic.TPS_GR.set(3)
   Cpix2Asic.cout.set(False)   # False - do not concatenate counters
   Cpix2Asic.ckc.set(True)     # True - count over TH1 in counter A and over Th2 in counter B
   Cpix2Asic.mod.set(False)    # False - synchronous mode
   Cpix2Asic.PP_OCB_S2D.set(True)
   Cpix2Asic.OCB.set(3)
   Cpix2Asic.Monost.set(3)
   Cpix2Asic.fastPP_enable.set(True)
   Cpix2Asic.Preamp.set(5)
   Cpix2Asic.Pixel_FB.set(0)
   Cpix2Asic.Vld1_b.set(1)
   Cpix2Asic.CompTH2_DAC.set(0)
   Cpix2Asic.Vtrim_b.set(3)
   Cpix2Asic.tc.set(0)
   Cpix2Asic.S2D.set(3)
   Cpix2Asic.S2D_DAC_Bias.set(3)
   Cpix2Asic.TPS_DAC.set(17)
   Cpix2Asic.PLL_RO_filt1b.set(2)
   Cpix2Asic.PLL_RO_filter2.set(2)
   Cpix2Asic.PLL_RO_divider.set(0)
   Cpix2Asic.test_BE.set(False)
   Cpix2Asic.DigRO_disable.set(False)
   Cpix2Asic.DelEXEC.set(False)
   Cpix2Asic.DelCCKreg.set(False)
   Cpix2Asic.RO_rst_en.set(True)
   Cpix2Asic.SLVDSbit.set(True)
   Cpix2Asic.Pix_Count_T.set(True)
   Cpix2Asic.Pix_Count_sel.set(False)
   Cpix2Asic.RowStop.set(47)
   Cpix2Asic.ColumnStop.set(47)
   #Cpix2Asic.CHIP ID.set(0)
   Cpix2Asic.DCycle_DAC.set(25)
   Cpix2Asic.DCycle_en.set(True)
   Cpix2Asic.DCycle_bypass.set(False)
   Cpix2Asic.MSBCompTH1_DAC.set(4)
   Cpix2Asic.MSBCompTH2_DAC.set(14)

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
   addrSize=4
   Cpix2Asic.ColCounter.set(y)
   Cpix2Asic.RowCounter.set(x)
   Cpix2Asic.PixelData.set(val)
   print('Set ASIC pixel (%d, %d) to %d'%(x,y,val))

def asic1ModifyBitPixel(x, y, val, offset, size):
   addrSize=4
   mask = (2**size-1)<<offset
   Cpix2Asic.ColCounter.set(y)
   Cpix2Asic.RowCounter.set(x)
   pix = Cpix2Asic.PixelData.get()
   pix = pix & (~mask & 0xFF)
   pix = pix | ((val<<offset) & mask)
   Cpix2Asic.PixelData.set(pix)
   print('Set ASIC pixel (%d, %d) to %d'%(x,y,pix))

def setAsicMatrixMaskGrid22(x, y):
   addrSize=4
   Cpix2Asic.CmdPrepForRead()
   Cpix2Asic.PrepareMultiConfig()
   for i in range(48):
      for j in range(48):
         if (i % 2 == x) and (j % 2 == y):
            pass
         else:
            asic1ModifyBitPixel(i, j, 1, 1, 1)
   Cpix2Asic.CmdPrepForRead()

def setAsic1MatrixGrid66(x, y):
   addrSize=4
   Cpix2Asic.CmdPrepForRead()
   Cpix2Asic.PrepareMultiConfig()
   for i in range(48):
      for j in range(48):
         if (i % 6 == x) and (j % 6 == y):
            asic1ModifyBitPixel(i, j, 1, 0, 1)
   Cpix2Asic.CmdPrepForRead()

def setAsic1MatrixGrid88(x, y):
   addrSize=4
   Cpix2Asic.CmdPrepForRead()
   Cpix2Asic.PrepareMultiConfig()
   for i in range(48):
      for j in range(48):
         if (i % 8 == x) and (j % 8 == y):
            asic1ModifyBitPixel(i, j, 1, 0, 1)
   Cpix2Asic.CmdPrepForRead()

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
    "--trim",
    type     = str,
    required = False,
    default  = ' ',
    help     = "Trim bits csv file",
)

parser.add_argument(
    "--asic",
    type     = int,
    required = False,
    default  = 0,
    help     = "ASIC number",
)

parser.add_argument(
    "--framesPerThreshold",
    type     = int,
    required = False,
    default  = 10,
    help     = "Test 11: number of frames per threshold",
)

parser.add_argument(
    "--thStart",
    type     = int,
    required = False,
    default  = 300,
    help     = "Test 11: first threshold",
)

parser.add_argument(
    "--thStop",
    type     = int,
    required = False,
    default  = 400,
    help     = "Test 11: last threshold",
)

parser.add_argument(
    "--c",
    type     = str,
    required = False,
    default  = './',
    help     = "Configuration yml file",
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
         #pulserAmpliture = self.Cpix2.Cpix2Asic.Pulser.get()
         #if pulserAmpliture == 1023:
         #    pulserAmpliture = 0
         #else:
         #    pulserAmpliture += 1
         #self.Cpix2.Cpix2Asic.Pulser.set(pulserAmpliture)
         self.runControl.runCount.set(self.runControl.runCount.get())
         #print("run control", self.runControl.runCount.get())


      self.add(pyrogue.RunControl(name = 'runControl', description='Run Controller cPix2', cmd=self.Trigger, rates={1:'1 Hz', 2:'2 Hz', 4:'4 Hz', 8:'8 Hz', 10:'10 Hz', 30:'30 Hz', 60:'60 Hz', 120:'120 Hz'}))
      #set timeout value
      #self.setTimeout(10)


################################################################################
#   Event reader class
#
################################################################################
class ImgProc(rogue.interfaces.stream.Slave):
   """retrieves data from a file using rogue utilities services"""

   def __init__(self, reqFrames) :
      rogue.interfaces.stream.Slave.__init__(self)
      self.frameNum = 0
      self.reqFrames = reqFrames
      self.badFrames = 0
      self.frameBuf = np.empty((reqFrames, 48, 48))

   #def __del__(self):
   #   rogue.interfaces.stream.Slave.__del__(self)

   def _acceptFrame(self,frame):
      cframe = bytearray(frame.getPayload())
      frame.read(cframe,0)
      if frame.getPayload() == 4620 and self.frameNum < self.reqFrames:
         self.frameBuf[self.frameNum] = np.frombuffer(cframe, dtype=np.uint16, count=-1, offset=12).reshape(48,48)
         self.frameNum = self.frameNum + 1
         #print(self.frameNum)
      else:
         self.badFrames = self.badFrames + 1




# Create GUI
appTop = QApplication(sys.argv)
#guiTop = pyrogue.gui.GuiTop(group = 'Cpix2Gui')
#ePixBoard = EpixBoard(guiTop, cmd, dataWriter, srp)
ePixBoard = EpixBoard(0, cmd, dataWriter, srp)
ePixBoard.start(pollEn=args.pollEn, initRead = args.initRead, timeout=3.0)
#pyrogue.streamTap(pgpVc0, ePixBoard.eventReader)
# Viewer gui

if args.asic == 1:
   Cpix2Asic = ePixBoard.Cpix2.Cpix2Asic1
   AsicDeserializer = ePixBoard.Cpix2.Asic1Deserializer
   AsicPktRegisters =  ePixBoard.Cpix2.Asic1PktRegisters
else:
   Cpix2Asic = ePixBoard.Cpix2.Cpix2Asic0
   AsicDeserializer = ePixBoard.Cpix2.Asic0Deserializer
   AsicPktRegisters = ePixBoard.Cpix2.Asic0PktRegisters

# simple pulser scan for my purpose
if args.test == 1:

   # test specific settings
   framesPerThreshold = 1000
   Pulser = 0
   Npulse = 1000


   thStart = args.thStart              # first threshold
   thStop = args.thStop               # last threshold

   if thStart > thStop:
      thDir = -1
   else:
      thDir = 1


   if os.path.isdir(args.dir):

      print('Setting camera registers')
      ePixBoard.ReadConfig(args.c)


      print('Enable only counter A readout')
      Cpix2Asic.Pix_Count_T.set(False)
      Cpix2Asic.Pix_Count_sel.set(False)

      # that was too long delay in all other settings (?)
      # this should be long enough to read one frame (1/500mbps * 48 * 48 ~= 5000 ns)
      # setting to 10000 ns to double this time for safety
      print('Speedup sync pulse')
      #ePixBoard.Cpix2.Cpix2FpgaRegisters.SyncDelay.set(1000)
      ePixBoard.Cpix2.Cpix2FpgaRegisters.SyncDelay.set(50000)
      ePixBoard.Cpix2.Cpix2FpgaRegisters.SyncWidth.set(1)

      # that was too long delay in all other settings (?)
      print('Speedup 1st readout pulse')
      ePixBoard.Cpix2.Cpix2FpgaRegisters.SR0Delay1.set(10)
      ePixBoard.Cpix2.Cpix2FpgaRegisters.SR0Width1.set(5)

      print('Disable 2nd readout pulse')
      ePixBoard.Cpix2.Cpix2FpgaRegisters.SR0Delay2.set(0)
      ePixBoard.Cpix2.Cpix2FpgaRegisters.SR0Width2.set(0)

      acqTime = ePixBoard.Cpix2.TriggerRegisters.AutoTrigPeriod.get() * (ePixBoard.Cpix2.Cpix2FpgaRegisters.AcqWidth1.get() + ePixBoard.Cpix2.Cpix2FpgaRegisters.AcqDelay1.get()) * ePixBoard.Cpix2.Cpix2FpgaRegisters.ReqTriggerCnt.get()
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
      print('Synchronizing ASIC %d'%(args.asic))
      rsyncTry = 1
      AsicDeserializer.Resync.set(True)
      time.sleep(1)
      while rsyncTry < 10 and AsicDeserializer.Locked.get() == False:
         rsyncTry = rsyncTry + 1
         AsicDeserializer.Resync.set(True)
         time.sleep(1)
      if AsicDeserializer.Locked.get() == False:
         print('Failed to synchronize ASIC %d after %d tries'%(args.asic,rsyncTry))
         exit()
      else:
         print('ASIC %d synchronized after %d tries'%(args.asic,rsyncTry))

      print('Clearing ASIC %d matrix'%(args.asic))
      Cpix2Asic.ClearMatrix()

      if args.trim == ' ':
         print('Missing --trim argument')
         exit()
      else:
         gr_fail = True
         while gr_fail:
            try:
               print('Setting ASIC %d pixel trim bits'%(args.asic))
               #Cpix2Asic.SetPixelBitmap(args.trim)
               Cpix2Asic.fnSetPixelBitmap(cmd=cmd, dev=Cpix2Asic, arg=args.trim)
               gr_fail = False
            except:
               gr_fail = True

      print('Disabling pulser')
      Cpix2Asic.Pulser.set(Pulser)
      Cpix2Asic.test.set(False)
      Cpix2Asic.atest.set(False)

      print('Setting TH2 to maximum')
      threshold_2 = 1023
      Cpix2Asic.MSBCompTH2_DAC.set(threshold_2 >> 6) # 4 bit MSB
      Cpix2Asic.CompTH2_DAC.set(threshold_2 & 0x3F) # 6 bit LSB

      print('Setting TH1 to maximum')
      threshold_1 = 1023
      Cpix2Asic.MSBCompTH1_DAC.set(threshold_1 >> 6) # 4 bit MSB
      Cpix2Asic.CompTH1_DAC.set(threshold_1 & 0x3F) # 6 bit LSB

      # dummy readout to flush
      time.sleep(totalTimeSec+totalTimeSec*0.1)
      ePixBoard.Trigger()

      # enable packetizer to monitor that the data is still coming
      AsicPktRegisters.enable.set(True)
      AsicPktRegisters.ResetCounters.set(True)
      AsicPktRegisters.ResetCounters.set(False)

      # get settings for the file name
      VtrimB = Cpix2Asic.Vtrim_b.get() & 0x3
      Pulser = Cpix2Asic.Pulser.get() & 0x3FF
      Npulse = ePixBoard.Cpix2.Cpix2FpgaRegisters.ReqTriggerCnt.get()

      Cpix2Asic.Pixel_FB.set(7)

      #for threshold_2 in range(1023,-1,-1):
      #for threshold_1 in range(319,256,-1):
      for threshold_1 in range(thStart,thStop-1,thDir):

         while True:

            frms_start = AsicPktRegisters.FrameCount.get()
            print('Setting TH1 to %d'%threshold_1)
            Cpix2Asic.MSBCompTH1_DAC.set(threshold_1 >> 6) # 4 bit MSB
            Cpix2Asic.CompTH1_DAC.set(threshold_1 & 0x3F) # 6 bit LSB
            print('Setting TH2 to %d'%threshold_2)
            Cpix2Asic.MSBCompTH2_DAC.set(threshold_2 >> 6) # 4 bit MSB
            Cpix2Asic.CompTH2_DAC.set(threshold_2 & 0x3F) # 6 bit LSB
            #print('Acquiring %d frames with Threshold_1=%d' %(framesPerThreshold, threshold_1))
            ePixBoard.dataWriter.dataFile.set(args.dir + '/ACQ' + '{:04d}'.format(framesPerThreshold) + '_VTRIMB' + '{:1d}'.format(VtrimB) + '_TH1' + '{:04d}'.format(threshold_1) + '_TH2' + '{:04d}'.format(threshold_2) + '_P' + '{:04d}'.format(Pulser) + '_N' + '{:05d}'.format(Npulse) + '_6600.dat')
            ePixBoard.dataWriter.open.set(True)

            # acquire frames
            for frm in range(framesPerThreshold+1):
               time.sleep(totalTimeSec+totalTimeSec*0.1)
               ePixBoard.Trigger()
            ePixBoard.dataWriter.open.set(False)

            #check if still in sync
            if AsicPktRegisters.FrameCount.get() - frms_start < int(framesPerThreshold*0.9):
               #resync
               print('Re-synchronizing ASIC %d. FRM count %d'%(args.asic, AsicPktRegisters.FrameCount.get()))
               rsyncTry = 1
               AsicDeserializer.Resync.set(True)
               time.sleep(1)
               while rsyncTry < 10 and AsicDeserializer.Locked.get() == False:
                  rsyncTry = rsyncTry + 1
                  AsicDeserializer.Resync.set(True)
                  time.sleep(1)
               if AsicDeserializer.Locked.get() == False:
                  print('Failed to re-synchronize ASIC %d after %d tries'%(args.asic,rsyncTry))
                  exit()
               else:
                  print('ASIC %d re-synchronized after %d tries'%(args.asic,rsyncTry))
            else:
               break


   else:
      print('Directory %s does not exist'%args.dir)


# threshold TH1 scan upwards on noise
if args.test == 2:


   # test specific settings
   framesPerThreshold = 20


   if os.path.isdir(args.dir):

      print('Setting camera registers')
      setAsicAsyncModeRegisters()

      acqTime = ePixBoard.Cpix2.TriggerRegisters.AutoTrigPeriod.get() * (ePixBoard.Cpix2.Cpix2FpgaRegisters.AcqWidth1.get() + ePixBoard.Cpix2.Cpix2FpgaRegisters.AcqDelay1.get()) * ePixBoard.Cpix2.Cpix2FpgaRegisters.ReqTriggerCnt.get()
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
      print('Synchronizing ASIC %d'%(args.asic))
      rsyncTry = 1
      AsicDeserializer.Resync.set(True)
      time.sleep(1)
      while rsyncTry < 10 and AsicDeserializer.Locked.get() == False:
         rsyncTry = rsyncTry + 1
         AsicDeserializer.Resync.set(True)
         time.sleep(1)
      if AsicDeserializer.Locked.get() == False:
         print('Failed to synchronize ASIC %d after %d tries'%(args.asic,rsyncTry))
         exit()
      else:
         print('ASIC %d synchronized after %d tries'%(args.asic,rsyncTry))

      print('Clearing ASIC %d matrix'%(args.asic))
      Cpix2Asic.ClearMatrix()

      print('Disabling pulser')
      Cpix2Asic.Pulser.set(0)
      Cpix2Asic.test.set(False)
      Cpix2Asic.atest.set(False)

      print('Setting TH2 to maximum')
      threshold_2 = 1023
      Cpix2Asic.MSBCompTH2_DAC.set(threshold_2 >> 6) # 4 bit MSB
      Cpix2Asic.CompTH2_DAC.set(threshold_2 & 0x3F) # 6 bit LSB

      print('Setting TH1 to minimum')
      threshold_1 = 0
      Cpix2Asic.MSBCompTH1_DAC.set(threshold_1 >> 6) # 4 bit MSB
      Cpix2Asic.CompTH1_DAC.set(threshold_1 & 0x3F) # 6 bit LSB

      # dummy readout to flush
      time.sleep(totalTimeSec+totalTimeSec*0.1)
      ePixBoard.Trigger()

      # enable packetizer to monitor that the data is still coming
      AsicPktRegisters.enable.set(True)
      AsicPktRegisters.ResetCounters.set(True)
      AsicPktRegisters.ResetCounters.set(False)

      # get settings for the file name
      VtrimB = Cpix2Asic.Vtrim_b.get() & 0x3
      Pulser = Cpix2Asic.Pulser.get() & 0x3FF
      Npulse = ePixBoard.Cpix2.Cpix2FpgaRegisters.ReqTriggerCnt.get()

      for threshold_1 in range(1024):

         t_start = datetime.datetime.now()

         while True:

            frms_start = AsicPktRegisters.FrameCount.get()
            Cpix2Asic.MSBCompTH1_DAC.set(threshold_1 >> 6) # 4 bit MSB
            Cpix2Asic.CompTH1_DAC.set(threshold_1 & 0x3F) # 6 bit LSB
            print('Acquiring %d frames with Threshold_1=%d' %(framesPerThreshold, threshold_1))
            ePixBoard.dataWriter.dataFile.set(args.dir + '/ACQ' + '{:04d}'.format(framesPerThreshold) + '_VTRIMB' + '{:1d}'.format(VtrimB) + '_TH1' + '{:04d}'.format(threshold_1) + '_TH2' + '{:04d}'.format(threshold_2) + '_P' + '{:04d}'.format(Pulser) + '_N' + '{:05d}'.format(Npulse) + '_6600.dat')
            ePixBoard.dataWriter.open.set(True)

            # acquire frames
            for frm in range(framesPerThreshold+1):
               time.sleep(totalTimeSec+totalTimeSec*0.1)
               ePixBoard.Trigger()
            ePixBoard.dataWriter.open.set(False)

            #check if still in sync
            if AsicPktRegisters.FrameCount.get() - frms_start < int(framesPerThreshold*0.9):
               #resync
               print('Re-synchronizing ASIC %d'%(args.asic))
               rsyncTry = 1
               AsicDeserializer.Resync.set(True)
               time.sleep(1)
               while rsyncTry < 10 and AsicDeserializer.Locked.get() == False:
                  rsyncTry = rsyncTry + 1
                  AsicDeserializer.Resync.set(True)
                  time.sleep(1)
               if AsicDeserializer.Locked.get() == False:
                  print('Failed to re-synchronize ASIC %d after %d tries'%(args.asic,rsyncTry))
                  exit()
               else:
                  print('ASIC %d re-synchronized after %d tries'%(args.asic,rsyncTry))
            else:
               break

         print(abs(datetime.datetime.now()-t_start))


   else:
      print('Directory %s does not exist'%args.dir)


# threshold TH2 scan downwards on noise
if args.test == 3:


   # test specific settings
   framesPerThreshold = 20


   if os.path.isdir(args.dir):

      print('Setting camera registers')
      setAsicAsyncModeRegisters()

      acqTime = ePixBoard.Cpix2.TriggerRegisters.AutoTrigPeriod.get() * (ePixBoard.Cpix2.Cpix2FpgaRegisters.AcqWidth1.get() + ePixBoard.Cpix2.Cpix2FpgaRegisters.AcqDelay1.get()) * ePixBoard.Cpix2.Cpix2FpgaRegisters.ReqTriggerCnt.get()
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
      print('Synchronizing ASIC %d'%(args.asic))
      rsyncTry = 1
      AsicDeserializer.Resync.set(True)
      time.sleep(1)
      while rsyncTry < 10 and AsicDeserializer.Locked.get() == False:
         rsyncTry = rsyncTry + 1
         AsicDeserializer.Resync.set(True)
         time.sleep(1)
      if AsicDeserializer.Locked.get() == False:
         print('Failed to synchronize ASIC %d after %d tries'%(args.asic,rsyncTry))
         exit()
      else:
         print('ASIC %d synchronized after %d tries'%(args.asic,rsyncTry))

      print('Clearing ASIC %d matrix'%(args.asic))
      Cpix2Asic.ClearMatrix()

      print('Disabling pulser')
      Cpix2Asic.Pulser.set(0)
      Cpix2Asic.test.set(False)
      Cpix2Asic.atest.set(False)

      print('Setting TH2 to maximum')
      threshold_2 = 1023
      Cpix2Asic.MSBCompTH2_DAC.set(threshold_2 >> 6) # 4 bit MSB
      Cpix2Asic.CompTH2_DAC.set(threshold_2 & 0x3F) # 6 bit LSB

      print('Setting TH1 to maximum')
      threshold_1 = 1023
      Cpix2Asic.MSBCompTH1_DAC.set(threshold_1 >> 6) # 4 bit MSB
      Cpix2Asic.CompTH1_DAC.set(threshold_1 & 0x3F) # 6 bit LSB

      # dummy readout to flush
      time.sleep(totalTimeSec+totalTimeSec*0.1)
      ePixBoard.Trigger()

      # enable packetizer to monitor that the data is still coming
      AsicPktRegisters.enable.set(True)
      AsicPktRegisters.ResetCounters.set(True)
      AsicPktRegisters.ResetCounters.set(False)

      # get settings for the file name
      VtrimB = Cpix2Asic.Vtrim_b.get() & 0x3
      Pulser = Cpix2Asic.Pulser.get() & 0x3FF
      Npulse = ePixBoard.Cpix2.Cpix2FpgaRegisters.ReqTriggerCnt.get()

      for threshold_2 in range(1023,-1,-1):

         t_start = datetime.datetime.now()

         while True:

            frms_start = AsicPktRegisters.FrameCount.get()
            Cpix2Asic.MSBCompTH2_DAC.set(threshold_2 >> 6) # 4 bit MSB
            Cpix2Asic.CompTH2_DAC.set(threshold_2 & 0x3F) # 6 bit LSB
            print('Acquiring %d frames with Threshold_2=%d' %(framesPerThreshold, threshold_2))
            ePixBoard.dataWriter.dataFile.set(args.dir + '/ACQ' + '{:04d}'.format(framesPerThreshold) + '_VTRIMB' + '{:1d}'.format(VtrimB) + '_TH1' + '{:04d}'.format(threshold_1) + '_TH2' + '{:04d}'.format(threshold_2) + '_P' + '{:04d}'.format(Pulser) + '_N' + '{:05d}'.format(Npulse) + '_6600.dat')
            ePixBoard.dataWriter.open.set(True)

            # acquire frames
            for frm in range(framesPerThreshold+1):
               time.sleep(totalTimeSec+totalTimeSec*0.1)
               ePixBoard.Trigger()
            ePixBoard.dataWriter.open.set(False)

            #check if still in sync
            if AsicPktRegisters.FrameCount.get() - frms_start < int(framesPerThreshold*0.9):
               #resync
               print('Re-synchronizing ASIC %d'%(args.asic))
               rsyncTry = 1
               AsicDeserializer.Resync.set(True)
               time.sleep(1)
               while rsyncTry < 10 and AsicDeserializer.Locked.get() == False:
                  rsyncTry = rsyncTry + 1
                  AsicDeserializer.Resync.set(True)
                  time.sleep(1)
               if AsicDeserializer.Locked.get() == False:
                  print('Failed to re-synchronize ASIC %d after %d tries'%(args.asic,rsyncTry))
                  exit()
               else:
                  print('ASIC %d re-synchronized after %d tries'%(args.asic,rsyncTry))
            else:
               break

         print(abs(datetime.datetime.now()-t_start))


   else:
      print('Directory %s does not exist'%args.dir)



#  -> Scan VtrimB 0 to 3
#     -> Scan (4) trim bits only 0 and 15 values (coarse)
#        -> Keep TH1 1023, scan TH2 1023-0
#        -> Keep TH2 1023, scan TH1 1023-0
if args.test == 4:


   # test specific settings
   framesPerThreshold = 10


   if os.path.isdir(args.dir):

      print('Setting camera registers')
      setAsicAsyncModeRegisters()

      acqTime = ePixBoard.Cpix2.TriggerRegisters.AutoTrigPeriod.get() * (ePixBoard.Cpix2.Cpix2FpgaRegisters.AcqWidth1.get() + ePixBoard.Cpix2.Cpix2FpgaRegisters.AcqDelay1.get()) * ePixBoard.Cpix2.Cpix2FpgaRegisters.ReqTriggerCnt.get()
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
      print('Synchronizing ASIC %d'%(args.asic))
      rsyncTry = 1
      AsicDeserializer.Resync.set(True)
      time.sleep(1)
      while rsyncTry < 10 and AsicDeserializer.Locked.get() == False:
         rsyncTry = rsyncTry + 1
         AsicDeserializer.Resync.set(True)
         time.sleep(1)
      if AsicDeserializer.Locked.get() == False:
         print('Failed to synchronize ASIC %d after %d tries'%(args.asic,rsyncTry))
         exit()
      else:
         print('ASIC %d synchronized after %d tries'%(args.asic,rsyncTry))

      print('Clearing ASIC %d matrix'%(args.asic))
      Cpix2Asic.ClearMatrix()

      print('Disabling pulser')
      Cpix2Asic.Pulser.set(0)
      Cpix2Asic.test.set(False)
      Cpix2Asic.atest.set(False)

      print('Setting TH2 to maximum')
      threshold_2 = 1023
      Cpix2Asic.MSBCompTH2_DAC.set(threshold_2 >> 6) # 4 bit MSB
      Cpix2Asic.CompTH2_DAC.set(threshold_2 & 0x3F) # 6 bit LSB

      print('Setting TH1 to maximum')
      threshold_1 = 1023
      Cpix2Asic.MSBCompTH1_DAC.set(threshold_1 >> 6) # 4 bit MSB
      Cpix2Asic.CompTH1_DAC.set(threshold_1 & 0x3F) # 6 bit LSB

      # dummy readout to flush
      time.sleep(totalTimeSec+totalTimeSec*0.1)
      ePixBoard.Trigger()

      # enable packetizer to monitor that the data is still coming
      AsicPktRegisters.enable.set(True)
      AsicPktRegisters.ResetCounters.set(True)
      AsicPktRegisters.ResetCounters.set(False)

      # get settings for the file name
      #VtrimB = Cpix2Asic.Vtrim_b.get() & 0x3
      Pulser = Cpix2Asic.Pulser.get() & 0x3FF
      Npulse = ePixBoard.Cpix2.Cpix2FpgaRegisters.ReqTriggerCnt.get()

      addrSize=4

      for VtrimB in range(4):

         print('Setting Vtrim_b to %d'%(VtrimB))
         Cpix2Asic.Vtrim_b.set(VtrimB)

         for TrimBits in range(0,16,15):

            print('Setting ASIC %d matrix to %x'%(args.asic,(TrimBits<<2)))
            # set all pixels trim bits
            Cpix2Asic.PrepareMultiConfig()
            Cpix2Asic.WriteMatrixData(TrimBits<<2)

            # verify one pixel that the write matrix worked
            Cpix2Asic.RowCounter(1)
            Cpix2Asic.ColCounter(1)
            rdBack = Cpix2Asic.PixelData.get()

            if rdBack != TrimBits<<2:
               print('Failed to set the pixel configuration. Expected %x, read %x'%(TrimBits<<2, rdBack))
               exit()


            for threshold_2 in range(1023,-1,-1):

               t_start = datetime.datetime.now()

               while True:

                  frms_start = AsicPktRegisters.FrameCount.get()
                  Cpix2Asic.MSBCompTH2_DAC.set(threshold_2 >> 6) # 4 bit MSB
                  Cpix2Asic.CompTH2_DAC.set(threshold_2 & 0x3F) # 6 bit LSB
                  print('Acquiring %d frames with Threshold_2=%d' %(framesPerThreshold, threshold_2))
                  ePixBoard.dataWriter.dataFile.set(args.dir + '/ACQ' + '{:04d}'.format(framesPerThreshold) + '_VTRIMB' + '{:1d}'.format(VtrimB) + '_TH1' + '{:04d}'.format(threshold_1) + '_TH2' + '{:04d}'.format(threshold_2) + '_P' + '{:04d}'.format(Pulser) + '_N' + '{:05d}'.format(Npulse) + '_6600'  + '_TrimBits' + '{:02d}'.format(TrimBits) + '.dat')
                  ePixBoard.dataWriter.open.set(True)

                  # acquire frames
                  for frm in range(framesPerThreshold+1):
                     time.sleep(totalTimeSec+totalTimeSec*0.1)
                     ePixBoard.Trigger()
                  ePixBoard.dataWriter.open.set(False)

                  #check if still in sync
                  if AsicPktRegisters.FrameCount.get() - frms_start < int(framesPerThreshold*0.9):
                     #resync
                     print('Re-synchronizing ASIC %d'%(args.asic))
                     rsyncTry = 1
                     AsicDeserializer.Resync.set(True)
                     time.sleep(1)
                     while rsyncTry < 10 and AsicDeserializer.Locked.get() == False:
                        rsyncTry = rsyncTry + 1
                        AsicDeserializer.Resync.set(True)
                        time.sleep(1)
                     if AsicDeserializer.Locked.get() == False:
                        print('Failed to re-synchronize ASIC %d after %d tries'%(args.asic,rsyncTry))
                        exit()
                     else:
                        print('ASIC %d re-synchronized after %d tries'%(args.asic,rsyncTry))
                  else:
                     break

               print(abs(datetime.datetime.now()-t_start))

            print('Setting TH2 to maximum')
            threshold_2 = 1023
            Cpix2Asic.MSBCompTH2_DAC.set(threshold_2 >> 6) # 4 bit MSB
            Cpix2Asic.CompTH2_DAC.set(threshold_2 & 0x3F) # 6 bit LSB

            for threshold_1 in range(1023,-1,-1):

               t_start = datetime.datetime.now()

               while True:

                  frms_start = AsicPktRegisters.FrameCount.get()
                  Cpix2Asic.MSBCompTH1_DAC.set(threshold_1 >> 6) # 4 bit MSB
                  Cpix2Asic.CompTH1_DAC.set(threshold_1 & 0x3F) # 6 bit LSB
                  print('Acquiring %d frames with Threshold_1=%d' %(framesPerThreshold, threshold_1))
                  ePixBoard.dataWriter.dataFile.set(args.dir + '/ACQ' + '{:04d}'.format(framesPerThreshold) + '_VTRIMB' + '{:1d}'.format(VtrimB) + '_TH1' + '{:04d}'.format(threshold_1) + '_TH2' + '{:04d}'.format(threshold_2) + '_P' + '{:04d}'.format(Pulser) + '_N' + '{:05d}'.format(Npulse) + '_6600'  + '_TrimBits' + '{:02d}'.format(TrimBits) + '.dat')
                  ePixBoard.dataWriter.open.set(True)

                  # acquire frames
                  for frm in range(framesPerThreshold+1):
                     time.sleep(totalTimeSec+totalTimeSec*0.1)
                     ePixBoard.Trigger()
                  ePixBoard.dataWriter.open.set(False)

                  #check if still in sync
                  if AsicPktRegisters.FrameCount.get() - frms_start < int(framesPerThreshold*0.9):
                     #resync
                     print('Re-synchronizing ASIC %d'%(args.asic))
                     rsyncTry = 1
                     AsicDeserializer.Resync.set(True)
                     time.sleep(1)
                     while rsyncTry < 10 and AsicDeserializer.Locked.get() == False:
                        rsyncTry = rsyncTry + 1
                        AsicDeserializer.Resync.set(True)
                        time.sleep(1)
                     if AsicDeserializer.Locked.get() == False:
                        print('Failed to re-synchronize ASIC %d after %d tries'%(args.asic,rsyncTry))
                        exit()
                     else:
                        print('ASIC %d re-synchronized after %d tries'%(args.asic,rsyncTry))
                  else:
                     break

               print(abs(datetime.datetime.now()-t_start))

            print('Setting TH1 to maximum')
            threshold_1 = 1023
            Cpix2Asic.MSBCompTH1_DAC.set(threshold_1 >> 6) # 4 bit MSB
            Cpix2Asic.CompTH1_DAC.set(threshold_1 & 0x3F) # 6 bit LSB


   else:
      print('Directory %s does not exist'%args.dir)



###########################
#  -> Scan VtrimB 0 to 3
#     -> Scan (4) trim bits 0 to 15 values (fine)
#        -> Keep TH2 1023, scan TH1 400-200
if args.test == 5:


   # test specific settings
   framesPerThreshold = 10


   if os.path.isdir(args.dir):

      print('Setting camera registers')
      setAsicAsyncModeRegisters()

      acqTime = ePixBoard.Cpix2.TriggerRegisters.AutoTrigPeriod.get() * (ePixBoard.Cpix2.Cpix2FpgaRegisters.AcqWidth1.get() + ePixBoard.Cpix2.Cpix2FpgaRegisters.AcqDelay1.get()) * ePixBoard.Cpix2.Cpix2FpgaRegisters.ReqTriggerCnt.get()
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
      print('Synchronizing ASIC %d'%(args.asic))
      rsyncTry = 1
      AsicDeserializer.Resync.set(True)
      time.sleep(1)
      while rsyncTry < 10 and AsicDeserializer.Locked.get() == False:
         rsyncTry = rsyncTry + 1
         AsicDeserializer.Resync.set(True)
         time.sleep(1)
      if AsicDeserializer.Locked.get() == False:
         print('Failed to synchronize ASIC %d after %d tries'%(args.asic,rsyncTry))
         exit()
      else:
         print('ASIC %d synchronized after %d tries'%(args.asic,rsyncTry))

      print('Clearing ASIC %d matrix'%(args.asic))
      Cpix2Asic.ClearMatrix()

      print('Disabling pulser')
      Cpix2Asic.Pulser.set(0)
      Cpix2Asic.test.set(False)
      Cpix2Asic.atest.set(False)

      print('Setting TH2 to maximum')
      threshold_2 = 1023
      Cpix2Asic.MSBCompTH2_DAC.set(threshold_2 >> 6) # 4 bit MSB
      Cpix2Asic.CompTH2_DAC.set(threshold_2 & 0x3F) # 6 bit LSB

      print('Setting TH1 to maximum')
      threshold_1 = 1023
      Cpix2Asic.MSBCompTH1_DAC.set(threshold_1 >> 6) # 4 bit MSB
      Cpix2Asic.CompTH1_DAC.set(threshold_1 & 0x3F) # 6 bit LSB

      # dummy readout to flush
      time.sleep(totalTimeSec+totalTimeSec*0.1)
      ePixBoard.Trigger()

      # enable packetizer to monitor that the data is still coming
      AsicPktRegisters.enable.set(True)
      AsicPktRegisters.ResetCounters.set(True)
      AsicPktRegisters.ResetCounters.set(False)

      # get settings for the file name
      #VtrimB = Cpix2Asic.Vtrim_b.get() & 0x3
      Pulser = Cpix2Asic.Pulser.get() & 0x3FF
      Npulse = ePixBoard.Cpix2.Cpix2FpgaRegisters.ReqTriggerCnt.get()

      addrSize=4

      for VtrimB in range(4):

         print('Setting Vtrim_b to %d'%(VtrimB))
         Cpix2Asic.Vtrim_b.set(VtrimB)

         for TrimBits in range(0,16,1):

            print('Setting ASIC %d matrix to %x'%(args.asic,(TrimBits<<2)))
            # set all pixels trim bits
            Cpix2Asic.PrepareMultiConfig()
            Cpix2Asic.WriteMatrixData(TrimBits<<2)

            # verify one pixel that the write matrix worked
            Cpix2Asic.RowCounter(1)
            Cpix2Asic.ColCounter(1)
            rdBack = Cpix2Asic.PixelData.get()

            if rdBack != TrimBits<<2:
               print('Failed to set the pixel configuration. Expected %x, read %x'%(TrimBits<<2, rdBack))
               exit()

            for threshold_1 in range(400,199,-1):

               t_start = datetime.datetime.now()

               while True:

                  frms_start = AsicPktRegisters.FrameCount.get()
                  Cpix2Asic.MSBCompTH1_DAC.set(threshold_1 >> 6) # 4 bit MSB
                  Cpix2Asic.CompTH1_DAC.set(threshold_1 & 0x3F) # 6 bit LSB
                  print('Acquiring %d frames with Threshold_1=%d' %(framesPerThreshold, threshold_1))
                  ePixBoard.dataWriter.dataFile.set(args.dir + '/ACQ' + '{:04d}'.format(framesPerThreshold) + '_VTRIMB' + '{:1d}'.format(VtrimB) + '_TH1' + '{:04d}'.format(threshold_1) + '_TH2' + '{:04d}'.format(threshold_2) + '_P' + '{:04d}'.format(Pulser) + '_N' + '{:05d}'.format(Npulse) + '_6600'  + '_TrimBits' + '{:02d}'.format(TrimBits) + '.dat')
                  ePixBoard.dataWriter.open.set(True)

                  # acquire frames
                  for frm in range(framesPerThreshold+1):
                     time.sleep(totalTimeSec+totalTimeSec*0.1)
                     ePixBoard.Trigger()
                  ePixBoard.dataWriter.open.set(False)

                  #check if still in sync
                  if AsicPktRegisters.FrameCount.get() - frms_start < int(framesPerThreshold*0.9):
                     #resync
                     print('Re-synchronizing ASIC %d'%(args.asic))
                     rsyncTry = 1
                     AsicDeserializer.Resync.set(True)
                     time.sleep(1)
                     while rsyncTry < 10 and AsicDeserializer.Locked.get() == False:
                        rsyncTry = rsyncTry + 1
                        AsicDeserializer.Resync.set(True)
                        time.sleep(1)
                     if AsicDeserializer.Locked.get() == False:
                        print('Failed to re-synchronize ASIC %d after %d tries'%(args.asic,rsyncTry))
                        exit()
                     else:
                        print('ASIC %d re-synchronized after %d tries'%(args.asic,rsyncTry))
                  else:
                     break

               print(abs(datetime.datetime.now()-t_start))

            print('Setting TH1 to maximum')
            threshold_1 = 1023
            Cpix2Asic.MSBCompTH1_DAC.set(threshold_1 >> 6) # 4 bit MSB
            Cpix2Asic.CompTH1_DAC.set(threshold_1 & 0x3F) # 6 bit LSB


   else:
      print('Directory %s does not exist'%args.dir)


###########################
#  -> Set TH1 600, TH2 700, TrimBits 0, Pulser pattern 6600, Scan Pulser 0-1023
if args.test == 6:


   # test specific settings
   framesPerThreshold = 10
   NPulses = 100



   if os.path.isdir(args.dir):

      print('Setting camera registers')
      setAsicAsyncModeRegisters()
      ePixBoard.Cpix2.Cpix2FpgaRegisters.ReqTriggerCnt.set(NPulses)

      acqTime = ePixBoard.Cpix2.TriggerRegisters.AutoTrigPeriod.get() * (ePixBoard.Cpix2.Cpix2FpgaRegisters.AcqWidth1.get() + ePixBoard.Cpix2.Cpix2FpgaRegisters.AcqDelay1.get()) * ePixBoard.Cpix2.Cpix2FpgaRegisters.ReqTriggerCnt.get()
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
      print('Synchronizing ASIC %d'%(args.asic))
      rsyncTry = 1
      AsicDeserializer.Resync.set(True)
      time.sleep(1)
      while rsyncTry < 10 and AsicDeserializer.Locked.get() == False:
         rsyncTry = rsyncTry + 1
         AsicDeserializer.Resync.set(True)
         time.sleep(1)
      if AsicDeserializer.Locked.get() == False:
         print('Failed to synchronize ASIC %d after %d tries'%(args.asic,rsyncTry))
         exit()
      else:
         print('ASIC %d synchronized after %d tries'%(args.asic,rsyncTry))

      print('Clearing ASIC %d matrix'%(args.asic))
      Cpix2Asic.ClearMatrix()

      print('Enabling pulser')
      Cpix2Asic.Pulser.set(0)
      Cpix2Asic.test.set(True)
      Cpix2Asic.atest.set(False)


      threshold_2 = 700
      Cpix2Asic.MSBCompTH2_DAC.set(threshold_2 >> 6) # 4 bit MSB
      Cpix2Asic.CompTH2_DAC.set(threshold_2 & 0x3F) # 6 bit LSB
      print('Setting TH2 to %d'%(threshold_2))

      threshold_1 = 600
      Cpix2Asic.MSBCompTH1_DAC.set(threshold_1 >> 6) # 4 bit MSB
      Cpix2Asic.CompTH1_DAC.set(threshold_1 & 0x3F) # 6 bit LSB
      print('Setting TH1 to %d'%(threshold_1))

      # dummy readout to flush
      time.sleep(totalTimeSec+totalTimeSec*0.1)
      ePixBoard.Trigger()

      # enable packetizer to monitor that the data is still coming
      AsicPktRegisters.enable.set(True)
      AsicPktRegisters.ResetCounters.set(True)
      AsicPktRegisters.ResetCounters.set(False)

      VtrimB = 0
      print('Setting Vtrim_b to %d'%(VtrimB))
      Cpix2Asic.Vtrim_b.set(VtrimB)

      TrimBits = 0
      addrSize=4
      print('Setting ASIC %d matrix to %x'%(args.asic,(TrimBits<<2)))
      # set all pixels trim bits
      Cpix2Asic.PrepareMultiConfig()
      Cpix2Asic.WriteMatrixData(TrimBits<<2)

      # verify one pixel that the write matrix worked
      Cpix2Asic.RowCounter(1)
      Cpix2Asic.ColCounter(1)
      rdBack = Cpix2Asic.PixelData.get()

      if rdBack != TrimBits<<2:
         print('Failed to set the pixel configuration. Expected %x, read %x'%(TrimBits<<2, rdBack))
         exit()



      print('Set ASIC %d matrix to 6600 pulse pattern'%(args.asic))
      setAsic1MatrixGrid66(0,0)

      # get settings for the file name
      VtrimB = Cpix2Asic.Vtrim_b.get() & 0x3
      #Pulser = Cpix2Asic.Pulser.get() & 0x3FF
      Npulse = ePixBoard.Cpix2.Cpix2FpgaRegisters.ReqTriggerCnt.get()



      for Pulser in range(1024):

         Cpix2Asic.Pulser.set(Pulser)
         t_start = datetime.datetime.now()

         while True:

            frms_start = AsicPktRegisters.FrameCount.get()
            print('Acquiring %d frames with Pulser=%d' %(framesPerThreshold, Pulser))
            ePixBoard.dataWriter.dataFile.set(args.dir + '/ACQ' + '{:04d}'.format(framesPerThreshold) + '_VTRIMB' + '{:1d}'.format(VtrimB) + '_TH1' + '{:04d}'.format(threshold_1) + '_TH2' + '{:04d}'.format(threshold_2) + '_P' + '{:04d}'.format(Pulser) + '_N' + '{:05d}'.format(Npulse) + '_6600'  + '_TrimBits' + '{:02d}'.format(TrimBits) + '.dat')
            ePixBoard.dataWriter.open.set(True)

            # acquire frames
            for frm in range(framesPerThreshold+1):
               time.sleep(totalTimeSec+totalTimeSec*0.1)
               ePixBoard.Trigger()
            ePixBoard.dataWriter.open.set(False)

            #check if still in sync
            if AsicPktRegisters.FrameCount.get() - frms_start < int(framesPerThreshold*0.9):
               #resync
               print('Re-synchronizing ASIC %d'%(args.asic))
               rsyncTry = 1
               AsicDeserializer.Resync.set(True)
               time.sleep(1)
               while rsyncTry < 10 and AsicDeserializer.Locked.get() == False:
                  rsyncTry = rsyncTry + 1
                  AsicDeserializer.Resync.set(True)
                  time.sleep(1)
               if AsicDeserializer.Locked.get() == False:
                  print('Failed to re-synchronize ASIC %d after %d tries'%(args.asic,rsyncTry))
                  exit()
               else:
                  print('ASIC %d re-synchronized after %d tries'%(args.asic,rsyncTry))
            else:
               break

         print(abs(datetime.datetime.now()-t_start))

   else:
      print('Directory %s does not exist'%args.dir)


###########################
#  -> Set Pulser to 319
#  -> Scan VtrimB 0 to 3
#     -> Scan (4) trim bits 0 to 15 values (fine)
#        -> Scan all bit masks 6600 to 6655 (x36)
#           -> Keep TH2 1023, scan TH1 900-400
if args.test == 7:


   # test specific settings
   framesPerThreshold = 10
   Pulser = 319
   Npulse = 100


   if os.path.isdir(args.dir):

      print('Setting camera registers')
      setAsicAsyncModeRegisters()
      ePixBoard.Cpix2.Cpix2FpgaRegisters.ReqTriggerCnt.set(Npulse)
      print('Enable only counter A readout')
      Cpix2Asic.Pix_Count_T.set(False)
      Cpix2Asic.Pix_Count_sel.set(False)

      print('Disable 2nd readout pulse')
      ePixBoard.Cpix2.Cpix2FpgaRegisters.SR0Delay2.set(0)
      ePixBoard.Cpix2.Cpix2FpgaRegisters.SR0Width2.set(0)

      acqTime = ePixBoard.Cpix2.TriggerRegisters.AutoTrigPeriod.get() * (ePixBoard.Cpix2.Cpix2FpgaRegisters.AcqWidth1.get() + ePixBoard.Cpix2.Cpix2FpgaRegisters.AcqDelay1.get()) * ePixBoard.Cpix2.Cpix2FpgaRegisters.ReqTriggerCnt.get()
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
      print('Synchronizing ASIC %d'%(args.asic))
      rsyncTry = 1
      AsicDeserializer.Resync.set(True)
      time.sleep(1)
      while rsyncTry < 10 and AsicDeserializer.Locked.get() == False:
         rsyncTry = rsyncTry + 1
         AsicDeserializer.Resync.set(True)
         time.sleep(1)
      if AsicDeserializer.Locked.get() == False:
         print('Failed to synchronize ASIC %d after %d tries'%(args.asic,rsyncTry))
         exit()
      else:
         print('ASIC %d synchronized after %d tries'%(args.asic,rsyncTry))

      print('Clearing ASIC %d matrix'%(args.asic))
      Cpix2Asic.ClearMatrix()

      print('Enabling pulser')
      Cpix2Asic.Pulser.set(Pulser)
      Cpix2Asic.test.set(True)
      Cpix2Asic.atest.set(False)

      print('Setting TH2 to maximum')
      threshold_2 = 1023
      Cpix2Asic.MSBCompTH2_DAC.set(threshold_2 >> 6) # 4 bit MSB
      Cpix2Asic.CompTH2_DAC.set(threshold_2 & 0x3F) # 6 bit LSB

      print('Setting TH1 to maximum')
      threshold_1 = 1023
      Cpix2Asic.MSBCompTH1_DAC.set(threshold_1 >> 6) # 4 bit MSB
      Cpix2Asic.CompTH1_DAC.set(threshold_1 & 0x3F) # 6 bit LSB

      # dummy readout to flush
      time.sleep(totalTimeSec+totalTimeSec*0.1)
      ePixBoard.Trigger()

      # enable packetizer to monitor that the data is still coming
      AsicPktRegisters.enable.set(True)
      AsicPktRegisters.ResetCounters.set(True)
      AsicPktRegisters.ResetCounters.set(False)

      # get settings for the file name
      #VtrimB = Cpix2Asic.Vtrim_b.get() & 0x3
      Pulser = Cpix2Asic.Pulser.get() & 0x3FF
      Npulse = ePixBoard.Cpix2.Cpix2FpgaRegisters.ReqTriggerCnt.get()

      addrSize=4

      for VtrimB in range(4):
         for TrimBits in range(0,16,1):
            for Mask_x in range(6):
               for Mask_y in range(6):

                  gr_fail = True
                  while gr_fail:
                     try:
                        print('Setting Vtrim_b to %d'%(VtrimB))
                        Cpix2Asic.Vtrim_b.set(VtrimB)
                        gr_fail = False
                     except:
                        gr_fail = True

                  gr_fail = True
                  while gr_fail:
                     try:
                        while True:
                           print('Setting ASIC %d matrix to %x'%(args.asic,(TrimBits<<2)))
                           # set all pixels trim bits
                           Cpix2Asic.PrepareMultiConfig()
                           Cpix2Asic.WriteMatrixData(TrimBits<<2)

                           # verify one pixel that the write matrix worked
                           Cpix2Asic.RowCounter(1)
                           Cpix2Asic.ColCounter(1)
                           rdBack = Cpix2Asic.PixelData.get()
                           rdBack = rdBack & 0x3C

                           if rdBack != TrimBits<<2:
                              print('Failed to set the pixel configuration. Expected %x, read %x'%(TrimBits<<2, rdBack))
                           else:
                              break

                        gr_fail = False
                     except:
                        gr_fail = True


                  gr_fail = True
                  while gr_fail:
                     try:
                        print('Set ASIC %d matrix to 66%d%d pulse pattern'%(args.asic,Mask_x,Mask_y))
                        setAsic1MatrixGrid66(Mask_x,Mask_y)
                        gr_fail = False
                     except:
                        gr_fail = True


                  for threshold_1 in range(900,400,-1):

                     t_start = datetime.datetime.now()

                     frms_start = AsicPktRegisters.FrameCount.get()
                     Cpix2Asic.MSBCompTH1_DAC.set(threshold_1 >> 6) # 4 bit MSB
                     Cpix2Asic.CompTH1_DAC.set(threshold_1 & 0x3F) # 6 bit LSB
                     print('Acquiring %d frames with Threshold_1=%d' %(framesPerThreshold, threshold_1))
                     ePixBoard.dataWriter.dataFile.set(args.dir + '/ACQ' + '{:04d}'.format(framesPerThreshold) + '_VTRIMB' + '{:1d}'.format(VtrimB) + '_TH1' + '{:04d}'.format(threshold_1) + '_TH2' + '{:04d}'.format(threshold_2) + '_P' + '{:04d}'.format(Pulser) + '_N' + '{:05d}'.format(Npulse) + '_66' + '{:1d}'.format(Mask_x) + '{:1d}'.format(Mask_y)  + '_TrimBits' + '{:02d}'.format(TrimBits) + '.dat')
                     ePixBoard.dataWriter.open.set(True)

                     # acquire frames
                     frmCnt = 0
                     mult = 1
                     while ePixBoard.dataWriter.frameCount.get() < framesPerThreshold*mult:

                        # do not read fater than acquisition
                        time.sleep(totalTimeSec+totalTimeSec*0.1)

                        ePixBoard.Trigger()
                        frmCnt = frmCnt + 1

                        #check if still in sync
                        if frmCnt - ePixBoard.dataWriter.frameCount.get() > int(framesPerThreshold/2):
                           print('Re-synchronizing ASIC %d'%(args.asic))
                           rsyncTry = 1
                           AsicDeserializer.Resync.set(True)
                           time.sleep(1)
                           while AsicDeserializer.Locked.get() == False:
                              rsyncTry = rsyncTry + 1
                              AsicDeserializer.Resync.set(True)
                              time.sleep(1)
                           print('ASIC %d re-synchronized after %d tries'%(args.asic,rsyncTry))
                           frmCnt = ePixBoard.dataWriter.frameCount.get()
                           if mult < 5:
                              mult = mult + 1

                     ePixBoard.dataWriter.open.set(False)

                     print(abs(datetime.datetime.now()-t_start))




   else:
      print('Directory %s does not exist'%args.dir)


###########################
# This test is to verify the trim bit settings from test no. 7
#  -> Set Pulser to 319
#     -> Scan all bit masks 8800 to 8877 (x64)
#        -> Keep TH2 1023, scan TH1 900-400
if args.test == 8:


   # test specific settings
   framesPerThreshold = 10
   Pulser = 319
   Npulse = 100
   VtrimB = 3


   if os.path.isdir(args.dir):

      print('Setting camera registers')
      setAsicAsyncModeRegisters()
      ePixBoard.Cpix2.Cpix2FpgaRegisters.ReqTriggerCnt.set(Npulse)
      print('Enable only counter A readout')
      Cpix2Asic.Pix_Count_T.set(False)
      Cpix2Asic.Pix_Count_sel.set(False)

      print('Disable 2nd readout pulse')
      ePixBoard.Cpix2.Cpix2FpgaRegisters.SR0Delay2.set(0)
      ePixBoard.Cpix2.Cpix2FpgaRegisters.SR0Width2.set(0)

      acqTime = ePixBoard.Cpix2.TriggerRegisters.AutoTrigPeriod.get() * (ePixBoard.Cpix2.Cpix2FpgaRegisters.AcqWidth1.get() + ePixBoard.Cpix2.Cpix2FpgaRegisters.AcqDelay1.get()) * ePixBoard.Cpix2.Cpix2FpgaRegisters.ReqTriggerCnt.get()
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
      print('Synchronizing ASIC %d'%(args.asic))
      rsyncTry = 1
      AsicDeserializer.Resync.set(True)
      time.sleep(1)
      while rsyncTry < 10 and AsicDeserializer.Locked.get() == False:
         rsyncTry = rsyncTry + 1
         AsicDeserializer.Resync.set(True)
         time.sleep(1)
      if AsicDeserializer.Locked.get() == False:
         print('Failed to synchronize ASIC %d after %d tries'%(args.asic,rsyncTry))
         exit()
      else:
         print('ASIC %d synchronized after %d tries'%(args.asic,rsyncTry))

      print('Clearing ASIC %d matrix'%(args.asic))
      Cpix2Asic.ClearMatrix()

      if args.trim == ' ':
         print('Missing --trim argument')
         exit()
      else:
         gr_fail = True
         while gr_fail:
            try:
               print('Setting ASIC %d pixel trim bits'%(args.asic))
               #Cpix2Asic.SetPixelBitmap(args.trim)
               Cpix2Asic.fnSetPixelBitmap(cmd=cmd, dev=Cpix2Asic, arg=args.trim)
               gr_fail = False
            except:
               gr_fail = True

      print('Enabling pulser')
      Cpix2Asic.Pulser.set(Pulser)
      Cpix2Asic.test.set(True)
      Cpix2Asic.atest.set(False)

      print('Setting TH2 to maximum')
      threshold_2 = 1023
      Cpix2Asic.MSBCompTH2_DAC.set(threshold_2 >> 6) # 4 bit MSB
      Cpix2Asic.CompTH2_DAC.set(threshold_2 & 0x3F) # 6 bit LSB

      print('Setting TH1 to maximum')
      threshold_1 = 1023
      Cpix2Asic.MSBCompTH1_DAC.set(threshold_1 >> 6) # 4 bit MSB
      Cpix2Asic.CompTH1_DAC.set(threshold_1 & 0x3F) # 6 bit LSB

      # dummy readout to flush
      time.sleep(totalTimeSec+totalTimeSec*0.1)
      ePixBoard.Trigger()

      # enable packetizer to monitor that the data is still coming
      AsicPktRegisters.enable.set(True)
      AsicPktRegisters.ResetCounters.set(True)
      AsicPktRegisters.ResetCounters.set(False)

      # get settings for the file name
      Cpix2Asic.Vtrim_b.set(VtrimB)
      VtrimB = Cpix2Asic.Vtrim_b.get() & 0x3
      Pulser = Cpix2Asic.Pulser.get() & 0x3FF
      Npulse = ePixBoard.Cpix2.Cpix2FpgaRegisters.ReqTriggerCnt.get()

      addrSize=4

      for Mask_x in range(8):
         for Mask_y in range(8):

            gr_fail = True
            while gr_fail:
               try:
                  print('Setting ASIC %d pixel trim bits'%(args.asic))
                  #Cpix2Asic.SetPixelBitmap(args.trim)
                  Cpix2Asic.fnSetPixelBitmap(cmd=cmd, dev=Cpix2Asic, arg=args.trim)
                  gr_fail = False
               except:
                  gr_fail = True

            gr_fail = True
            while gr_fail:
               try:
                  print('Set ASIC %d matrix to 88%d%d pulse pattern'%(args.asic,Mask_x,Mask_y))
                  setAsic1MatrixGrid88(Mask_x,Mask_y)
                  gr_fail = False
               except:
                  gr_fail = True


            for threshold_1 in range(750,400,-1):

               t_start = datetime.datetime.now()

               frms_start = AsicPktRegisters.FrameCount.get()
               Cpix2Asic.MSBCompTH1_DAC.set(threshold_1 >> 6) # 4 bit MSB
               Cpix2Asic.CompTH1_DAC.set(threshold_1 & 0x3F) # 6 bit LSB
               print('Acquiring %d frames with Threshold_1=%d' %(framesPerThreshold, threshold_1))
               ePixBoard.dataWriter.dataFile.set(args.dir + '/ACQ' + '{:04d}'.format(framesPerThreshold) + '_VTRIMB' + '{:1d}'.format(VtrimB) + '_TH1' + '{:04d}'.format(threshold_1) + '_TH2' + '{:04d}'.format(threshold_2) + '_P' + '{:04d}'.format(Pulser) + '_N' + '{:05d}'.format(Npulse) + '_88' + '{:1d}'.format(Mask_x) + '{:1d}'.format(Mask_y) + '.dat')
               ePixBoard.dataWriter.open.set(True)

               # acquire frames
               frmCnt = 0
               mult = 1
               while ePixBoard.dataWriter.frameCount.get() < framesPerThreshold*mult:

                  # do not read fater than acquisition
                  time.sleep(totalTimeSec+totalTimeSec*0.1)

                  ePixBoard.Trigger()
                  frmCnt = frmCnt + 1

                  #check if still in sync
                  if frmCnt - ePixBoard.dataWriter.frameCount.get() > int(framesPerThreshold/2):
                     print('Re-synchronizing ASIC %d'%(args.asic))
                     rsyncTry = 1
                     AsicDeserializer.Resync.set(True)
                     time.sleep(1)
                     while AsicDeserializer.Locked.get() == False:
                        rsyncTry = rsyncTry + 1
                        AsicDeserializer.Resync.set(True)
                        time.sleep(1)
                     print('ASIC %d re-synchronized after %d tries'%(args.asic,rsyncTry))
                     frmCnt = ePixBoard.dataWriter.frameCount.get()
                     if mult < 5:

                        mult = mult + 1

               ePixBoard.dataWriter.open.set(False)

               print(abs(datetime.datetime.now()-t_start))




   else:
      print('Directory %s does not exist'%args.dir)



###########################
# The same as test 7 but scanning th2 and counting in counter B
#  -> Set Pulser to 319
#  -> Scan VtrimB 0 to 3
#     -> Scan (4) trim bits 0 to 15 values (fine)
#        -> Scan all bit masks 6600 to 6655 (x36)
#           -> Keep TH1 1023, scan TH2 900-400
if args.test == 9:


   # test specific settings
   framesPerThreshold = 10
   Pulser = 319
   Npulse = 100


   if os.path.isdir(args.dir):

      print('Setting camera registers')
      setAsicAsyncModeRegisters()
      ePixBoard.Cpix2.Cpix2FpgaRegisters.ReqTriggerCnt.set(Npulse)
      print('Enable only counter B readout')
      Cpix2Asic.Pix_Count_T.set(False)
      Cpix2Asic.Pix_Count_sel.set(True)

      print('Disable 2nd readout pulse')
      ePixBoard.Cpix2.Cpix2FpgaRegisters.SR0Delay2.set(0)
      ePixBoard.Cpix2.Cpix2FpgaRegisters.SR0Width2.set(0)

      acqTime = ePixBoard.Cpix2.TriggerRegisters.AutoTrigPeriod.get() * (ePixBoard.Cpix2.Cpix2FpgaRegisters.AcqWidth1.get() + ePixBoard.Cpix2.Cpix2FpgaRegisters.AcqDelay1.get()) * ePixBoard.Cpix2.Cpix2FpgaRegisters.ReqTriggerCnt.get()
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
      print('Synchronizing ASIC %d'%(args.asic))
      rsyncTry = 1
      AsicDeserializer.Resync.set(True)
      time.sleep(1)
      while rsyncTry < 10 and AsicDeserializer.Locked.get() == False:
         rsyncTry = rsyncTry + 1
         AsicDeserializer.Resync.set(True)
         time.sleep(1)
      if AsicDeserializer.Locked.get() == False:
         print('Failed to synchronize ASIC %d after %d tries'%(args.asic,rsyncTry))
         exit()
      else:
         print('ASIC %d synchronized after %d tries'%(args.asic,rsyncTry))

      print('Clearing ASIC %d matrix'%(args.asic))
      Cpix2Asic.ClearMatrix()

      print('Enabling pulser')
      Cpix2Asic.Pulser.set(Pulser)
      Cpix2Asic.test.set(True)
      Cpix2Asic.atest.set(False)

      print('Setting TH2 to maximum')
      threshold_2 = 1023
      Cpix2Asic.MSBCompTH2_DAC.set(threshold_2 >> 6) # 4 bit MSB
      Cpix2Asic.CompTH2_DAC.set(threshold_2 & 0x3F) # 6 bit LSB

      print('Setting TH1 to maximum')
      threshold_1 = 1023
      Cpix2Asic.MSBCompTH1_DAC.set(threshold_1 >> 6) # 4 bit MSB
      Cpix2Asic.CompTH1_DAC.set(threshold_1 & 0x3F) # 6 bit LSB

      # dummy readout to flush
      time.sleep(totalTimeSec+totalTimeSec*0.1)
      ePixBoard.Trigger()

      # enable packetizer to monitor that the data is still coming
      AsicPktRegisters.enable.set(True)
      AsicPktRegisters.ResetCounters.set(True)
      AsicPktRegisters.ResetCounters.set(False)

      # get settings for the file name
      #VtrimB = Cpix2Asic.Vtrim_b.get() & 0x3
      Pulser = Cpix2Asic.Pulser.get() & 0x3FF
      Npulse = ePixBoard.Cpix2.Cpix2FpgaRegisters.ReqTriggerCnt.get()

      addrSize=4

      for VtrimB in range(4):
         for TrimBits in range(0,16,1):
            for Mask_x in range(6):
               for Mask_y in range(6):

                  gr_fail = True
                  while gr_fail:
                     try:
                        print('Setting Vtrim_b to %d'%(VtrimB))
                        Cpix2Asic.Vtrim_b.set(VtrimB)
                        gr_fail = False
                     except:
                        gr_fail = True

                  gr_fail = True
                  while gr_fail:
                     try:
                        while True:
                           print('Setting ASIC %d matrix to %x'%(args.asic,(TrimBits<<2)))
                           # set all pixels trim bits
                           Cpix2Asic.PrepareMultiConfig()
                           Cpix2Asic.WriteMatrixData(TrimBits<<2)

                           # verify one pixel that the write matrix worked
                           Cpix2Asic.RowCounter(1)
                           Cpix2Asic.ColCounter(1)
                           rdBack = Cpix2Asic.PixelData.get()
                           rdBack = rdBack & 0x3C

                           if rdBack != TrimBits<<2:
                              print('Failed to set the pixel configuration. Expected %x, read %x'%(TrimBits<<2, rdBack))
                           else:
                              break

                        gr_fail = False
                     except:
                        gr_fail = True


                  gr_fail = True
                  while gr_fail:
                     try:
                        print('Set ASIC %d matrix to 66%d%d pulse pattern'%(args.asic,Mask_x,Mask_y))
                        setAsic1MatrixGrid66(Mask_x,Mask_y)
                        gr_fail = False
                     except:
                        gr_fail = True


                  for threshold_2 in range(900,400,-1):

                     t_start = datetime.datetime.now()

                     frms_start = AsicPktRegisters.FrameCount.get()
                     Cpix2Asic.MSBCompTH2_DAC.set(threshold_2 >> 6) # 4 bit MSB
                     Cpix2Asic.CompTH2_DAC.set(threshold_2 & 0x3F) # 6 bit LSB
                     print('Acquiring %d frames with Threshold_2=%d' %(framesPerThreshold, threshold_2))
                     ePixBoard.dataWriter.dataFile.set(args.dir + '/ACQ' + '{:04d}'.format(framesPerThreshold) + '_VTRIMB' + '{:1d}'.format(VtrimB) + '_TH1' + '{:04d}'.format(threshold_1) + '_TH2' + '{:04d}'.format(threshold_2) + '_P' + '{:04d}'.format(Pulser) + '_N' + '{:05d}'.format(Npulse) + '_66' + '{:1d}'.format(Mask_x) + '{:1d}'.format(Mask_y)  + '_TrimBits' + '{:02d}'.format(TrimBits) + '.dat')
                     ePixBoard.dataWriter.open.set(True)

                     # acquire frames
                     frmCnt = 0
                     mult = 1
                     while ePixBoard.dataWriter.frameCount.get() < framesPerThreshold*mult:

                        # do not read fater than acquisition
                        time.sleep(totalTimeSec+totalTimeSec*0.1)

                        ePixBoard.Trigger()
                        frmCnt = frmCnt + 1

                        #check if still in sync
                        if frmCnt - ePixBoard.dataWriter.frameCount.get() > int(framesPerThreshold/2):
                           print('Re-synchronizing ASIC %d'%(args.asic))
                           rsyncTry = 1
                           AsicDeserializer.Resync.set(True)
                           time.sleep(1)
                           while AsicDeserializer.Locked.get() == False:
                              rsyncTry = rsyncTry + 1
                              AsicDeserializer.Resync.set(True)
                              time.sleep(1)
                           print('ASIC %d re-synchronized after %d tries'%(args.asic,rsyncTry))
                           frmCnt = ePixBoard.dataWriter.frameCount.get()
                           if mult < 5:
                              mult = mult + 1

                     ePixBoard.dataWriter.open.set(False)

                     print(abs(datetime.datetime.now()-t_start))




   else:
      print('Directory %s does not exist'%args.dir)



###########################
# This test is to verify the trim bit settings from test no. 7
# It is first test without pulser and with photons
# -> Load trim bits and disable test
# -> Set integration to 1ms (asynchronous mode)
# -> Keep TH2 1023, scan TH1 1023-0 (0 might be impossible)

if args.test == 10:


   # test specific settings
   framesPerThreshold = 10
   Npulse = 1
   AcqWidth = 100000
   VtrimB = 3


   if os.path.isdir(args.dir):

      print('Setting camera registers')
      setAsicAsyncModeRegisters()
      print('Enable only counter A readout')
      Cpix2Asic.Pix_Count_T.set(False)
      Cpix2Asic.Pix_Count_sel.set(False)

      print('Set integration time to %d ns'%(AcqWidth*10))
      ePixBoard.Cpix2.Cpix2FpgaRegisters.ReqTriggerCnt.set(Npulse)
      ePixBoard.Cpix2.Cpix2FpgaRegisters.AcqWidth1.set(AcqWidth)


      print('Disable 2nd readout pulse')
      ePixBoard.Cpix2.Cpix2FpgaRegisters.SR0Delay2.set(0)
      ePixBoard.Cpix2.Cpix2FpgaRegisters.SR0Width2.set(0)

      acqTime = ePixBoard.Cpix2.TriggerRegisters.AutoTrigPeriod.get() * (ePixBoard.Cpix2.Cpix2FpgaRegisters.AcqWidth1.get() + ePixBoard.Cpix2.Cpix2FpgaRegisters.AcqDelay1.get()) * ePixBoard.Cpix2.Cpix2FpgaRegisters.ReqTriggerCnt.get()
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
      print('Synchronizing ASIC %d'%(args.asic))
      rsyncTry = 1
      AsicDeserializer.Resync.set(True)
      time.sleep(1)
      while rsyncTry < 10 and AsicDeserializer.Locked.get() == False:
         rsyncTry = rsyncTry + 1
         AsicDeserializer.Resync.set(True)
         time.sleep(1)
      if AsicDeserializer.Locked.get() == False:
         print('Failed to synchronize ASIC %d after %d tries'%(args.asic,rsyncTry))
         exit()
      else:
         print('ASIC %d synchronized after %d tries'%(args.asic,rsyncTry))

      print('Clearing ASIC %d matrix'%(args.asic))
      Cpix2Asic.ClearMatrix()

      if args.trim == ' ':
         print('Missing --trim argument')
         exit()
      else:
         gr_fail = True
         while gr_fail:
            try:
               print('Setting ASIC %d pixel trim bits'%(args.asic))
               #Cpix2Asic.SetPixelBitmap(args.trim)
               Cpix2Asic.fnSetPixelBitmap(cmd=cmd, dev=Cpix2Asic, arg=args.trim)
               gr_fail = False
            except:
               gr_fail = True

      print('Disabling pulser')
      Cpix2Asic.Pulser.set(0)
      Cpix2Asic.test.set(False)
      Cpix2Asic.atest.set(False)

      print('Setting TH2 to maximum')
      threshold_2 = 1023
      Cpix2Asic.MSBCompTH2_DAC.set(threshold_2 >> 6) # 4 bit MSB
      Cpix2Asic.CompTH2_DAC.set(threshold_2 & 0x3F) # 6 bit LSB

      print('Setting TH1 to maximum')
      threshold_1 = 1023
      Cpix2Asic.MSBCompTH1_DAC.set(threshold_1 >> 6) # 4 bit MSB
      Cpix2Asic.CompTH1_DAC.set(threshold_1 & 0x3F) # 6 bit LSB

      # dummy readout to flush
      time.sleep(totalTimeSec+totalTimeSec*0.1)
      ePixBoard.Trigger()

      # enable packetizer to monitor that the data is still coming
      AsicPktRegisters.enable.set(True)
      AsicPktRegisters.ResetCounters.set(True)
      AsicPktRegisters.ResetCounters.set(False)

      # get settings for the file name
      Cpix2Asic.Vtrim_b.set(VtrimB)
      VtrimB = Cpix2Asic.Vtrim_b.get() & 0x3
      Pulser = Cpix2Asic.Pulser.get() & 0x3FF
      Npulse = ePixBoard.Cpix2.Cpix2FpgaRegisters.ReqTriggerCnt.get()

      addrSize=4
      Mask_x = 0
      Mask_y = 0

      gr_fail = True
      while gr_fail:
         try:
            print('Setting ASIC %d pixel trim bits'%(args.asic))
            #Cpix2Asic.SetPixelBitmap(args.trim)
            Cpix2Asic.fnSetPixelBitmap(cmd=cmd, dev=Cpix2Asic, arg=args.trim)
            gr_fail = False
         except:
            gr_fail = True


      for threshold_1 in range(1023,-1,-1):

         t_start = datetime.datetime.now()

         frms_start = AsicPktRegisters.FrameCount.get()
         Cpix2Asic.MSBCompTH1_DAC.set(threshold_1 >> 6) # 4 bit MSB
         Cpix2Asic.CompTH1_DAC.set(threshold_1 & 0x3F) # 6 bit LSB
         print('Acquiring %d frames with Threshold_1=%d' %(framesPerThreshold, threshold_1))
         ePixBoard.dataWriter.dataFile.set(args.dir + '/ACQ' + '{:04d}'.format(framesPerThreshold) + '_VTRIMB' + '{:1d}'.format(VtrimB) + '_TH1' + '{:04d}'.format(threshold_1) + '_TH2' + '{:04d}'.format(threshold_2) + '_P' + '{:04d}'.format(Pulser) + '_N' + '{:05d}'.format(Npulse) + '_88' + '{:1d}'.format(Mask_x) + '{:1d}'.format(Mask_y) + '.dat')
         ePixBoard.dataWriter.open.set(True)

         # acquire frames
         frmCnt = 0
         mult = 1
         while ePixBoard.dataWriter.frameCount.get() < framesPerThreshold*mult:

            # do not read fater than acquisition
            time.sleep(totalTimeSec+totalTimeSec*0.1)

            ePixBoard.Trigger()
            frmCnt = frmCnt + 1

            #check if still in sync
            if frmCnt - ePixBoard.dataWriter.frameCount.get() > int(framesPerThreshold/2):
               print('Re-synchronizing ASIC %d'%(args.asic))
               rsyncTry = 1
               AsicDeserializer.Resync.set(True)
               time.sleep(1)
               while AsicDeserializer.Locked.get() == False:
                  rsyncTry = rsyncTry + 1
                  AsicDeserializer.Resync.set(True)
                  time.sleep(1)
               print('ASIC %d re-synchronized after %d tries'%(args.asic,rsyncTry))
               frmCnt = ePixBoard.dataWriter.frameCount.get()
               if mult < 5:

                  mult = mult + 1

         ePixBoard.dataWriter.open.set(False)

         print(abs(datetime.datetime.now()-t_start))




   else:
      print('Directory %s does not exist'%args.dir)


if args.test == 11:


   # test specific settings
   framesPerThreshold = args.framesPerThreshold    # number of frames per threshold
   thStart = args.thStart              # first threshold
   thStop = args.thStop               # last threshold
   Npulse = 1
   AcqWidth = 100000
   VtrimB = 3

   if thStart > thStop:
      thDir = -1
   else:
      thDir = 1

   if os.path.isdir(args.dir):

      print('Setting camera registers')
      setAsicAsyncModeRegisters()
      print('Enable only counter A readout')
      Cpix2Asic.Pix_Count_T.set(False)
      Cpix2Asic.Pix_Count_sel.set(False)

      print('Set integration time to %d ns'%(AcqWidth*10))
      ePixBoard.Cpix2.Cpix2FpgaRegisters.ReqTriggerCnt.set(Npulse)
      ePixBoard.Cpix2.Cpix2FpgaRegisters.AcqWidth1.set(AcqWidth)


      print('Disable 2nd readout pulse')
      ePixBoard.Cpix2.Cpix2FpgaRegisters.SR0Delay2.set(0)
      ePixBoard.Cpix2.Cpix2FpgaRegisters.SR0Width2.set(0)

      acqTime = ePixBoard.Cpix2.TriggerRegisters.AutoTrigPeriod.get() * (ePixBoard.Cpix2.Cpix2FpgaRegisters.AcqWidth1.get() + ePixBoard.Cpix2.Cpix2FpgaRegisters.AcqDelay1.get()) * ePixBoard.Cpix2.Cpix2FpgaRegisters.ReqTriggerCnt.get()
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
      print('Synchronizing ASIC %d'%(args.asic))
      rsyncTry = 1
      AsicDeserializer.Resync.set(True)
      time.sleep(1)
      while rsyncTry < 10 and AsicDeserializer.Locked.get() == False:
         rsyncTry = rsyncTry + 1
         AsicDeserializer.Resync.set(True)
         time.sleep(1)
      if AsicDeserializer.Locked.get() == False:
         print('Failed to synchronize ASIC %d after %d tries'%(args.asic,rsyncTry))
         exit()
      else:
         print('ASIC %d synchronized after %d tries'%(args.asic,rsyncTry))

      print('Clearing ASIC %d matrix'%(args.asic))
      Cpix2Asic.ClearMatrix()

      if args.trim == ' ':
         print('Missing --trim argument')
         exit()
      else:
         gr_fail = True
         while gr_fail:
            try:
               print('Setting ASIC %d pixel trim bits'%(args.asic))
               #Cpix2Asic.SetPixelBitmap(args.trim)
               Cpix2Asic.fnSetPixelBitmap(cmd=cmd, dev=Cpix2Asic, arg=args.trim)
               gr_fail = False
            except:
               gr_fail = True

      print('Disabling pulser')
      Cpix2Asic.Pulser.set(0)
      Cpix2Asic.test.set(False)
      Cpix2Asic.atest.set(False)

      print('Setting TH2 to maximum')
      threshold_2 = 1023
      Cpix2Asic.MSBCompTH2_DAC.set(threshold_2 >> 6) # 4 bit MSB
      Cpix2Asic.CompTH2_DAC.set(threshold_2 & 0x3F) # 6 bit LSB

      print('Setting TH1 to maximum')
      threshold_1 = thStart
      Cpix2Asic.MSBCompTH1_DAC.set(threshold_1 >> 6) # 4 bit MSB
      Cpix2Asic.CompTH1_DAC.set(threshold_1 & 0x3F) # 6 bit LSB

      # dummy readout to flush
      time.sleep(totalTimeSec+totalTimeSec*0.1)
      ePixBoard.Trigger()

      # enable packetizer to monitor that the data is still coming
      AsicPktRegisters.enable.set(True)
      AsicPktRegisters.ResetCounters.set(True)
      AsicPktRegisters.ResetCounters.set(False)

      # get settings for the file name
      Cpix2Asic.Vtrim_b.set(VtrimB)
      VtrimB = Cpix2Asic.Vtrim_b.get() & 0x3
      Pulser = Cpix2Asic.Pulser.get() & 0x3FF
      Npulse = ePixBoard.Cpix2.Cpix2FpgaRegisters.ReqTriggerCnt.get()

      addrSize=4
      Mask_x = 0
      Mask_y = 0

      gr_fail = True
      while gr_fail:
         try:
            print('Setting ASIC %d pixel trim bits'%(args.asic))
            #Cpix2Asic.SetPixelBitmap(args.trim)
            Cpix2Asic.fnSetPixelBitmap(cmd=cmd, dev=Cpix2Asic, arg=args.trim)
            gr_fail = False
         except:
            gr_fail = True


      for threshold_1 in range(thStart,thStop-1,thDir):

         t_start = datetime.datetime.now()

         frms_start = AsicPktRegisters.FrameCount.get()
         Cpix2Asic.MSBCompTH1_DAC.set(threshold_1 >> 6) # 4 bit MSB
         Cpix2Asic.CompTH1_DAC.set(threshold_1 & 0x3F) # 6 bit LSB
         print('Acquiring %d frames with Threshold_1=%d' %(framesPerThreshold, threshold_1))
         ePixBoard.dataWriter.dataFile.set(args.dir + '/ACQ' + '{:04d}'.format(framesPerThreshold) + '_VTRIMB' + '{:1d}'.format(VtrimB) + '_TH1' + '{:04d}'.format(threshold_1) + '_TH2' + '{:04d}'.format(threshold_2) + '_P' + '{:04d}'.format(Pulser) + '_N' + '{:05d}'.format(Npulse) + '_88' + '{:1d}'.format(Mask_x) + '{:1d}'.format(Mask_y) + '.dat')
         ePixBoard.dataWriter.open.set(True)

         # acquire frames
         frmCnt = 0
         mult = 1
         while ePixBoard.dataWriter.frameCount.get() < framesPerThreshold*mult:

            # do not read fater than acquisition
            time.sleep(totalTimeSec+totalTimeSec*0.1)

            ePixBoard.Trigger()
            frmCnt = frmCnt + 1

            #check if still in sync
            if frmCnt - ePixBoard.dataWriter.frameCount.get() > int(framesPerThreshold/2):
               print('Re-synchronizing ASIC %d'%(args.asic))
               rsyncTry = 1
               AsicDeserializer.Resync.set(True)
               time.sleep(1)
               while AsicDeserializer.Locked.get() == False:
                  rsyncTry = rsyncTry + 1
                  AsicDeserializer.Resync.set(True)
                  time.sleep(1)
               print('ASIC %d re-synchronized after %d tries'%(args.asic,rsyncTry))
               frmCnt = ePixBoard.dataWriter.frameCount.get()
               if mult < 5:

                  mult = mult + 1

         ePixBoard.dataWriter.open.set(False)

         print(abs(datetime.datetime.now()-t_start))




   else:
      print('Directory %s does not exist'%args.dir)


###########################
#  New threshold trim calibration procedure using noise instead of pulser
#  -> Set synchronous mode and count to 1000
#  -> Set pulser DAC 0 (global test not working in prototype)
#  -> Clear matrix to disable pulser
#  -> Count only in counter A (no toggling and single readout)
#  -> Count over threshold 1
#  -> Scan VtrimB 0 to 3
#     -> Scan (4) trim bits 0 to 15 values (fine)
#        -> Keep TH2 1023, scan TH1 0-1023
#           -> Acquire 10 frames and do median over each pixel
#              mask pixel if med >= 3
#              replace median value of masked pixel with -1
#              save median only to a binary file (signed int32)
if args.test == 12:


   # test specific settings
   framesPerThreshold = 10
   Pulser = 0
   Npulse = 1000
   medThr = 3


   if os.path.isdir(args.dir):


      print('Setting camera registers')
      ePixBoard.ReadConfig(args.c)

      #print('Setting camera registers')
      #setAsicAsyncModeRegisters()
      ePixBoard.Cpix2.Cpix2FpgaRegisters.ReqTriggerCnt.set(Npulse)
      print('Enable only counter A readout')
      Cpix2Asic.Pix_Count_T.set(False)
      Cpix2Asic.Pix_Count_sel.set(False)

      # that was too long delay in all other settings (?)
      # this should be long enough to read one frame (1/500mbps * 48 * 48 ~= 5000 ns)
      # setting to 10000 ns to double this time for safety
      print('Speedup sync pulse')
      #ePixBoard.Cpix2.Cpix2FpgaRegisters.SyncDelay.set(1000)
      ePixBoard.Cpix2.Cpix2FpgaRegisters.SyncDelay.set(50000)
      ePixBoard.Cpix2.Cpix2FpgaRegisters.SyncWidth.set(1)

      # that was too long delay in all other settings (?)
      print('Speedup 1st readout pulse')
      ePixBoard.Cpix2.Cpix2FpgaRegisters.SR0Delay1.set(10)
      ePixBoard.Cpix2.Cpix2FpgaRegisters.SR0Width1.set(5)

      print('Disable 2nd readout pulse')
      ePixBoard.Cpix2.Cpix2FpgaRegisters.SR0Delay2.set(0)
      ePixBoard.Cpix2.Cpix2FpgaRegisters.SR0Width2.set(0)

      acqTime = ePixBoard.Cpix2.TriggerRegisters.AutoTrigPeriod.get() * (ePixBoard.Cpix2.Cpix2FpgaRegisters.AcqWidth1.get() + ePixBoard.Cpix2.Cpix2FpgaRegisters.AcqDelay1.get()) * ePixBoard.Cpix2.Cpix2FpgaRegisters.ReqTriggerCnt.get()
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
         ePixBoard.Cpix2.Cpix2FpgaRegisters.SaciSyncWidth.get()) * 100
      print('SACI sync time set is %d ns' %saciSyncTime)
      totalTime = acqTime + max([rdoutTime, syncTime, saciSyncTime])
      totalTimeSec = (totalTime*1e-9)
      print('Total time set is %f seconds' %totalTimeSec)
      print('Maximum frame rate is %f fps' %(1.0/totalTimeSec))


      # resync ASIC
      print('Synchronizing ASIC %d'%(args.asic))
      rsyncTry = 1
      AsicDeserializer.Resync.set(True)
      time.sleep(1)
      while rsyncTry < 10 and AsicDeserializer.Locked.get() == False:
         rsyncTry = rsyncTry + 1
         AsicDeserializer.Resync.set(True)
         time.sleep(1)
      if AsicDeserializer.Locked.get() == False:
         print('Failed to synchronize ASIC %d after %d tries'%(args.asic,rsyncTry))
         exit()
      else:
         print('ASIC %d synchronized after %d tries'%(args.asic,rsyncTry))

      print('Clearing ASIC %d matrix'%(args.asic))
      Cpix2Asic.ClearMatrix()

      print('Disabling pulser')
      Cpix2Asic.Pulser.set(Pulser)
      Cpix2Asic.test.set(False)
      Cpix2Asic.atest.set(False)

      print('Setting TH2 to maximum')
      threshold_2 = 1023
      Cpix2Asic.MSBCompTH2_DAC.set(threshold_2 >> 6) # 4 bit MSB
      Cpix2Asic.CompTH2_DAC.set(threshold_2 & 0x3F) # 6 bit LSB

      print('Setting TH1 to maximum')
      threshold_1 = 1023
      Cpix2Asic.MSBCompTH1_DAC.set(threshold_1 >> 6) # 4 bit MSB
      Cpix2Asic.CompTH1_DAC.set(threshold_1 & 0x3F) # 6 bit LSB

      # dummy readout to flush
      time.sleep(totalTimeSec+totalTimeSec*0.1)
      ePixBoard.Trigger()

      # enable packetizer to monitor that the data is still coming
      AsicPktRegisters.enable.set(True)
      AsicPktRegisters.ResetCounters.set(True)
      AsicPktRegisters.ResetCounters.set(False)

      # get settings for the file name
      #VtrimB = Cpix2Asic.Vtrim_b.get() & 0x3
      Pulser = Cpix2Asic.Pulser.get() & 0x3FF
      Npulse = ePixBoard.Cpix2.Cpix2FpgaRegisters.ReqTriggerCnt.get()

      # connect ImageProc
      imgProc = ImgProc(framesPerThreshold)
      pyrogue.streamTap(pgpVc0, imgProc)

      addrSize=4

      for VtrimB in range(3,4,1):
         for TrimBits in range(0,16,1):
            for Mask_x in range(2):
               for Mask_y in range(2):

                  gr_fail = True
                  while gr_fail:
                     try:
                        print('Setting Vtrim_b to %d'%(VtrimB))
                        Cpix2Asic.Vtrim_b.set(VtrimB)
                        gr_fail = False
                     except:
                        gr_fail = True

                  gr_fail = True
                  while gr_fail:
                     try:
                        while True:
                           print('Setting ASIC %d matrix to %x'%(args.asic,(TrimBits<<2)))
                           # set all pixels trim bits
                           Cpix2Asic.PrepareMultiConfig()
                           Cpix2Asic.WriteMatrixData(TrimBits<<2)

                           # verify one pixel that the write matrix worked
                           Cpix2Asic.RowCounter(1)
                           Cpix2Asic.ColCounter(1)
                           rdBack = Cpix2Asic.PixelData.get()
                           rdBack = rdBack & 0x3C

                           if rdBack != TrimBits<<2:
                              print('Failed to set the pixel configuration. Expected %x, read %x'%(TrimBits<<2, rdBack))
                           else:
                              break

                        gr_fail = False
                     except:
                        gr_fail = True

                  gr_fail = True
                  while gr_fail:
                     try:
                        print('Set ASIC %d matrix to 22%d%d mask pattern'%(args.asic,Mask_x,Mask_y))
                        setAsicMatrixMaskGrid22(Mask_x,Mask_y)
                        gr_fail = False
                     except:
                        gr_fail = True


                  maskedPixel = np.zeros([48, 48], dtype=int)
                  for threshold_1 in range(1023,0,-1):

                     Cpix2Asic.MSBCompTH1_DAC.set(threshold_1 >> 6) # 4 bit MSB
                     Cpix2Asic.CompTH1_DAC.set(threshold_1 & 0x3F) # 6 bit LSB
                     print('Acquiring %d frames with Threshold_1=%d' %(framesPerThreshold, threshold_1))

                     # acquire frames
                     frmCnt = 0
                     mult = 1

                     # eanble automatic readout
                     ePixBoard.Cpix2.Cpix2FpgaRegisters.EnAllFrames.set(True)
                     ePixBoard.Cpix2.Cpix2FpgaRegisters.EnSingleFrame.set(True)

                     # acquire images
                     while imgProc.frameNum < framesPerThreshold:

                        # sleep for ACQ time
                        time.sleep(totalTimeSec)


                     # stop triggering data
                     ePixBoard.Cpix2.Cpix2FpgaRegisters.EnAllFrames.set(False)
                     ePixBoard.Cpix2.Cpix2FpgaRegisters.EnSingleFrame.set(False)

                     # calculate median
                     #pixMedian = np.median(a=imgProc.frameBuf, axis=0)
                     pixMedian = np.sum(a=imgProc.frameBuf, axis=0)

                     # subtract previously masked (should give -1)
                     # and save median
                     fileName = args.dir + '/ACQ' + '{:04d}'.format(framesPerThreshold) + '_VTRIMB' + '{:1d}'.format(VtrimB) + '_TH1' + '{:04d}'.format(threshold_1) + '_TH2' + '{:04d}'.format(threshold_2) + '_P' + '{:04d}'.format(Pulser) + '_N' + '{:05d}'.format(Npulse) + '_TrimBits' + '{:02d}'.format(TrimBits) + '_22' + '{:1d}'.format(Mask_x) + '{:1d}'.format(Mask_y) + '_sum'

                     np.savez_compressed(fileName, im=pixMedian-maskedPixel)

                     # mask pixels that are above the median threshold
                     pixToMask = np.argwhere(pixMedian >= medThr)
                     for i in range(pixToMask.shape[0]):
                        #if maskedPixel[pixToMask[i,0], pixToMask[i,1]] == 0:
                        asic1ModifyBitPixel(x=int(pixToMask[i,0]), y=int(pixToMask[i,1]), val=1, offset=1, size=1)
                        maskedPixel[pixToMask[i,0], pixToMask[i,1]] = 1



                     # reset image processor for next run
                     imgProc.frameNum = 0



   else:
      print('Directory %s does not exist'%args.dir)



if args.test == 13:


   # test specific settings
   framesPerThreshold = 2
   Pulser = 800
   Npulse = 1000
   medThr = 3
   TrimBits = 0


   if os.path.isdir(args.dir):


      print('Setting camera registers')
      ePixBoard.LoadConfig(args.c)

      #print('Setting camera registers')
      #setAsicAsyncModeRegisters()
      ePixBoard.Cpix2.Cpix2FpgaRegisters.ReqTriggerCnt.set(Npulse)
      print('Enable only counter A readout')
      Cpix2Asic.Pix_Count_T.set(False)
      Cpix2Asic.Pix_Count_sel.set(False)

      # that was too long delay in all other settings (?)
      # this should be long enough to read one frame (1/500mbps * 48 * 48 ~= 5000 ns)
      # setting to 10000 ns to double this time for safety
      print('Speedup sync pulse')
      #ePixBoard.Cpix2.Cpix2FpgaRegisters.SyncDelay.set(1000)
      ePixBoard.Cpix2.Cpix2FpgaRegisters.SyncDelay.set(1000000)
      ePixBoard.Cpix2.Cpix2FpgaRegisters.SyncWidth.set(1)

      # that was too long delay in all other settings (?)
      print('Speedup 1st readout pulse')
      ePixBoard.Cpix2.Cpix2FpgaRegisters.SR0Delay1.set(10000)
      ePixBoard.Cpix2.Cpix2FpgaRegisters.SR0Width1.set(5)

      print('Disable 2nd readout pulse')
      ePixBoard.Cpix2.Cpix2FpgaRegisters.SR0Delay2.set(0)
      ePixBoard.Cpix2.Cpix2FpgaRegisters.SR0Width2.set(0)

      acqTime = ePixBoard.Cpix2.TriggerRegisters.AutoTrigPeriod.get() * (ePixBoard.Cpix2.Cpix2FpgaRegisters.AcqWidth1.get() + ePixBoard.Cpix2.Cpix2FpgaRegisters.AcqDelay1.get()) * ePixBoard.Cpix2.Cpix2FpgaRegisters.ReqTriggerCnt.get()
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
         ePixBoard.Cpix2.Cpix2FpgaRegisters.SaciSyncWidth.get()) * 100
      print('SACI sync time set is %d ns' %saciSyncTime)
      totalTime = acqTime + max([rdoutTime, syncTime, saciSyncTime])
      totalTimeSec = (totalTime*1e-9)
      print('Total time set is %f seconds' %totalTimeSec)
      print('Maximum frame rate is %f fps' %(1.0/totalTimeSec))


      # resync ASIC
      print('Synchronizing ASIC %d'%(args.asic))
      rsyncTry = 1
      AsicDeserializer.Resync.set(True)
      time.sleep(1)
      while rsyncTry < 10 and AsicDeserializer.Locked.get() == False:
         rsyncTry = rsyncTry + 1
         AsicDeserializer.Resync.set(True)
         time.sleep(1)
      if AsicDeserializer.Locked.get() == False:
         print('Failed to synchronize ASIC %d after %d tries'%(args.asic,rsyncTry))
         exit()
      else:
         print('ASIC %d synchronized after %d tries'%(args.asic,rsyncTry))

      print('Clearing ASIC %d matrix'%(args.asic))
      Cpix2Asic.ClearMatrix()

      print('Enabling pulser')
      Cpix2Asic.Pulser.set(Pulser)
      Cpix2Asic.test.set(True)
      Cpix2Asic.atest.set(False)

      print('Setting TH2 to maximum')
      threshold_2 = 1023
      Cpix2Asic.MSBCompTH2_DAC.set(threshold_2 >> 6) # 4 bit MSB
      Cpix2Asic.CompTH2_DAC.set(threshold_2 & 0x3F) # 6 bit LSB

      print('Setting TH1 to maximum')
      threshold_1 = 1023
      Cpix2Asic.MSBCompTH1_DAC.set(threshold_1 >> 6) # 4 bit MSB
      Cpix2Asic.CompTH1_DAC.set(threshold_1 & 0x3F) # 6 bit LSB

      # dummy readout to flush
      time.sleep(totalTimeSec+totalTimeSec*0.1)
      ePixBoard.Trigger()

      # enable packetizer to monitor that the data is still coming
      AsicPktRegisters.enable.set(True)
      AsicPktRegisters.ResetCounters.set(True)
      AsicPktRegisters.ResetCounters.set(False)

      # get settings for the file name
      VtrimB = Cpix2Asic.Vtrim_b.get() & 0x3
      Pulser = Cpix2Asic.Pulser.get() & 0x3FF
      Npulse = ePixBoard.Cpix2.Cpix2FpgaRegisters.ReqTriggerCnt.get()

      # connect ImageProc
      imgProc = ImgProc(framesPerThreshold)
      pyrogue.streamTap(pgpVc0, imgProc)

      addrSize=4

      print('Acquiring %d frames with Threshold_1=%d' %(framesPerThreshold, threshold_1))
      threshold_1 = 300
      Cpix2Asic.MSBCompTH1_DAC.set(threshold_1 >> 6) # 4 bit MSB
      Cpix2Asic.CompTH1_DAC.set(threshold_1 & 0x3F) # 6 bit LSB


      # row pattern
      pattern = "twoCols"
      pix_x = 5
      pix_y = 5

      if pattern == "twoRows":
         for pix_y in range(48):
            asic1SetPixel(pix_x, pix_y, 1)
         pix_x = pix_x + 2
         for pix_y in range(48):
            asic1SetPixel(pix_x, pix_y, 1)
         print('Pulsing %s x=%d, y=%d' %(pattern, pix_x, pix_y))
      if pattern == "twoCols":
         for pix_x in range(48):
            asic1SetPixel(pix_x, pix_y, 1)
         pix_y = pix_y + 2
         for pix_x in range(48):
            asic1SetPixel(pix_x, pix_y, 1)
         print('Pulsing %s x=%d, y=%d' %(pattern, pix_x, pix_y))
      if pattern == "twoRowsDotted":
         for pix_y in range(48):
            if pix_y%2:
               asic1SetPixel(pix_x, pix_y, 1)
         pix_x = pix_x + 2
         for pix_y in range(48):
            if pix_y%2:
               asic1SetPixel(pix_x, pix_y, 1)
         print('Pulsing dotted rows x=%d, y=%d' %(pix_x, pix_y))
      if pattern == "twoColsDotted":
         for pix_x in range(48):
            if pix_x%2:
               asic1SetPixel(pix_x, pix_y, 1)
         pix_y = pix_y + 2
         for pix_x in range(48):
            if pix_x%2:
               asic1SetPixel(pix_x, pix_y, 1)
         print('Pulsing dotted rows x=%d, y=%d' %(pix_x, pix_y))

      Nmax=32768
      Step=20
      #Nmax=5000
      imgScan = np.zeros((int(Nmax*framesPerThreshold/Step)+framesPerThreshold,48,48),dtype=np.uint16)
      badFrms = np.zeros((int(Nmax/Step)+framesPerThreshold,1),dtype=np.uint16)
      i=0
      for Npulse in range(0,Nmax,Step):

         # set number of pulser pulses
         print('Setting pulser pulses to %d' %(Npulse))
         ePixBoard.Cpix2.Cpix2FpgaRegisters.ReqTriggerCnt.set(Npulse)

         # eanble automatic readout
         ePixBoard.Cpix2.Cpix2FpgaRegisters.EnAllFrames.set(True)
         #ePixBoard.Cpix2.Cpix2FpgaRegisters.EnSingleFrame.set(True)

         # acquire images
         while imgProc.frameNum < framesPerThreshold:

            # sleep for ACQ time
            time.sleep(totalTimeSec)

            if imgProc.badFrames > 50:
               print('Timeout')
               break


         # stop triggering data
         ePixBoard.Cpix2.Cpix2FpgaRegisters.EnAllFrames.set(False)
         #ePixBoard.Cpix2.Cpix2FpgaRegisters.EnSingleFrame.set(False)

         # move data from img buffer
         imgScan[i*framesPerThreshold:(i+1)*framesPerThreshold] = imgProc.frameBuf
         badFrms[i] = imgProc.badFrames
         i = i + 1

         # reset image processor for next run
         imgProc.frameNum = 0
         imgProc.badFrames = 0


      now = datetime.now()
      fileName = args.dir + '/ACQ' + '{:04d}'.format(framesPerThreshold) + '_VTRIMB' + '{:1d}'.format(VtrimB) + '_TH1' + '{:04d}'.format(threshold_1) + '_TH2' + '{:04d}'.format(threshold_2) + '_P' + '{:04d}'.format(Pulser) + '_N' + '{:05d}'.format(Npulse) + '_TrimBits' + '{:02d}'.format(TrimBits) + '_' + now.strftime("%m%d%Y_%H%M%S") +'_' +pattern
      np.save(fileName, arr=imgScan)
      np.save(fileName + '_bad_frames', arr=badFrms)


   else:
      print('Directory %s does not exist'%args.dir)



# Close window and stop polling
ePixBoard.stop()
exit()


