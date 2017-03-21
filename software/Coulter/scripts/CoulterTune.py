#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : PyRogue febBoard Module
#-----------------------------------------------------------------------------
# File       : febBoard.py
# Author     : Larry Ruckman <ruckman@slac.stanford.edu>
# Created    : 2016-11-09
# Last update: 2016-11-09
#-----------------------------------------------------------------------------
# Description:
# Rogue interface to FEB board
#-----------------------------------------------------------------------------
# This file is part of the ATLAS CHESS2 DEV. It is subject to 
# the license terms in the LICENSE.txt file found in the top-level directory 
# of this distribution and at: 
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
# No part of the ATLAS CHESS2 DEV, including this file, may be 
# copied, modified, propagated, or distributed except according to the terms 
# contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------
#import rogue.hardware.pgp
import rogue.interfaces.memory
import pyrogue.simulation
import pyrogue.utilities.fileio
import pyrogue.gui
import pyrogue.mesh
import pyrogue.epics
import coulter
import threading
import signal
import atexit
import yaml
import time
import sys
import PyQt4.QtGui
import PyQt4.QtCore
import logging


# File writer
dataWriter = pyrogue.utilities.fileio.StreamWriter('dataWriter')

#logging.getLogger("pyrogue.SRP").setLevel(logging.INFO)
#logging.getLogger("pyrogue.DATA[0]").setLevel(logging.INFO)


# Create the PGP interfaces

vcReg = [rogue.hardware.pgp.PgpCard('/dev/pgpcard_0',i,0) for i in range(2)] # Registers
vcData = [rogue.hardware.pgp.PgpCard('/dev/pgpcard_0',i,1) for i in range(2)] # Data
vcTrigger = vcReg[0]


#print("")
#print("PGP Card Version: %x" % (vcReg.getInfo().version))

# Create and Connect SRPv0 to VC0 
srp = [rogue.protocols.srp.SrpV0() for i in range(2)]

for i in range(2):
    pyrogue.streamConnectBiDir(vcReg[i] ,srp[i])
    pyrogue.streamConnect(vcData[i], dataWriter.getChannel(i))
    vcReg[i].setDebug(16, "VC[{}]".format(i))
    
dbgSrp = rogue.interfaces.stream.Slave()
dbgSrp.setDebug(16, "SRP")
#pyrogue.streamTap(srp[0], dbgSrp)

parsers = [coulter.CoulterFrameParser(), coulter.CoulterFrameParser()]

for i in range(2):
    dbgData = rogue.interfaces.stream.Slave()
    #dbgData.setDebug(1, "DATA[{}]".format(i))
    pyrogue.streamTap(vcData[i], dbgData)
    pyrogue.streamTap(vcData[i], parsers[i])
    


# Instantiate top and pass stream and srp configurations
coulterDaq = coulter.CoulterRoot(pollEn=False, pgp=vcReg, srp=srp, trig=vcTrigger, dataWriter=dataWriter)
#coulterDaq.setTimeout(100000000)
#coulterDaq = pyrogue.Root(name="CoulterDaq", description="Coulter Data Acquisition")
#coulterDaq.add(coulter.CoulterRunControl(name="RunControl"))
#coulterDaq.add(coulter.Coulter(name="Coulter0"))
#coulterDaq.add(pyrogue.Device("Test"))

#mNode = pyrogue.mesh.MeshNode('MeshTest', root=coulterDaq, iface='eth1')
#mNode.start()

#epics = pyrogue.epics.EpicsCaServer('MeshTest', coulterDaq)
#epics.start()

# def stop():
#    mNode.stop()
#    evalBoard.stop()
#    exit()


coulterDaq.readConfig('/afs/slac/u/re/bareese/projects/epix-git/software/Coulter/cfg/config5.yml')

#for phase in range(0, 65536, 32):
#print('Phase: {}'.format(phase))
#coulterDaq.Coulter[0].AcquisitionControl.AdcClkDelay.set(phase, True)
#for delay in range(2**9):



delay = 210

while True:
    tmp = input("Delay: ({})".format(delay))
    if tmp != '':
        delay = int(tmp)
    
    coulterDaq.Coulter[0].AcquisitionControl.AdcWindowDelay.set(delay, True)
    coulterDaq.Coulter[0].AcquisitionControl.AdcClkDelay.set(5, True)
#    coulterDaq.Coulter[0].AcquisitionControl.ScCount.set(2048, True)    
    coulterDaq.Coulter[0].ASIC[0].atest.set(0, True)
    coulterDaq.Coulter[0].ASIC[1].atest.set(0, True)         


    coulterDaq.Trigger()

    time.sleep(.1)

    f = parsers[0].lastFrame()
    #print(list(f.keys()), delay)
    slot = 2
 
    for slot in (a for a in sorted(f.keys()) if a%2==1):
        for channel in [0,]:
            data = [f[slot][channel][pixel] for pixel in sorted(f[slot][channel].keys())]
            print('Slot: {}, Channel: {}, Data: {}'.format(slot, channel, ['{:.3f}_{}'.format(voltage(d), hex(d)) for d in data]))

