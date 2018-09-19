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

import rogue
import rogue.hardware.pgp
import rogue.utilities.fileio

import pyrogue
import pyrogue as pr
import pyrogue.protocols
import pyrogue.utilities.fileio
import pyrogue.interfaces.simulation
import time

import surf.axi as axi
import surf.xilinx as xil
import surf.devices.analog_devices as analog_devices
import ePixAsics as epix

import ePixQuad

class Top(pr.Root):
    def __init__(   self,       
            name        = "Top",
            description = "Container for EpixQuad",
            dev         = '/dev/pgpcard_0',
            hwType      = 'pgp2b',
            **kwargs):
        super().__init__(name=name, description=description, **kwargs)
        
        # File writer
        dataWriter = pr.utilities.fileio.StreamWriter()
        self.add(dataWriter)
        
        ######################################################################          
        
        if (hwType == 'simulation'):
            self.pgpVc0 = pr.interfaces.simulation.StreamSim(host='localhost', dest=0, uid=1, ssi=True)
            self.pgpVc1 = pr.interfaces.simulation.StreamSim(host='localhost', dest=1, uid=1, ssi=True)
            self.pgpVc2 = pr.interfaces.simulation.StreamSim(host='localhost', dest=2, uid=1, ssi=True)
            self.pgpVc3 = pr.interfaces.simulation.StreamSim(host='localhost', dest=3, uid=1, ssi=True)      
        else:
            self.pgpVc0 = rogue.hardware.pgp.PgpCard(dev,0,0) # Data & cmds
            self.pgpVc1 = rogue.hardware.pgp.PgpCard(dev,0,1) # Registers for ePix board
            self.pgpVc2 = rogue.hardware.pgp.PgpCard(dev,0,2) # PseudoScope
            self.pgpVc3 = rogue.hardware.pgp.PgpCard(dev,0,3) # Monitoring (Slow ADC)
                
        ######################################################################
        
        # Connect the SRPv3 to PGPv3.VC[0]
        memMap = rogue.protocols.srp.SrpV3()                
        pr.streamConnectBiDir(self.pgpVc1, memMap)             
        
        pyrogue.streamConnect(self.pgpVc0, dataWriter.getChannel(0x1))
        # Add pseudoscope to file writer
        pyrogue.streamConnect(self.pgpVc2, dataWriter.getChannel(0x2))
        pyrogue.streamConnect(self.pgpVc3, dataWriter.getChannel(0x3))
        
        cmd = rogue.protocols.srp.Cmd()
        pyrogue.streamConnect(cmd, self.pgpVc0)
        
        ######################################################################
        
        # Add devices
        self.add(axi.AxiVersion( 
            name    = 'AxiVersion', 
            memBase = memMap, 
            offset  = 0x00000000, 
            expand  = False,
        ))
        
        self.add(ePixQuad.SystemRegs( 
            name    = 'SystemRegs', 
            memBase = memMap, 
            offset  = 0x00100000, 
            expand  = False,
        ))
        
        self.add(ePixQuad.AcqCore( 
            name    = 'AcqCore', 
            memBase = memMap, 
            offset  = 0x01000000, 
            expand  = False,
        ))
        
        self.add(ePixQuad.RdoutCore( 
            name    = 'RdoutCore', 
            memBase = memMap, 
            offset  = 0x01100000, 
            expand  = False,
        ))
        
        self.add(ePixQuad.PseudoScopeCore( 
            name    = 'PseudoScopeCore', 
            memBase = memMap, 
            offset  = 0x01200000, 
            expand  = False,
        ))
        
        self.add(axi.AxiMemTester( 
            name    = 'AxiMemTester', 
            memBase = memMap, 
            offset  = 0x00400000, 
            expand  = False,
        ))
        
        for i in range(16):
            asicSaciAddr = [
                0x04000000, 0x04400000, 0x04800000, 0x04C00000,
                0x05000000, 0x05400000, 0x05800000, 0x05C00000,
                0x06000000, 0x06400000, 0x06800000, 0x06C00000,
                0x07000000, 0x07400000, 0x07800000, 0x07C00000
            ]
            self.add(epix.Epix10kaAsic(
                  name    = ('Epix10kaSaci[%d]'%i),
                  memBase = memMap, 
                  offset  = asicSaciAddr[i], 
                  enabled = False,
                  expand  = False,
            ))
        
        if (hwType != 'simulation'):
            confAddr = [
               0x02A00000, 0x02A00800, 0x02A01000, 0x02A01800, 0x02B00000, 
               0x02B00800, 0x02B01000, 0x02B01800, 0x02C00000, 0x02C00800
            ]
            for i in range(10):      
                self.add(analog_devices.Ad9249ConfigGroup(
                    name    = ('Ad9249Config[%d]'%i),
                    memBase = memMap, 
                    offset  = confAddr[i], 
                    enabled = False,
                    expand  = False,
                ))
        
        for i in range(10):      
            self.add(analog_devices.Ad9249ReadoutGroup(
                  name    = ('Ad9249Readout[%d]'%i),
                  memBase = memMap, 
                  offset  = (0x02000000+i*0x00100000), 
                  expand  = False,
                  fpga    = 'ultrascale',
            ))
        
        self.add(ePixQuad.AdcTester( 
            name    = 'Ad9249Tester', 
            memBase = memMap, 
            offset  = 0x02D00000, 
            expand  = False,
        ))
        
        ######################################################################
        
        @self.command(description="ADC Initialization",)
        def AdcInit():
            
            # Enable all devices
            self.SystemRegs.enable.set(True)
            self._root.checkBlocks(recurse=True)
            self.Ad9249Tester.enable.set(True)
            self._root.checkBlocks(recurse=True)
            for adc in range(10):
               self.Ad9249Readout[adc].enable.set(True)
               self._root.checkBlocks(recurse=True)
               if (hwType != 'simulation'):
                  self.Ad9249Config[adc].enable.set(True)
                  self._root.checkBlocks(recurse=True)
            
            # Enable DCDCs
            print('Enable DCDCs')
            self.SystemRegs.DcDcEnable.set(0xF)
            self._root.checkBlocks(recurse=True)
            time.sleep(1.0)
            
            # Reset ADCs
            if (hwType != 'simulation'):
               for adc in range(10):
                  print('ADC[%d] assert digital reset'%adc)
                  self.Ad9249Config[adc].InternalPdwnMode.set(3)
                  self._root.checkBlocks(recurse=True)
                  self.Ad9249Config[adc].InternalPdwnMode.set(0)
                  self._root.checkBlocks(recurse=True)
               time.sleep(1.0)
            
            # Reset deserializers
            print('Reset ISERDESE3')
            self.SystemRegs.AdcClkRst.set(True)
            self._root.checkBlocks(recurse=True)
            self.SystemRegs.AdcClkRst.set(False)
            self._root.checkBlocks(recurse=True)
            time.sleep(1.0)
            
            # apply pretrained delays
            adcDelays = [
                [253, 234, 226, 244, 234, 270, 269, 265, 257],
                [244, 228, 267, 231, 254, 281, 268, 284, 275],
                [372, 367, 362, 368, 361, 380, 365, 380, 388],
                [300, 256, 218, 247, 199, 249, 237, 258, 206],
                [376, 369, 369, 374, 369, 388, 369, 398, 396],
                [231, 242, 244, 255, 256, 269, 269, 266, 261],
                [260, 229, 215, 240, 251, 278, 281, 283, 254],
                [232, 280, 271, 274, 290, 291, 295, 295, 292],
                [232, 251, 225, 264, 259, 221, 229, 250, 240],
                [242, 256, 264, 228, 243, 215, 217, 203, 205]
            ]
            for adc in range(10):
                self.Ad9249Readout[adc].FrameDelay.set(0x200+adcDelays[adc][0])
                self._root.checkBlocks(recurse=True)
                print('ADC[%d] frame delay set to %d'%(adc, adcDelays[adc][0]))
                for channel in range(8):
                    self.Ad9249Readout[adc].ChannelDelay[channel].set(0x200+adcDelays[adc][1+channel])
                    self._root.checkBlocks(recurse=True)
                    print('ADC[%d] channel[%d] delay set to %d'%(adc, channel, adcDelays[adc][1+channel]))
            
            # enable offset binary mode
            if (hwType != 'simulation'):
               for adc in range(10):
                  print('ADC[%d] enable offset binary output'%adc)
                  self.Ad9249Config[adc].OutputFormat.set(0)
                  self._root.checkBlocks(recurse=True)
        
        ######################################################################
        