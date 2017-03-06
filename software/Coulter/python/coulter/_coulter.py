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
#from pyrogue.hardware.pgp._pgpcard import PgpCardDevice
import surf.AxiVersion
import surf
import functools
import threading
import time
from collections import defaultdict

import rogue.interfaces.stream

class CoulterRoot(pr.Root):
    def __init__(self, pgp=None, srp=None, trig=None, dataWriter=None, cmd=None, **kwargs):
        super(self.__class__, self).__init__("CoulterDaq", "Coulter Data Acquisition", **kwargs)

        self.trig = trig
        self.cmd = cmd

#        self.add(PgpCardDevice(pgp[0]))
        self.add(CoulterRunControl("RunControl"))
        if dataWriter is not None: self.add(dataWriter)

        for i in range(len(srp)):
            self.add(Coulter(name="Coulter[{}]".format(i), memBase=srp[i], offset=0, enabled=True))

        if len(srp) > 1:
            self.Coulter[1].enable.set(False)

        @self.command(base='hex')
        def Cmd(opCode):
            self.cmd.sendCmd(opCode, 0)

        @self.command()
        def Trigger():
            self.trig.sendOpCode(0x55)

        @self.command(base='hex')
        def SendOpCode(code):
            self.trig.sendOpCode(code)


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
         delay = 1.0 / ({value: key for key,value in self.runRate.enum.items()}[self._runRate])
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

        self.add((
            #surf.GenericMemory(name="AdcTap", elements=2**5-1, bitSize=32, offset=0x00080004),
            surf.Xadc(offset=0x00080000),
            surf.AxiVersion.create(offset=0x00000000),
            AcquisitionControl(name='AcquisitionControl', offset=0x00060000, clkFreq=125.0e6),
            ReadoutControl(name='ReadoutControl', offset=0x000A0000),
            ELine100Config(name='ASIC[0]', offset=0x00010000, enabled=False),
            ELine100Config(name='ASIC[1]', offset=0x00020000, enabled=False),
            surf.Ad9249Config(name='AdcConfig', offset=0x00030000, chips=1),
            surf.Ad9249ReadoutGroup(name = 'AdcReadoutBank[0]', offset=0x00040000, channels=6),
            surf.Ad9249ReadoutGroup(name = 'AdcReadoutBank[1]', offset=0x00050000, channels=6),
            CoulterPgp(name='CoulterPgp', offset=0x00070000)))
        
        
        self.Xadc.simpleView()

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
             
        self.add((
            pr.Variable(name = "pbitt",   offset = 0x30, bitOffset = 0 , bitSize = 1,  description = "Test Pulse Polarity (0=pos, 1=neg)"),
            pr.Variable(name = "cs",      offset = 0x30, bitOffset = 1 , bitSize = 1,  description = "Disable Outputs"),
            pr.Variable(name = "atest",   offset = 0x30, bitOffset = 2 , bitSize = 1,  description = "Automatic Test Mode Enable"),
            pr.Variable(name = "vdacm",   offset = 0x30, bitOffset = 3 , bitSize = 1,  description = "Enabled APS monitor AO2"),
            pr.Variable(name = "hrtest",  offset = 0x30, bitOffset = 4 , bitSize = 1,  description = "High Resolution Test Mode"),
            pr.Variable(name = "sbm",     offset = 0x30, bitOffset = 5 , bitSize = 1,  description = "Monitor Output Buffer Enable"),
            pr.Variable(name = "sb",      offset = 0x30, bitOffset = 6 , bitSize = 1,  description = "Output Buffers Enable"),
            pr.Variable(name = "test",    offset = 0x30, bitOffset = 7 , bitSize = 1,  description = "Test Pulser Enable"),
            pr.Variable(name = "saux",    offset = 0x30, bitOffset = 8 , bitSize = 1,  description = "Enable Auxilary Output"),
            pr.Variable(name = "slrb",    offset = 0x30, bitOffset = 9 , bitSize = 2,  description = "Reset Time"),
                       # enum={0: '450 ns', 1: '600 ns', 2: '825 ns', 3: '1100 ns'}, base='enum'),
            pr.Variable(name = "claen",   offset = 0x30, bitOffset = 11, bitSize = 1,  description = "Manual Pulser DAC"),
            pr.Variable(name = "pb",      offset = 0x30, bitOffset = 12, bitSize = 10, description = "Pump timout disable"),
            pr.Variable(name = "tr",      offset = 0x30, bitOffset = 22, bitSize = 3,  description = "Baseline Adjust"),
                       # enum={0: '0m', 1: '75m', 2: '150m', 3: '225m', 4: '300m', 5: '375m', 6: '450m', 7: '525m'}, base='enum'),
            pr.Variable(name = "sse",     offset = 0x30, bitOffset = 25, bitSize = 1,  description = "Disable Multiple Firings Inhibit (1-disabled)"),
            pr.Variable(name = "disen",   offset = 0x30, bitOffset = 26, bitSize = 1,  description = "Disable Pump"),
            pr.Variable(name = "pa",      offset = 0x34, bitOffset = 0 , bitSize = 10, description = "Threshold DAC")))
        self.add((
#            pr.Variable(name = 'pa_Voltage', mode = 'RO', getFunction=self.voltage, dependencies=[self.pa]),
            pr.Variable(name = "esm",     offset = 0x34, bitOffset = 10, bitSize = 1,  description = "Enable DAC Monitor"),
            pr.Variable(name = "t",       offset = 0x34, bitOffset = 11, bitSize = 3,  description = "Filter time to flat top"),
                       # enum = {x: '{} us'.format((x+2)*2) for x in range(8)}, base='enum'),
            pr.Variable(name = "dd",      offset = 0x34, bitOffset = 14, bitSize = 1,  description = "DAC Monitor Select (0-thr, 1-pulser)"),
            pr.Variable(name = "sabtest", offset = 0x34, bitOffset = 15, bitSize = 1,  description = "Select CDS test"),
            pr.Variable(name = "clab",    offset = 0x34, bitOffset = 16, bitSize = 3,  description = "Pump Timeout"),
                       # enum = {0: '550 ns', 1: '1670 ns', 2: '2800 ns', 3: '4000 ns',
                       #         4: '5200 ns', 5: '6400 ns', 6: '7500 ns', 7: '8700 ns'},
                       # base= 'enum'),
            pr.Variable(name = "tres",    offset = 0x34, bitOffset = 19, bitSize = 3,  description = "Reset Tweak OP")))
                       # enum = {0: '0', 1: '10m', 2: '20m', 3: '30m', 4: '-10m', 5: '-20m', 6: '-30m', 7: '-40m'}, base='enum')))
                
        self.add((
            pr.Variable(name='somi', offset=0x0, bitSize=96, bitOffset=0, base='hex', description='Channel select'),
                      #  enum={(n+1)**2: str(n) for n in range(-1, 96)}),
            pr.Variable(name='sm[31:0]', offset=0x10, bitSize=32, bitOffset=0, base='hex',  description='Channel Mask[31:0]'),
            pr.Variable(name='sm[63:32]', offset=0x14, bitSize=32, bitOffset=0, base='hex', description='Channel Mask[63:32]'),
            pr.Variable(name='sm[95:64]', offset=0x18, bitSize=32, bitOffset=0, base='hex', description='Channel Mask[95:64]'),
            pr.Variable(name='st[31:0]', offset=0x20, bitSize=32, bitOffset=0, base='hex',  description='Enable Test[31:0]'),
            pr.Variable(name='st[63:32]', offset=0x24, bitSize=32, bitOffset=0, base='hex', description='Enable Test[63:32]'),
            pr.Variable(name='st[95:64]', offset=0x28, bitSize=32, bitOffset=0, base='hex', description='Enable Test[95:64]')))

        #self.somi.enum[0] = "None"
        def cmd(dev, var, val):
            print('CMD: {}'.format(var))
            pr.Command.touch(dev, var, val)
           
        self.add(pr.Command(name = "WriteAsic",
                            description = "Write the current configuration registers into the ASIC",
                            offset = 0x40, bitSize = 1, bitOffset = 0, hidden = False,
                            function = cmd))
        self.add(pr.Command(name = "ReadAsic", description = "Read the current configuration registers from the ASIC",
                            offset = 0x44, bitSize = 1, bitOffset = 0, hidden = False,
                            function = cmd))

        for n,v in self.variables.items():
            if n != "EnaAnalogMonitor":
                v.beforeReadCmd = self.ReadAsic
                v.afterWriteCmd = self.WriteAsic

                
class AdcStreamFilter(pr.Device):
    def __init__(self, **kwargs):
        super(self.__class__, self).__init__(**kwargs)

        self.add(pr.Variable(name='DelayCount', offset=0, bitSize=32, mode='RO'))
        self.add(pr.Variable(name='State', offset=4, bitSize=3, mode='RO'))
        self.add(pr.Variable(name='ScFallCount', offset=8, bitSize=32, mode='RO'))        

                
class ReadoutControl(pr.Device):
    def __init__(self, **kwargs):
        super(self.__class__, self).__init__(**kwargs)

        for i in range(11):
            self.add(AdcStreamFilter(name='AdcStreamFilter[{}]'.format(i), offset=i*2**12))

                     

class AcquisitionControl(pr.Device):
    def __init__(self, clkFreq=156.25e6, **kwargs):

        super(self.__class__, self).__init__(description="Configure Coulter Acquisition Parameters", **kwargs)

        self.clkFreq = clkFreq
        self.clkPeriod = 1/clkFreq

        # SC Params
        self.addVariable(name='ScDelay', description="Delay between trigger and SC rising edge",
                         offset=0x00, bitSize=16, bitOffset=0, base='hex')
        self.addVariable(name='ScDelayTime', description="Delay between trigger and SC rising edge",
                         mode='RO', base='string',
                         getFunction=self.periodConverter(), dependencies=[self.ScDelay])

        self.addVariable(name='ScPosWidth', description="SC high time (baseline sampling)",
                         offset=0x04, bitSize=16, bitOffset=0, base='hex')
        self.addVariable(name='ScNegWidth', description="SC low time",
                         offset=0x08, bitSize=16, bitOffset=0, base='hex')
        self.addVariable(name="ScPeriod", description="Tslot. Time for each slot",
                         mode = 'RO',  base='string',
                         getFunction=self.periodConverter(), dependencies=[self.ScPosWidth, self.ScNegWidth])
        self.addVariable(name='ScFrequency', mode='RO', base='string', getFunction=self.frequencyConverter(),
                         dependencies=[self.ScPosWidth, self.ScNegWidth])
        
        self.addVariable(name="ScCount", description="Number of slots per acquisition",
                         offset=0x0C, bitSize=12, bitOffset=0, base='hex')
        
        # MCK params
        self.addVariable(name='MckDelay', description="Delay between trigger and SC rising edge",
                         offset=0x10, bitSize=16, bitOffset=0, base='hex')
        self.addVariable(name='MckDelayTime', description="Delay between trigger and SC rising edge",
                         mode='RO',  base='string',
                         getFunction=self.periodConverter(), dependencies=[self.MckDelay])
        
        self.addVariable(name='MckPosWidth', description="SC high time (baseline sampling)",
                         offset=0x14, bitSize=16, bitOffset=0, base='hex')
        self.addVariable(name='MckNegWidth', description="SC low time",
                         offset=0x18, bitSize=16, bitOffset=0, base='hex')
        self.addVariable(name="MckPeriod", description="Tslot. Time for each slot",
                         mode = 'RO', base='string',
                         getFunction=self.periodConverter(), dependencies=[self.MckPosWidth, self.MckNegWidth])
        self.addVariable(name='MckFrequency', mode='RO', base='string', getFunction=self.frequencyConverter(),
                         dependencies=[self.MckPosWidth, self.MckNegWidth])
        
        
        self.addVariable(name="MckCount", description="Number of MCK pulses per slot (should always be 16)",
                         offset=0x1C, bitSize=8, bitOffset=0, base='hex')
        
        # ADC CLK params
        self.addVariable(name='AdcClkDelay', description="Delay between trigger and new rising edge of ADC clk",
                         offset=0x28, bitSize=16, bitOffset=0, base='hex')
        self.addVariable(name='AdcClkDelayTime', description="Delay between trigger and new rising edge of ADC clk",
                         mode='RO',  base='string',
                         getFunction=self.periodConverter(), dependencies=[self.AdcClkDelay])
        
        self.addVariable(name='AdcClkPosWidth', description="AdcClk high time",
                         offset=0x20, bitSize=16, bitOffset=0, base='hex')
        self.addVariable(name='AdcClkNegWidth', description="AdcClk low time",
                         offset=0x24, bitSize=16, bitOffset=0, base='hex')
        self.addVariable(name="AdcClkPeriod", description="Adc Clk period",
                         mode = 'RO',  base='string',
                         getFunction=self.periodConverter(), dependencies=[self.AdcClkPosWidth, self.AdcClkNegWidth])
        self.addVariable(name='AdcFrequency', mode='RO', base='string', getFunction=self.frequencyConverter(),
                         dependencies=[self.AdcClkPosWidth, self.AdcClkNegWidth])
        
        
        # ADC window
        self.addVariable(name="AdcWindowDelay", description="Delay between first mck of slot at start of adc sample capture",
                         offset=0x2c, bitSize=10, bitOffset=0, base = 'hex')
        self.addVariable(name="AdcWindowDelayTime", description="AdcWindowDelay in readable units",
                         mode = 'RO',  base='string',
                         getFunction=self.periodConverter(), dependencies=[self.AdcWindowDelay])
        
        #There are probably useless
        self.addVariable(name="MckDisable", description="Disables MCK generation",
                         offset=0x30, bitSize=1, bitOffset=0, base = 'bool')
        self.addVariable(name="ClkDisable", description="Disable SC, MCK and AdcClk generation",
                         offset=0x34, bitSize=1, bitOffset=0, base = 'bool')

        self.add(pr.Variable(name="ScFallCount", offset=0x40, base='hex', mode='RO'))

        def reset(dev, cmd, arg):
            print('Reseting ASICs')
            cmd.set(1)
            time.sleep(1)
            cmd.set(0)
            print('Done')            
        
        # Asic reset
        self.addCommand(name = "ResetAsic", description = "Reset the ELine100 ASICS",
                        offset=0x38, bitSize=1, bitOffset=0, function=reset)


    @staticmethod
    def _count(vars):
        count = 2
        for v in vars:
            count += v.get(read=False)
        #print('_count-> {}'.format(count))
        return count

    def periodConverter(self):
        def func(dev, var):
            return '{:.3f} us'.format(self.clkPeriod * self._count(var.dependencies) * 1e6)
        return func

    
    def frequencyConverter(self):
        def func(dev, var):         
            return '{:.3f} kHz'.format(1/(self.clkPeriod * self._count(var.dependencies)) * 1e-3)
        return func

class CoulterFrameParser(rogue.interfaces.stream.Slave):

    def __init__(self):
        rogue.interfaces.stream.Slave.__init__(self)
        nesteddict = lambda:defaultdict(nesteddict)
        self.d = nesteddict()

    def words(self, ba):
        yield ('header', int.from_bytes(ba[0:16], 'little'))
        cnt = 16
        while cnt < len(ba)-16:
            yield (cnt/16-1, int.from_bytes(ba[cnt:cnt+16], 'little'))
            cnt = cnt + 16
        yield('tail', int.from_bytes(ba[cnt:cnt+16], 'little'))
            

    def _acceptFrame(self, frame):
        p = bytearray(frame.getPayload())
        frame.read(p, 0)



        def conv(i, highBit, lowBit):
            o = i >> lowBit
            o = o & (2**(highBit-lowBit+1)-1)
            return int(o)

        count = 0
        
        for word in self.words(p):
        #print("-------------------------")
        #print("New Frame")
        #print("-------------------------")
        #print("Header:")

            if word[0] == 'header':
                count = conv(word[1], 15, 0)
                print('header', word[1], p[0:16], count)                
            elif word[0] == 'tail':
                pass
            else:

                last = conv(word[1], 7, 7)            
                channel = conv(word[1], 6, 0)
                slot = conv(word[1], 15, 8)
                #data = {i+(8*last): conv(word[1], 16+(i*14)+13, 16+(i*14)) for i in range(8)}

                print(word[1] >> 16)
                for i, pixel in enumerate(range(last*8, last*8+8)):
                    data = conv(word[1], 16+(i*14)+13, 16+(i*14))
                    self.d[count][slot][channel][pixel] = data
                    print(slot, channel, pixel, hex(data))



        #print("------Tail---------------")
        #print(p[cnt:cnt+16])
        #print("------End of Frame-------")

    def printData(self):
        for count in self.d.keys():
            print("Frame {}".format(count))
            for slot in self.d[count].keys():
                print("  Slot {}".format(slot))
                for channel in self.d[count][slot].keys():
                    data = [hex(x) for x in list(self.d[count][slot][channel].values())]
                    if len(data) != 0:
                        print("    Channel {} Data {}".format(channel, data))


                      
            
