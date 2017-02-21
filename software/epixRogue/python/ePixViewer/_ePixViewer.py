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
import ePixViewer.Cameras as cameras


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
        #QtGui.QApplication.setStyle(QtGui.QStyleFactory.create('Cleanlooks'))

        # creates a camera object
        self.currentCam = cameras.Camera(cameraType = 'ePix100a')

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

        self.readFileDelay = 0.1
        
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
        self.label.mousePressEvent = self.mouseClickedOnImage
        self.label.setAlignment(QtCore.Qt.AlignTop)
        self.label.setFixedSize(800,800)
        #self.label.setFrameStyle(QtGui.QFrame.Raised)
        self.label.setScaledContents(True)
        
        #frame for the image
        btnFrame = QtGui.QFrame()
        #btnFrame.setFrameShape(QtGui.QFrame.StyledPanel)
        btnFrame.setFrameStyle(QtGui.QFrame.StyledPanel) 
        btnFrame.setWindowTitle("dfasdf")
        btnFrame.setLineWidth(4)

        #label used to display frame number
        self.labelFrameNum = QtGui.QLabel('')

        #button set dark
        btn1 = QtGui.QPushButton("Set Dark")
        btn1.setMaximumWidth(150)
        btn1.clicked.connect(self.setDark)
        btn1.resize(btn1.minimumSizeHint())

        #button set dark
        btn1_1 = QtGui.QPushButton("Rem. Dark")
        btn1_1.setMaximumWidth(150)
        btn1_1.clicked.connect(self.unsetDark)
        btn1_1.resize(btn1_1.minimumSizeHint())

        #button prev
        btn2 = QtGui.QPushButton("Prev")
        btn2.setMaximumWidth(150)
        btn2.clicked.connect(self.prevFrame)
        btn2.resize(btn2.minimumSizeHint())

        #button next
        btn3 = QtGui.QPushButton("Next")
        btn3.setMaximumWidth(150)
        btn3.clicked.connect(self.nextFrame)
        btn3.resize(btn3.minimumSizeHint())
        
        #frame number
        self.frameNumberLine = QtGui.QLineEdit()
        self.frameNumberLine.setMaximumWidth(50)
        self.frameNumberLine.setText(str(1))

        #button quit
        btn4 = QtGui.QPushButton("Quit")
        btn4.setMaximumWidth(150)
        btn4.clicked.connect(self.close_viewer)
        btn4.resize(btn4.minimumSizeHint())

        # mouse buttons
        mouseLabel = QtGui.QLabel("Pixel Information")
        self.mouseXLine = QtGui.QLineEdit()
        self.mouseXLine.setMaximumWidth(50)
        self.mouseYLine = QtGui.QLineEdit()
        self.mouseYLine.setMaximumWidth(50)
        self.mouseValueLine = QtGui.QLineEdit()
        self.mouseValueLine.setMaximumWidth(100)

        imageScaleLabel = QtGui.QLabel("Set image dynamic range (max, min)")
        self.imageScaleMaxLine = QtGui.QLineEdit()
        self.imageScaleMaxLine.setMaximumWidth(50)
        self.imageScaleMaxLine.setText(str(200))
        self.imageScaleMinLine = QtGui.QLineEdit()
        self.imageScaleMinLine.setMaximumWidth(50)
        self.imageScaleMinLine.setText(str(-200))

        self.mainWidget = QtGui.QWidget(self)
        vbox1 = QVBoxLayout()
        #vbox1.addWidget(labelFrame)
        vbox1.setAlignment(QtCore.Qt.AlignTop)
        vbox1.addWidget(self.label,  QtCore.Qt.AlignTop)
        #vbox1.addStretch(1)

        gridVbox2 = QGridLayout()
        gridVbox2.setSpacing(2)
        #control buttons
        gridVbox2.addWidget(btn1,1,0)
        gridVbox2.addWidget(btn1_1,1,1)
        gridVbox2.addWidget(btn2,2,1)
        gridVbox2.addWidget(btn3,2,0)
        gridVbox2.addWidget(self.frameNumberLine,2,2)
        gridVbox2.addWidget(btn4,3,0)
        # mouse functions
        gridVbox2.addWidget(mouseLabel,4,0)
        gridVbox2.addWidget(self.mouseXLine,4,1)
        gridVbox2.addWidget(self.mouseYLine,4,2)
        gridVbox2.addWidget(self.mouseValueLine,4,3)
        #image scale
        gridVbox2.addWidget(imageScaleLabel,5,0)
        gridVbox2.addWidget(self.imageScaleMaxLine,5,1)
        gridVbox2.addWidget(self.imageScaleMinLine,5,2)
        # status
        gridVbox2.addWidget(self.labelFrameNum,8,0)
        


        
#        vbox2 = QVBoxLayout()
#        #btnFrame.setLayout(vbox2)
##        vbox2.addLayout(grigVbox2)
#        vbox2.addWidget(btn1)
#        vbox2.addWidget(btn2)
#        vbox2.addWidget(btn3)
#        vbox2.addWidget(btn4)
#        vbox2.addStretch(1)
#        vbox2.addWidget(self.labelFrameNum)
        
        
        hbox = QHBoxLayout(self.mainWidget)
        hbox.addLayout(vbox1)
        hbox.addLayout(gridVbox2)

        #QtGui.QApplication.setStyle(QtGui.QStyleFactory.create('Cleanlooks'))

        self.mainWidget.setFocus()        
        self.setCentralWidget(self.mainWidget)

    def setReadDelay(self, delay):
        self.eventReader.readFileDelay = delay
        self.readFileDelay = delay
        

    def file_open(self):
        self.eventReader.frameIndex = 45
        self.eventReader.ViewDataChannel = 1
        self.setReadDelay(0.1)
        self.filename = QtGui.QFileDialog.getOpenFileName(self, 'Open File', '', 'Rogue Images (*.dat);; GenDAQ Images (*.bin);;Any (*.*)')  
        if (os.path.splitext(self.filename)[1] == '.dat'): 
            self.displayImagDat(self.filename)
        else:
            self.displayImag(self.filename)


    def def_bttns(self):
        return self
 

    def setDark(self):
        self.imgTool.setDarkImg(self.imgDesc)

    def unsetDark(self):
        self.imgTool.unsetDarkImg()
        
    # display the previous frame from the current file
    def prevFrame(self):
        self.eventReader.frameIndex = int(self.frameNumberLine.text()) - 1
        if (self.eventReader.frameIndex<1):
            self.eventReader.frameIndex = 1
        self.frameNumberLine.setText(str(self.eventReader.frameIndex))
        print('Selected frame ', self.eventReader.frameIndex)
        self.displayImagDat(self.filename)


    # display the next frame from the current file
    def nextFrame(self):
        self.eventReader.frameIndex = int(self.frameNumberLine.text()) + 1
        self.frameNumberLine.setText(str(self.eventReader.frameIndex))
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

          
        self.imgTool.imgWidth = self.currentCam.sensorWidth
        self.imgTool.imgHeight = self.currentCam.sensorHeight

        self.imgDesc = self.currentCam.descrambleImage(self.eventReader.frameData)
                    
        arrayLen = len(self.imgDesc)
        print('Descrambled image size: ', arrayLen)

        if (self.imgTool.imgDark_isSet):
            self.ImgDarkSub = self.imgTool.getDarkSubtractedImg(self.imgDesc)
            _8bitImg = self.imgTool.reScaleImgTo8bit(self.ImgDarkSub, int(self.imageScaleMaxLine.text()), int(self.imageScaleMinLine.text()))
        else:
            # get the data into the image object
            _8bitImg = self.imgTool.reScaleImgTo8bit(self.imgDesc, int(self.imageScaleMaxLine.text()), int(self.imageScaleMinLine.text()))

        self.image = QtGui.QImage(_8bitImg.repeat(4), self.imgTool.imgWidth, self.imgTool.imgHeight, QtGui.QImage.Format_RGB32)
        
##               
##        if (self.imgTool.imgDark_isSet):
##            self.ImgDarkSub = self.imgTool.getDarkSubtractedImg(self.imgDesc)
##            self.image = QtGui.QImage(self.ImgDarkSub, self.imgTool.imgWidth, self.imgTool.imgHeight, QtGui.QImage.Format_RGB16)
##        else:
##            # get the data into the image object
##            self.image = QtGui.QImage(self.imgDesc, self.imgTool.imgWidth, self.imgTool.imgHeight, QtGui.QImage.Format_RGB16)
##
        pp = QtGui.QPixmap.fromImage(self.image)
        self.label.setPixmap(pp.scaled(self.label.size(),QtCore.Qt.KeepAspectRatio,QtCore.Qt.SmoothTransformation))
        self.label.adjustSize()
        # updates the frame number
        # this sleep is a weak way of waiting for the file to be readout completely... needs improvement
        time.sleep(self.readFileDelay)
        thisString = 'Frame {} of {}'.format(self.eventReader.frameIndex, self.eventReader.numAcceptedFrames)
        print(thisString)
        self.labelFrameNum.setText(thisString)


    def mouseClickedOnImage(self, event):
        mouseX = event.pos().x()
        mouseY = event.pos().y()
        pixmapH = self.label.height()
        pixmapW = self.label.width()
        imageH = self.image.height()
        imageW = self.image.width()

        self.mouseX = int(imageW*mouseX/pixmapW)
        self.mouseY = int(imageH*mouseY/pixmapH)

        #self.mousePixelValue = self.image.pixel(self.mouseX, self.mouseY)
        if (self.imgTool.imgDark_isSet):
            self.mousePixelValue = self.ImgDarkSub[self.mouseY, self.mouseX]
        else:
            self.mousePixelValue = self.imgDesc[self.mouseY, self.mouseX]

        print('Raw mouse coordinates: {},{}'.format(mouseX, mouseY))
        print('Pixel map dimensions: {},{}'.format(pixmapW, pixmapH))
        print('Image dimensions: {},{}'.format(imageW, imageH))
        print('Pixel[{},{}] = {}'.format(self.mouseX, self.mouseY, self.mousePixelValue))
        self.mouseXLine.setText(str(self.mouseX))
        self.mouseYLine.setText(str(self.mouseY))
        self.mouseValueLine.setText(str(self.mousePixelValue))


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
        self.ViewDataChannel = 0x1
        self.readFileDelay = 0.1
        self.busy = False


    # checks all frames in the file to look for the one that needs to be displayed
    # self.frameIndex defines which frame should be returned
    # Once the frame is found, saves data and emits a signal do enable the class window
    # to dislplay it. The emit signal is needed because only that class' thread can 
    # access the screen.
    def _acceptFrame(self,frame):

        self.lastFrame = frame
        if ((self.enable) and (not self.busy)):
            self.busy = True
            self.numAcceptedFrames += 1
            # Get the channel number
            chNum = (frame.getFlags() >> 24)
            #print('-------- Frame ',self.numAcceptedFrames,'Channel flags',frame.getFlags() , ' Accepeted --------' , chNum)
            # Check if channel number is 0x1 (streaming data channel)
            if (chNum == self.ViewDataChannel) :
                #print('-------- Event --------')
                # Collect the data
                p = bytearray(frame.getPayload())
                #print('Num. data readout: ', len(p))
                frame.read(p,0)
                cnt = 0
                if ((self.numAcceptedFrames == self.frameIndex) or (self.frameIndex == 0)):              
                    self.frameData = p
                    self.readDataDone = True
                    # Emit the signal.
                    self.parent.trigger.emit()
                    # if displaying all images the sleep produces a frame rate that can be displayed without 
                    # freezing or crashing the program. It is also good for the person viewing the images.
                    time.sleep(self.readFileDelay)
            self.busy = False


