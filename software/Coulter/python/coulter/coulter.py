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
import coulter

class Coulter(pr.Device):
    def __init__(self, name, offset=0, memBase=None, hidden=False):

        super(Coulter, self).__init__(name, "Coulter FPGA", 0x10000, memBase, offset, hidden)

        self.add(surf.AxiVersion.create(offset=0x00000000))
        self.add(coulter.ELine100Config(name='ASIC 0', offset=0x00001000))
        self.add(coulter.ELine100Config(name='ASIC 1', offset=0x00002000))
        self.add(surf.Ad9252Config.create(offset=0x00003000, chipCount=2))
        self.add(surf.Ad9252Readout.create(offset=0x00004000))
        self.add(surf.Ad9252Readout.create(offset=0x00005000))                
        self.add(coulter.AcquisitionControl.create(offset=0x00006000))
        self.add(coulter.CoulterPgp.create(offset=0x00007000))


class CoulterPgp(pr.Device):
    def __init__(self, name, offset=0, memBase=None, hidden=False):
        # Double check size param
        super(CoulterPgp, self).__init__(name, "CoulterPgp", 0x10000, memBase, offset, hidden)

        self.add(surf.Pgp2bAxi())
#        self.add(surf.Gtp7Axi())

        
class ELine100Config(pr.Device):

    def __init__(self, name, memBase, offset, hidden):

        super(ELine100Config, self).__init__(name, "ELine 100 ASIC Configuration",
                                             0x100, memBase, offset, hidden)

        for i in xrange(96):
            self.add(pr.Variable(name= "Ch" + i + "_somi",
                                 description = "Channel " + i + " Selector Enable",
                                 offset = i/2,
                                 bitSize = 1,
                                 bitOffset = (i%2)*4,
                                 base = 'bool',
                                 mode = 'RW'))
            self.add(pr.Variable(name = "Ch" + i + "_sm",
                                 description = "Channel " + i + " Mask",
                                 offset = i/2,
                                 bitSize = 1,
                                 bitOffset = (i%2)*4+1,
                                 base = 'bool',
                                 mode = 'RW'))
            self.add(pr.Variable(name = "Ch" + i + "_st",
                                 description = "Enable Test on channel " + i,
                                 offset = i/2,
                                 bitSize = 1,
                                 bitOffset = (i%2)*4+2,
                                 base = 'bool',
                                 mode = 'RW'))

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
        self.add(pr.Variable(name = "pa",      offset = 0x34, bitOffset = 0 , bitSize = 10, description =  "Threshold DAC"))
        self.add(pr.Variable(name = "esm",     offset = 0x34, bitOffset = 10, bitSize = 1,  description = "Enable DAC Monitor"))
        self.add(pr.Variable(name = "t",       offset = 0x34, bitOffset = 11, bitSize = 3,  description = "Filter time to flat top"))
        self.add(pr.Variable(name = "dd",      offset = 0x34, bitOffset = 14, bitSize = 1,  description =  "DAC Monitor Select (0-thr, 1-pulser)"))
        self.add(pr.Variable(name = "sabtest", offset = 0x34, bitOffset = 15, bitSize = 1,  description = "Select CDS test"))
        self.add(pr.Variable(name = "clab",    offset = 0x34, bitOffset = 16, bitSize = 3,  description = "Pump Timeout"))
        self.add(pr.Variable(name = "tres",    offset = 0x34, bitOffset = 19, bitSize = 3,  description = "Reset Tweak OP"))
           
        self.add(pr.Command(name = "WriteAsic", description = "Write the current configuration registers into the ASIC",
                            offset = 0x40, bitSize = 1, bitOffset = 0, hidden = True))
        self.add(pr.Command(name = "ReadAsic", description = "Read the current configuration registers from the ASIC",
                            offset = 0x44, bitSize = 1, bitOffset = 0, hidden = True))

        def _afterWrite(self):
            pass
