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
# Describes the camera main parameters and implements descrambling function
# 
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

# define global constants
NOCAMERA = 0
EPIX100A = 1
EPIX100P = 2

################################################################################
################################################################################
#   Camera class
#   Define camera specific parameters and descrambler functions
#   After using this class the image of all cameras should be a 2d matrix
#   with sensor heigh, width with a given pixel depth
################################################################################
class Camera():
    """implements basic image processing specific to the SLAC cameras"""

    # define global properties
    cameraType = ""
    cameraModule = ""
    sensorWidth = 0
    sensorHeight = 0
    pixelDepth = 0
    availableCameras = {  'ePix100a':  EPIX100A, 'ePix100p' : EPIX100P }
    

    def __init__(self, cameraType = 'ePix100a') :
        
        camID = self.availableCameras.get(cameraType, NOCAMERA)

        # check if the camera exists
        if (camID == NOCAMERA):
            print("Camera ", cameraType ," not supported")
            
        self.cameraType = cameraType

        #selcts proper initialization based on camera type
        if (camID == EPIX100A):
            self._initEPix100a()
        if (camID == EPIX100P):
            self._initEPix100p()
        
    # return a dict with all available cameras    
    def getAvailableCameras():
        return self.availableCameras

    # return the descrambled image based on the current camera settings
    def descrambleImage(self, rawData):
        camID = self.availableCameras.get(self.cameraType, NOCAMERA)
        if (camID == EPIX100A):
            return  self._descrambleEPix100aImage(rawData)
        if (camID == EPIX100P):
            return self._descrambleEPix100aImage(rawData)        
        if (camID == NOCAMERA):
            return Null


    ##########################################################
    # define all camera specific init values
    ##########################################################
    def _initEPix100a(self):
        self._superRowSize = 384
        self._NumAsicsPerSide = 2
        self._NumAdcChPerAsic = 4
        self._NumColPerAdcCh = 96
        self._superRowSizeInBytes = self._superRowSize * 4
        self.sensorWidth = self._calcImgWidth()
        self.sensorHeight = 706
        self.pixelDepth = 16
        self.cameraModule = "Standard ePix100a"


    def _initEPix100p(self):
        self._superRowSize = 384
        self._NumAsicsPerSide = 2
        self._NumAdcChPerAsic = 4
        self._NumColPerAdcCh = 96
        self._superRowSizeInBytes = self._superRowSize * 4
        self.sensorWidth = self._calcImgWidth()
        self.sensorHeight = 706
        self.pixelDepth = 16
      
    ##########################################################
    # define all camera specific descrabler functions
    ##########################################################

    def _descrambleEPix100pImage(self, rawData):
        """performs the ePix100A image descrambling"""
        
        #removes header before displying the image
        for j in range(0,32):
            rawData.pop(0)
        
        #get the first superline
        imgBot = rawData[(0*self._superRowSizeInBytes):(1*self._superRowSizeInBytes)] 
        imgTop = rawData[(1*self._superRowSizeInBytes):(2*self._superRowSizeInBytes)] 
        for j in range(2,self.sensorHeight):
            if (j%2):
                imgBot.extend(rawData[(j*self._superRowSizeInBytes):((j+1)*self._superRowSizeInBytes)])
            else:
                imgTop.extend(rawData[(j*self._superRowSizeInBytes):((j+1)*self._superRowSizeInBytes)]) 
        imgDesc = imgBot
        imgDesc.extend(imgTop)

        # convert to numpy array
        imgDesc = np.array(imgDesc,dtype='uint8')

        # returns final image
        return imgDesc


    def _descrambleEPix100aImageAsByteArray(self, rawData):
        """performs the ePix100P image descrambling (this is a place holder only)"""
        
        #removes header before displying the image
        for j in range(0,32):
            rawData.pop(0)
        
        #get the first superline
        imgBot = rawData[(0*self._superRowSizeInBytes):(1*self._superRowSizeInBytes)] 
        imgTop = rawData[(1*self._superRowSizeInBytes):(2*self._superRowSizeInBytes)] 
        for j in range(2,self.sensorHeight):
            if (j%2):
                imgBot.extend(rawData[(j*self._superRowSizeInBytes):((j+1)*self._superRowSizeInBytes)])
            else:
                imgTop.extend(rawData[(j*self._superRowSizeInBytes):((j+1)*self._superRowSizeInBytes)]) 
        imgDesc = imgBot
        imgDesc.extend(imgTop)

        # returns final image
        return imgDesc

    def _descrambleEPix100aImage(self, rawData):
        """performs the ePix100P image descrambling (this is a place holder only)"""
        
        imgDescBA = self._descrambleEPix100aImageAsByteArray(rawData)

        imgDesc = np.frombuffer(imgDescBA,dtype='int16')
        imgDesc = imgDesc.reshape(self.sensorHeight, self.sensorWidth)
        # returns final image
        return imgDesc

    # helper functions
    def _calcImgWidth(self):
        return self._NumAsicsPerSide * self._NumAdcChPerAsic * self._NumColPerAdcCh

