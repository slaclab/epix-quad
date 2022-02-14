#!/usr/bin/env python
# -----------------------------------------------------------------------------
# Title      : local image viewer for the ePix camera images
# -----------------------------------------------------------------------------
# File       : ePixViewer.py
# Author     : Dionisio Doering
# Created    : 2017-02-08
# Last update: 2017-02-08
# -----------------------------------------------------------------------------
# Description:
# Describes the camera main parameters and implements descrambling function
#
#
# -----------------------------------------------------------------------------
# This file is part of the ATLAS CHESS2 DEV. It is subject to
# the license terms in the LICENSE.txt file found in the top-level directory
# of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of the ATLAS CHESS2 DEV, including this file, may be
# copied, modified, propagated, or distributed except according to the terms
# contained in the LICENSE.txt file.
# -----------------------------------------------------------------------------

import sys
import os
#import rogue.utilities
#import rogue.utilities.fileio
#import rogue.interfaces.stream
#import pyrogue
import time
import numpy as np
import ePixViewer.imgProcessing as imgPr

try:
    from PyQt5.QtWidgets import *
    from PyQt5.QtCore import *
    from PyQt5.QtGui import *
except ImportError:
    from PyQt4.QtCore import *
    from PyQt4.QtGui import *

PRINT_VERBOSE = 0

# define global constants
NOCAMERA = 0
EPIX100A = 1
EPIXS = 2
TIXEL48X48 = 3
EPIX10KA = 4
CPIX2 = 5
EPIXM32 = 6
HRADC32x32 = 7
EPIXQUAD = 8
EPIXQUADSIM = 9
EPIXMSH = 10


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
    availableCameras = {
        'ePix100a': EPIX100A, 'ePixS': EPIXS, 'Tixel48x48': TIXEL48X48, 'ePix10ka': EPIX10KA,
        'Cpix2': CPIX2, 'ePixM32Array': EPIXM32, 'HrAdc32x32': HRADC32x32, 'ePixQuad': EPIXQUAD,
        'ePixQuadSim': EPIXQUADSIM, 'ePixMsh': EPIXMSH}

    def __init__(self, cameraType='ePix100a'):

        camID = self.availableCameras.get(cameraType, NOCAMERA)

        # check if the camera exists
        print("Camera ", cameraType, " selected.")
        if (camID == NOCAMERA):
            print("Camera ", cameraType, " not supported")

        self.cameraType = cameraType

        # selcts proper initialization based on camera type
        if (camID == EPIX100A):
            self._initEPix100a()
        if (camID == EPIXS):
            self._initEPixS()
        if (camID == TIXEL48X48):
            self._initTixel48x48()
        if (camID == EPIX10KA):
            self._initEpix10ka()
        if (camID == CPIX2):
            self._initCpix2()
        if (camID == EPIXMSH):
            self._initEpixMsh()
        if (camID == EPIXM32):
            self._initEpixM32()
        if (camID == HRADC32x32):
            self._initEpixHRADC32x32()
        if (camID == EPIXQUAD):
            self._initEpix10kaQuad()
        if (camID == EPIXQUADSIM):
            # self._initEpix10kaQuadSim()
            self._initEpix10kaQuad()

        # creates a image processing tool for local use
        self.imgTool = imgPr.ImageProcessing(self)

    # return a dict with all available cameras
    def getAvailableCameras():
        return self.availableCameras

    # return the descrambled image based on the current camera settings
    def descrambleImage(self, rawData):
        camID = self.availableCameras.get(self.cameraType, NOCAMERA)
        if (camID == EPIX100A):
            descImg = self._descrambleEPix100aImage(rawData)
            return self.imgTool.applyBitMask(descImg, mask=self.bitMask)
        if (camID == EPIXS):
            descImg = self._descrambleEPix100aImage(rawData)
            return self.imgTool.applyBitMask(descImg, mask=self.bitMask)
        if (camID == TIXEL48X48):
            descImg = self._descrambleTixel48x48Image(rawData)
            return self.imgTool.applyBitMask(descImg, mask=self.bitMask)
        if (camID == EPIX10KA):
            descImg = self._descrambleEPix100aImage(rawData)
            return self.imgTool.applyBitMask(descImg, mask=self.bitMask)
        if (camID == EPIXQUAD or camID == EPIXQUADSIM):
            descImg = self._descrambleEPixQuadImage(rawData)
            return self.imgTool.applyBitMask(descImg, mask=self.bitMask)
        if (camID == CPIX2):
            descImg = self._descrambleCpix2Image(rawData)
            return self.imgTool.applyBitMask(descImg, mask=self.bitMask)
        if (camID == EPIXMSH):
            descImg = self._descrambleEpixMshImage(rawData)
            return self.imgTool.applyBitMask(descImg, mask=self.bitMask)
        if (camID == EPIXM32):
            descImg = self._descrambleEpixM32Image(rawData)
            return self.imgTool.applyBitMask(descImg, mask=self.bitMask)
        if (camID == HRADC32x32):
            descImg = self._descrambleEpixHRADC32x32Image(rawData)
            return self.imgTool.applyBitMask(descImg, mask=self.bitMask)
        if (camID == NOCAMERA):
            return Null

    # return
    def buildImageFrame(self, currentRawData, newRawData):
        camID = self.availableCameras.get(self.cameraType, NOCAMERA)

        if (PRINT_VERBOSE):
            print('buildImageFrame - camID: ', camID)

        frameComplete = 0
        readyForDisplay = 0
        if (camID == EPIX100A):
            # The flags are always true since each frame holds an entire image
            frameComplete = 1
            readyForDisplay = 1
            return [frameComplete, readyForDisplay, newRawData]
        if (camID == EPIXS):
            # The flags are always true since each frame holds an entire image
            frameComplete = 1
            readyForDisplay = 1
            return [frameComplete, readyForDisplay, newRawData]
        if (camID == TIXEL48X48):
            # Needs to check the two frames and make a decision on the flags
            [frameComplete, readyForDisplay, newRawData] = self._buildFrameTixel48x48Image(currentRawData, newRawData)
            return [frameComplete, readyForDisplay, newRawData]
        if (camID == EPIX10KA):
            # The flags are always true since each frame holds an entire image
            frameComplete = 1
            readyForDisplay = 1
            return [frameComplete, readyForDisplay, newRawData]
        if (camID == EPIXQUAD or camID == EPIXQUADSIM):
            # The flags are always true since each frame holds an entire image
            frameComplete = 1
            readyForDisplay = 1
            return [frameComplete, readyForDisplay, newRawData]
        if (camID == CPIX2):
            # Needs to check the two frames and make a decision on the flags
            [frameComplete, readyForDisplay, newRawData] = self._buildFrameCpix2Image(currentRawData, newRawData)
            return [frameComplete, readyForDisplay, newRawData]
            print('end of buildImageFrame')
        if (camID == EPIXMSH):
            frameComplete = 1
            readyForDisplay = 1
            return [frameComplete, readyForDisplay, newRawData]
        if (camID == EPIXM32):
            [frameComplete, readyForDisplay, newRawData] = self._buildFrameEpixM32Image(currentRawData, newRawData)
            return [frameComplete, readyForDisplay, newRawData]
        if (camID == HRADC32x32):
            [frameComplete, readyForDisplay, newRawData] = self._buildFrameEpixHRADC32x32Image(
                currentRawData, newRawData)
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
        self.sensorHeight = 708
        self.pixelDepth = 16
        self.cameraModule = "Standard ePix100a"
        self.bitMask = np.uint16(0xFFFF)

    def _initEPixS(self):
        self._superRowSize = 10
        self._NumAsicsPerSide = 2
        self._NumAdcChPerAsic = 1
        self._NumColPerAdcCh = 10
        self._superRowSizeInBytes = self._superRowSize * 4
        self.sensorWidth = self._calcImgWidth()
        self.sensorHeight = 24
        self.pixelDepth = 16
        self.bitMask = np.uint16(0xFFFF)

    def _initTixel48x48(self):
        #self._superRowSize = 384
        self._NumAsicsPerSide = 1
        #self._NumAdcChPerAsic = 4
        #self._NumColPerAdcCh = 96
        #self._superRowSizeInBytes = self._superRowSize * 4
        # The sensor size in this dimension is doubled because each pixel has two information (ToT and ToA)
        self.sensorWidth = 96
        # The sensor size in this dimension is doubled because each pixel has two information (ToT and ToA)
        self.sensorHeight = 96
        self.pixelDepth = 16
        self.bitMask = np.uint16(0xFFFF)

    def _initEpix10ka(self):
        self._superRowSize = int(384 / 2)
        self._NumAsicsPerSide = 2
        self._NumAdcChPerAsic = 4
        self._NumColPerAdcCh = int(96 / 2)
        self._superRowSizeInBytes = self._superRowSize * 4
        self.sensorWidth = self._calcImgWidth()
        self.sensorHeight = 356  # 706
        self.pixelDepth = 16
        self.cameraModule = "Standard ePix10ka"
        self.bitMask = np.uint16(0x7FFF)

    def _initEpix10kaQuad(self):
        self._superRowSize = int(768 / 2)
        self._NumAsicsPerSide = 4
        self._NumAdcChPerAsic = 4
        self._NumColPerAdcCh = int(96 / 2)
        self._superRowSizeInBytes = self._superRowSize * 4
        self.sensorWidth = self._calcImgWidth()
        self.sensorHeight = 712
        self.pixelDepth = 16
        self.cameraModule = "ePix10ka Quad"
        self.bitMask = np.uint16(0x7FFF)

    def _initEpix10kaQuadSim(self):
        # this is for simulation image size (smaller for sim speed-up)
        self._superRowSize = int(384 / 2)
        self._NumAsicsPerSide = 4
        self._NumAdcChPerAsic = 4
        self._NumColPerAdcCh = int(24)
        self._superRowSizeInBytes = self._superRowSize * 4
        self.sensorWidth = self._calcImgWidth()
        self.sensorHeight = 192
        self.pixelDepth = 16
        self.cameraModule = "ePix10ka Quad"
        self.bitMask = np.uint16(0x3FFF)

    def _initCpix2(self):
        #self._superRowSize = 384
        self._NumAsicsPerSide = 1
        #self._NumAdcChPerAsic = 4
        #self._NumColPerAdcCh = 96
        #self._superRowSizeInBytes = self._superRowSize * 4
        # The sensor size in this dimension is doubled because each pixel has two information (ToT and ToA)
        self.sensorWidth = 96
        # The sensor size in this dimension is doubled because each pixel has two information (ToT and ToA)
        self.sensorHeight = 96
        self.pixelDepth = 16
        self.bitMask = np.uint16(0x7FFF)

    def _initEpixMsh(self):
        self._NumAsicsPerSide = 1
        self.sensorWidth = 48
        self.sensorHeight = 48
        self.pixelDepth = 16
        self.bitMask = np.uint16(0x7FFF)

    def _initEpixM32(self):
        #self._superRowSize = 384
        self._NumAsicsPerSide = 1
        #self._NumAdcChPerAsic = 4
        #self._NumColPerAdcCh = 96
        #self._superRowSizeInBytes = self._superRowSize * 4
        # The sensor size in this dimension is doubled because each pixel has two information (ToT and ToA)
        self.sensorWidth = 64
        # The sensor size in this dimension is doubled because each pixel has two information (ToT and ToA)
        self.sensorHeight = 64
        self.pixelDepth = 16
        self.bitMask = np.uint16(0x3FFF)

    def _initEpixHRADC32x32(self):
        #self._superRowSize = 384
        self._NumAsicsPerSide = 1
        #self._NumAdcChPerAsic = 4
        #self._NumColPerAdcCh = 96
        #self._superRowSizeInBytes = self._superRowSize * 4
        # The sensor size in this dimension is doubled because each pixel has two information (ToT and ToA)
        self.sensorWidth = 64
        # The sensor size in this dimension is doubled because each pixel has two information (ToT and ToA)
        self.sensorHeight = 32
        self.pixelDepth = 16
        self.bitMask = np.uint16(0xFFFF)

    ##########################################################
    # define all camera specific build frame functions
    ##########################################################
    def _buildFrameTixel48x48Image(self, currentRawData, newRawData):
        """ Performs the Tixel frame building.
            For this sensor the image takes four frames, twa with time of arrival info
            and two with time over threshold. There is no guarantee both frames will always arrive nor on their order."""
        # init local variables
        frameComplete = 0
        readyForDisplay = 0
        returnedRawData = []
        acqNum_currentRawData = 0
        isTOA_currentRawData = 0
        asicNum_currentRawData = 0
        acqNum_newRawData = 0
        isTOA_newRawData = 0
        asicNum_newRawData = 0

        ##if (PRINT_VERBOSE): print('\nlen current Raw data', len(currentRawData), 'len new raw data', len(newRawData))
        # converts data to 32 bit
        newRawData_DW = np.frombuffer(newRawData, dtype='uint32')
        ##if (PRINT_VERBOSE): print('\nlen current Raw data', len(currentRawData), 'len new raw data DW', len(newRawData_DW))

        # retrieves header info
        # header dword 0 (VC info)
        acqNum_newRawData = newRawData_DW[1]                    # header dword 1
        isTOA_newRawData = (newRawData_DW[2] & 0x8) >> 3        # header dword 2
        asicNum_newRawData = newRawData_DW[2] & 0x7              # header dword 2
        ##if (PRINT_VERBOSE): print('\nacqNum_newRawData: ', acqNum_newRawData, '\nisTOA_newRawData:', isTOA_newRawData, '\nasicNum_newRawData:', asicNum_newRawData)

        # interpret headers
        # case 1: new image (which means currentRawData is empty)
        if (len(currentRawData) == 0):
            frameComplete = 0
            readyForDisplay = 0
            z = np.zeros((1156,), dtype='uint32')  # 2310 for the package plus 1 (first byte for the valid flag
            returnedRawData = np.array([z, z, z, z])
            # makes the current raw data info the same as new so the logic later on
            # this function will add the new data to the memory
            acqNum_currentRawData = acqNum_newRawData
            isTOA_currentRawData = isTOA_newRawData
            asicNum_currentRawData = asicNum_newRawData
        # case where the currentRawData is a byte array
        elif(len(currentRawData) == 4620):
            frameComplete = 0
            readyForDisplay = 0
            z = np.zeros((1156,), dtype='uint32')  # 2310 for the package plus 1 (first byte for the valid flag
            returnedRawData = np.array([z, z, z, z])
            #
            currentRawData_DW = np.frombuffer(currentRawData, dtype='uint32')
            # header dword 0 (VC info)
            acqNum_currentRawData = currentRawData_DW[1]                   # header dword 1
            isTOA_currentRawData = (currentRawData_DW[2] & 0x8) >> 3       # header dword 2
            asicNum_currentRawData = currentRawData_DW[2] & 0x7             # header dword 2

            currentRawData = self.fill_memory(returnedRawData, asicNum_currentRawData,
                                              isTOA_currentRawData, currentRawData_DW)
            returnedRawData = currentRawData

        elif(len(currentRawData) == 4):
            # recovers currentRawData header info
            # loop traverses the four traces to find the info
            for j in range(0, 4):
                # print(len(currentRawData))
                if(currentRawData[j, 0] == 1):
                    # extended header dword 0 (valid trace)
                    # extended header dword 1 (VC info)
                    acqNum_currentRawData = currentRawData[j, 2]               # extended header dword 2 (acq num)
                    isTOA_currentRawData = (currentRawData[j, 3] & 0x8) >> 3   # extended header dword 3
                    asicNum_currentRawData = currentRawData[j, 3] & 0x7         # extended header dword 1 (VC info)
            # saves current data on returned data before adding new data
            returnedRawData = currentRawData
        else:
            # packet size error
            if (PRINT_VERBOSE):
                print('\n packet size error, packet len: ', len(currentRawData))

        ##if (PRINT_VERBOSE): print('\nacqNum_currentRawData: ', acqNum_currentRawData, '\nisTOA_currentRawData: ', isTOA_currentRawData, '\nasicNum_currentRawData: ', asicNum_currentRawData)
        ##if (PRINT_VERBOSE): print('\nacqNum_newRawData: ',     acqNum_newRawData,     '\nisTOA_newRawData: ',     isTOA_newRawData, '\nasicNum_newRawData: ', asicNum_newRawData)
        # case 2: acqNumber are different
        if(acqNum_newRawData != acqNum_currentRawData):
            frameComplete = 0
            readyForDisplay = 1
            return [frameComplete, readyForDisplay, currentRawData]

        # fill the memory with the new data (when acqNums matches)
        returnedRawData = self.fill_memory(returnedRawData, asicNum_newRawData, isTOA_newRawData, newRawData_DW)
        if (PRINT_VERBOSE):
            print('Return data 0:', returnedRawData[0, 0:10])
        if (PRINT_VERBOSE):
            print('Return data 1:', returnedRawData[1, 0:10])
        if (PRINT_VERBOSE):
            print('Return data 2:', returnedRawData[2, 0:10])
        if (PRINT_VERBOSE):
            print('Return data 3:', returnedRawData[3, 0:10])

        # checks if the image is complete
        isValidTrace0 = returnedRawData[0, 0]
        if (PRINT_VERBOSE):
            print('\nisValidTrace0', isValidTrace0)
        isValidTrace1 = returnedRawData[1, 0]
        if (PRINT_VERBOSE):
            print('\nisValidTrace1', isValidTrace1)
        isValidTrace2 = returnedRawData[2, 0]
        if (PRINT_VERBOSE):
            print('\nisValidTrace2', isValidTrace2)
        isValidTrace3 = returnedRawData[3, 0]
        if (PRINT_VERBOSE):
            print('\nisValidTrace3', isValidTrace3)

        if((isValidTrace0 == 1) and (isValidTrace1 == 1) and (isValidTrace2 == 1) and (isValidTrace3 == 1)):
            frameComplete = 1
            readyForDisplay = 1
        else:
            frameComplete = 0
            readyForDisplay = 0

        if (PRINT_VERBOSE):
            print(
                'frameComplete: ',
                frameComplete,
                'readyForDisplay: ',
                readyForDisplay,
                'returned raw data len',
                len(returnedRawData))
        # return parameters
        return [frameComplete, readyForDisplay, returnedRawData]

    def _buildFrameCpix2Image(self, currentRawData, newRawData):
        """ Performs the Cpix2 frame building.
            For this sensor the image takes four frames, twa with time of arrival info
            and two with time over threshold. There is no guarantee both frames will always arrive nor on their order."""
        # init local variables
        frameComplete = 0
        readyForDisplay = 0
        returnedRawData = []
        acqNum_currentRawData = 0
        isTOA_currentRawData = 0
        asicNum_currentRawData = 0
        acqNum_newRawData = 0
        isTOA_newRawData = 0
        asicNum_newRawData = 0

        if (PRINT_VERBOSE):
            print('\n0 \nlen current Raw data', len(currentRawData), 'len new raw data', len(newRawData))
        # converts data to 32 bit
        newRawData_DW = np.frombuffer(newRawData, dtype='uint32')
        if (PRINT_VERBOSE):
            print('\n1 \nlen current Raw data', len(currentRawData), 'len new raw data DW', len(newRawData_DW))

        # retrieves header info
            # header dword 0 (VC info)
        acqNum_newRawData = newRawData_DW[1]                    # header dword 1
        isTOA_newRawData = (newRawData_DW[2] & 0x8) >> 3        # header dword 2
        asicNum_newRawData = newRawData_DW[2] & 0x7              # header dword 2
        if (PRINT_VERBOSE):
            print(
                '\n2 \n acqNum_newRawData: ',
                acqNum_newRawData,
                '\nisTOA_newRawData:',
                isTOA_newRawData,
                '\nasicNum_newRawData:',
                asicNum_newRawData)

        # interpret headers
        # case 1: new image (which means currentRawData is empty)
        if (len(currentRawData) == 0):
            frameComplete = 0
            readyForDisplay = 0
            z = np.zeros((1156,), dtype='uint32')  # 2310 for the package plus 1 (first byte for the valid flag
            returnedRawData = np.array([z, z, z, z])
            # makes the current raw data info the same as new so the logic later on
            # this function will add the new data to the memory
            acqNum_currentRawData = acqNum_newRawData
            isTOA_currentRawData = isTOA_newRawData
            asicNum_currentRawData = asicNum_newRawData
        # case where the currentRawData is a byte array
        elif((len(currentRawData) == 1155) or (len(currentRawData) == 4620)):
            frameComplete = 0
            readyForDisplay = 0
            z = np.zeros((1156,), dtype='uint32')  # 2310 for the package plus 1 (first byte for the valid flag
            returnedRawData = np.array([z, z, z, z])
            #
            currentRawData_DW = np.frombuffer(currentRawData, dtype='uint32')
            # header dword 0 (VC info)
            acqNum_currentRawData = currentRawData_DW[1]                   # header dword 1
            isTOA_currentRawData = (currentRawData_DW[2] & 0x8) >> 3       # header dword 2
            asicNum_currentRawData = currentRawData_DW[2] & 0x7             # header dword 2

            currentRawData = self.fill_memory(returnedRawData, asicNum_currentRawData,
                                              isTOA_currentRawData, currentRawData_DW)
            returnedRawData = currentRawData

            if (PRINT_VERBOSE):
                print('\n3 \n Return data 0:', returnedRawData[0, 0:10])
            if (PRINT_VERBOSE):
                print('\n3 \n Return data 1:', returnedRawData[1, 0:10])
            if (PRINT_VERBOSE):
                print('\n3 \n Return data 2:', returnedRawData[2, 0:10])
            if (PRINT_VERBOSE):
                print('\n3 \n Return data 3:', returnedRawData[3, 0:10])

        elif(len(currentRawData) == 4):
            # recovers currentRawData header info
            # loop traverses the four traces to find the info
            for j in range(0, 4):
                # print(len(currentRawData))
                if(currentRawData[j, 0] == 1):
                    # extended header dword 0 (valid trace)
                    # extended header dword 1 (VC info)
                    acqNum_currentRawData = currentRawData[j, 2]               # extended header dword 2 (acq num)
                    isTOA_currentRawData = (currentRawData[j, 3] & 0x8) >> 3   # extended header dword 3
                    asicNum_currentRawData = currentRawData[j, 3] & 0x7         # extended header dword 1 (VC info)
            # saves current data on returned data before adding new data
            if (PRINT_VERBOSE):
                print('\n3B \n len 4')
            returnedRawData = currentRawData
        else:
            # packet size error
            if (PRINT_VERBOSE):
                print('\n4  \npacket size error, packet len: ', len(currentRawData))

        if (PRINT_VERBOSE):
            print(
                '\n5 \nacqNum_currentRawData: ',
                acqNum_currentRawData,
                '\nisTOA_currentRawData: ',
                isTOA_currentRawData,
                '\nasicNum_currentRawData: ',
                asicNum_currentRawData)
        if (PRINT_VERBOSE):
            print(
                '\n5 \nacqNum_newRawData: ',
                acqNum_newRawData,
                '\nisTOA_newRawData: ',
                isTOA_newRawData,
                '\nasicNum_newRawData: ',
                asicNum_newRawData)
        # case 2: acqNumber are different
        if(acqNum_newRawData != acqNum_currentRawData):
            frameComplete = 0
            readyForDisplay = 1
            return [frameComplete, readyForDisplay, currentRawData]

        # fill the memory with the new data (when acqNums matches)
        returnedRawData = self.fill_memory(returnedRawData, asicNum_newRawData, isTOA_newRawData, newRawData_DW)
        if (PRINT_VERBOSE):
            print('\n6 \nReturn data 0:', returnedRawData[0, 0:10])
        if (PRINT_VERBOSE):
            print('\n6 \nReturn data 1:', returnedRawData[1, 0:10])
        if (PRINT_VERBOSE):
            print('\n6 \nReturn data 2:', returnedRawData[2, 0:10])
        if (PRINT_VERBOSE):
            print('\n6 \nReturn data 3:', returnedRawData[3, 0:10])

        # checks if the image is complete
        isValidTrace0 = returnedRawData[0, 0]
        if (PRINT_VERBOSE):
            print('\n7 \nisValidTrace0', isValidTrace0)
        isValidTrace1 = returnedRawData[1, 0]
        if (PRINT_VERBOSE):
            print('\n8 \nisValidTrace1', isValidTrace1)
        isValidTrace2 = returnedRawData[2, 0]
        if (PRINT_VERBOSE):
            print('\n9 \nisValidTrace2', isValidTrace2)
        isValidTrace3 = returnedRawData[3, 0]
        if (PRINT_VERBOSE):
            print('\n10 \nisValidTrace3', isValidTrace3)

        if((isValidTrace0 == 1) and (isValidTrace1 == 1) and (isValidTrace2 == 1) and (isValidTrace3 == 1)):
            frameComplete = 1
            readyForDisplay = 1
        else:
            frameComplete = 0
            readyForDisplay = 0

        if (PRINT_VERBOSE):
            print(
                '\n11 \nframeComplete: ',
                frameComplete,
                'readyForDisplay: ',
                readyForDisplay,
                'returned raw data len',
                len(returnedRawData))
        # return parameters
        return [frameComplete, readyForDisplay, returnedRawData]

    # fill the memory with the new data (when acqNums matches)
    def fill_memory(self, returnedRawData, asicNum_currentRawData, isTOA_currentRawData, newRawData_DW):
        ##if (PRINT_VERBOSE): print('New data:', newRawData_DW[0:10])
        if (len(newRawData_DW) == 1155):
            if(asicNum_currentRawData == 0 and isTOA_currentRawData == 0):
                returnedRawData[0, 0] = 1
                returnedRawData[0, 1:] = newRawData_DW
            if(asicNum_currentRawData == 1 and isTOA_currentRawData == 0):
                returnedRawData[1, 0] = 1
                returnedRawData[1, 1:] = newRawData_DW
            if(asicNum_currentRawData == 0 and isTOA_currentRawData == 1):
                returnedRawData[2, 0] = 1
                returnedRawData[2, 1:] = newRawData_DW
            if(asicNum_currentRawData == 1 and isTOA_currentRawData == 1):
                returnedRawData[3, 0] = 1
                returnedRawData[3, 1:] = newRawData_DW
            ##if (PRINT_VERBOSE): print('Return data 0:', returnedRawData[0,0:10])
            ##if (PRINT_VERBOSE): print('Return data 1:', returnedRawData[1,0:10])
            ##if (PRINT_VERBOSE): print('Return data 2:', returnedRawData[2,0:10])
            ##if (PRINT_VERBOSE): print('Return data 3:', returnedRawData[3,0:10])
        return returnedRawData

    def _buildFrameEpixM32Image(self, currentRawData, newRawData):
        """ Performs the epixM32 frame building.
            For this sensor the image takes two frames
            There is no guarantee both frames will always arrive nor on their order."""
        # init local variables
        frameComplete = 0
        readyForDisplay = 0
        returnedRawData = []
        acqNum_currentRawData = 0
        asicNum_currentRawData = 0
        acqNum_newRawData = 0
        asicNum_newRawData = 0

        #if (PRINT_VERBOSE): print('\nlen current Raw data', len(currentRawData), 'len new raw data', len(newRawData))
        # converts data to 32 bit
        newRawData_DW = np.frombuffer(newRawData, dtype='uint32')
        #if (PRINT_VERBOSE): print('\nlen current Raw data', len(currentRawData), 'len new raw data DW', len(newRawData_DW))

        # retrieves header info
        # header dword 0 (VC info)
        acqNum_newRawData = newRawData_DW[1]                    # header dword 1
        asicNum_newRawData = newRawData_DW[2] & 0xF              # header dword 2
        #if (PRINT_VERBOSE): print('\nacqNum_newRawData: ', acqNum_newRawData, '\nasicNum_newRawData:', asicNum_newRawData)

        # for i in range(3, 10):
        #    print('New %x %x' %(newRawData_DW[i]&0xFFFF, newRawData_DW[i]>>16))

        # interpret headers
        # case 1: new image (which means currentRawData is empty)
        if (len(currentRawData) == 0):
            frameComplete = 0
            readyForDisplay = 0
            z = np.zeros((1028,), dtype='uint32')  # 2054 for the package plus 1 (first byte for the valid flag
            returnedRawData = np.array([z, z])
            # makes the current raw data info the same as new so the logic later on
            # this function will add the new data to the memory
            acqNum_currentRawData = acqNum_newRawData
            asicNum_currentRawData = asicNum_newRawData
        # case where the currentRawData is a byte array
        elif(len(currentRawData) == 4108):
            # for i in range(3, 10):
            #    print('Curr %x %x' %(currentRawData[i]&0xFFFF, currentRawData[i]>>16))
            frameComplete = 0
            readyForDisplay = 0
            z = np.zeros((1028,), dtype='uint32')  # 2054 for the package plus 1 (first byte for the valid flag
            returnedRawData = np.array([z, z])

            # makes the current raw data info the same as new so the logic later on
            # this function will add the new data to the memory
            acqNum_currentRawData = acqNum_newRawData
            asicNum_currentRawData = asicNum_newRawData

        elif(len(currentRawData) == 2):
            # for i in range(3, 10):
            #    print('Cur0 %x %x' %(currentRawData[0,i]&0xFFFF, currentRawData[0,i]>>16))
            # for i in range(3, 10):
            #    print('Cur1 %x %x' %(currentRawData[1,i]&0xFFFF, currentRawData[1,i]>>16))

            # recovers currentRawData header info
            # loop traverses the four traces to find the info
            for j in range(0, 2):
                # print(len(currentRawData))
                if(currentRawData[j, 0] == 1):
                    # extended header dword 0 (valid trace)
                    # extended header dword 1 (VC info)
                    acqNum_currentRawData = currentRawData[j, 2]               # extended header dword 2 (acq num)
                    asicNum_currentRawData = currentRawData[j, 3] & 0xf         # extended header dword 1 (VC info)
            # saves current data on returned data before adding new data
            returnedRawData = currentRawData
        else:
            # packet size error
            if (PRINT_VERBOSE):
                print('\n packet size error, packet len: ', len(currentRawData))

        ##if (PRINT_VERBOSE): print('\nacqNum_currentRawData: ', acqNum_currentRawData, '\nisTOA_currentRawData: ', isTOA_currentRawData, '\nasicNum_currentRawData: ', asicNum_currentRawData)
        ##if (PRINT_VERBOSE): print('\nacqNum_newRawData: ',     acqNum_newRawData,     '\nisTOA_newRawData: ',     isTOA_newRawData, '\nasicNum_newRawData: ', asicNum_newRawData)
        # case 2: acqNumber are different
        if(acqNum_newRawData != acqNum_currentRawData):
            frameComplete = 0
            readyForDisplay = 1
            return [frameComplete, readyForDisplay, currentRawData]

        # fill the memory with the new data (when acqNums matches)
        if (len(newRawData_DW) == 1027):
            if(asicNum_newRawData == 0):
                returnedRawData[0, 0] = 1
                returnedRawData[0, 1:] = newRawData_DW
            if(asicNum_newRawData == 1):
                returnedRawData[1, 0] = 1
                returnedRawData[1, 1:] = newRawData_DW

        # checks if the image is complete
        isValidTrace0 = returnedRawData[0, 0]
        ##if (PRINT_VERBOSE): print('\nisValidTrace0', isValidTrace0)
        isValidTrace1 = returnedRawData[1, 0]
        ##if (PRINT_VERBOSE): print('\nisValidTrace1', isValidTrace1)
        if((isValidTrace0 == 1) and (isValidTrace1 == 1)):
            frameComplete = 1
            readyForDisplay = 1
        else:
            frameComplete = 0
            readyForDisplay = 0

        #if (PRINT_VERBOSE): print('frameComplete: ', frameComplete, 'readyForDisplay: ', readyForDisplay, 'returned raw data len', len(returnedRawData))
        # return parameters
        return [frameComplete, readyForDisplay, returnedRawData]

    def _buildFrameEpixHRADC32x32Image(self, currentRawData, newRawData):
        """ Performs the epixHRADC32x32 frame building.
            For this sensor the image takes two frames
            There is no guarantee both frames will always arrive nor on their order."""
        # init local variables
        frameComplete = 0
        readyForDisplay = 0
        returnedRawData = []
        acqNum_currentRawData = 0
        asicNum_currentRawData = 0
        acqNum_newRawData = 0
        asicNum_newRawData = 0

        #if (PRINT_VERBOSE): print('\nlen current Raw data', len(currentRawData), 'len new raw data', len(newRawData))
        # converts data to 32 bit
        newRawData_DW = np.frombuffer(newRawData, dtype='uint32')
        #if (PRINT_VERBOSE): print('\nlen current Raw data', len(currentRawData), 'len new raw data DW', len(newRawData_DW))

        # retrieves header info
        # header dword 0 (VC info)
        acqNum_newRawData = newRawData_DW[1]                    # header dword 1
        asicNum_newRawData = newRawData_DW[2] & 0x7              # header dword 2
        #if (PRINT_VERBOSE): print('\nacqNum_newRawData: ', acqNum_newRawData, '\nasicNum_newRawData:', asicNum_newRawData)

        # for i in range(3, 10):
        #    print('New %x %x' %(newRawData_DW[i]&0xFFFF, newRawData_DW[i]>>16))

        # interpret headers
        # case 1: new image (which means currentRawData is empty)
        if (len(currentRawData) == 0):
            frameComplete = 0
            readyForDisplay = 0
            z = np.zeros((516,), dtype='uint32')  # 512 for the package plus 1 (first byte for the valid flag
            returnedRawData = np.array([z, z])
            # makes the current raw data info the same as new so the logic later on
            # this function will add the new data to the memory
            acqNum_currentRawData = acqNum_newRawData
            asicNum_currentRawData = asicNum_newRawData
        # case where the currentRawData is a byte array
        elif(len(currentRawData) == 2060):
            # for i in range(3, 10):
            #    print('Curr %x %x' %(currentRawData[i]&0xFFFF, currentRawData[i]>>16))
            frameComplete = 0
            readyForDisplay = 0
            z = np.zeros((516,), dtype='uint32')  # 512 for the package plus 1 (first byte for the valid flag
            returnedRawData = np.array([z, z])

            # makes the current raw data info the same as new so the logic later on
            # this function will add the new data to the memory
            acqNum_currentRawData = acqNum_newRawData
            asicNum_currentRawData = asicNum_newRawData

        elif(len(currentRawData) == 2):
            # for i in range(3, 10):
            #    print('Cur0 %x %x' %(currentRawData[0,i]&0xFFFF, currentRawData[0,i]>>16))
            # for i in range(3, 10):
            #    print('Cur1 %x %x' %(currentRawData[1,i]&0xFFFF, currentRawData[1,i]>>16))

            # recovers currentRawData header info
            # loop traverses the four traces to find the info
            for j in range(0, 2):
                print("_buildFrameEpixHRADC32x32Image", len(currentRawData))
                if(currentRawData[j, 0] == 1):
                    # extended header dword 0 (valid trace)
                    # extended header dword 1 (VC info)
                    acqNum_currentRawData = currentRawData[j, 2]               # extended header dword 2 (acq num)
                    asicNum_currentRawData = currentRawData[j, 3] & 0x7         # extended header dword 1 (VC info)
            # saves current data on returned data before adding new data
            returnedRawData = currentRawData
        else:
            # packet size error
            if (PRINT_VERBOSE):
                print('\n_buildFrameEpixHRADC32x32Image: packet size error, packet len: ', len(currentRawData))

        ##if (PRINT_VERBOSE): print('\nacqNum_currentRawData: ', acqNum_currentRawData, '\nisTOA_currentRawData: ', isTOA_currentRawData, '\nasicNum_currentRawData: ', asicNum_currentRawData)
        ##if (PRINT_VERBOSE): print('\nacqNum_newRawData: ',     acqNum_newRawData,     '\nisTOA_newRawData: ',     isTOA_newRawData, '\nasicNum_newRawData: ', asicNum_newRawData)
        # case 2: acqNumber are different
        if(acqNum_newRawData != acqNum_currentRawData):
            frameComplete = 0
            readyForDisplay = 1
            return [frameComplete, readyForDisplay, currentRawData]

        # fill the memory with the new data (when acqNums matches)
        if (len(newRawData_DW) == 515):
            if(asicNum_newRawData == 0 or asicNum_newRawData == 2):
                returnedRawData[0, 0] = 1
                returnedRawData[0, 1:] = newRawData_DW
            if(asicNum_newRawData == 1):
                returnedRawData[1, 0] = 1
                returnedRawData[1, 1:] = newRawData_DW

        # checks if the image is complete
        isValidTrace0 = returnedRawData[0, 0]
        if (PRINT_VERBOSE):
            print('\n_buildFrameEpixHRADC32x32Image: isValidTrace0', isValidTrace0)
        isValidTrace1 = returnedRawData[1, 0]
        if (PRINT_VERBOSE):
            print('\n_buildFrameEpixHRADC32x32Image: isValidTrace1', isValidTrace1)
        if((isValidTrace0 == 1) and (isValidTrace1 == 1)):
            frameComplete = 1
            readyForDisplay = 1
        else:
            frameComplete = 0
            readyForDisplay = 0

        if (PRINT_VERBOSE):
            print(
                '_buildFrameEpixHRADC32x32Image: frameComplete: ',
                frameComplete,
                'readyForDisplay: ',
                readyForDisplay,
                'returned raw data len',
                len(returnedRawData))
        # return parameters
        return [frameComplete, readyForDisplay, returnedRawData]

    ##########################################################
    # define all camera specific descrabler functions
    ##########################################################

    def _descrambleEPix100aImageAsByteArray(self, rawData):
        """performs the ePix100a image descrambling (this is a place holder only)"""

        # removes header before displying the image
        for j in range(0, 32):
            rawData.pop(0)

        # get the first superline
        imgBot = bytearray()
        imgTop = bytearray()
        for j in range(0, self.sensorHeight):
            if (j % 2):
                imgTop.extend(rawData[((self.sensorHeight - j) * self._superRowSizeInBytes):((self.sensorHeight - j + 1) * self._superRowSizeInBytes)])
            else:
                imgBot.extend(rawData[(j * self._superRowSizeInBytes):((j + 1) * self._superRowSizeInBytes)])
        imgDesc = imgTop
        imgDesc.extend(imgBot)

        # returns final image
        return imgDesc

    def _descrambleEPix100aImage(self, rawData):
        """performs the ePix100a image descrambling """

        imgDescBA = self._descrambleEPix100aImageAsByteArray(rawData)

        imgDesc = np.frombuffer(imgDescBA, dtype='int16')
        if self.sensorHeight * self.sensorWidth != len(imgDesc):
            print("Got wrong pixel number ", len(imgDesc))
        else:
            if (PRINT_VERBOSE):
                print("Got pixel number ", len(imgDesc))
            imgDesc = imgDesc.reshape(self.sensorHeight, self.sensorWidth)
        # returns final image
        return imgDesc

    def getThermistorTemp(self, x):
        # resistor divider 100k and MC65F103B (Rt25=10k)
        # Vref 2.5V
        if x != 0:
            Umeas = x / 16383.0 * 2.5
            Itherm = Umeas / 100000
            Rtherm = (2.5 - Umeas) / Itherm
            LnRtR25 = np.log(Rtherm / 10000.0)
            TthermK = 1.0 / (3.3538646E-03 + 2.5654090E-04 * LnRtR25 + 1.9243889E-06 *
                             (LnRtR25**2) + 1.0969244E-07 * (LnRtR25**3))
            return TthermK - 273.15
        else:
            return 0.0

    def _descrambleEPixQuadImageAsByteArray(self, rawData):
        """performs the ePix Quad image descrambling (this is a place holder only)"""

        # example of monitoring data descrambling
        if (PRINT_VERBOSE):
            footerOffset = 32 + self._superRowSizeInBytes * self.sensorHeight
            footer = rawData[footerOffset:footerOffset + 38 * 2]

            shtHumRaw = (footer[1] << 8) | footer[0]
            shtTempRaw = (footer[3] << 8) | footer[2]
            nctLocTempRaw = footer[4]
            nctRemTempLRaw = footer[6]
            nctRemTempHRaw = footer[7]
            ad7949DataRaw0 = (footer[9] << 8) | footer[8]
            ad7949DataRaw1 = (footer[11] << 8) | footer[10]
            ad7949DataRaw2 = (footer[13] << 8) | footer[12]
            ad7949DataRaw3 = (footer[15] << 8) | footer[14]
            ad7949DataRaw4 = (footer[17] << 8) | footer[16]
            ad7949DataRaw5 = (footer[19] << 8) | footer[18]
            ad7949DataRaw6 = (footer[21] << 8) | footer[20]
            ad7949DataRaw7 = (footer[23] << 8) | footer[22]
            sensorRegRaw = [0] * 26
            for i in range(26):
                sensorRegRaw[i] = (footer[25 + i * 2] << 8) | footer[24 + i * 2]
            print('SHT31 humidity %f %%' % (shtHumRaw / 65535.0 * 100.0))
            print('SHT31 temperature %f deg C' % (shtTempRaw / 65535.0 * 175.0 - 45.0))
            print('NCT local temperature %d deg C' % (nctLocTempRaw))
            print('NCT FPGA temperature %f deg C' % (nctRemTempHRaw + (nctRemTempLRaw >> 6) * 0.25))
            print('ASIC_A0_2V5_Current %f mA' % (ad7949DataRaw0 / 16383.0 * 2.5 / 330.0 * 1000000))
            print('ASIC_A1_2V5_Current %f mA' % (ad7949DataRaw1 / 16383.0 * 2.5 / 330.0 * 1000000))
            print('ASIC_A2_2V5_Current %f mA' % (ad7949DataRaw2 / 16383.0 * 2.5 / 330.0 * 1000000))
            print('ASIC_A3_2V5_Current %f mA' % (ad7949DataRaw3 / 16383.0 * 2.5 / 330.0 * 1000000))
            print('ASIC_D0_2V5_Current %f mA' % (ad7949DataRaw4 / 16383.0 * 2.5 / 330.0 * 1000000 / 2.0))
            print('ASIC_D1_2V5_Current %f mA' % (ad7949DataRaw5 / 16383.0 * 2.5 / 330.0 * 1000000 / 2.0))
            print('Therm0_Temp %f deg C' % (self.getThermistorTemp(ad7949DataRaw6)))
            print('Therm1_Temp %f deg C' % (self.getThermistorTemp(ad7949DataRaw7)))
            print('PwrDigCurr %f A' % (sensorRegRaw[0] * 0.1024 / 4095 / 0.02))
            print('PwrDigVin %f V' % (sensorRegRaw[1] * 102.4 / 4095))
            print('PwrDigTemp %f deg C' % (sensorRegRaw[2] * 2.048 /
                  4095 * (130.0 / (0.882 - 1.951)) + (0.882 / 0.0082 + 100)))
            print('PwrAnaCurr %f A' % (sensorRegRaw[3] * 0.1024 / 4095 / 0.02))
            print('PwrAnaVin %f V' % (sensorRegRaw[4] * 102.4 / 4095))
            print('PwrAnaTemp %f deg C' % (sensorRegRaw[5] * 2.048 /
                  4095 * (130.0 / (0.882 - 1.951)) + (0.882 / 0.0082 + 100)))
            LdoNames = [
                'A0+2_5V_H_Temp', 'A0+2_5V_L_Temp',
                'A1+2_5V_H_Temp', 'A1+2_5V_L_Temp',
                'A2+2_5V_H_Temp', 'A2+2_5V_L_Temp',
                'A3+2_5V_H_Temp', 'A3+2_5V_L_Temp',
                'D0+2_5V_Temp', 'D1+2_5V_Temp',
                'A0+1_8V_Temp', 'A1+1_8V_Temp',
                'A2+1_8V_Temp'
            ]
            for i in range(13):
                print('%s %f deg C' % (LdoNames[i], sensorRegRaw[6 + i] * 1.65 / 65535 * 100))
            print('PcbAnaTemp0 %f deg C' % (sensorRegRaw[19] * 1.65 /
                  65535 * (130.0 / (0.882 - 1.951)) + (0.882 / 0.0082 + 100)))
            print('PcbAnaTemp1 %f deg C' % (sensorRegRaw[20] * 1.65 /
                  65535 * (130.0 / (0.882 - 1.951)) + (0.882 / 0.0082 + 100)))
            print('PcbAnaTemp2 %f deg C' % (sensorRegRaw[21] * 1.65 /
                  65535 * (130.0 / (0.882 - 1.951)) + (0.882 / 0.0082 + 100)))
            print('TrOptTemp %f deg C' % (sensorRegRaw[22] * 1.0 / 256))
            print('TrOptVcc %f V' % (sensorRegRaw[23] * 0.0001))
            print('TrOptTxPwr %f uW' % (sensorRegRaw[24] * 0.1))
            print('TrOptRxPwr %f uW' % (sensorRegRaw[25] * 0.1))

        # removes header before displying the image
        for j in range(0, 32):
            rawData.pop(0)

        imgTopBot = bytearray()
        imgTopTop = bytearray()
        imgBotBot = bytearray()
        imgBotTop = bytearray()
        for j in range(0, self.sensorHeight):
            if (j % 4 == 3):
                imgTopTop.extend(rawData[((self.sensorHeight - j) * self._superRowSizeInBytes):((self.sensorHeight - j + 1) * self._superRowSizeInBytes)])
            elif (j % 4 == 2):
                imgTopBot.extend(rawData[(j * self._superRowSizeInBytes):((j + 1) * self._superRowSizeInBytes)])
            elif (j % 4 == 1):
                imgBotTop.extend(rawData[((self.sensorHeight - j) * self._superRowSizeInBytes):((self.sensorHeight - j + 1) * self._superRowSizeInBytes)])
            else:
                imgBotBot.extend(rawData[(j * self._superRowSizeInBytes):((j + 1) * self._superRowSizeInBytes)])

        imgDesc = imgBotTop
        imgDesc.extend(imgTopBot)
        imgDesc.extend(imgTopTop)
        imgDesc.extend(imgBotBot)

        # returns final image
        return imgDesc

    def _descrambleEPixQuadImage(self, rawData):
        """performs the ePix Quad image descrambling """

        imgDescBA = self._descrambleEPixQuadImageAsByteArray(rawData)

        imgDesc = np.frombuffer(imgDescBA, dtype='int16')
        if self.sensorHeight * self.sensorWidth != len(imgDesc):
            print("Got wrong pixel number %d. Expected %d." % (len(imgDesc), self.sensorHeight * self.sensorWidth))
        else:
            if (PRINT_VERBOSE):
                print("Got pixel number ", len(imgDesc))
            imgDesc = imgDesc.reshape(self.sensorHeight, self.sensorWidth)
        # returns final image
        return imgDesc

    def _descrambleTixel48x48Image(self, rawData):
        """performs the Tixel image descrambling """
        if (len(rawData) == 4):
            if (PRINT_VERBOSE):
                print('raw data 0:', rawData[0, 0:10])
            if (PRINT_VERBOSE):
                print('raw data 1:', rawData[1, 0:10])
            if (PRINT_VERBOSE):
                print('raw data 2:', rawData[2, 0:10])
            if (PRINT_VERBOSE):
                print('raw data 3:', rawData[3, 0:10])

            quadrant0 = np.frombuffer(rawData[0, 4:], dtype='uint16')
            quadrant0sq = quadrant0.reshape(48, 48)
            quadrant1 = np.frombuffer(rawData[1, 4:], dtype='uint16')
            quadrant1sq = quadrant1.reshape(48, 48)
            quadrant2 = np.frombuffer(rawData[2, 4:], dtype='uint16')
            quadrant2sq = quadrant2.reshape(48, 48)
            quadrant3 = np.frombuffer(rawData[3, 4:], dtype='uint16')
            quadrant3sq = quadrant3.reshape(48, 48)

            imgTop = np.concatenate((quadrant0sq, quadrant1sq), 1)
            imgBot = np.concatenate((quadrant2sq, quadrant3sq), 1)

            imgDesc = np.concatenate((imgTop, imgBot), 0)
        else:
            imgDesc = np.zeros((48 * 2, 48 * 2), dtype='uint16')
        # returns final image
        imgDesc = np.where((imgDesc & 0x1) == 1, imgDesc, 0)
        return imgDesc

    def _descrambleCpix2Image(self, rawData):
        """performs the Tixel image descrambling """
        if (len(rawData) == 4):
            ##if (PRINT_VERBOSE): print('raw data 0:', rawData[0,0:10])
            ##if (PRINT_VERBOSE): print('raw data 1:', rawData[1,0:10])
            ##if (PRINT_VERBOSE): print('raw data 2:', rawData[2,0:10])
            ##if (PRINT_VERBOSE): print('raw data 3:', rawData[3,0:10])

            quadrant0 = np.frombuffer(rawData[0, 4:], dtype='uint16')
            quadrant0sq = quadrant0.reshape(48, 48)
            quadrant1 = np.frombuffer(rawData[1, 4:], dtype='uint16')
            quadrant1sq = quadrant1.reshape(48, 48)
            quadrant2 = np.frombuffer(rawData[2, 4:], dtype='uint16')
            quadrant2sq = quadrant2.reshape(48, 48)
            quadrant3 = np.frombuffer(rawData[3, 4:], dtype='uint16')
            quadrant3sq = quadrant3.reshape(48, 48)

            imgTop = np.concatenate((quadrant0sq, quadrant1sq), 1)
            imgBot = np.concatenate((quadrant2sq, quadrant3sq), 1)

            imgDesc = np.concatenate((imgTop, imgBot), 0)
        else:
            imgDesc = np.zeros((48 * 2, 48 * 2), dtype='uint16')
        # returns final image

        return imgDesc

    def _descrambleEpixMshImage(self, rawData):
        """performs the EpixMsh image descrambling """

        if len(rawData) < 48 * 48 * 2 + 32:
            print("Got wrong pixel number ", len(imgDesc))

        # removes header before displying the image
        for j in range(0, 32):
            rawData.pop(0)

        imgDesc = np.frombuffer(rawData[0:48 * 48 * 2], dtype='int16')
        if (PRINT_VERBOSE):
            print("Got pixel number ", len(imgDesc))
        imgDesc = imgDesc.reshape(self.sensorHeight, self.sensorWidth)
        # returns final image
        return imgDesc

    def _descrambleEpixM32Image(self, rawData):
        """performs the EpixM32 image descrambling """
        if (len(rawData) == 2):
            #if (PRINT_VERBOSE): print('raw data 0:', rawData[0,0:10])
            #if (PRINT_VERBOSE): print('raw data 1:', rawData[1,0:10])

            quadrant0 = np.frombuffer(rawData[0, 4:], dtype='uint16')
            quadrant0sq = quadrant0.reshape(64, 32)
            quadrant1 = np.frombuffer(rawData[1, 4:], dtype='uint16')
            quadrant1sq = quadrant1.reshape(64, 32)

            imgTop = quadrant0sq
            imgBot = quadrant1sq

            imgDesc = np.concatenate((imgTop, imgBot), 1)
        else:
            imgDesc = np.zeros((64, 64), dtype='uint16')
        # returns final image
        return imgDesc

    def _descrambleEpixHRADC32x32Image(self, rawData):
        """performs the EpixM32 image descrambling """
        if (len(rawData) == 2):
            if (PRINT_VERBOSE):
                print('_descrambleEpixHRADC32x32Image: raw data 0:', rawData[0, 0:10])
            if (PRINT_VERBOSE):
                print('_descrambleEpixHRADC32x32Image: raw data 1:', rawData[1, 0:10])

            quadrant0 = np.frombuffer(rawData[0, 4:], dtype='uint16')
            quadrant0sq = quadrant0.reshape(32, 32)
            quadrant1 = np.frombuffer(rawData[1, 4:], dtype='uint16')
            quadrant1sq = quadrant1.reshape(32, 32)

            imgTop = quadrant0sq
            imgBot = quadrant1sq

            imgDesc = np.concatenate((imgTop, imgBot), 1)
        else:
            imgDesc = np.zeros((32, 64), dtype='uint16')
            print("_descrambleEpixHRADC32x32Image: Wrong number of buffers. Returning zeros")
        # returns final image
        return imgDesc

    # helper functions
    def _calcImgWidth(self):
        return self._NumAsicsPerSide * self._NumAdcChPerAsic * self._NumColPerAdcCh
