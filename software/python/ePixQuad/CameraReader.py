#!/usr/bin/env python
import rogue.utilities
import rogue.utilities.fileio
import rogue.interfaces.stream
import time

import ePixViewer.imgProcessing as imgPr
import ePixViewer.Cameras as cameras

PRINT_VERBOSE = False

class CameraReader(rogue.interfaces.stream.Slave):
    """retrieves data from a file using rogue utilities services"""

    def __init__(self, cameraType = 'ePix100a', refreshRate = 1):
        rogue.interfaces.stream.Slave.__init__(self)
        super(CameraReader, self).__init__()

        self.cameraType = cameraType
        self.currentCam = cameras.Camera(cameraType=cameraType)
        self.imgTool = imgPr.ImageProcessing(self)

        self.rawImgFrame = []

        self.img = None
        self.imgts = None
        self.refreshRate = refreshRate

        self.darkRequest = False

        self.VIEW_DATA_CHANNEL_ID = 0x1
        self.lastTime = time.clock_gettime(0)

    def _acceptFrame(self, frame):
        # reads entire frame
        frameData = bytearray(frame.getPayload())
        frame.read(frameData, 0)
        
        VcNum = frameData[0] & 0xF

        if (time.clock_gettime(0) - self.lastTime) > self.refreshRate or self.cameraType == 'ePixM32Array':
            self.lastTime = time.clock_gettime(0)
            
            if (VcNum == 0):
                self._processFrame(frameData)

    def _processFrame(self, frameData):
        newRawData = frameData.copy()
        
        [frameComplete, readyForDisplay, self.rawImgFrame] = self.currentCam.buildImageFrame(
            currentRawData=self.rawImgFrame, newRawData=newRawData)

        if (readyForDisplay):
            #print('Ready for display')
            self.imgAnalyzer(imageData=self.rawImgFrame)

        if (frameComplete == 0 and readyForDisplay == 1):
            # in this condition we have data about two different images
            # since a new image has been sent and the old one is incomplete
            # the next line preserves the new data to be used with the next frame
            print("Incomplete frame")
            self.rawImgFrame = newRawData

        if (frameComplete == 1):
            # frees the memory since it has been used alreay enabling a new frame logic to start fresh
            self.rawImgFrame = []
            
    def imgAnalyzer(self, imageData):
        # init variables
        self.displayBusy = True
        self.imgTool.imgWidth = self.currentCam.sensorWidth
        self.imgTool.imgHeight = self.currentCam.sensorHeight

        # get descrambled image com camera
        imgDesc = self.currentCam.descrambleImage(imageData)
        
        if (self.darkRequest):
            self.imgTool.numDarkImages = 1
            self.imgTool.setDarkImg(imgDesc)
            self.darkRequest = False

        if (self.imgTool.imgDark_isSet):
            self.img = self.imgTool.getDarkSubtractedImg(imgDesc)
        else:
            self.img = imgDesc
            
        self.imgts = time.time()
