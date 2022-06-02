# -----------------------------------------------------------------------------
# Title      : read images from file script
# -----------------------------------------------------------------------------
# File       : read_image_from_file.py
# Created    : 2017-06-19
# Last update: 2017-06-21
# -----------------------------------------------------------------------------
# Description:
# Simple image viewer that enble a local feedback from data collected using
# ePix cameras. The initial intent is to use it with stand alone systems
#
# -----------------------------------------------------------------------------
# This file is part of the ePix rogue. It is subject to
# the license terms in the LICENSE.txt file found in the top-level directory
# of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of the ePix rogue, including this file, may be
# copied, modified, propagated, or distributed except according to the terms
# contained in the LICENSE.txt file.
# -----------------------------------------------------------------------------
import setupLibPaths
import h5py
import matplotlib.pyplot as plt
import os
import sys
import time
import numpy as np
import ePixViewer.Cameras as cameras
import ePixViewer.imgProcessing as imgPr
#
import matplotlib
from matplotlib.backends.backend_qt5agg import FigureCanvasQTAgg as FigureCanvas
from matplotlib.backends.backend_qt5agg import NavigationToolbar2QT as NavigationToolbar
from matplotlib.figure import Figure

import pdb

try:
    from PyQt5.QtWidgets import *
    from PyQt5.QtCore import *
    from PyQt5.QtGui import *
except ImportError:
    from PyQt4.QtCore import *
    from PyQt4.QtGui import *


#matplotlib.pyplot.ion()
NUMBER_OF_PACKETS_PER_FRAME = 2
#MAX_NUMBER_OF_FRAMES_PER_BATCH  = 1500*NUMBER_OF_PACKETS_PER_FRAME
MAX_NUMBER_OF_FRAMES_PER_BATCH  = 200

PAYLOAD_SERIAL_FRAME = 4112 #2064
PAYLOAD_TS           = 7360

##################################################
# Global variables
##################################################
cameraType            = 'ePix10ka'
bitMask               = 0xffff
PLOT_IMAGE            = True
PLOT_ADC9_VS_N        = False
PLOT_IMAGE_DARKSUB    = False
PLOT_IMAGE_DARK       = False
PLOT_IMAGE_HEATMAP    = False
PLOT_SET_HISTOGRAM    = False
PLOT_ADC_VS_N         = False
SAVEHDF5              = True


##################################################
# Dark images
##################################################
def getData(localFile):

    file_header = [0]
    numberOfFrames = 0
    previousSize = 0
    while ((len(file_header)>0) and ((numberOfFrames<MAX_NUMBER_OF_FRAMES_PER_BATCH) or (MAX_NUMBER_OF_FRAMES_PER_BATCH==-1))):
        try:
            # reads file header [the number of bytes to read, EVIO]
            file_header = np.fromfile(localFile, dtype='uint32', count=2)
            payloadSize = int(file_header[0]/2)-2 #-1 is need because size info includes the second word from the header
            newPayload = np.fromfile(f, dtype='uint16', count=payloadSize) #(frame size splited by four to read 32 bit 
            #save only serial data frames
            if (numberOfFrames == 0):
                allFrames = [newPayload.copy()]
            else:
                newFrame  = [newPayload.copy()]
                allFrames = np.append(allFrames, newFrame, axis = 0)
            numberOfFrames = numberOfFrames + 1 
            #print ("Payload" , numberOfFrames, ":",  (newPayload[0:5]))
            previousSize = file_header
       
            if (numberOfFrames%100==0):
                print("Read %d frames" % numberOfFrames)

        except Exception: 
            e = sys.exc_info()[0]
            #print ("Message\n", e)
            print ('size', file_header, 'previous size', previousSize)
            print("numberOfFrames read: " ,numberOfFrames)

    return allFrames

def getDescImaData(localAllFrames):
##################################################
# image descrambling
##################################################
    numberOfFrames = localAllFrames.shape[0]
    currentCam = cameras.Camera(cameraType = cameraType)
    currentCam.bitMask = bitMask
#numberOfFrames = allFrames.shape[0]
    print("numberOfFrames in the 3D array: " ,numberOfFrames)
    print("Starting descrambling images")
    currentRawData = []
    imgDesc = []
    if(numberOfFrames==1):
        [frameComplete, readyForDisplay, rawImgFrame] = currentCam.buildImageFrame(currentRawData = [], newRawData = allFrames[0])
        imgDesc = np.array([currentCam.descrambleImage(bytearray(rawImgFrame.tobytes()))])
    else:
        for i in range(0, numberOfFrames):
        #get an specific frame
            [frameComplete, readyForDisplay, rawImgFrame] = currentCam.buildImageFrame(currentRawData, newRawData = localAllFrames[i,:])
            currentRawData = rawImgFrame

        #get descrambled image from camera
            if (len(imgDesc)==0 and (readyForDisplay)):
                imgDesc = np.array([currentCam.descrambleImage(bytearray(rawImgFrame.tobytes()))])
                currentRawData = []
            else:
                if readyForDisplay:
                    currentRawData = []
                    newImage = np.array([currentCam.descrambleImage(bytearray(rawImgFrame.tobytes()))])
                #newImage = currentCam.descrambleImage(rawImgFrame)
                #newImage = newImage.astype(np.float, copy=False)
                #if (np.sum(np.sum(newImage))==0):
                #    newImage[np.where(newImage==0)]=np.nan
                    imgDesc = np.concatenate((imgDesc, np.array([newImage[0]])),0)

    return imgDesc

##################################################
# Dark images
##################################################
if (len(sys.argv[1])>0):
    filename = sys.argv[1]
else:
    filename = ''

f = open(filename, mode = 'rb')
imgDesc = []
for i in range(200):
    print("Starting to get data set %d" % (i))
    allFrames = getData(f)
    imgDesc2 = getDescImaData(allFrames)
    if i == 0:
        headers = allFrames[:,0:6]
        imgDesc = imgDesc2
    else:
        headers = np.concatenate((headers, allFrames[:,0:6]),0)
        imgDesc = np.concatenate((imgDesc, imgDesc2),0)
    if allFrames.shape[0] != MAX_NUMBER_OF_FRAMES_PER_BATCH:
        break


numberOfFrames = allFrames.shape[0]



if(SAVEHDF5):
    print("Saving Hdf5")
    h5_filename = os.path.splitext(filename)[0]+".hdf5"
    f = h5py.File(h5_filename, "w")
    for i in range(0,6):
        f['header_%d'%i] = headers[:,i]
    f['adcData'] = imgDesc.astype('uint16')
    f.close()

    np.savetxt(os.path.splitext(filename)[0] + "_traces" + ".csv", imgDesc[0,:,:], fmt='%d', delimiter=',', newline='\n')

##################################################
#from here on we have a set of images to work with
##################################################
# if PLOT_ADC9_VS_N :
#     # All averages
#     plt.plot(imgDesc[i,9,:])
#     plt.title('ADC value')
#     plt.show()

#     # All averages and stds
#     plt.figure(1)
#     plt.subplot(211)
#     plt.title('Average ADC value')
#     plt.plot(np.transpose(imgDesc[i,0:31,:]))

#     plt.subplot(212)
#     plt.plot(np.transpose(imgDesc[i,32:63,:]))
#     plt.title('Standard deviation of the ADC value')
#     plt.show()



 #show first image
if PLOT_IMAGE :
     for i in range(5, 6):
         plt.imshow((imgDesc[i,:,:]), vmin=6000, vmax=16000,  interpolation='nearest')
         plt.gray()
         plt.colorbar()
         plt.title('image %d.' % (i))
         plt.show()
