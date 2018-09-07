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

import surf.axi as axiVer
import surf.xilinx as xil
import surf.devices.micron as prom
import surf.devices.linear as linear
import surf.devices.nxp as nxp


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
        self.add(axiVer.AxiVersion( 
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
            offset  = 0x01400000, 
            expand  = False,
        ))
        
        ######################################################################
        