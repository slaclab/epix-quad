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

import rogue.interfaces.memory
import rogue.interfaces.stream

import pyrogue.simulation
import pyrogue.utilities.fileio
import pyrogue.gui
import pyrogue as pr

import surf.axi
import surf.devices.analog_devices
import surf.protocols.pgp
import surf.xilinx
import surf.misc

import sys
import logging
import functools
import threading
import time
from collections import defaultdict
import numpy
import pprint



class CoulterRootBase(pr.Root):
    def __init__(self, vcReg, vcData, vcTrigger, pollEn=False, **kwargs):

        super().__init__(name='CoulterDaq', description='Coulter Data Acquisition', **kwargs)

        # Add run control
        self.add(CoulterRunControl('RunControl'))

        # add DataWriter
        dataWriter = pyrogue.utilities.fileio.StreamWriter(name='dataWriter')
        self.add(dataWriter)

        
        # Create SRP interfaces and attach to vcReg channels

        for i, vc in enumerate(vcReg):
            srp = rogue.protocols.srp.SrpV3()
            pr.streamConnectBiDir(vc, srp)
            self.add(Coulter(name=f'Coulter[{i}]', memBase=srp, offset=0, enabled=True))

            # Debug
            #logging.getLogger('pyrogue.SRP[{}]'.format(i)).setLevel(logging.INFO)        
            #dbgSrp = rogue.interfaces.stream.Slave()
            #dbgSrp.setDebug(16, 'SRP[{}]'.format(i))
            #pr.streamTap(srp, dbgSrp)
            

        # Connect data vc to dataWriter
        for i, vc in enumerate(vcData):
            pr.streamConnect(vc, dataWriter.getChannel(i))

            #logging.getLogger('pyrogue.DATA[{}]'.format(i)).setLevel(logging.INFO)                
            #dbgData = rogue.interfaces.stream.Slave()
            #dbgData.setDebug(32, 'DATA[{}]'.format(i))
            #pr.streamTap(vcData[i], dbgData)
            
        
        if len(vcReg) > 1:
            self.Coulter[1].enable.set(False)

        @self.command()
        def Trigger():
            vcTrigger.sendOpCode(0x55)

        @self.command()
        def SendOpCode(arg):
            vcTrigger.sendOpCode(arg)

        self.start(pollEn=pollEn)

class CoulterRoot(CoulterRootBase):
    def __init__(self):

        # Set up logging
        logging.getLogger('pyrogue.SRP').setLevel(logging.DEBUG)
        #logging.getLogger('pyrogue.DATA[0]').setLevel(logging.INFO)


        # Create the PGP interfaces
        vcReg = [rogue.hardware.pgp.PgpCard('/dev/pgpcard_0',i,0) for i in range(2)] # Registers
        vcData = [rogue.hardware.pgp.PgpCard('/dev/pgpcard_0',i,1) for i in range(2)] # Data
        vcTrigger = vcReg[0]
        
        super().__init__(vcReg=[vcReg], vcData=[vcData], vcTrigger=vcTrigger)
        

class CoulterSimRoot(CoulterRootBase):
    def __init__(self):

        # Set up logging


        
        # Simulated PGP interface
        vcReg = pyrogue.simulation.StreamSim(host='localhost', dest=0, uid=1, ssi=True)
        vcData = pyrogue.simulation.StreamSim(host='localhost', dest=1, uid=1, ssi=True)
        vcTrigger = pyrogue.simulation.StreamSim(host='localhost', dest=4, uid=1, ssi=True)



        # Parse incomming data and dump to terminal
        parser = CoulterFrameParser()
        pr.streamTap(vcData, parser)

        # Call generic super constructor
        super().__init__(vcReg=[vcReg], vcData=[vcData], vcTrigger=vcTrigger)

        # Simulation needs longer txn timeouts
        self.setTimeout(1000)

        


# Custom run control
class CoulterRunControl(pr.RunControl):
   def __init__(self,name):
      pr.RunControl.__init__(self,name='Run Controller', rates={1:'1 Hz', 10:'10 Hz', 30:'30 Hz', 0:'Auto'})
#      self._thread = None

#    def _setRunState(self,dev,var,value):
#       if self.runState.value != value:
#          self.runState.value = value

#          if self.runState == 'Running':
#             self._thread = threading.Thread(target=self._run)
#             self._thread.start()
#          else:
#             self._thread.join()
#             self._thread = None

   def _run(self):
      self.runCount.set(0)

      while (self.runState.valueDisp() == 'Running'):
          print('Sending Trigger')
          self.root.Trigger()          
          if self.runRate == 'Auto':
              self.root.dataWriter.getChannel(0).waitFrameCount(self.runCount.value()+1)
          else:
              delay = 1.0 / self.runRate.value()
              time.sleep(delay)
              # Add command here

          self.runCount += 1



class Coulter(pr.Device):
    def __init__(self, **kwargs):
        if 'description' not in kwargs:
            kwargs['description'] = 'Coulter FPGA'
            
        super(self.__class__, self).__init__(**kwargs)

        self.add((
            surf.xilinx.Xadc(offset=0x00080000),
            surf.axi.AxiVersion(offset=0x00000000),
            AcquisitionControl(name='AcquisitionControl', offset=0x00060000, clkFreq=125.0e6),
            ReadoutControl(name='ReadoutControl', offset=0x000A0000),
            ELine100Config(name='ASIC[0]', offset=0x00010000, enabled=False),
            ELine100Config(name='ASIC[1]', offset=0x00020000, enabled=False),
            surf.devices.analog_devices.Ad9249Config(name='AdcConfig', offset=0x00030000, chips=1, enabled=False),
            surf.devices.analog_devices.Ad9249ReadoutGroup(name = 'AdcReadoutBank[0]', offset=0x00040000, channels=6),
            surf.devices.analog_devices.Ad9249ReadoutGroup(name = 'AdcReadoutBank[1]', offset=0x00050000, channels=6),
            #CoulterPgp(name='CoulterPgp', offset=0x00070000),
        ))


        
        
        self.Xadc.simpleView()

class CoulterPgp(pr.Device):
    def __init__(self, **kwargs):
        # Double check size param
        super(self.__class__, self).__init__(**kwargs)

        self.add(surf.protocols.pgp.Pgp2bAxi(name='Pgp2bAxi', offset=0x0))
#        self.add(surf.Gtp7Axi())

        
class ELine100Config(pr.Device):

    def __init__(self, **kwargs):
        if 'description' not in kwargs:
            kwargs['description'] = 'ELINE100 ASIC Configuration'

        super(self.__class__, self).__init__(**kwargs)

        self.add(pr.RemoteVariable(
            name = 'EnaAnalogMonitor',
            offset = 0x80,
            bitSize=1,
            base=pr.Bool,
            description='Set the ENA_AMON pin on the ASIC'))
             
        self.add((
            pr.RemoteVariable(name = 'pbitt',   offset = 0x30, bitOffset = 0 , bitSize = 1,  description = 'Test Pulse Polarity (0=pos, 1=neg)'),
            pr.RemoteVariable(name = 'cs',      offset = 0x30, bitOffset = 1 , bitSize = 1,  description = 'Disable Outputs'),
            pr.RemoteVariable(name = 'atest',   offset = 0x30, bitOffset = 2 , bitSize = 1,  description = 'Automatic Test Mode Enable'),
            pr.RemoteVariable(name = 'vdacm',   offset = 0x30, bitOffset = 3 , bitSize = 1,  description = 'Enabled APS monitor AO2'),
            pr.RemoteVariable(name = 'hrtest',  offset = 0x30, bitOffset = 4 , bitSize = 1,  description = 'High Resolution Test Mode'),
            pr.RemoteVariable(name = 'sbm',     offset = 0x30, bitOffset = 5 , bitSize = 1,  description = 'Monitor Output Buffer Enable'),
            pr.RemoteVariable(name = 'sb',      offset = 0x30, bitOffset = 6 , bitSize = 1,  description = 'Output Buffers Enable'),
            pr.RemoteVariable(name = 'test',    offset = 0x30, bitOffset = 7 , bitSize = 1,  description = 'Test Pulser Enable'),
            pr.RemoteVariable(name = 'saux',    offset = 0x30, bitOffset = 8 , bitSize = 1,  description = 'Enable Auxilary Output'),
            pr.RemoteVariable(name = 'slrb',    offset = 0x30, bitOffset = 9 , bitSize = 2,  description = 'Reset Time'),
                       # enum={0: '450 ns', 1: '600 ns', 2: '825 ns', 3: '1100 ns'}, base='enum'),
            pr.RemoteVariable(name = 'claen',   offset = 0x30, bitOffset = 11, bitSize = 1,  description = 'Manual Pulser DAC'),
            pr.RemoteVariable(name = 'pb',      offset = 0x30, bitOffset = 12, bitSize = 10, description = 'Pump timout disable'),
            pr.RemoteVariable(name = 'tr',      offset = 0x30, bitOffset = 22, bitSize = 3,  description = 'Baseline Adjust'),
                       # enum={0: '0m', 1: '75m', 2: '150m', 3: '225m', 4: '300m', 5: '375m', 6: '450m', 7: '525m'}, base='enum'),
            pr.RemoteVariable(name = 'sse',     offset = 0x30, bitOffset = 25, bitSize = 1,  description = 'Disable Multiple Firings Inhibit (1-disabled)'),
            pr.RemoteVariable(name = 'disen',   offset = 0x30, bitOffset = 26, bitSize = 1,  description = 'Disable Pump'),
            pr.RemoteVariable(name = 'pa',      offset = 0x34, bitOffset = 0 , bitSize = 10, description = 'Threshold DAC')))
        self.add((
#            pr.Variable(name = 'pa_Voltage', mode = 'RO', getFunction=self.voltage, dependencies=[self.pa]),
            pr.RemoteVariable(name = 'esm',     offset = 0x34, bitOffset = 10, bitSize = 1,  description = 'Enable DAC Monitor'),
            pr.RemoteVariable(name = 't',       offset = 0x34, bitOffset = 11, bitSize = 3,  description = 'Filter time to flat top'),
                       # enum = {x: '{} us'.format((x+2)*2) for x in range(8)}, base='enum'),
            pr.RemoteVariable(name = 'dd',      offset = 0x34, bitOffset = 14, bitSize = 1,  description = 'DAC Monitor Select (0-thr, 1-pulser)'),
            pr.RemoteVariable(name = 'sabtest', offset = 0x34, bitOffset = 15, bitSize = 1,  description = 'Select CDS test'),
            pr.RemoteVariable(name = 'clab',    offset = 0x34, bitOffset = 16, bitSize = 3,  description = 'Pump Timeout'),
                       # enum = {0: '550 ns', 1: '1670 ns', 2: '2800 ns', 3: '4000 ns',
                       #         4: '5200 ns', 5: '6400 ns', 6: '7500 ns', 7: '8700 ns'},
                       # base= 'enum'),
            pr.RemoteVariable(name = 'tres',    offset = 0x34, bitOffset = 19, bitSize = 3,  description = 'Reset Tweak OP')))
                       # enum = {0: '0', 1: '10m', 2: '20m', 3: '30m', 4: '-10m', 5: '-20m', 6: '-30m', 7: '-40m'}, base='enum')))
                
        self.add((
            pr.RemoteVariable(name='somi', offset=0x0, bitSize=96, bitOffset=0,  description='Channel select'),
                      #  enum={(n+1)**2: str(n) for n in range(-1, 96)}),
            pr.RemoteVariable(name='sm[31:0]', offset=0x10, bitSize=32, bitOffset=0,   description='Channel Mask[31:0]'),
            pr.RemoteVariable(name='sm[63:32]', offset=0x14, bitSize=32, bitOffset=0,  description='Channel Mask[63:32]'),
            pr.RemoteVariable(name='sm[95:64]', offset=0x18, bitSize=32, bitOffset=0,  description='Channel Mask[95:64]'),
            pr.RemoteVariable(name='st[31:0]', offset=0x20, bitSize=32, bitOffset=0,   description='Enable Test[31:0]'),
            pr.RemoteVariable(name='st[63:32]', offset=0x24, bitSize=32, bitOffset=0,  description='Enable Test[63:32]'),
            pr.RemoteVariable(name='st[95:64]', offset=0x28, bitSize=32, bitOffset=0,  description='Enable Test[95:64]')))

        #self.somi.enum[0] = 'None'
           
        self.add(pr.RemoteCommand(name = 'WriteAsic',
                                  description = 'Write the current configuration registers into the ASIC',
                                  offset = 0x40, bitSize = 1, bitOffset = 0, hidden = False, 
                                  function = pr.BaseCommand.touchOne))
        self.add(pr.RemoteCommand(name = 'ReadAsic', description = 'Read the current configuration registers from the ASIC',
                                  offset = 0x44, bitSize = 1, bitOffset = 0, hidden = False, 
                                  function = pr.BaseCommand.touchOne))

#         for n,v in self.variables.items():
#             if n != 'EnaAnalogMonitor':
#                 v.beforeReadCmd = self.ReadAsic
#                 v.afterWriteCmd = self.WriteAsic

    def writeBlocks(self, force=False, recurse=True, variable=None):
       if not self.enable.get(): return

       # Write the blocks
       if variable is not None:
           variable._block.backgroundTransaction(rogue.interfaces.memory.Write)
       else:
           for block in self._blocks:
               if force or block.stale:
                   if not all((isinstance(v, pr.RemoteCommand) for v in block._variables)):
                       block.backgroundTransaction(rogue.interfaces.memory.Write)
                   else:
                       print(f'Skipping write on Command {block}')                       

       # Hold until all blocks have been written
       self.checkBlocks(varUpdate=True, recurse=recurse, variable=variable)

       # Call WriteAsic command to start the shift of config data to the ASIC
       if variable != self.EnaAnalogMonitor:
           self.WriteAsic()

    def __readHelper(self, typ, recurse=True, variable=None):
        if not self.enable.get(): return

        # Call ReadAsic command to read out the ASIC via shift register
        if variable != self.EnaAnalogMonitor:
            self.ReadAsic()
 
        # Process local blocks.
        if variable is not None:

            variable._block.backgroundTransaction(rogue.interfaces.memory.Read)
        else:
            for block in self._blocks:
                if not all((isinstance(v, pr.RemoteCommand) for v in block._variables)):
                    block.backgroundTransaction(rogue.interfaces.memory.Read)
                else:
                    print(f'Skipping read on Command {block}')

    def readBlocks(self, recurse=True, variable=None):
        self.__readHelper(rogue.interfaces.memory.Read, recurse=recurse, variable=variable)

    def verifyBlocks(self, recurse=True, variable=None):
        self.__readHelper(typ=rogue.interfaces.memory.Verify, recurse=recurse, variable=variable)
    
                
class AdcStreamFilter(pr.Device):
    def __init__(self, **kwargs):
        super(self.__class__, self).__init__(**kwargs)

        self.add(pr.RemoteVariable(name='DelayCount', offset=0, bitSize=32, mode='RO'))
        self.add(pr.RemoteVariable(name='State', offset=4, bitSize=3, mode='RO'))
        self.add(pr.RemoteVariable(name='ScFallCount', offset=8, bitSize=32, mode='RO'))        

                
class ReadoutControl(pr.Device):
    def __init__(self, **kwargs):
        super(self.__class__, self).__init__(**kwargs)

        for i in range(11):
            self.add(AdcStreamFilter(name=f'AdcStreamFilter[{i}]', offset=i*2**12))

                     

class AcquisitionControl(pr.Device):
    def __init__(self, clkFreq=156.25e6, **kwargs):

        super(self.__class__, self).__init__(description='Configure Coulter Acquisition Parameters', **kwargs)

        self.clkFreq = clkFreq
        self.clkPeriod = 1/clkFreq

        def addPeriodLink(name, variables):
            self.add(pr.LinkVariable(
                name=name,
                units='us',
                disp='{:.3f}',
                linkedGet=self.periodConverter))

        def addFrequencyLink(name, variables):
            self.add(pr.LinkVariable(
                name=name,
                units='kHz',
                disp='{:.3f}',
                linkedGet=self.frequencyConverter))
            

        # SC Params
        self.add(pr.RemoteVariable(
            name='ScDelay',
            description='Delay between trigger and SC rising edge',
            offset=0x00,
            bitSize=16,
            bitOffset=0))

        addPeriodLink('ScDelayPeriod', [self.ScDelay])

        self.add(pr.RemoteVariable(
            name='ScPosWidth',
            description='SC high time (baseline sampling)',
            offset=0x04,
            bitSize=16,
            bitOffset=0,
            base=pr.UInt))
        
        self.add(pr.RemoteVariable(
            name='ScNegWidth',
            description='SC low time',
            offset=0x08,
            bitSize=16,
            bitOffset=0,
            base=pr.UInt))
                 
        addPeriodLink('ScPeriod', [self.ScPosWidth, self.ScNegWidth])
        addFrequencyLink('ScFrequency', [self.ScPosWidth, self.ScNegWidth])
        
        self.add(pr.RemoteVariable(
            name='ScCount',
            description='Number of slots per acquisition',
            offset=0x0C,
            bitSize=16,
            bitOffset=0))
        
        # MCK params
        self.add(pr.RemoteVariable(
            name='MckDelay',
            description='Delay between trigger and SC rising edge',
            offset=0x10,
            bitSize=16,
            bitOffset=0,
            base=pr.UInt))
                 
        addPeriodLink('MckDelayPeriod', [self.MckDelay])
        
        self.add(pr.RemoteVariable(
            name='MckPosWidth',
            description='SC high time (baseline sampling)',
            offset=0x14,
            bitSize=16,
            bitOffset=0))
                 
        self.add(pr.RemoteVariable(
            name='MckNegWidth',
            description='SC low time',
            offset=0x18,
            bitSize=16,
            bitOffset=0,
            base=pr.UInt))

        addPeriodLink('MckPeriod', [self.MckPosWidth, self.MckNegWidth])
        addFrequencyLink('MckFrequency', [self.MckPosWidth, self.MckNegWidth])
        
        self.add(pr.RemoteVariable(
            name='MckCount',
            description='Number of MCK pulses per slot (should always be 16)',
            offset=0x1C,
            bitSize=8,
            bitOffset=0,
            base=pr.UInt))
        
        # ADC CLK params
        self.add(pr.RemoteVariable(
            name='AdcClkDelay',
            description='Delay between trigger and new rising edge of ADC clk',
            offset=0x28,
            bitSize=16,
            bitOffset=0,
            base=pr.UInt))

        addPeriodLink('AdcClkDelayTime', [self.AdcClkDelay])
                 
        self.add(pr.RemoteVariable(
            name='AdcClkPosWidth',
            description='AdcClk high time',
            offset=0x20,
            bitSize=16,
            bitOffset=0,
            base=pr.UInt))
                 
        self.add(pr.RemoteVariable(
            name='AdcClkNegWidth',
            description='AdcClk low time',
            offset=0x24,
            bitSize=16,
            bitOffset=0,
            base=pr.UInt))

        addPeriodLink('AdcClkPeriod', [self.AdcClkPosWidth, self.AdcClkNegWidth])
        addFrequencyLink('AdcFrequency', [self.AdcClkPosWidth, self.AdcClkNegWidth])
                 
        
        # ADC window
        self.add(pr.RemoteVariable(
            name='AdcWindowDelay',
            description='Delay between first mck of slot at start of adc sample capture',
            offset=0x2c,
            bitSize=10,
            bitOffset=0,
            disp='{:d}',
            base=pr.UInt))

        addPeriodLink('AdcWindowDelayTime', [self.AdcWindowDelay])
                 
        #There are probably useless
        self.add(pr.RemoteVariable(
            name='MckDisable',
            description='Disables MCK generation',
            offset=0x30,
            bitSize=1,
            bitOffset=0,
            base = pr.Bool))
                 
        self.add(pr.RemoteVariable(
            name='ClkDisable',
            description='Disable SC, MCK and AdcClk generation',
            offset=0x34,
            bitSize=1,
            bitOffset=0,
            base=pr.Bool))

        self.add(pr.RemoteVariable(
            name='ScFallCount',
            offset=0x3C,
            base=pr.UInt,
            mode='RO'))

        self.add(pr.RemoteVariable(
            name='InvertMck',
            offset=0x44,
            bitSize=1,
            base=pr.Bool,
            mode='RW'))


#         def reset():
#             print('Reseting ASICs')
#             cmd.set(1)
#             time.sleep(1)
#             cmd.set(0)
#             print('Done')            
        
        # Asic reset
        self.add(pr.RemoteCommand(
            name = 'ResetAsic',
            description = 'Reset the ELine100 ASICS',
            offset=0x38,
            bitSize=1,
            bitOffset=0,
            function=pr.RemoteCommand.toggle))


    @staticmethod
    def _count(vars):
        count = 2
        for v in vars:
            count += v.value()
        #print('_count-> {}'.format(count))
        return count

    def periodConverter(self, var):
        return self.clkPeriod * self._count(var.dependencies) * 1e6
#return '{:.3f} us'.format(                 

    def frequencyConverter(self, var):
        return 1.0/(self.clkPeriod * self._count(var.dependencies)) * 1e-3
 
#return '{:.3f} kHz'.format
                 
class CoulterFrameParser(rogue.interfaces.stream.Slave):

    def __init__(self):
        rogue.interfaces.stream.Slave.__init__(self)
        nesteddict = lambda:defaultdict(nesteddict)
        self.d = []#nesteddict()


    @staticmethod
    def conv(i, highBit, lowBit):
        o = i >> lowBit
        o = o & (2**(highBit-lowBit+1)-1)
        return int(o)

    def _acceptFrame(self, frame):

        if frame.getError():
            print('Frame Error!')
            return

        
        p = bytearray(frame.getPayload())
        frame.read(p, 0)

        chNum = (frame.getFlags() >> 24)
        if chNum != 0:
            print('CH = {}'.format(chNum))
            print(p.decode('utf-8'))
            return
        

        self.d.append(numpy.zeros(shape=(256, 12, 16), dtype=numpy.uint16))

        lastByte = len(p)-16
        frame = len(self.d)-1
        byte = 16
        meta =0
        last = 0
        channel = 0
        slot = 0
        low = 0
        mid = 0
        high = 0
        print('Frame {}'.format(frame+1))
        while byte < lastByte:
            meta = int.from_bytes(p[byte:byte+2], 'little')
            last = (meta >> 4) & 1
            channel = (meta &0xf) 
            slot = (meta >> 5) & 0x7ff

            low = int.from_bytes(p[byte+2:byte+9], 'little')
            high = int.from_bytes(p[byte+9:byte+16], 'little')

            self.d[frame][slot, channel, last*8:last*8+4] = numpy.fromiter(((low >> (i*14))&0x3FFF for i in range(4)), numpy.uint16)
            self.d[frame][slot, channel, last*8+4:last*8+8] = numpy.fromiter(((high >> (i*14))&0x3FFF for i in range(4)), numpy.uint16)
            
            byte = byte + 16


    @staticmethod
    def sign_extend(value, bits=14):
        sign_bit = 1 << (bits-1)
        return (value & (sign_bit - 1)) - (value & sign_bit)

    @staticmethod
    def voltage(adc):
        return (CoulterFrameParser.sign_extend(adc)/(2**14)) + 1.0

    def noise(self, filename=None):
        d = numpy.array(self.d)
        even = d[10:, 2::2, :, :]
        odd =  d[10:, 3::2, :, :]
        print('{} samples'.format(len(d)))
        print('Pixels Noise')

        noise = [((i,j),
                  numpy.rint(numpy.std(even[:,:,i,j])),
                  numpy.rint(numpy.std(odd[:,:,i,j])))                  
            for i in range(12) for j in range(16)]

        print('Pixel, std, mean, min, max')        
        pprint.pprint(sorted(noise, key=lambda x:x[0]))

        print('Best 10')
        s = sorted(noise, key=lambda x:max(x[1:2]))
        pprint.pprint(s[0:10])
        print('Worst 10')
        pprint.pprint(list(reversed(s[-10:])))

        if filename is not None:
            numpy.save(filename, d)



    def pixelData(self, pixel):
        adc,mck = pixel
        return [frame[:][adc][mck] for slot in range(256) for frame in self.d]

    def adcData(self, adcCh):
        return [frame[:][adcCh][:] for slot in range(256) for frame in self.d for mck in range(16)]

