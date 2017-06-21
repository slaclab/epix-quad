import os, sys, time
import numpy as np
import ePixViewer.Cameras as cameras
import ePixViewer.imgProcessing as imgPr
# 
import matplotlib   
matplotlib.use('QT4Agg')
import matplotlib.pyplot as plt
#matplotlib.pyplot.ion()


##################################################
# Global variables
##################################################
cameraType = 'ePix10ka'


##################################################
# Dark images
##################################################
f = open('/u1/ddoering/10kaImages/darkImage_10ka_120Hz_afterClearMatrix.dat', mode = 'rb')

frame_size = [0]
numberOfFrames = 0
while (len(frame_size)==1):
    try:
        # reads the number of bytes to read 
        frame_size = np.fromfile(f, dtype='uint32', count=1)
        #print ('size',  frame_size)
        newPayload = np.fromfile(f, dtype='uint32', count=int(frame_size[0]/4)) #(frame size splited by four to read 32 bit 
        if (numberOfFrames == 0):
            allFrames = [newPayload.copy()]
        else:
            newFrame  = [newPayload.copy()]
            allFrames = np.append(allFrames, newFrame, axis = 0)
        numberOfFrames = numberOfFrames + 1 
        #print (newPayload[0:7])
        previousSize = frame_size
    except Exception: 
        #e = sys.exc_info()[0]
        #print ("Message\n", e)
        #print ('size', frame_size, 'previous size', previousSize)
        print("numberOfFrames read: " ,numberOfFrames)


##################################################
# image descrambling
##################################################
currentCam = cameras.Camera(cameraType = cameraType)
numberOfFrames = allFrames.shape[0]
print("numberOfFrames in the 3D array: " ,numberOfFrames)


for i in range(0, numberOfFrames):
    #get an specific frame
    [frameComplete, readyForDisplay, rawImgFrame] = currentCam.buildImageFrame(currentRawData = [], newRawData = allFrames[i,:])

    #get descrambled image com camera
    if (i==0):
        imgDesc = np.array([currentCam.descrambleImage(bytearray(rawImgFrame.tobytes()))])
    else:
        imgDesc = np.concatenate((imgDesc, np.array([currentCam.descrambleImage(bytearray(rawImgFrame.tobytes()))])),0)

##################################################
#from here on we have a set of images to work with
##################################################
avgDark = np.average(imgDesc,0)
stdDark = np.std(imgDesc,0)

plt.imshow(avgDark, interpolation='nearest')
plt.gray()
plt.colorbar()
plt.title('Average dark image')

plt.show()

plt.imshow(stdDark, interpolation='nearest')
plt.gray()
plt.colorbar()
plt.title('Standard deviation of the dark image')
plt.show()

plt.imshow(imgDesc[5,:,:]-avgDark, interpolation='nearest',vmin=-100, vmax=100)
plt.gray()
plt.colorbar()
plt.title('Example of dark image subtracted image')
plt.show()

    



#imgTool = imgPr.ImageProcessing(None)

#imgTool.imgWidth = currentCam.sensorWidth
#imgTool.imgHeight = currentCam.sensorHeight




