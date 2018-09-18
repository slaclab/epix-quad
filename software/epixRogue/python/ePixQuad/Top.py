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
            pgpVc0 = pr.interfaces.simulation.StreamSim(host='localhost', dest=0, uid=1, ssi=True)
            pgpVc1 = pr.interfaces.simulation.StreamSim(host='localhost', dest=1, uid=1, ssi=True)
            pgpVc2 = pr.interfaces.simulation.StreamSim(host='localhost', dest=2, uid=1, ssi=True)
            pgpVc3 = pr.interfaces.simulation.StreamSim(host='localhost', dest=3, uid=1, ssi=True)      
        else:
            pgpVc0 = rogue.hardware.pgp.PgpCard(dev,0,0) # Data & cmds
            pgpVc1 = rogue.hardware.pgp.PgpCard(dev,0,1) # Registers for ePix board
            pgpVc2 = rogue.hardware.pgp.PgpCard(dev,0,2) # PseudoScope
            pgpVc3 = rogue.hardware.pgp.PgpCard(dev,0,3) # Monitoring (Slow ADC)
                
        ######################################################################
        
        # Connect the SRPv3 to PGPv3.VC[0]
        memMap = rogue.protocols.srp.SrpV3()                
        pr.streamConnectBiDir(pgpVc1, memMap)             
        
        pyrogue.streamConnect(pgpVc0, dataWriter.getChannel(0x1))
        # Add pseudoscope to file writer
        pyrogue.streamConnect(pgpVc2, dataWriter.getChannel(0x2))
        pyrogue.streamConnect(pgpVc3, dataWriter.getChannel(0x3))
        
        cmd = rogue.protocols.srp.Cmd()
        pyrogue.streamConnect(cmd, pgpVc0)
        
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
        