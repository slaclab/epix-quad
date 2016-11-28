#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : PyRogue Device - Coulter EPIX Board
#-----------------------------------------------------------------------------
# File       : Coulter.py
# Author     : Ryan Herbst, rherbst@slac.stanford.edu
# Created    : 2016-10-24
# Last update: 2016-10-24
#-----------------------------------------------------------------------------
# Description:
# Device creator for Coulter
#-----------------------------------------------------------------------------
# This file is part of the Coulter project. It is subject to 
# the license terms in the LICENSE.txt file found in the top-level directory 
# of this distribution and at: 
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
# No part of the Coulter project, including this file, may be 
# copied, modified, propagated, or distributed except according to the terms 
# contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

import pyrogue as pr
import surf.AxiVersion

class CoulterRoot(pr.Root):
    def __init__(self, srp0=None, dataWriter=None):
        super(self.__class__, self).__init__("CoulterDaq", "Coulter Data Acquisition")

        self.add(CoulterRunControl("RunControl"))
        if dataWriter is not None: self.add(dataWriter)
        self.add(Coulter(name="Coulter0", memBase=srp0, offset=0))

# Custom run control
class CoulterRunControl(pr.RunControl):
   def __init__(self,name):
      pr.RunControl.__init__(self,name,'Run Controller')
      self._thread = None

      self.runRate.enum = {1:'1 Hz', 10:'10 Hz', 30:'30 Hz'}

   def _setRunState(self,dev,var,value):
      if self._runState != value:
         self._runState = value

         if self._runState == 'Running':
            self._thread = threading.Thread(target=self._run)
            self._thread.start()
         else:
            self._thread.join()
            self._thread = None

   def _run(self):
      self._runCount = 0
      self._last = int(time.time())

      while (self._runState == 'Running'):
         delay = 1.0 / ({value: key for key,value in self.runRate.enum.iteritems()}[self._runRate])
         time.sleep(delay)
         # Add command here
         #ExampleCommand: self._root.ssiPrbsTx.oneShot()

         self._runCount += 1
         if self._last != int(time.time()):
             self._last = int(time.time())
             self.runCount._updated()


class Coulter(pr.Device):
    def __init__(self, name="", offset=0, memBase=None, hidden=False):

        super(self.__class__, self).__init__(name=name, description="Coulter FPGA",
                                             membase=memBase, offset=offset, hidden=hidden)

        self.add(surf.AxiVersion.create(offset=0x00000000))
        self.add(ELine100Config(name='ASIC0', offset=0x00001000))
        self.add(ELine100Config(name='ASIC1', offset=0x00002000))
        self.add(surf.Ad9249Config(name = 'AdcConfig', offset=0x00003000))
        self.add(surf.Ad9249ReadoutGroup(name = 'AdcReadoutBank0', offset=0x00004000))
        self.add(surf.Ad9249ReadoutGroup(name = 'AdcReadoutBank1', offset=0x00005000))                
        self.add(AcquisitionControl(name='AcquisitionControl', offset=0x00006000))
        self.add(CoulterPgp(name='CoulterPgp', offset=0x00007000))


class CoulterPgp(pr.Device):
    def __init__(self, name="", offset=0, memBase=None, hidden=False):
        # Double check size param
        super(self.__class__, self).__init__(name=name, Description="CoulterPgp",
                                             memBase=memBase, offset=offset, hidden=hidden)

        self.add(surf.Pgp2bAxi())
#        self.add(surf.Gtp7Axi())

        
class ELine100Config(pr.Device):

    def __init__(self, name=None, offset=0, memBase=None, hidden=False):

        super(self.__class__, self).__init__(name=name, description="ELine 100 ASIC Configuration",
                                             memBase=memBase, offset=offset, hidden=hidden)

        class SelMaskTest(pr.Device):
            def __init__(self, name=None, offset=0, memBase=None, hidden=False, index=0):
                super(self.__class__, self).__init__(name, "SOMI, SM, and ST",
                                                     memBase, offset, hidden)

                self.enable.hidden = True
                self.add(pr.Variable(name= "Ch{:d}_somi".format(index),
                                  description = "Channel {:d} Selector Enable".format(index),
                                  offset = index/2,
                                  bitSize = 1,
                                  bitOffset = (index%2)*4,
                                  base = 'bool',
                                  mode = 'RW'))
                self.add(pr.Variable(name = "Ch{:d}_sm".format(index),
                                  description = "Channel {:d} Mask".format(index),
                                  offset = index/2,
                                  bitSize = 1,
                                  bitOffset = (index%2)*4+1,
                                  base = 'bool',
                                  mode = 'RW'))
                self.add(pr.Variable(name = "Ch{:d}_st".format(index),
                                  description = "Enable Test on channel {:d}".format(index),
                                  offset = index/2,
                                  bitSize = 1,
                                  bitOffset = (index%2)*4+2,
                                  base = 'bool',
                                  mode = 'RW'))

        for i in xrange(96):
            self.add(SelMaskTest("SomiSmSt"+str(i), offset=0, index=i))
    
             
        self.add(pr.Variable(name = "pbitt",   offset = 0x30, bitOffset = 0 , bitSize = 1,  description = "Test Pulse Polarity (0=pos, 1=neg)"))
        self.add(pr.Variable(name = "cs",      offset = 0x30, bitOffset = 1 , bitSize = 1,  description = "Disable Outputs"))
        self.add(pr.Variable(name = "atest",   offset = 0x30, bitOffset = 2 , bitSize = 1,  description = "Automatic Test Mode Enable"))
        self.add(pr.Variable(name = "vdacm",   offset = 0x30, bitOffset = 3 , bitSize = 1,  description = "Enabled APS monitor AO2"))
        self.add(pr.Variable(name = "hrtest",  offset = 0x30, bitOffset = 4 , bitSize = 1,  description = "High Resolution Test Mode"))
        self.add(pr.Variable(name = "sbm",     offset = 0x30, bitOffset = 5 , bitSize = 1,  description = "Monitor Output Buffer Enable"))
        self.add(pr.Variable(name = "sb",      offset = 0x30, bitOffset = 6 , bitSize = 1,  description = "Output Buffers Enable"))
        self.add(pr.Variable(name = "test",    offset = 0x30, bitOffset = 7 , bitSize = 1,  description = "Test Pulser Enable"))
        self.add(pr.Variable(name = "saux",    offset = 0x30, bitOffset = 8 , bitSize = 1,  description = "Enable Auxilary Output"))
        self.add(pr.Variable(name = "slrb",    offset = 0x30, bitOffset = 9 , bitSize = 2,  description = "Reset Time"))
        self.add(pr.Variable(name = "claen",   offset = 0x30, bitOffset = 11, bitSize = 1,  description = "Manual Pulser DAC"))
        self.add(pr.Variable(name = "pb",      offset = 0x30, bitOffset = 12, bitSize = 10, description = "Pump timout disable"))
        self.add(pr.Variable(name = "tr",      offset = 0x30, bitOffset = 22, bitSize = 3,  description = "Baseline Adjust"))
        self.add(pr.Variable(name = "sse",     offset = 0x30, bitOffset = 25, bitSize = 1,  description = "Disable Multiple Firings Inhibit (1-disabled)"))
        self.add(pr.Variable(name = "disen",   offset = 0x30, bitOffset = 26, bitSize = 1,  description = "Disable Pump"))
        self.add(pr.Variable(name = "pa",      offset = 0x34, bitOffset = 0 , bitSize = 10, description = "Threshold DAC"))
        self.add(pr.Variable(name = "esm",     offset = 0x34, bitOffset = 10, bitSize = 1,  description = "Enable DAC Monitor"))
        self.add(pr.Variable(name = "t",       offset = 0x34, bitOffset = 11, bitSize = 3,  description = "Filter time to flat top"))
        self.add(pr.Variable(name = "dd",      offset = 0x34, bitOffset = 14, bitSize = 1,  description =  "DAC Monitor Select (0-thr, 1-pulser)"))
        self.add(pr.Variable(name = "sabtest", offset = 0x34, bitOffset = 15, bitSize = 1,  description = "Select CDS test"))
        self.add(pr.Variable(name = "clab",    offset = 0x34, bitOffset = 16, bitSize = 3,  description = "Pump Timeout"))
        self.add(pr.Variable(name = "tres",    offset = 0x34, bitOffset = 19, bitSize = 3,  description = "Reset Tweak OP"))
           
        self.add(pr.Command(name = "WriteAsic",
                            description = "Write the current configuration registers into the ASIC",
                            offset = 0x40, bitSize = 1, bitOffset = 0, hidden = True,
                            function = pr.Command.toggle))
        self.add(pr.Command(name = "ReadAsic", description = "Read the current configuration registers from the ASIC",
                            offset = 0x44, bitSize = 1, bitOffset = 0, hidden = True,
                            function = pr.Command.toggle))

        def _afterWrite(self):
            self.WriteAsic()

        def _beforeRead(self):
            self.ReadAsic()

        def _beforeVerify(self):
            self.ReadAsic()


class AcquisitionControl(pr.Device):
    def __init__(self, name="", offset=0, memBase=None, hidden=False, clkFreq=156.25e6):

        super(self.__class__, self).__init__(name, "Configure Coulter Acquisition Parameters",
                                             memBase, offset, hidden)

        self.clkFreq = clkFreq
        self.clkPeriod = 1/clkFreq

        # SC Params
        self.add(pr.Variable('ScDelay', "Delay between trigger and SC rising edge",
                             0x00, 16, 0, base='hex'))
        self.add(pr.Variable('ScDelayPeriod', "Delay between trigger and SC rising edge",
                             mode='SL', base='string', getFunction=makePeriodConverter(self.ScDelay)))

        self.add(pr.Variable('ScPosWidth', "SC high time (baseline sampling)",
                             0x04, 16, 0, base='hex'))
        self.add(pr.Variable('ScNegWidth', "SC low time",
                             0x08, 16, 0, base='hex'))
        self.add(pr.Variable("ScPeriod", "Tslot. Time for each slot",
                             mode = 'SL',  base='string', getFunction=makePeriodConverter([self.ScPosWidth, self.ScNegWidth])))

        self.add(pr.Variable("ScCount", "Number of slots per acquisition",
                             0x0C, 12, 0, base='hex'))

        # MCK params
        self.add(pr.Variable('MckDelay', "Delay between trigger and SC rising edge",
                             0x10, 16, 0, base='hex'))
        self.add(pr.Variable('MckDelayPeriod', "Delay between trigger and SC rising edge",
                             mode='SL',  base='string', getFunction=makePeriodConverter(self.MckDelay)))

        self.add(pr.Variable('MckPosWidth', "SC high time (baseline sampling)",
                             0x14, 16, 0, base='hex'))
        self.add(pr.Variable('MckNegWidth', "SC low time",
                             0x18, 16, 0, base='hex'))
        self.add(pr.Variable("MckPeriod", "Tslot. Time for each slot",
                             mode = 'SL', base='string',  getFunction=makePeriodConverter([self.MckPosWidth, self.MckNegWidth])))

        self.add(pr.Variable("MckCount", "Number of MCK pulses per slot (should always be 16)",
                             0x1C, 8, 0, base='hex'))

        
        # ADC CLK params
        self.add(pr.Variable('AdcClkDelay', "Delay between trigger and new rising edge of ADC clk",
                             0x28, 16, 0, base='hex'))
        self.add(pr.Variable('AdcClkDelayPeriod', "Delay between trigger and new rising edge of ADC clk",
                             mode='SL',  base='string', getFunction=makePeriodConverter(self.AdcClkDelay)))

        self.add(pr.Variable('AdcClkPosWidth', "AdcClk high time",
                             0x14, 16, 0, base='hex'))
        self.add(pr.Variable('AdcClkNegWidth', "AdcClk low time",
                             0x18, 16, 0, base='hex'))
        self.add(pr.Variable("AdcClkPeriod", "Adc Clk period",
                             mode = 'SL',  base='string', getFunction=makePeriodConverter([self.AdcClkPosWidth, self.AdcClkNegWidth])))

        # ADC window
        self.add(pr.Variable("AdcWindowDelay", "Delay between first mck of slot at start of adc sample capture",
                             0x2c, 0, 10, base = 'hex'))
        self.add(pr.Variable("AdcWindowDelayTime", "AdcWindowDelay in readable units",
                             mode = 'SL',  base='string', getFunction=makePeriodConverter(self.AdcWindowDelay)))

        #There are probably useless
        self.add(pr.Variable("MckDisable", "Disables MCK generation",
                             0x30, 0, 10, base = 'bool'))
        self.add(pr.Variable("ClkDisable", "Disable SC, MCK and AdcClk generation",
                             0x34, 0, 1, base = 'bool'))
        

def makePeriodConverter(link):
    def conv(dev, var):
        counts = 0
        if isinstance(link, list):
            counts = reduce(lambda x,y: x._getRawUInt()+y._getRawUInt(), link)

        elif isinstance(link, pr.Variable):
            counts = link._getRawUInt()

        return '{:f} ns'.format(dev.clkPeriod * counts * 1e9)
    return conv
        
