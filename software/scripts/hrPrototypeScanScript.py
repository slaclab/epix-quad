#!/usr/bin/env python3
#-----------------------------------------------------------------------------
# Title      : ePix 100a board instance
#-----------------------------------------------------------------------------
# File       : epix100aDAQ.py evolved from evalBoard.py
# Author     : Ryan Herbst, rherbst@slac.stanford.edu
# Modified by: Dionisio Doering
# Created    : 2016-09-29
# Last update: 2017-02-01
#-----------------------------------------------------------------------------
# Description:
# Rogue interface to ePix 100a board
#-----------------------------------------------------------------------------
# This file is part of the rogue_example software. It is subject to 
# the license terms in the LICENSE.txt file found in the top-level directory 
# of this distribution and at: 
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
# No part of the rogue_example software, including this file, may be 
# copied, modified, propagated, or distributed except according to the terms 
# contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------
import rogue.hardware.pgp
import pyrogue.utilities.prbs
import pyrogue.utilities.fileio
import pyrogue.gui
import surf
import surf.axi
import surf.protocols.ssi
import threading
import signal
import atexit
import yaml
import time
import sys
import testBridge
import ePixViewer as vi
import ePixFpga as fpga
import numpy as np

try:
    from PyQt5.QtWidgets import *
    from PyQt5.QtCore    import *
    from PyQt5.QtGui     import *
except ImportError:
    from PyQt4.QtCore    import *
    from PyQt4.QtGui     import *

#-----------------------------------------------------------------------------
# To convert the generated data use
#-----------------------------------------------------------------------------
#-----------------------------------------------------------------------------
# virtualenv /u1/ddoering/localPython/
# cd /u1/ddoering/localPython/bin/
# source bin/activate.csh
# call the datatranslator script, for TEST_SCAN_SDCLK_SD_RST use
# ipython3 scripts/imgProc/read_read_from_file_HrAdc_ScanScript_SDcleSDrst*.py
# *change in the script the run number to select the appropriated one
#-----------------------------------------------------------------------------
# to run notebooks
#-----------------------------------------------------------------------------
# .anaconda/navigator/scripts/notebook.sh &


#############################################
# Define if the GUI is started (1 starts it)
START_GUI = True
START_VIEWER = True
TEST_SCAN_SDCLK_SD_RST = False
TEST_S2D = True
#############################################
#Define driver used
#DRIVER = 'pgp-gen3'  
DRIVER = 'kcu1500'
#############################################
if ( DRIVER == 'pgp-gen3' ):
    # Create the PGP interfaces for ePix camera
    pgpVc0 = rogue.hardware.pgp.PgpCard('/dev/pgpcard_0',0,0) # Data & cmds
    pgpVc1 = rogue.hardware.pgp.PgpCard('/dev/pgpcard_0',0,1) # Registers for ePix board
    pgpVc2 = rogue.hardware.pgp.PgpCard('/dev/pgpcard_0',0,2) # PseudoScope
    pgpVc3 = rogue.hardware.pgp.PgpCard('/dev/pgpcard_0',0,3) # Monitoring (Slow ADC)

    print("")
    print("PGP Card Version: %x" % (pgpVc0.getInfo().version))
elif ( DRIVER == 'kcu1500' ):
    # Create the PGP interfaces for ePix hr camera
    pgpVc0 = rogue.hardware.data.DataCard('/dev/datadev_0',(0*32)+0) # Data & cmds
    pgpVc1 = rogue.hardware.data.DataCard('/dev/datadev_0',(0*32)+1) # Registers for ePix board
    pgpVc2 = rogue.hardware.data.DataCard('/dev/datadev_0',(0*32)+2) # PseudoScope
    pgpVc3 = rogue.hardware.data.DataCard('/dev/datadev_0',(0*32)+3) # Monitoring (Slow ADC)
else:
    raise ValueError("Invalid type (%s)" % (args.type) )



# Add data stream to file as channel 1
# File writer
dataWriter = pyrogue.utilities.fileio.StreamWriter(name = 'dataWriter')
pyrogue.streamConnect(pgpVc0, dataWriter.getChannel(0x1))
# Add pseudoscope to file writer
pyrogue.streamConnect(pgpVc2, dataWriter.getChannel(0x2))
pyrogue.streamConnect(pgpVc3, dataWriter.getChannel(0x3))

cmd = rogue.protocols.srp.Cmd()
pyrogue.streamConnect(cmd, pgpVc0)

# Create and Connect SRP to VC1 to send commands
srp = rogue.protocols.srp.SrpV0()
pyrogue.streamConnectBiDir(pgpVc1,srp)

#############################################
# Microblaze console printout
#############################################
class MbDebug(rogue.interfaces.stream.Slave):

    def __init__(self):
        rogue.interfaces.stream.Slave.__init__(self)
        self.enable = False

    def _acceptFrame(self,frame):
        if self.enable:
            p = bytearray(frame.getPayload())
            frame.read(p,0)
            print('-------- Microblaze Console --------')
            print(p.decode('utf-8'))

#######################################
# Custom run control
#######################################
class MyRunControl(pyrogue.RunControl):
    def __init__(self,name):
        pyrogue.RunControl.__init__(self,name=name,description='Run Controller HR prototype', rates={1:'1 Hz', 2:'2 Hz', 4:'4 Hz', 8:'8 Hz', 10:'10 Hz', 30:'30 Hz', 60:'60 Hz', 120:'120 Hz'})
        self._thread = None
        
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
            self._root.Trigger()

            self._runCount += 1
            if self._last != int(time.time()):
                self._last = int(time.time())
                self.runCount._updated()
            
##############################
# Set base
##############################
class EpixBoard(pyrogue.Root):
    def __init__(self, guiTop, cmd, dataWriter, srp, **kwargs):
        super().__init__(name = 'ePixBoard', description = 'HR prototype Board', **kwargs)
        #self.add(MyRunControl('runControl'))
        self.add(dataWriter)
        self.guiTop = guiTop

        @self.command()
        def Trigger():
            cmd.sendCmd(0, 0)

        # Add Devices
        self.add(fpga.HrPrototype(name='hrFPGA', offset=0, memBase=srp, hidden=False, enabled=True))
        self.add(pyrogue.RunControl(name = 'runControl', description='Run Controller hr prototype', cmd=self.Trigger, rates={1:'1 Hz', 2:'2 Hz', 4:'4 Hz', 8:'8 Hz', 10:'10 Hz', 30:'30 Hz', 60:'60 Hz', 120:'120 Hz'}))




# Create GUI
appTop = QApplication(sys.argv)
guiTop = pyrogue.gui.GuiTop(group = 'HRGui')
ePixBoard = EpixBoard(guiTop, cmd, dataWriter, srp)
ePixBoard.start()
guiTop.addTree(ePixBoard)

# Viewer gui
if(START_VIEWER):
    gui = vi.Window(cameraType = 'HrAdc32x32')
    gui.eventReader.frameIndex = 0
    gui.setReadDelay(0)
    pyrogue.streamTap(pgpVc0, gui.eventReader)
    pyrogue.streamTap(pgpVc2, gui.eventReaderScope)# PseudoScope
    pyrogue.streamTap(pgpVc3, gui.eventReaderMonitoring) # Slow Monitoring

# Create mesh node (this is for remote control only, no data is shared with this)
#mNode = pyrogue.mesh.MeshNode('rogueEpix100a',iface='eth0',root=None)
#mNode.setNewTreeCb(guiTop.addTree)
#mNode.start()

# Run gui
if (START_GUI):
    appTop.exec_()

# Close window and stop polling
def stop():
    mNode.stop()
    ePixBoard.stop()
    exit()

print("Started rogue mesh and epics V3 server. To exit type stop()")

if (TEST_SCAN_SDCLK_SD_RST):
    #read config parameters for the fpga and asic
    ePixBoard.readConfig("yml/epixHR_ADCOnly.yml")

    #set HS dac waveform
    #ePixBoard.hrFPGA.SetWaveform('ramp.csv')
    waveform = np.genfromtxt('ramp.csv', delimiter=',', dtype='uint16')
    if waveform.shape == (1024,):
        for x in range (0, 1024):
            ePixBoard.hrFPGA._rawWrite(offset = (0x0E000000 + x * 4),data =  int(waveform[x]))
        print('Waveform file uploaded')
    else:
        print('wrong csv file format')

    ePixBoard.hrFPGA.HighSpeedDAC.enabled.set(True)
    ePixBoard.hrFPGA.HighSpeedDAC.externalUpdateEn.set(True)
    ePixBoard.hrFPGA.HighSpeedDAC.run.set(True)

    #Sync deserializers
    ePixBoard.hrFPGA.Asic0Deserializer.Resync.set(True)
    ePixBoard.hrFPGA.Asic1Deserializer.Resync.set(True)

    time.sleep(1.0 / float(120))

    print ("ASIC0 locked: ",  ePixBoard.hrFPGA.Asic0Deserializer.Locked.get())
    print ("ASIC1 locked: ",  ePixBoard.hrFPGA.Asic1Deserializer.Locked.get())

    for reSyncAttempts in range(0,10):
        if ePixBoard.hrFPGA.Asic0Deserializer.Locked.get() == False:
            ePixBoard.hrFPGA.Asic0Deserializer.Resync.set(True)
            time.sleep(1.0 / float(1))
            print ("ASIC0 locked: ",  ePixBoard.hrFPGA.Asic0Deserializer.Locked.get())

    for reSyncAttempts in range(0,10):
        if ePixBoard.hrFPGA.Asic1Deserializer.Locked.get() == False:
            ePixBoard.hrFPGA.Asic1Deserializer.Resync.set(True)
            time.sleep(1.0 / float(1))
            print ("ASIC1 locked: ",  ePixBoard.hrFPGA.Asic1Deserializer.Locked.get())

    fileFolders = [ ['/u1/ddoering/hrdata/rampData/','/u1/ddoering/hrdata/dark/'] ]
    fileNameRoot = 'ramp_scan_'
    ####
    FileNameRun = '_run' + str(10) + '.dat'
    ####
    
    # enabling second order bit makes adc to send zeros all the time
    #ePixBoard.hrFPGA.HrAdcAsic0.SecondOrder.set(True)

    ePixBoard.hrFPGA.HrAdcAsic0.shvc_DAC.set(28) # default is 0x17 or 23
    
    #config pixels
    for SDclk in range(0,16):
        for SDrst in range(0,16):
            #set ASIC parameters
            ePixBoard.hrFPGA.HrAdcAsic0.SDclk_b.set(SDclk)
            ePixBoard.hrFPGA.HrAdcAsic0.SDrst_b.set(SDrst)

            #create current filename
            fullFileName = fileFolders[0][0]+fileNameRoot+'SDclk_'+str(SDclk)+'SDrst_'+str(SDrst)+FileNameRun
            print(fullFileName)
            ePixBoard.dataWriter.dataFile.set(fullFileName)
            ePixBoard.dataWriter.open.set(True)

            time.sleep(1.0 / float(1))

            # gets data
            for frames in range(0,2048):     
                ePixBoard.Trigger()
                time.sleep(1.0 / float(120))

            ePixBoard.dataWriter.open.set(False)


if (TEST_S2D):
    #read config parameters for the fpga and asic
    ePixBoard.readConfig("yml/epixHR_ADCOnly.yml")

    #set HS dac waveform
    #ePixBoard.hrFPGA.SetWaveform('ramp.csv')
    waveform = np.genfromtxt('ramp.csv', delimiter=',', dtype='uint16')
    if waveform.shape == (1024,):
        for x in range (0, 1024):
            ePixBoard.hrFPGA._rawWrite(offset = (0x0E000000 + x * 4),data =  int(waveform[x]))
        print('Waveform file uploaded')
    else:
        print('wrong csv file format')

    ePixBoard.hrFPGA.HighSpeedDAC.enabled.set(True)
    ePixBoard.hrFPGA.HighSpeedDAC.externalUpdateEn.set(True)
    ePixBoard.hrFPGA.HighSpeedDAC.run.set(True)

    #Sync deserializers
    ePixBoard.hrFPGA.Asic0Deserializer.Resync.set(True)
    ePixBoard.hrFPGA.Asic1Deserializer.Resync.set(True)

    time.sleep(1.0 / float(120))

    print ("ASIC0 locked: ",  ePixBoard.hrFPGA.Asic0Deserializer.Locked.get())
    print ("ASIC1 locked: ",  ePixBoard.hrFPGA.Asic1Deserializer.Locked.get())

    for reSyncAttempts in range(0,10):
        if ePixBoard.hrFPGA.Asic0Deserializer.Locked.get() == False:
            ePixBoard.hrFPGA.Asic0Deserializer.Resync.set(True)
            time.sleep(1.0 / float(1))
            print ("ASIC0 locked: ",  ePixBoard.hrFPGA.Asic0Deserializer.Locked.get())

    for reSyncAttempts in range(0,10):
        if ePixBoard.hrFPGA.Asic1Deserializer.Locked.get() == False:
            ePixBoard.hrFPGA.Asic1Deserializer.Resync.set(True)
            time.sleep(1.0 / float(1))
            print ("ASIC1 locked: ",  ePixBoard.hrFPGA.Asic1Deserializer.Locked.get())

    fileFolders = [ ['/u1/ddoering/hrdata/rampData/','/u1/ddoering/hrdata/dark/'] ]
    fileNameRoot = 'ramp_scan_'
    ####
    FileNameRun = '_run' + str(14) + '.dat'
    ####
    
    # enabling second order bit makes adc to send zeros all the time
    #ePixBoard.hrFPGA.HrAdcAsic0.SecondOrder.set(True)

    ePixBoard.hrFPGA.HrAdcAsic0.shvc_DAC.set(28) # default is 0x17 or 23
    
    #config pixels
    for SDclk in range(0,16):
        for S2D_1_b in range(0,8):
            #set ASIC parameters
            ePixBoard.hrFPGA.HrAdcAsic0.SDclk_b.set(SDclk)
            ePixBoard.hrFPGA.HrAdcAsic0.S2D_1_b.set(S2D_1_b)

            #create current filename
            fullFileName = fileFolders[0][0]+fileNameRoot+'SDclk_'+str(SDclk)+'S2D_1_b_'+str(S2D_1_b)+FileNameRun
            print(fullFileName)
            ePixBoard.dataWriter.dataFile.set(fullFileName)
            ePixBoard.dataWriter.open.set(True)

            time.sleep(1.0 / float(1))

            # gets data
            for frames in range(0,2048):     
                ePixBoard.Trigger()
                time.sleep(1.0 / float(120))

            ePixBoard.dataWriter.open.set(False)


print("Started rogue mesh and epics V3 server. To exit type stop()")
