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
import surf

class CoulterRoot(pr.Root):
    def __init__(self, srp0=None, trig=None, dataWriter=None):
        super(self.__class__, self).__init__("CoulterDaq", "Coulter Data Acquisition")

        self.trig = trig
        self.add(CoulterRunControl("RunControl"))
        if dataWriter is not None: self.add(dataWriter)
        self.add(Coulter(name="Coulter0", memBase=srp0, offset=0))

        def trigFunc(dev, var, val):
            self.trig.sendOpCode(0xAA)

        self.add(pr.Command(name="Trigger", function=trigFunc))
        

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
         self.root.Trigger()


         self._runCount += 1
         if self._last != int(time.time()):
             self._last = int(time.time())
             self.runCount._updated()


class Coulter(pr.Device):
    def __init__(self, **kwargs):
        if 'description' not in kwargs:
            kwargs['description'] = "Coulter FPGA"
            
        super(self.__class__, self).__init__(**kwargs)

        self.add(surf.AxiVersion.create(offset=0x00000000))
        self.add(ELine100Config(name='ASIC0', offset=0x00010000, enabled=True))
        self.add(ELine100Config(name='ASIC1', offset=0x00020000, enabled=True))
        self.add(surf.Ad9249Config(chips=1, name='AdcConfig', offset=0x00030000))
        self.add(surf.Ad9249ReadoutGroup(name = 'AdcReadoutBank0', offset=0x00040000, channels=6))
        self.add(surf.Ad9249ReadoutGroup(name = 'AdcReadoutBank1', offset=0x00050000, channels=6))                
        self.add(AcquisitionControl(name='AcquisitionControl', offset=0x00060000))        
        self.add(CoulterPgp(name='CoulterPgp', offset=0x00070000))
        self.add(surf.Xadc(offset=0x00080000))


class CoulterPgp(pr.Device):
    def __init__(self, **kwargs):
        # Double check size param
        super(self.__class__, self).__init__(**kwargs)

        self.add(surf.Pgp2bAxi(name='Pgp2bAxi', offset=0x0))
#        self.add(surf.Gtp7Axi())

        
class ELine100Config(pr.Device):

    def __init__(self, **kwargs):
        if 'description' not in kwargs:
            kwargs['description'] = "ELINE100 ASIC Configuration"

        super(self.__class__, self).__init__(**kwargs)

        self.add(pr.Variable(name = "EnaAnalogMonitor", offset = 0x80, bitSize=1, base='bool', description="Set the ENA_AMON pin on the ASIC"))
             
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
        self.add(pr.Variable(name = "dd",      offset = 0x34, bitOffset = 14, bitSize = 1,  description = "DAC Monitor Select (0-thr, 1-pulser)"))
        self.add(pr.Variable(name = "sabtest", offset = 0x34, bitOffset = 15, bitSize = 1,  description = "Select CDS test"))
        self.add(pr.Variable(name = "clab",    offset = 0x34, bitOffset = 16, bitSize = 3,  description = "Pump Timeout"))
        self.add(pr.Variable(name = "tres",    offset = 0x34, bitOffset = 19, bitSize = 3,  description = "Reset Tweak OP"))

        for i in xrange(12):
            self.add(pr.Variable('SomiSmSt_{:02d}-{:02d}'.format(i*8+7, i*8),
                                 description="Channel Selector Enable, Channel Mask, Enable Test",
                                 offset=i*4,
                                 bitSize=32,
                                 bitOffset=0,
                                 base='hex',
                                 mode='RW'))
           
        self.add(pr.Command(name = "WriteAsic",
                            description = "Write the current configuration registers into the ASIC",
                            offset = 0x40, bitSize = 1, bitOffset = 0, hidden = False,
                            function = pr.Command.touch))
        self.add(pr.Command(name = "ReadAsic", description = "Read the current configuration registers from the ASIC",
                            offset = 0x44, bitSize = 1, bitOffset = 0, hidden = False,
                            function = pr.Command.touch))

        for n,v in self.variables.iteritems():
            if n != "EnaAnalogMonitor":
                v.beforeReadCmd = self.ReadAsic
                v.beforeVerifyCmd = self.ReadAsic
                v.afterWriteCmd = self.WriteAsic

class AcquisitionControl(pr.Device):
    def __init__(self, clkFreq=156.25e6, **kwargs):

        super(self.__class__, self).__init__(description="Configure Coulter Acquisition Parameters", **kwargs)

        self.clkFreq = clkFreq
        self.clkPeriod = 1/clkFreq

        # SC Params
        self.add(pr.Variable('ScDelay', "Delay between trigger and SC rising edge",
                             offset=0x00, bitSize=16, bitOffset=0, base='hex'))
        self.add(pr.Variable('ScDelayPeriod', "Delay between trigger and SC rising edge",
                             mode='RO', base='string',
                             getFunction=self.periodConverter(), dependencies=[self.ScDelay]))

        self.add(pr.Variable('ScPosWidth', "SC high time (baseline sampling)",
                             offset=0x04, bitSize=16, bitOffset=0, base='hex'))
        self.add(pr.Variable('ScNegWidth', "SC low time",
                             offset=0x08, bitSize=16, bitOffset=0, base='hex'))
        self.add(pr.Variable("ScPeriod", "Tslot. Time for each slot",
                             mode = 'RO',  base='string',
                             getFunction=self.periodConverter(), dependencies=[self.ScPosWidth, self.ScNegWidth]))

        self.add(pr.Variable("ScCount", "Number of slots per acquisition",
                             offset=0x0C, bitSize=12, bitOffset=0, base='hex'))

        # MCK params
        self.add(pr.Variable('MckDelay', "Delay between trigger and SC rising edge",
                             offset=0x10, bitSize=16, bitOffset=0, base='hex'))
        self.add(pr.Variable('MckDelayPeriod', "Delay between trigger and SC rising edge",
                             mode='RO',  base='string',
                             getFunction=self.periodConverter(), dependencies=[self.MckDelay]))

        self.add(pr.Variable('MckPosWidth', "SC high time (baseline sampling)",
                             offset=0x14, bitSize=16, bitOffset=0, base='hex'))
        self.add(pr.Variable('MckNegWidth', "SC low time",
                             offset=0x18, bitSize=16, bitOffset=0, base='hex'))
        self.add(pr.Variable("MckPeriod", "Tslot. Time for each slot",
                             mode = 'RO', base='string',
                             getFunction=self.periodConverter(), dependencies=[self.MckPosWidth, self.MckNegWidth]))

        self.add(pr.Variable("MckCount", "Number of MCK pulses per slot (should always be 16)",
                             offset=0x1C, bitSize=8, bitOffset=0, base='hex'))

        
        # ADC CLK params
        self.add(pr.Variable('AdcClkDelay', "Delay between trigger and new rising edge of ADC clk",
                             offset=0x28, bitSize=16, bitOffset=0, base='hex'))
        self.add(pr.Variable('AdcClkDelayPeriod', "Delay between trigger and new rising edge of ADC clk",
                             mode='RO',  base='string',
                             getFunction=self.periodConverter(), dependencies=[self.AdcClkDelay]))

        self.add(pr.Variable('AdcClkPosWidth', "AdcClk high time",
                             offset=0x20, bitSize=16, bitOffset=0, base='hex'))
        self.add(pr.Variable('AdcClkNegWidth', "AdcClk low time",
                             offset=0x24, bitSize=16, bitOffset=0, base='hex'))
        self.add(pr.Variable("AdcClkPeriod", "Adc Clk period",
                             mode = 'RO',  base='string',
                             getFunction=self.periodConverter(), dependencies=[self.AdcClkPosWidth, self.AdcClkNegWidth]))

        # ADC window
        self.add(pr.Variable("AdcWindowDelay", "Delay between first mck of slot at start of adc sample capture",
                             offset=0x2c, bitSize=10, bitOffset=0, base = 'hex'))
        self.add(pr.Variable("AdcWindowDelayTime", "AdcWindowDelay in readable units",
                             mode = 'RO',  base='string',
                             getFunction=self.periodConverter(), dependencies=[self.AdcWindowDelay]))

        #There are probably useless
        self.add(pr.Variable("MckDisable", "Disables MCK generation",
                             offset=0x30, bitSize=10, bitOffset=0, base = 'bool'))
        self.add(pr.Variable("ClkDisable", "Disable SC, MCK and AdcClk generation",
                             offset=0x34, bitSize=1, bitOffset=0, base = 'bool'))

        self.add(pr.Command(name = "ResetAsic", description = "Reset the ELine100 ASICS",
                            offset=0x38, bitSize=1, bitOffset=0, function=pr.Command.toggle))

        

    def periodConverter(self):
        def func(dev, var):
            counts = reduce(lambda x,y: x.get(read=False)+1+y.get(read=False)+1, var.dependencies)
            if isinstance(counts, pr.Variable):
                counts = counts.get(read=False)
            return '{:.3f} ns'.format(self.clkPeriod * counts * 1e9)
        return func

    
