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
NOCAMERA   = 0
EPIX100A   = 1
EPIX100P   = 2
TIXEL48X48 = 3

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
    availableCameras = {  'ePix100a':  EPIX100A, 'ePix100p' : EPIX100P, 'Tixel48x48' : TIXEL48X48 }
    

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
        if (camID == TIXEL48X48):
            self._initTixel48x48()
        
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
        if (camID == TIXEL48X48):
            return self._descrambleTixel48x48Image(rawData)        
        if (camID == NOCAMERA):
            return Null

    # return
    def buildImageFrame(self, currentRawData, newRawData):
        camID = self.availableCameras.get(self.cameraType, NOCAMERA)
        frameComplete = 0
        readyForDisplay = 0
        if (camID == EPIX100A):
            # The flags are always true since each frame holds an entire image
            frameComplete = 1
            readyForDisplay = 1
            return [frameComplete, readyForDisplay, newRawData]
        if (camID == EPIX100P):
            # The flags are always true since each frame holds an entire image
            frameComplete = 1
            readyForDisplay = 1
            return [frameComplete, readyForDisplay, newRawData]
        if (camID == TIXEL48X48):
            #Needs to check the two frames and make a decision on the flags
            [frameComplete, readyForDisplay, newRawData]  = self._buildFrameTixel48x48Image(currentRawData, newRawData)
            return [frameComplete, readyForDisplay, newRawData]
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

    def _initTixel48x48(self):
        #self._superRowSize = 384
        self._NumAsicsPerSide = 1
        #self._NumAdcChPerAsic = 4
        #self._NumColPerAdcCh = 96
        #self._superRowSizeInBytes = self._superRowSize * 4
        self.sensorWidth = 48 
        self.sensorHeight = 48
        self.pixelDepth = 16

    ##########################################################
    # define all camera specific build frame functions
    ##########################################################
    def _buildFrameTixel48x48Image(self, currentRawData, newRawData):
        """ Performs the Tixel frame building.
            For this sensor the image takes four frames, twa with time of arrival info
            and two with time over threshold. There is no guarantee both frames will always arrive nor on their order."""
        #init local variables
        frameComplete = 0
        readyForDisplay = 0
        returnedRawData = []

        #converts data to 32 bit and retrieves header info
        newRawData_DW = np.frombuffer(newRawData,dtype='uint32')
        acqNum_newRawData  = newRawData[0]
        isTOA_newRawData   = newRawData[1] & 0x8
        asicNum_newRawData = newRawData[1] & 0x7

        #interpret headers
        #case 1: new image (which means currentRawData is empty)
        if (len(currentRawData) == 0):
            frameComplete = 0
            readyForDisplay = 0
            z = np.zeros((2309,),dtype='uint32')
            returnedRawData = np.array([z,z,z,z])
            #makes the current raw data info the same as new so the logic later on this function will add the new data to the memory
            acqNum_currentRawData  = acqNum_newRawData
            isTOA_currentRawData   = isTOA_newRawData
            asicNum_currentRawData = asicNum_newRawData
        else:
            #recovers currentRawData header info
            for j in range(0,4):
                if(currentRawData[j,0]==1):
                    acqNum_currentRawData  = currentRawData[j,1]
                    isTOA_currentRawData   = currentRawData[j,2] & 0x8
                    asicNum_currentRawData = currentRawData[j,2] & 0x7

        #case 2: acqNumber are different
        if(acqNum_newRawData != acqNum_currentRawData):
            frameComplete = 0
            readyForDisplay = 1
            return [frameComplete, readyForDisplay, currentRawData]

        #fill the memory with the new data (when acqNums matches)
        if(asicNum_currentRawData==0 and isTOA_currentRawData==0):
            returnedRawData[0,0]  = 1
            returnedRawData[0,1:] = newRawData_DW
        if(asicNum_currentRawData==1 and isTOA_currentRawData==0):
            returnedRawData[1,0]  = 1
            returnedRawData[1,1:] = newRawData_DW
        if(asicNum_currentRawData==0 and isTOA_currentRawData==1):
            returnedRawData[2,0]  = 1
            returnedRawData[2,1:] = newRawData_DW
        if(asicNum_currentRawData==1 and isTOA_currentRawData==1):
            returnedRawData[3,0]  = 1
            returnedRawData[3,1:] = newRawData_DW

        #checks if the image is complete
        if((currentRawData[0,0]==1) and (currentRawData[1,0]==1) and (currentRawData[2,0]==1) and (currentRawData[3,0]==1)):
            frameComplete = 1
            readyForDisplay = 1
        else:
            frameComplete = 0
            readyForDisplay = 0


        #return parameters
        return [frameComplete, readyForDisplay, returnedRawData]


      
    ##########################################################
    # define all camera specific descrabler functions
    ##########################################################

    def _descrambleEPix100pImage(self, rawData):
        """performs the ePix100p image descrambling"""
        
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
        """performs the ePix100a image descrambling (this is a place holder only)"""
        
        #removes header before displying the image
        for j in range(0,32):
            rawData.pop(0)
        
        #get the first superline
        imgTop = rawData[(0*self._superRowSizeInBytes):(1*self._superRowSizeInBytes)] 
        imgBot = rawData[(1*self._superRowSizeInBytes):(2*self._superRowSizeInBytes)] 
        for j in range(2,self.sensorHeight+1):
            if (j%2):
                imgTop.extend(rawData[((self.sensorHeight-j-2)*self._superRowSizeInBytes):((self.sensorHeight-j-1)*self._superRowSizeInBytes)])
            else:
                imgBot.extend(rawData[(j*self._superRowSizeInBytes):((j+1)*self._superRowSizeInBytes)]) 
        imgDesc = imgTop
        imgDesc.extend(imgBot)

        # returns final image
        return imgDesc

    def _descrambleEPix100aImage(self, rawData):
        """performs the ePix100a image descrambling """
        
        imgDescBA = self._descrambleEPix100aImageAsByteArray(rawData)

        imgDesc = np.frombuffer(imgDescBA,dtype='int16')
        imgDesc = imgDesc.reshape(self.sensorHeight, self.sensorWidth)
        # returns final image
        return imgDesc

    def _descrambleTixel48x48Image(self, rawData):
        """performs the Tixel image descrambling """
        
        imgTop = rawData[0,1:]
        imgTop.extend(rawData[1,1:])
        imgBot = rawData[2,1:]
        imgBot.extend(rawData[3,1:])
        imgDescBA = imgTop
        imgDescBA.extend(imgBot)

        imgDesc = np.frombuffer(imgDescBA,dtype='int16')
        imgDesc = imgDesc.reshape(self.sensorHeight, self.sensorWidth)
        # returns final image
        return imgDesc


    # helper functions
    def _calcImgWidth(self):
        return self._NumAsicsPerSide * self._NumAdcChPerAsic * self._NumColPerAdcCh

