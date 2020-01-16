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
import rogue.hardware.axi
import rogue.utilities.fileio

import pyrogue
import pyrogue as pr
import pyrogue.protocols
import pyrogue.utilities.fileio
import pyrogue.interfaces.simulation
import time

import surf.axi                     as axi
import surf.devices.analog_devices  as analog_devices
import surf.devices.cypress         as cypress
import surf.xilinx                  as xil

import ePixAsics as epix

import ePixQuad

class Top(pr.Root):
    def __init__(   self,       
            name        = "Top",
            description = "Container for EpixQuad",
            dev         = '/dev/pgpcard_0',
            hwType      = 'pgp3_cardG3',
            lane        = 0,
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
        elif (hwType == 'datadev'):
            self.pgpVc0 = rogue.hardware.axi.AxiStreamDma(dev,32*lane+0,True) # Data & cmds
            self.pgpVc1 = rogue.hardware.axi.AxiStreamDma(dev,32*lane+1,True) # Registers for ePix board
            self.pgpVc2 = rogue.hardware.axi.AxiStreamDma(dev,32*lane+2,True) # PseudoScope
            self.pgpVc3 = rogue.hardware.axi.AxiStreamDma(dev,32*lane+3,True) # Monitoring (Slow ADC)        
        else:
            self.pgpVc0 = rogue.hardware.pgp.PgpCard(dev,lane,0) # Data & cmds
            self.pgpVc1 = rogue.hardware.pgp.PgpCard(dev,lane,1) # Registers for ePix board
            self.pgpVc2 = rogue.hardware.pgp.PgpCard(dev,lane,2) # PseudoScope
            self.pgpVc3 = rogue.hardware.pgp.PgpCard(dev,lane,3) # Monitoring (Slow ADC)
                
        ######################################################################
        
        # Connect the SRPv3 to PGPv3.VC[0]
        memMap = rogue.protocols.srp.SrpV3()                
        pr.streamConnectBiDir(self.pgpVc0, memMap)             
        
        pyrogue.streamConnect(self.pgpVc1, dataWriter.getChannel(0x1))
        # Add pseudoscope to file writer
        pyrogue.streamConnect(self.pgpVc2, dataWriter.getChannel(0x2))
        pyrogue.streamConnect(self.pgpVc3, dataWriter.getChannel(0x3))
        
        cmdVc1 = rogue.protocols.srp.Cmd()
        pyrogue.streamConnect(cmdVc1, self.pgpVc1)
        cmdVc3 = rogue.protocols.srp.Cmd()
        pyrogue.streamConnect(cmdVc3, self.pgpVc3)
        
        @self.command()
        def ClearAsicMatrix():
            # save TrigEn state and stop
            self.SystemRegs.enable.set(True)
            trigEn = self.SystemRegs.TrigEn.get()
            self.SystemRegs.TrigEn.set(False)
            # clear matrix in all enabled ASICs
            for i in range(16):
                self.Epix10kaSaci[i].ClearMatrix()
            # restore TrigEn state
            self.SystemRegs.TrigEn.set(trigEn)
        
        @self.command()
        def MonStrEnable():
            cmdVc3.sendCmd(1, 0)
        
        @self.command()
        def MonStrDisable():
            cmdVc3.sendCmd(0, 0)
        
        
        ######################################################################
        
        # Add devices
        self.add(ePixQuad.EpixVersion( 
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
        
        self.add(axi.AxiStreamMonitoring( 
            name    = 'RdoutStreamMonitoring', 
            memBase = memMap, 
            offset  = 0x01300000, 
            expand  = False,
        ))
        
        self.add(ePixQuad.PseudoScopeCore( 
            name    = 'PseudoScopeCore', 
            memBase = memMap, 
            offset  = 0x01200000, 
            expand  = False,
        ))
        
        if (hwType != 'simulation'): 
            self.add(ePixQuad.VguardDac( 
               name    = 'VguardDac', 
               memBase = memMap, 
               offset  = 0x00500000, 
               expand  = False,
            ))
        
        self.add(ePixQuad.EpixQuadMonitor( 
            name    = 'EpixQuadMonitor', 
            memBase = memMap, 
            offset  = 0x00700000, 
            expand  = False,
        ))
        
        #################################################
        # DO NOT MAP. MICROBLAZE IS THE ONLY 
        # AXI LITE MASTER THAT SHOULD ACCESS THIS DEVICE
        #################################################
        self.add(ePixQuad.AxiI2cMaster( 
            name    = 'AxiI2cMaster', 
            memBase = memMap, 
            offset  = 0x00600000, 
            expand  = False,
            hidden  = True,
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
        
        self.add(ePixQuad.SaciConfigCore( 
            name       = 'SaciConfigCore', 
            memBase    = memMap, 
            offset     = 0x08000000, 
            expand     = False,
            simSpeedup = (hwType == 'simulation'),
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
                  enabled = False,
                  expand  = False,
                  fpga    = 'ultrascale',
            ))
        
        self.add(ePixQuad.AdcTester( 
            name    = 'Ad9249Tester', 
            memBase = memMap, 
            offset  = 0x02D00000, 
            enabled = False,
            expand  = False,
        ))
                
        if (hwType != 'simulation'):
        
            self.add(cypress.CypressS25Fl(
               offset   = 0x00300000, 
               memBase  = memMap,
               expand   = False, 
               addrMode = True, 
               hidden   = True, 
            ))                   
         
        