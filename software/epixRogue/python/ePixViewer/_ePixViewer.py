#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : local image viewer for the ePix camera images
#-----------------------------------------------------------------------------
# File       : ePixViewer.py
# Author     : Dionisio Doering
# Created    : 2017-02-08
# Last update: 2017-02-08
#-----------------------------------------------------------------------------
# Description:
# Simple image viewer that enble a local feedback from data collected using
# ePix cameras. The initial intent is to use it with stand alone systems
#
#-----------------------------------------------------------------------------
# This file is part of the ATLAS CHESS2 DEV. It is subject to 
# the license terms in the LICENSE.txt file found in the top-level directory 
# of this distribution and at: 
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
# No part of the ATLAS CHESS2 DEV, including this file, may be 
# copied, modified, propagated, or distributed except according to the terms 
# contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

import sys
import os
import rogue.utilities
import rogue.utilities.fileio
import rogue.interfaces.stream
import pyrogue    
import time
from PyQt4 import QtGui, QtCore
from PyQt4.QtGui import *
from PyQt4.QtCore import QObject, pyqtSignal
import ePixViewer.imgProcessing as imgPr


################################################################################
################################################################################
#   Window class
#   Implements the screen that display all images.
#   Calls other classes defined in this file to properly read and process
#   the images in a givel file
################################################################################
class Window(QtGui.QMainWindow, QObject):
    """Class that defines the main window for the viewer."""
    
    # Define a new signal called 'trigger' that has no arguments.
    trigger = pyqtSignal()


    def __init__(self):
        super(Window, self).__init__()    
        # window init
        self.mainWdGeom = [50, 50, 1000, 600] # x, y, width, height
        self.setGeometry(self.mainWdGeom[0], self.mainWdGeom[1], self.mainWdGeom[2],self.mainWdGeom[3])
        self.setWindowTitle("ePix image viewer")

        # add actions for menu item
        extractAction = QtGui.QAction("&Quit", self)
        extractAction.setShortcut("Ctrl+Q")
        extractAction.setStatusTip('Leave The App')
        extractAction.triggered.connect(self.close_viewer)
        # 
        openFile = QtGui.QAction("&Open File", self)
        openFile.setShortcut("Ctrl+O")
        openFile.setStatusTip('Open a new set of images')
        openFile.setStatusTip('Open file')
        openFile.triggered.connect(self.file_open)

        # display status tips for all menu items (or actions)
        self.statusBar()

        # Creates the main menu, 
        mainMenu = self.menuBar()
        # adds items and subitems
        fileMenu = mainMenu.addMenu('&File')
        fileMenu.addAction(openFile)
        fileMenu.addAction(extractAction)

        # Create widget
        self.prepairWindow()

        # add all buttons to the screen
        self.def_bttns()

        #########################     
        # rogue interconection  #
        #########################
        # Create the objects            
        self.fileReader  = rogue.utilities.fileio.StreamReader()
        self.eventReader = EventReader(self)
        # Connect the fileReader to our event processor
        pyrogue.streamConnect(self.fileReader,self.eventReader)

 #       self.imgProc = imgPr.imageProcessing()
        # Connect the trigger signal to a slot.
        # the different threads send messages to synchronize their tasks
        self.trigger.connect(self.displayImageFromReader)
        
        self.imgDesc = []
        self.imgTool = imgPr.ImageProcessing(self)

        # display the window on the screen after all items have been added 
        self.show()


    def prepairWindow(self):
        # Center UI
        screen = QtGui.QDesktopWidget().screenGeometry(self)
        size = self.geometry()
        #self.move((screen.width()-size.width())/2, (screen.height()-size.height())/2)
        #self.setStyleSheet("QWidget{background-color: #000000;}")
        self.setWindowFlags(QtCore.Qt.WindowStaysOnTopHint)
        self.buildUi()
        #self.showFullScreen()


    #creates the main display element of the user interface
    def buildUi(self):
        #label used to display image
        self.label = QtGui.QLabel()
        #self.label.setAlignment(QtCore.Qt.AlignCenter)
        #self.label.setScaledContents(True)

        #label used to display frame number
        self.labelFrameNum = QtGui.QLabel('')

        #button set dark
        btn1 = QtGui.QPushButton("Set Dark")
        btn1.setMaximumWidth(150)
        btn1.clicked.connect(self.setDark)
        btn1.resize(btn1.minimumSizeHint())

        #button next
        btn2 = QtGui.QPushButton("Prev")
        btn2.setMaximumWidth(150)
        btn2.clicked.connect(self.prevFrame)
        btn2.resize(btn2.minimumSizeHint())

        #button next
        btn3 = QtGui.QPushButton("Next")
        btn3.setMaximumWidth(150)
        btn3.clicked.connect(self.nextFrame)
        btn3.resize(btn3.minimumSizeHint())

        #button quit
        btn4 = QtGui.QPushButton("Quit")
        btn4.setMaximumWidth(150)
        btn4.clicked.connect(self.close_viewer)
        btn4.resize(btn4.minimumSizeHint())

        self.mainWidget = QtGui.QWidget(self)
        vbox1 = QVBoxLayout()
        vbox1.addWidget(self.label)

#        grigVbox2 = QGridLayout()
#        grigVbox2.setSpacing(2)
#        grigVbox2.addWidget(btn1,1,0)
#        grigVbox2.addWidget(btn2,3,1)
#        grigVbox2.addWidget(btn3,3,0)
#        grigVbox2.addWidget(btn4,4,0)
#        grigVbox2.addWidget(self.labelFrameNum,5,0)
        
        vbox2 = QVBoxLayout()
#        vbox2.addLayout(grigVbox2)
        vbox2.addWidget(btn1)
        vbox2.addWidget(btn2)
        vbox2.addWidget(btn3)
        vbox2.addWidget(btn4)
        vbox2.addStretch(1)
        vbox2.addWidget(self.labelFrameNum)
        
        hbox = QHBoxLayout(self.mainWidget)
        hbox.addLayout(vbox1)
        hbox.addLayout(vbox2)

        self.mainWidget.setFocus()        
        self.setCentralWidget(self.mainWidget)


    def file_open(self):
        self.eventReader.frameIndex = 1
        self.filename = QtGui.QFileDialog.getOpenFileName(self, 'Open File', '', 'Rogue Images (*.dat);; GenDAQ Images (*.bin);;Any (*.*)')  
        if (os.path.splitext(self.filename)[1] == '.dat'): 
            self.displayImagDat(self.filename)
        else:
            self.displayImag(self.filename)


    def def_bttns(self):
        return self
 

    def setDark(self):
        self.imgTool.setDarkImg(self.imgDesc)
        
    # display the previous frame from the current file
    def prevFrame(self):
        self.eventReader.frameIndex -= 1
        if (self.eventReader.frameIndex<1):
            self.eventReader.frameIndex = 1
        print('Selected frame ', self.eventReader.frameIndex)
        self.displayImagDat(self.filename)


    # display the next frame from the current file
    def nextFrame(self):
        self.eventReader.frameIndex += 1
        print('Selected frame ', self.eventReader.frameIndex)
        self.displayImagDat(self.filename)


    # checks if the user really wants to exit
    def close_viewer(self):
        choice = QtGui.QMessageBox.question(self, 'Quit!',
                                            "Do you want to quit viewer?",
                                            QtGui.QMessageBox.Yes | QtGui.QMessageBox.No)
        if choice == QtGui.QMessageBox.Yes:
            print("Exiting now...")
            sys.exit()
        else:
            pass


    # if the image is png or other standard extension it uses this function to display it.
    def displayImag(self, path):
        print('File name: ', path)
        if path:
            image = QtGui.QImage(path)
            pp = QtGui.QPixmap.fromImage(image)
            self.label.setPixmap(pp.scaled(
                    self.label.size(),
                    QtCore.Qt.KeepAspectRatio,
                    QtCore.Qt.SmoothTransformation))


    # if the image is a rogue type, calls the file reader object to read all frames
    def displayImagDat(self, filename):

        print('File name: ', filename)
        self.eventReader.readDataDone = False
        self.eventReader.numAcceptedFrames = 0
        self.fileReader.open(filename)

        # waits until data is found
        timeoutCnt = 0
        while ((self.eventReader.readDataDone == False) and (timeoutCnt < 10)):
             timeoutCnt += 1
             print('Loading image...', self.eventReader.frameIndex, 'atempt',  timeoutCnt)
             time.sleep(0.1)


    def displayImageFromReader(self):
        # core code for displaying the image

        arrayLen = len(self.eventReader.frameData)
        print('Image size: ', arrayLen)

        imgWidth = int(96 * 8)   #4*184
        imgHeight = int(708) 

        
        self.imgTool.imgWidth = imgWidth
        self.imgTool.imgHeight = imgHeight

        self.imgDesc = self.imgTool.descrambleEPix100AImage(self.eventReader.frameData)

        arrayLen = len(self.imgDesc)
        print('Descrambled image size: ', arrayLen)
               
        if (self.imgTool.imgDark_isSet):
            ImgDarkSub = self.imgTool.getDarkSubtractedImg(self.imgDesc)
            self.image = QtGui.QImage(ImgDarkSub, imgWidth, imgHeight, QtGui.QImage.Format_RGB16)
        else:
            # get the data into the image object
            self.image = QtGui.QImage(self.imgDesc, imgWidth, imgHeight, QtGui.QImage.Format_RGB16)

        pp = QtGui.QPixmap.fromImage(self.image)
        self.label.setPixmap(pp.scaled(self.label.size(),QtCore.Qt.KeepAspectRatio,QtCore.Qt.SmoothTransformation))
        self.label.adjustSize()
        #updates the frame number
        #this sleep is a weak way of waiting for the file to be readout completely... needs improvement
        time.sleep(0.1)
        thisString = 'Frame {} of {}'.format(self.eventReader.frameIndex, self.eventReader.numAcceptedFrames)
        print(thisString)
        self.labelFrameNum.setText(thisString)


################################################################################
################################################################################
#   Event reader class
#   
################################################################################
class EventReader(rogue.interfaces.stream.Slave):
    """retrieves data from a file using rogue utilities services"""

    def __init__(self, parent) :
        rogue.interfaces.stream.Slave.__init__(self)
        super(EventReader, self).__init__()
        self.enable = True
        self.numAcceptedFrames = 0
        self.lastFrame = rogue.interfaces.stream.Frame
        self.frameIndex = 1
        self.frameData = bytearray()
        self.readDataDone = False
        self.parent = parent


    # checks all frames in the file to look for the one that needs to be displayed
    # self.frameIndex defines which frame should be returned
    # Once the frame is found, saves data and emits a signal do enable the class window
    # to dislplay it. The emit signal is needed because only that class' thread can 
    # access the screen.
    def _acceptFrame(self,frame):
        self.lastFrame = frame
        if self.enable:
            self.numAcceptedFrames += 1
            # Get the channel number
            chNum = (frame.getFlags() >> 24)
            #print('-------- Frame ',self.numAcceptedFrames,'Channel flags',frame.getFlags() , ' Accepeted --------' , chNum)
            # Check if channel number is 0x1 (streaming data channel)
            if (chNum == 0x1) :
                #print('-------- Event --------')
                # Collect the data
                p = bytearray(frame.getPayload())
                print('Num. data readout: ', len(p))
                frame.read(p,0)
                cnt = 0
            if ((self.numAcceptedFrames == self.frameIndex) or (self.frameIndex == 0)):              
                self.frameData = p
                self.readDataDone = True
                # Emit the signal.
                self.parent.trigger.emit()
                # if displaying all images the sleep produces a frame rate that can be displayed without 
                # freezing or crashing the program. It is also good for the person viewing the images.
                time.sleep(0.1)


