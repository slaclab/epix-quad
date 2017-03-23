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
# This file is part of the ePix rogue. It is subject to 
# the license terms in the LICENSE.txt file found in the top-level directory 
# of this distribution and at: 
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
# No part of the ePix rogue, including this file, may be 
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
#matplotlib
from matplotlib.backends.backend_qt4agg import FigureCanvasQTAgg as FigureCanvas
from matplotlib.figure import Figure

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
        self.mainWdGeom = [50, 50, 1100, 600] # x, y, width, height
        self.setGeometry(self.mainWdGeom[0], self.mainWdGeom[1], self.mainWdGeom[2],self.mainWdGeom[3])
        self.setWindowTitle("ePix image viewer")

        # creates a camera object
        self.currentCam = cameras.Camera(cameraType = 'ePix100a')

        # add actions for menu item
        extractAction = QtGui.QAction("&Quit", self)
        extractAction.setShortcut("Ctrl+Q")
        extractAction.setStatusTip('Leave The App')
        extractAction.triggered.connect(self.close_viewer)
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

        # rogue interconection  #
        # Create the objects            
        self.fileReader  = rogue.utilities.fileio.StreamReader()
        self.eventReader = EventReader(self)
        # Connect the fileReader to our event processor
        pyrogue.streamConnect(self.fileReader,self.eventReader)

        # Connect the trigger signal to a slot.
        # the different threads send messages to synchronize their tasks
        self.trigger.connect(self.displayImageFromReader)
        # weak way to sync frame reader and display
        self.readFileDelay = 0.1
        # initialize image processing objects
        self.imgDesc = []
        self.imgTool = imgPr.ImageProcessing(self)

        # display the window on the screen after all items have been added 
        self.show()


    def prepairWindow(self):
        # Center UI
        screen = QtGui.QDesktopWidget().screenGeometry(self)
        size = self.geometry()
        self.buildUi()


    #creates the main display element of the user interface
    def buildUi(self):
        #label used to display image
        self.label = QtGui.QLabel()
        self.label.mousePressEvent = self.mouseClickedOnImage
        #self.label.paintEvent = self._paintEvent
        self.label.setAlignment(QtCore.Qt.AlignTop)
        self.label.setFixedSize(800,800)
        self.label.setScaledContents(True)
        
        # left hand side layout
        self.mainWidget = QtGui.QWidget(self)
        vbox1 = QVBoxLayout()
        vbox1.setAlignment(QtCore.Qt.AlignTop)
        vbox1.addWidget(self.label,  QtCore.Qt.AlignTop)

        #tabbed control box
        self.gridVbox2 = TabbedCtrlCanvas(self)
        hSubbox1 = QHBoxLayout()
        hSubbox1.addWidget(self.gridVbox2)
        # line plot 1
        self.lineCanvas1 = MplCanvas()        
        hSubbox2 = QHBoxLayout()
        hSubbox2.addWidget(self.lineCanvas1)
        
        # line plot 2
        self.lineCanvas2 = MplCanvas()        
        hSubbox3 = QHBoxLayout()
        hSubbox3.addWidget(self.lineCanvas2)

        # right hand side layout
        vbox2 = QVBoxLayout()
        vbox2.addLayout(hSubbox1)
        vbox2.addLayout(hSubbox2)
        vbox2.addLayout(hSubbox3)
            
        hbox = QHBoxLayout(self.mainWidget)
        hbox.addLayout(vbox1)
        hbox.addLayout(vbox2)

        self.mainWidget.setFocus()        
        self.setCentralWidget(self.mainWidget)


    def setReadDelay(self, delay):
        self.eventReader.readFileDelay = delay
        self.readFileDelay = delay
        

    def file_open(self):
        self.eventReader.frameIndex = 1
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


    # core code for displaying the image
    def displayImageFromReader(self):

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
        
        pp = QtGui.QPixmap.fromImage(self.image)
        self.label.setPixmap(pp.scaled(self.label.size(),QtCore.Qt.KeepAspectRatio,QtCore.Qt.SmoothTransformation))
        self.label.adjustSize()
        # updates the frame number
        # this sleep is a weak way of waiting for the file to be readout completely... needs improvement
        time.sleep(self.readFileDelay)
        thisString = 'Frame {} of {}'.format(self.eventReader.frameIndex, self.eventReader.numAcceptedFrames)
        print(thisString)
        #self.labelFrameNum.setText(thisString)


    def _paintEvent(self, e):
        qp = QtGui.QPainter()
        qp.begin(self.image) 
        self.drawCross(qp)
        qp.end()

    def drawPoint(self, qp):
        qp.setPen(QtCore.Qt.red)
        size = self.label.size()
        imageH = self.image.height()
        imageW = self.image.width()
        pixmapH = self.label.height()
        pixmapW = self.label.width()

        if ((self.mouseX > 0)and(self.mouseX<imageW)):
            if ((self.mouseY > 0)and(self.mouseY < imageH)):
                x = int(self.mouseX * pixmapW / imageW)
                y = int(self.mouseY * pixmapH / imageH)
                qp.drawPoint(x , y)

    def drawCross(self, qp):
        qp.setPen(QtCore.Qt.red)
        size = self.label.size()
        imageH = self.image.height()
        imageW = self.image.width()
        pixmapH = self.label.height()
        pixmapW = self.label.width()

        if ((self.mouseX > 0)and(self.mouseX<imageW)):
            if ((self.mouseY > 0)and(self.mouseY < imageH)):
                x = int(self.mouseX * pixmapW / imageW)
                y = int(self.mouseY * pixmapH / imageH)
                qp.drawLine(x-2 , y-2, x+2 , y+2)
                qp.drawLine(x-2 , y+2, x+2 , y-2)

    def mouseClickedOnImage(self, event):
        mouseX = event.pos().x()
        mouseY = event.pos().y()
        pixmapH = self.label.height()
        pixmapW = self.label.width()
        imageH = self.image.height()
        imageW = self.image.width()

        self.mouseX = int(imageW*mouseX/pixmapW)
        self.mouseY = int(imageH*mouseY/pixmapH)

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

################################################################################
################################################################################
#   Matplotlib class
#   
################################################################################
class MplCanvas(FigureCanvas):
    """This is a QWidget derived from FigureCanvasAgg."""


    def __init__(self, parent=None, width=5, height=4, dpi=100):

        fig = Figure(figsize=(width, height), dpi=dpi)
        self.axes = fig.add_subplot(111)

        self.compute_initial_figure()

        FigureCanvas.__init__(self, fig)
        self.setParent(parent)
        FigureCanvas.setSizePolicy(self, QtGui.QSizePolicy.Expanding, QtGui.QSizePolicy.Expanding)
        FigureCanvas.updateGeometry(self)
        

    def compute_initial_figure(self):
        self.axes.plot([0, 1, 2, 3], [1, 2, 0, 4], 'b')

    def update_figure(self):
        # Build a list of 4 random integers between 0 and 10 (both inclusive)
        l = [random.randint(0, 10) for i in range(4)]
        self.axes.cla()
        self.axes.plot([0, 1, 2, 3], l, 'r')
        self.draw()

################################################################################
################################################################################
#   Tabbed control class
#   
################################################################################
class TabbedCtrlCanvas(QtGui.QTabWidget):
    #https://pythonspot.com/qt4-tabs/ tips on tabs
    def __init__(self, parent):
        super(TabbedCtrlCanvas, self).__init__()

        # pointer to the parent class
        myParent = parent

        # Create tabs
        tab1	= QtGui.QWidget()	
        tab2	= QtGui.QWidget()

        # create widgets for tab 1
        # label used to display frame number
        self.labelFrameNum = QtGui.QLabel('')
        # button set dark
        btnSetDark = QtGui.QPushButton("Set Dark")
        btnSetDark.setMaximumWidth(150)
        btnSetDark.clicked.connect(myParent.setDark)
        btnSetDark.resize(btnSetDark.minimumSizeHint())
        # button set dark
        btnUnSetDark = QtGui.QPushButton("Rem. Dark")
        btnUnSetDark.setMaximumWidth(150)
        btnUnSetDark.clicked.connect(myParent.unsetDark)
        btnUnSetDark.resize(btnUnSetDark.minimumSizeHint())    
        # button quit
        btnQuit = QtGui.QPushButton("Quit")
        btnQuit.setMaximumWidth(150)
        btnQuit.clicked.connect(myParent.close_viewer)
        btnQuit.resize(btnQuit.minimumSizeHint())
        # mouse buttons
        mouseLabel = QtGui.QLabel("Pixel Information")
        myParent.mouseXLine = QtGui.QLineEdit()
        myParent.mouseXLine.setMaximumWidth(100)
        myParent.mouseXLine.setMinimumWidth(50)
        myParent.mouseYLine = QtGui.QLineEdit()
        myParent.mouseYLine.setMaximumWidth(100)
        myParent.mouseYLine.setMinimumWidth(50)
        myParent.mouseValueLine = QtGui.QLineEdit()
        myParent.mouseValueLine.setMaximumWidth(100)
        myParent.mouseValueLine.setMinimumWidth(50)
        # label
        imageScaleLabel = QtGui.QLabel("Contrast (max, min)")
        myParent.imageScaleMaxLine = QtGui.QLineEdit()
        myParent.imageScaleMaxLine.setMaximumWidth(100)
        myParent.imageScaleMaxLine.setMinimumWidth(50)
        myParent.imageScaleMaxLine.setText(str(10000))
        myParent.imageScaleMinLine = QtGui.QLineEdit()
        myParent.imageScaleMinLine.setMaximumWidth(100)
        myParent.imageScaleMinLine.setMinimumWidth(50)
        myParent.imageScaleMinLine.setText(str(-1))

        # set layout to tab 1
        tab1Frame = QtGui.QFrame()
        tab1Frame.setFrameStyle(QtGui.QFrame.Panel);
        tab1Frame.setGeometry(100, 200, 0, 0)
        tab1Frame.setLineWidth(1);
        grid = QtGui.QGridLayout()
        grid.setSpacing(5)
        grid.addWidget(tab1Frame,0,0,5,7)

        # add widgets to tab1
        grid.addWidget(btnSetDark, 1, 2)
        grid.addWidget(btnUnSetDark, 1, 3)
        #grid.addWidget(btnQuit, , )
        grid.addWidget(mouseLabel, 2, 1)
        grid.addWidget(myParent.mouseXLine, 2, 2)
        grid.addWidget(myParent.mouseYLine, 2, 3)
        grid.addWidget(myParent.mouseValueLine, 2, 4)
        grid.addWidget(imageScaleLabel, 3, 1)
        grid.addWidget(myParent.imageScaleMaxLine, 3, 2)
        grid.addWidget(myParent.imageScaleMinLine,3, 3)

        # complete tab1
        tab1.setLayout(grid)

        # create widgets for tab 2
        # button prev
        btnPrevFrame = QtGui.QPushButton("Prev")
        btnPrevFrame.setMaximumWidth(150)
        btnPrevFrame.clicked.connect(myParent.prevFrame)
        btnPrevFrame.resize(btnPrevFrame.minimumSizeHint())
        # button next
        btnNextFrame = QtGui.QPushButton("Next")
        btnNextFrame.setMaximumWidth(150)
        btnNextFrame.clicked.connect(myParent.nextFrame)
        btnNextFrame.resize(btnNextFrame.minimumSizeHint())    
        # frame number
        myParent.frameNumberLine = QtGui.QLineEdit()
        myParent.frameNumberLine.setMaximumWidth(100)
        myParent.frameNumberLine.setMinimumWidth(50)
        myParent.frameNumberLine.setText(str(1))

        # set layout to tab 2
        tab2Frame1 = QtGui.QFrame()
        tab2Frame1.setFrameStyle(QtGui.QFrame.Panel);
        tab2Frame1.setGeometry(100, 200, 0, 0)
        tab2Frame1.setLineWidth(1);
        
        # add widgets into tab2
        grid2 = QtGui.QGridLayout()
        grid2.setSpacing(5)
        grid2.setColumnMinimumWidth(0, 1)
        grid2.setColumnMinimumWidth(2, 1)
        grid2.setColumnMinimumWidth(3, 1)
        grid2.setColumnMinimumWidth(5, 1)
        grid2.addWidget(tab2Frame1,0,0,5,7)
        grid2.addWidget(btnNextFrame, 1, 1)
        grid2.addWidget(btnPrevFrame, 1, 2)
        grid2.addWidget(myParent.frameNumberLine, 2, 1)

        # complete tab2
        tab2.setLayout(grid2)
 
        # Add tabs
        self.addTab(tab1,"Main")
        self.addTab(tab2,"Tab2")

        self.setGeometry(300, 300, 300, 150)
        self.setWindowTitle('')    
        self.show()


