import pythonDaq
import time
import struct
import os
import sys
import getopt

def WriteMatrix(pythonDaq, test, mask, filter):
   pythonDaq.daqSetConfig("digFpga:epixSAsic:PixelTest",test)
   pythonDaq.daqSetConfig("digFpga:epixSAsic:PixelMask",mask)
   pythonDaq.daqSetConfig("digFpga:epixSAsic:PixelFilter",str(filter))
   pythonDaq.daqSendCommand("WriteMatrixData","")

def WritePixel(pythonDaq, row, col, test, mask, filter):
   pythonDaq.daqSetConfig("digFpga:epixSAsic:RowCounter",str(row))
   pythonDaq.daqSetConfig("digFpga:epixSAsic:ColCounter",str(col))
   pythonDaq.daqSetConfig("digFpga:epixSAsic:PixelTest",test)
   pythonDaq.daqSetConfig("digFpga:epixSAsic:PixelMask",mask)
   pythonDaq.daqSetConfig("digFpga:epixSAsic:PixelFilter",str(filter))
   pythonDaq.daqSendCommand("WritePixelData","")
   pythonDaq.daqSendCommand("PrepForRead","")

def WriteRow(pythonDaq, row, test, mask, filter):
   pythonDaq.daqSetConfig("digFpga:epixSAsic:RowCounter",str(row))
   pythonDaq.daqSetConfig("digFpga:epixSAsic:PixelTest",test)
   pythonDaq.daqSetConfig("digFpga:epixSAsic:PixelMask",mask)
   pythonDaq.daqSetConfig("digFpga:epixSAsic:PixelFilter",str(filter))
   pythonDaq.daqSendCommand("WriteRowData","")
   pythonDaq.daqSendCommand("PrepForRead","")

def WriteCol(pythonDaq, col, test, mask, Filter):
   pythonDaq.daqSetConfig("digFpga:epixSAsic:ColCounter",str(col))
   pythonDaq.daqSetConfig("digFpga:epixSAsic:PixelTest",test)
   pythonDaq.daqSetConfig("digFpga:epixSAsic:PixelMask",mask)
   pythonDaq.daqSetConfig("digFpga:epixSAsic:PixelFilter",str(Filter))
   pythonDaq.daqSendCommand("WriteColData","")
   pythonDaq.daqSendCommand("PrepForRead","")

def main(argv):
   inputfile = ''
   try:
      opts, args = getopt.getopt(argv,"hr:c:l:")
   except getopt.GetoptError:
      print 'LoadPixelMap -r <start row> -c <start column> -l <length of side in pixels>'
      sys.exit(2)
   for opt, arg in opts:
      if opt == '-h':
         print 'LoadPixelMap -r <start row> -c <start column> -l <length of side in pixels>'
         sys.exit()
      elif opt in ("-r", "--row"):
         startRow = arg
      elif opt in ("-c", "--col"):
         startCol = arg
      elif opt in ("-l", "--length"):
         length = arg

   pythonDaq.daqOpen("epix",1)
   print 'Resetting all pixels.'
   pixelFilter  = 0
   pixelTest = "True"
   pixelMask = "False"
   #Initialize full matrix
   WriteMatrix(pythonDaq,pixelTest,pixelMask,pixelFilter)
   #Prepare for readout, for good measure
   pythonDaq.daqSendCommand("PrepForRead","");

   print "Writing box starting at ("+str(startCol)+","+str(startRow)+"), length "+str(length)+"."

   #Program the rest of the matrix
   for row in range(0,10):
      if (row >= int(startRow) and row < int(startRow) + int(length)):
         for col in range (0,10):
            if (col >= int(startCol) and col < int(startCol) + int(length)):
               WritePixel(pythonDaq,row,col,"False","False",pixelFilter)

   print 'Sending prepare for readout'
   pythonDaq.daqSendCommand("PrepForRead","");
            

if __name__ == "__main__":
   main(sys.argv[1:])
          


