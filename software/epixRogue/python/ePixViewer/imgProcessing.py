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
import numpy as np



################################################################################
################################################################################
#   Image processing class
#   
################################################################################
class ImageProcessing():
    """implements basic image processing specific to the SLAC cameras"""

    # define global properties
    imgHeight = 706
    imgNumAsicsPerSide = 2
    imgNumAdcChPerAsic = 4
    imgNumColPerAdcCh = 96
    superRowSize = 384
    superRowSizeInBytes = superRowSize * 4 # 4 bytes per asic word
    #
    # variables to perform some initial image processing
    imgDark = np.array([],dtype='uint16')
    imgDark_isSet = False


    def __init__(self, parent) :
        # pointer to the parent class        
        self.parent = parent
        # init compound variables
        self.calcImgWidth()

    def calcImgWidth(self):
        self.imgWidth = self.imgNumAsicsPerSide * self.imgNumAdcChPerAsic * self.imgNumColPerAdcCh
        

    def setDarkImg(self, rawData):
        """performs the ePix100A image descrambling"""

        self.imgDark = np.array(rawData,dtype='int16')
        self.imgDark_isSet = True

    def getDarkSubtractedImg(self, rawImg):
        return rawImg - self.imgDark

#        for y in range(0,imgHeight):
#            for x in range(0,imgWidth):
#                arrayIndex = x+(y*imgWidth)
#                if (arrayIndex < arrayLen):
#                    data = self.eventReader.frameData[arrayIndex]
#                else:
#                    data = self.eventReader.frameData[0]
#                #value = QtGui.qRgb(data, data, data)
#                #image.setPixel(x,y,value)
#                self.image.setPixel(x,y,data<<16|data<<8|data)



