#!/usr/bin/env python3
#-----------------------------------------------------------------------------
# Title      : ePix 10ka board instance
#-----------------------------------------------------------------------------
# File       : epix10kaDAQ.py evolved from evalBoard.py
# Created    : 2017-06-19
# Last update: 2017-06-21
#-----------------------------------------------------------------------------
# Description:
# Rogue interface to ePix 10ka board
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

#############################################
#############################################
# Define if the GUI is started (1 starts it)
START_GUI = False
START_VIEWER = False
#############################################
#############################################
# Available tests
TEST_DARK = False
#and (Random pixel selection)
TEST_LINEARITY_TEST_A = False
#or
TEST_LINEARITY_TEST_B = False
#and (row pixel selection)
TEST_LINEARITY_TEST_C = False
#or 
TEST_LINEARITY_TEST_D = False
#and (col pixel selection)
TEST_LINEARITY_TEST_E = False
#or 
TEST_LINEARITY_TEST_F = False
#or 
TEST_WEIGHTINGFUNCTION = True
#############################################
#print debug info
PRINT_VERBOSE = False
#############################################

# Create the PGP interfaces for ePix camera
pgpVc0 = rogue.hardware.pgp.PgpCard('/dev/pgpcard_0',0,0) # Data & cmds
pgpVc1 = rogue.hardware.pgp.PgpCard('/dev/pgpcard_0',0,1) # Registers for ePix board
pgpVc2 = rogue.hardware.pgp.PgpCard('/dev/pgpcard_0',0,2) # PseudoScope
pgpVc3 = rogue.hardware.pgp.PgpCard('/dev/pgpcard_0',0,3) # Monitoring (Slow ADC)

print("")
print("PGP Card Version: %x" % (pgpVc0.getInfo().version))


# Add data stream to file as channel 1
# File writer
dataWriter = pyrogue.utilities.fileio.StreamWriter(name='dataWriter')
pyrogue.streamConnect(pgpVc0, dataWriter.getChannel(0x1))
# Add pseudoscope to file writer
#pyrogue.streamConnect(pgpVc2, dataWriter.getChannel(0x2))
#pyrogue.streamConnect(pgpVc3, dataWriter.getChannel(0x3))

cmd = rogue.protocols.srp.Cmd()
pyrogue.streamConnect(cmd, pgpVc0)

# Create and Connect SRP to VC1 to send commands
srp = rogue.protocols.srp.SrpV0()
pyrogue.streamConnectBiDir(pgpVc1,srp)

# Add configuration stream to file as channel 0
# Removed to reduce amount of data going to file
#pyrogue.streamConnect(ePixBoard,dataWriter.getChannel(0x0))

## Add microblaze console stream to file as channel 2
#pyrogue.streamConnect(pgpVc3,dataWriter.getChannel(0x2))

# PRBS Receiver as secdonary receiver for VC1
#prbsRx = pyrogue.utilities.prbs.PrbsRx('prbsRx')
#pyrogue.streamTap(pgpVc1,prbsRx)
#ePixBoard.add(prbsRx)

# Microblaze console monitor add secondary tap
#mbcon = MbDebug()
#pyrogue.streamTap(pgpVc3,mbcon)

#br = testBridge.Bridge()
#br._setSlave(srp)

#ePixBoard.add(surf.SsiPrbsTx.create(memBase=srp1,offset=0x00000000*4))

# Create epics node
#epics = pyrogue.epics.EpicsCaServer('rogueTest',ePixBoard)
#epics.start()


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

            
##############################
# Set base
##############################
class EpixBoard(pyrogue.Root):
    def __init__(self, guiTop, cmd, dataWriter, srp, **kwargs):
        super().__init__(name='ePixBoard',description='ePix 10ka Board', **kwargs)
        #self.add(MyRunControl('runControl'))
        self.add(dataWriter)
        self.guiTop = guiTop

        @self.command()
        def Trigger():
            cmd.sendCmd(0, 0)

        # Add Devices
        self.add(fpga.Epix10ka(name='Epix10ka', offset=0, memBase=srp, hidden=False, enabled=True))
        self.add(pyrogue.RunControl(name = 'runControl', description='Run Controller ePix 10ka', cmd=self.Trigger, rates={1:'1 Hz', 2:'2 Hz', 4:'4 Hz', 8:'8 Hz', 10:'10 Hz', 30:'30 Hz', 60:'60 Hz', 120:'120 Hz'}))
        

        


# debug
#mbcon = MbDebug()
#pyrogue.streamTap(pgpVc0,mbcon)

#mbcon1 = MbDebug()
#pyrogue.streamTap(pgpVc1,mbcon)

#mbcon2 = MbDebug()
#pyrogue.streamTap(pgpVc3,mbcon)

if (PRINT_VERBOSE): dbgData = rogue.interfaces.stream.Slave()
if (PRINT_VERBOSE): dbgData.setDebug(60, "DATA[{}]".format(0))
if (PRINT_VERBOSE): pyrogue.streamTap(pgpVc0, dbgData)


# Create GUI
appTop = QApplication(sys.argv)
guiTop = pyrogue.gui.GuiTop(group='ePix10kaGui')
ePixBoard = EpixBoard(guiTop, cmd, dataWriter, srp)
ePixBoard.start()
guiTop.addTree(ePixBoard)
guiTop.resize(1000,1000)

# Viewer gui
if (START_VIEWER):
    gui = vi.Window(cameraType = 'ePix10ka')
    gui.eventReader.frameIndex = 0
    #gui.eventReaderImage.VIEW_DATA_CHANNEL_ID = 0
    gui.setReadDelay(0)
    pyrogue.streamTap(pgpVc0, gui.eventReader) 
    pyrogue.streamTap(pgpVc2, gui.eventReaderScope)# PseudoScope
    pyrogue.streamTap(pgpVc3, gui.eventReaderMonitoring) # Slow Monitoring

# Create mesh node (this is for remote control only, no data is shared with this)
#mNode = pyrogue.mesh.MeshNode('rogueTest',iface='eth0',root=ePixBoard)
#mNode = pyrogue.mesh.MeshNode('rogueEpix10ka',iface='eth0',root=None)
#mNode.setNewTreeCb(guiTop.addTree)
#mNode.start()


#############################################################
#
# Test script starts here
#
#############################################################
if (TEST_DARK):
    #read config parameters for the fpga and asic
    ePixBoard.readConfig("yml/epix10ka_u0.yml")

    #set registers to take dark images
    #ePixBoard.Epix10ka.Epix10kaAsic0.fnSetPixelBitmap(cmd=cmd, dev=ePixBoard.Epix10ka.Epix10kaAsic0, arg='pixelBitMaps/epix10ka_gain_00.csv')

    #set dark image filename
    fileFolders = [ ['/u1/ddoering/10kaImages/ffff_ffff_ffff_ffff/dark/tr_0/00/','/u1/ddoering/10kaImages/ffff_ffff_ffff_ffff/dark/tr_0/01/','/u1/ddoering/10kaImages/ffff_ffff_ffff_ffff/dark/tr_0/10/','/u1/ddoering/10kaImages/ffff_ffff_ffff_ffff/dark/tr_0/11/'],
                    ['/u1/ddoering/10kaImages/ffff_ffff_ffff_ffff/dark/tr_1/00/','/u1/ddoering/10kaImages/ffff_ffff_ffff_ffff/dark/tr_1/01/','/u1/ddoering/10kaImages/ffff_ffff_ffff_ffff/dark/tr_1/10/','/u1/ddoering/10kaImages/ffff_ffff_ffff_ffff/dark/tr_1/11/']]
    fileName = 'darkImage_10ka_120Hz_run2.dat'

    configFiles = ['pixelBitMaps/epix10ka_AllPixelValues_0.csv','pixelBitMaps/epix10ka_AllPixelValues_4.csv','pixelBitMaps/epix10ka_AllPixelValues_8.csv','pixelBitMaps/epix10ka_AllPixelValues_12.csv']

    trs = [0, 1]
    gains = [0, 1, 2, 3]
    NumberOfDarkFrames = 10000
    ePixBoard.Epix10ka.Epix10kaAsic0.ClearMatrix()

    for tr in trs:
        ePixBoard.Epix10ka.Epix10kaAsic0.trbit.set(tr)
        for gain in gains:
            fullFileName = fileFolders[tr][gain]+fileName
            ePixBoard.dataWriter.dataFile.set(fullFileName)
            ePixBoard.dataWriter.open.set(True)
            #config pixels
            print('trbit:', tr, 'Config. file:', configFiles[gain])
            ePixBoard.Epix10ka.Epix10kaAsic0.fnSetPixelBitmap(cmd=cmd, dev=ePixBoard.Epix10ka.Epix10kaAsic0, arg=configFiles[gain])
    
            for i in range(0,NumberOfDarkFrames):
                cmd.sendCmd(0, 0)
                time.sleep(1.0 / float(120))
    
            ePixBoard.dataWriter.open.set(False)



#    #set registers to execute test;
#    ePixBoard.Epix10ka.Epix10kaAsic0.fnSetPixelBitmap(cmd=cmd, dev=ePixBoard.Epix10ka.Epix10kaAsic0, arg='pixelBitMaps/epix10ka_test_on_autoGain_pixel_1230.csv')
#    ePixBoard.Epix10ka.Epix10kaAsic0.atest.set(True)
#    ePixBoard.Epix10ka.Epix10kaAsic0.test.set(True)
#
#    #set test image filename
#    ePixBoard.dataWriter.dataFile.set('/u1/ddoering/10kaImages/testImage_10ka_120Hz_after_epix10ka_test_on_autoGain_pixel_1230_csv_run1.dat')
#    ePixBoard.dataWriter.open.set(True)
#
#    #run test
#    for i in range(0,10):
#        cmd.sendCmd(0, 0)
#        time.sleep(1.0 / float(120))
#    
#    ePixBoard.dataWriter.open.set(False)

if (TEST_LINEARITY_TEST_A or TEST_LINEARITY_TEST_B):
    #read config parameters for the fpga and asic
    ePixBoard.readConfig("yml/epix10ka_u0.yml")

    #set registers to take dark images
    #ePixBoard.Epix10ka.Epix10kaAsic0.fnSetPixelBitmap(cmd=cmd, dev=ePixBoard.Epix10ka.Epix10kaAsic0, arg='pixelBitMaps/epix10ka_gain_00.csv')
    ePixBoard.Epix10ka.Epix10kaAsic0.pbit.set(False)
    ePixBoard.Epix10ka.Epix10kaAsic0.atest.set(False)
    ePixBoard.Epix10ka.Epix10kaAsic0.test.set(True)
    if (TEST_LINEARITY_TEST_B):
        print('Executing Test B')
        ePixBoard.Epix10ka.Epix10kaAsic0.hrtest.set(True)
    else:
        print('Executing Test A')
        ePixBoard.Epix10ka.Epix10kaAsic0.hrtest.set(False)


    #set dark image filename
    fileFolders = [ ['/u1/ddoering/10kaImages/ffff_ffff_ffff_ffff/lin_random/tr_0/00/','/u1/ddoering/10kaImages/ffff_ffff_ffff_ffff/lin_random/tr_0/01/','/u1/ddoering/10kaImages/ffff_ffff_ffff_ffff/lin_random/tr_0/10/','/u1/ddoering/10kaImages/ffff_ffff_ffff_ffff/lin_random/tr_0/11/'],
                    ['/u1/ddoering/10kaImages/ffff_ffff_ffff_ffff/lin_random/tr_1/00/','/u1/ddoering/10kaImages/ffff_ffff_ffff_ffff/lin_random/tr_1/01/','/u1/ddoering/10kaImages/ffff_ffff_ffff_ffff/lin_random/tr_1/10/','/u1/ddoering/10kaImages/ffff_ffff_ffff_ffff/lin_random/tr_1/11/']]
    if (TEST_LINEARITY_TEST_B):
        fileName = 'linearityRandom_10ka_120Hz_hrtest_true'
    else:
        fileName = 'linearityRandom_10ka_120Hz_hrtest_false'

#    configFiles = ['pixelBitMaps/epix10ka_AllPixelValues_0.csv','pixelBitMaps/epix10ka_AllPixelValues_4.csv','pixelBitMaps/epix10ka_AllPixelValues_8.csv','pixelBitMaps/epix10ka_AllPixelValues_12.csv']

    trs = [0, 1]
    gains = [0, 4, 8, 12]
    NumberOfFrames = 1024
    ePixBoard.Epix10ka.Epix10kaAsic0.ClearMatrix()

    mu, sigma = 0, 0.1
    for run in range(2,18):
        FileNameRun = '_run' + str(run) + '.dat'
        for tr in trs:
            ePixBoard.Epix10ka.Epix10kaAsic0.trbit.set(tr)
            print('trbit:', tr)
            loopIndex = 0
            for gain in gains:          
                fullFileName = fileFolders[tr][loopIndex]+fileName+FileNameRun
                print(fullFileName)
                loopIndex = loopIndex + 1 
                ePixBoard.dataWriter.dataFile.set(fullFileName)
                ePixBoard.dataWriter.open.set(True)
                #select pixels ramdomly          
                rand_img =  np.random.normal(mu, sigma, size=(178,192))
                rand_img_bool = rand_img>(np.average(rand_img)+1.5*np.std(rand_img))
                config_matrix = rand_img_bool*(gain+1)
                #saves csv to reused tested functions that config the matrix
                np.savetxt('pixelBitMaps/currentFile'+str(tr+gain)+'.csv', config_matrix, fmt='%d', delimiter=',', newline='\n')
                #config pixels
                ePixBoard.Epix10ka.Epix10kaAsic0.fnSetPixelBitmap(cmd=cmd, dev=ePixBoard.Epix10ka.Epix10kaAsic0, arg='pixelBitMaps/currentFile'+str(tr+gain)+'.csv')
         
                for i in range(0,NumberOfFrames):
                    ePixBoard.Epix10ka.Epix10kaAsic0.Pulser.set(i)
                    cmd.sendCmd(0, 0)
                    time.sleep(1.0 / float(120))
        
                ePixBoard.dataWriter.open.set(False)
 


if (TEST_LINEARITY_TEST_C or TEST_LINEARITY_TEST_D):
    #read config parameters for the fpga and asic
    ePixBoard.readConfig("yml/epix10ka_u0.yml")

    #set registers to take dark images
    #ePixBoard.Epix10ka.Epix10kaAsic0.fnSetPixelBitmap(cmd=cmd, dev=ePixBoard.Epix10ka.Epix10kaAsic0, arg='pixelBitMaps/epix10ka_gain_00.csv')
    ePixBoard.Epix10ka.Epix10kaAsic0.pbit.set(False)
    ePixBoard.Epix10ka.Epix10kaAsic0.atest.set(False)
    ePixBoard.Epix10ka.Epix10kaAsic0.test.set(True)
    if (TEST_LINEARITY_TEST_D):
        print('Executing Test D')
        ePixBoard.Epix10ka.Epix10kaAsic0.hrtest.set(True)
    else:
        print('Executing Test C')
        ePixBoard.Epix10ka.Epix10kaAsic0.hrtest.set(False)


    #set dark image filename
    fileFolders = [ ['/u1/ddoering/10kaImages/ffff_ffff_ffff_ffff/lin_row/tr_0/00/','/u1/ddoering/10kaImages/ffff_ffff_ffff_ffff/lin_row/tr_0/01/','/u1/ddoering/10kaImages/ffff_ffff_ffff_ffff/lin_row/tr_0/10/','/u1/ddoering/10kaImages/ffff_ffff_ffff_ffff/lin_row/tr_0/11/'],
                    ['/u1/ddoering/10kaImages/ffff_ffff_ffff_ffff/lin_row/tr_1/00/','/u1/ddoering/10kaImages/ffff_ffff_ffff_ffff/lin_row/tr_1/01/','/u1/ddoering/10kaImages/ffff_ffff_ffff_ffff/lin_row/tr_1/10/','/u1/ddoering/10kaImages/ffff_ffff_ffff_ffff/lin_row/tr_1/11/']]
    if (TEST_LINEARITY_TEST_D):
        fileNameRoot = 'linearityRow_10ka_120Hz_hrtest_true_row_' 
    else:
        fileNameRoot = 'linearityRow_10ka_120Hz_hrtest_false_row_' 

#    configFiles = ['pixelBitMaps/epix10ka_AllPixelValues_0.csv','pixelBitMaps/epix10ka_AllPixelValues_4.csv','pixelBitMaps/epix10ka_AllPixelValues_8.csv','pixelBitMaps/epix10ka_AllPixelValues_12.csv']

    trs = [0, 1]
    gains = [1, 5, 9, 13] # gains 00, 01, 10 and 11 [0, 4, 8, 12] plus test bit 1 
    NumberOfFrames = 1024
    ePixBoard.Epix10ka.Epix10kaAsic0.ClearMatrix()

    #rows = np.arange(0, 178, 1)
    rows = np.arange(0, 5, 1)
    for run in range(2,18):
        FileNameRun = '_run' + str(run) + '.dat'
        for row in rows:
            print('Testing row : ', row)
            for tr in trs:
                ePixBoard.Epix10ka.Epix10kaAsic0.trbit.set(tr)
                print('trbit:', tr)
                loopIndex = 0
                for gain in gains:          
                    fullFileName = fileFolders[tr][loopIndex]+fileNameRoot+str(row)+FileNameRun
                    print(fullFileName)
                    loopIndex = loopIndex + 1 
                    ePixBoard.dataWriter.dataFile.set(fullFileName)
                    ePixBoard.dataWriter.open.set(True)
                    #select pixels ramdomly          
                    row_img =  np.zeros((178,192), dtype='uint32')
                    row_img[row,:] = 1
                    config_matrix = row_img*(gain)
                    #saves csv to reused tested functions that config the matrix
                    np.savetxt('pixelBitMaps/currentFile'+str(row+tr+gain)+'.csv', config_matrix, fmt='%d', delimiter=',', newline='\n')
                    #config pixels
                    ePixBoard.Epix10ka.Epix10kaAsic0.fnSetPixelBitmap(cmd=cmd, dev=ePixBoard.Epix10ka.Epix10kaAsic0, arg='pixelBitMaps/currentFile'+str(row+tr+gain)+'.csv')
             
                    for i in range(0,NumberOfFrames):
                        ePixBoard.Epix10ka.Epix10kaAsic0.Pulser.set(i)
                        cmd.sendCmd(0, 0)
                        time.sleep(1.0 / float(120))
        
                    ePixBoard.dataWriter.open.set(False)

if (TEST_LINEARITY_TEST_E or TEST_LINEARITY_TEST_F):
    #read config parameters for the fpga and asic
    ePixBoard.readConfig("yml/epix10ka_u0.yml")

    #set registers to take dark images
    #ePixBoard.Epix10ka.Epix10kaAsic0.fnSetPixelBitmap(cmd=cmd, dev=ePixBoard.Epix10ka.Epix10kaAsic0, arg='pixelBitMaps/epix10ka_gain_00.csv')
    ePixBoard.Epix10ka.Epix10kaAsic0.pbit.set(False)
    ePixBoard.Epix10ka.Epix10kaAsic0.atest.set(False)
    ePixBoard.Epix10ka.Epix10kaAsic0.test.set(True)
    if (TEST_LINEARITY_TEST_F):
        print('Executing Test F')
        ePixBoard.Epix10ka.Epix10kaAsic0.hrtest.set(True)
    else:
        print('Executing Test E')
        ePixBoard.Epix10ka.Epix10kaAsic0.hrtest.set(False)


    #set dark image filename
    fileFolders = [ ['/u1/ddoering/10kaImages/ffff_ffff_ffff_ffff/lin_col/tr_0/00/','/u1/ddoering/10kaImages/ffff_ffff_ffff_ffff/lin_col/tr_0/01/','/u1/ddoering/10kaImages/ffff_ffff_ffff_ffff/lin_col/tr_0/10/','/u1/ddoering/10kaImages/ffff_ffff_ffff_ffff/lin_col/tr_0/11/'],
                    ['/u1/ddoering/10kaImages/ffff_ffff_ffff_ffff/lin_col/tr_1/00/','/u1/ddoering/10kaImages/ffff_ffff_ffff_ffff/lin_col/tr_1/01/','/u1/ddoering/10kaImages/ffff_ffff_ffff_ffff/lin_col/tr_1/10/','/u1/ddoering/10kaImages/ffff_ffff_ffff_ffff/lin_col/tr_1/11/']]
    if (TEST_LINEARITY_TEST_F):
        fileNameRoot = 'linearityCol_10ka_120Hz_hrtest_true_col_' 
    else:
        fileNameRoot = 'linearityCol_10ka_120Hz_hrtest_false_col_' 
#    configFiles = ['pixelBitMaps/epix10ka_AllPixelValues_0.csv','pixelBitMaps/epix10ka_AllPixelValues_4.csv','pixelBitMaps/epix10ka_AllPixelValues_8.csv','pixelBitMaps/epix10ka_AllPixelValues_12.csv']

    trs = [0, 1]
    gains = [1, 5, 9, 13] # gains 00, 01, 10 and 11 [0, 4, 8, 12] plus test bit 1 
    NumberOfFrames = 1024
    ePixBoard.Epix10ka.Epix10kaAsic0.ClearMatrix()

    #cols = np.arange(0, 192, 1)
    cols = np.arange(0, 5, 1)
    for run in range(2,18):
        FileNameRun = '_run' + str(run) + '.dat'
        for col in cols:
            print('Testing col : ', col)
            for tr in trs:
                ePixBoard.Epix10ka.Epix10kaAsic0.trbit.set(tr)
                print('trbit:', tr)
                loopIndex = 0
                for gain in gains:          
                    fullFileName = fileFolders[tr][loopIndex]+fileNameRoot+str(col)+FileNameRun
                    print(fullFileName)
                    loopIndex = loopIndex + 1 
                    ePixBoard.dataWriter.dataFile.set(fullFileName)
                    ePixBoard.dataWriter.open.set(True)
                    #select pixels ramdomly          
                    col_img =  np.zeros((178,192), dtype='uint32')
                    col_img[:,col] = 1
                    config_matrix = col_img*(gain)
                    #saves csv to reused tested functions that config the matrix
                    np.savetxt('pixelBitMaps/currentFileCol'+'.csv', config_matrix, fmt='%d', delimiter=',', newline='\n')
                    #config pixels
                    ePixBoard.Epix10ka.Epix10kaAsic0.fnSetPixelBitmap(cmd=cmd, dev=ePixBoard.Epix10ka.Epix10kaAsic0, arg='pixelBitMaps/currentFileCol'+'.csv')
             
                    for i in range(0,NumberOfFrames):
                        ePixBoard.Epix10ka.Epix10kaAsic0.Pulser.set(i)
                        cmd.sendCmd(0, 0)
                        time.sleep(1.0 / float(120))
        
                    ePixBoard.dataWriter.open.set(False)

if (TEST_WEIGHTINGFUNCTION):
    #read config parameters for the fpga and asic
    ePixBoard.readConfig("yml/epix10ka_u0.yml")

    #set registers to take dark images
    #ePixBoard.Epix10ka.Epix10kaAsic0.fnSetPixelBitmap(cmd=cmd, dev=ePixBoard.Epix10ka.Epix10kaAsic0, arg='pixelBitMaps/epix10ka_gain_00.csv')
    ePixBoard.Epix10ka.Epix10kaAsic0.pbit.set(False)
    ePixBoard.Epix10ka.Epix10kaAsic0.atest.set(False)
    ePixBoard.Epix10ka.Epix10kaAsic0.test.set(False)
    ePixBoard.Epix10ka.Epix10kaAsic0.hrtest.set(False)

    #setting camera for internal trigger
    ePixBoard.Epix10ka.EpixFpgaRegisters.RunTriggerEnable.set(True)
    ePixBoard.Epix10ka.EpixFpgaRegisters.AutoRunEnable.set(True)
    ePixBoard.Epix10ka.EpixFpgaRegisters.AutoDaqEnable.set(True)
    ePixBoard.Epix10ka.EpixFpgaRegisters.AutoRunPeriod.set(10000000)

    #set dark image filename
    fileFolders = [ ['./']]
    fileNameRoot = 'laserPulse_delay_' 
    FileNameRun = '_run_1.dat'
    aquisitionDuration = 1
    trs = [0, 1]
    gains = [1, 5, 9, 13] # gains 00, 01, 10 and 11 [0, 4, 8, 12] plus test bit 1 
    numDelays = 10
    initialDelay  = 70000
    delayStepSize =  1000
    ePixBoard.Epix10ka.Epix10kaAsic0.ClearMatrix()

    #cols = np.arange(0, 192, 1)
    #cols = np.arange(0, 5, 1)
    for delayIndex in range(0,numDelays):
        delay = initialDelay + delayIndex * delayStepSize
        ePixBoard.Epix10ka.EpixFpgaRegisters.RunTriggerDelay.set(delay)
        fullFileName = fileFolders[0][0]+fileNameRoot+str(delay)+FileNameRun
        print(fullFileName)
        #loopIndex = loopIndex + 1 
        ePixBoard.dataWriter.dataFile.set(fullFileName)
        ePixBoard.dataWriter.open.set(True)
        time.sleep(aquisitionDuration)
        ePixBoard.dataWriter.open.set(False)

# Run gui
if (START_GUI):
    appTop.exec_()

# Close window and stop polling
def stop():
    mNode.stop()
#    epics.stop()
    ePixBoard.stop()
    exit()

# Start with: ipython -i scripts/epix10kaDAQ.py for interactive approach
print("Started rogue mesh and epics V3 server. To exit type stop()")
