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
import numpy as np

PRINT_VERBOSE = 0

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
        self.imgDark = np.array(rawData,dtype='uint16')
        self.imgDark_isSet = True

    def unsetDarkImg(self):
        """performs the ePix100A image descrambling"""
        self.imgDark_isSet = False

    def getDarkSubtractedImg(self, rawImg):
        return rawImg - self.imgDark


    def reScaleImgTo8bit(self, rawImage, scaleMax=20000, scaleMin=-200):
        #init
        if (PRINT_VERBOSE): print ("raw image" , rawImage.shape)
        if (PRINT_VERBOSE): print ("raw image max {}, min {}".format(np.amax(rawImage), np.amin(rawImage)))
        image = np.clip(rawImage, scaleMin, scaleMax)
        if (PRINT_VERBOSE): print ("image" , image.shape)
        if (PRINT_VERBOSE): print ("limits max {}, min {}".format(scaleMax, scaleMin))
        if (PRINT_VERBOSE): print ("clipped image max {}, min {}".format(np.amax(image), np.amin(image)))
        
        #re-scale
        imageRS = np.array(((image-scaleMin) * (255 / (scaleMax - scaleMin))))
        if (PRINT_VERBOSE): print ("16 bit image max {}, min {}".format(np.amax(imageRS), np.amin(imageRS)))
        
        image8b = imageRS.astype('uint8')
        if (PRINT_VERBOSE): print ("8 bit image max {}, min {}".format(np.amax(image8b), np.amin(image8b)))
        if (PRINT_VERBOSE): print ("scaled image" , image8b.shape)
        #return results
        return image8b

