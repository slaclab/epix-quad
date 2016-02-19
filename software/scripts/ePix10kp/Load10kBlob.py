import pythonDaq
import time
import struct
import os
import sys
import getopt

def WriteMatrix(pythonDaq, test, mask, G, GA):
   pythonDaq.daqSetConfig("digFpga:epix10kpAsic:PixelTest",test)
   pythonDaq.daqSetConfig("digFpga:epix10kpAsic:PixelMask",mask)
   pythonDaq.daqSetConfig("digFpga:epix10kpAsic:PixelG",G)
   pythonDaq.daqSetConfig("digFpga:epix10kpAsic:PixelGA",GA)
   pythonDaq.daqSendCommand("WriteMatrixData","")

def WritePixel(pythonDaq, row, col, test, mask, G, GA):
   pythonDaq.daqSetConfig("digFpga:epix10kpAsic:RowCounter",str(row))
   pythonDaq.daqSetConfig("digFpga:epix10kpAsic:ColCounter",str(col))
   pythonDaq.daqSetConfig("digFpga:epix10kpAsic:PixelTest",test)
   pythonDaq.daqSetConfig("digFpga:epix10kpAsic:PixelMask",mask)
   pythonDaq.daqSetConfig("digFpga:epix10kpAsic:PixelG",G)
   pythonDaq.daqSetConfig("digFpga:epix10kpAsic:PixelGA",GA)
   pythonDaq.daqSendCommand("WritePixelData","")
   pythonDaq.daqSendCommand("PrepForRead","")

def WriteRow(pythonDaq, row, test, mask, G, GA):
   pythonDaq.daqSetConfig("digFpga:epix10kpAsic:RowCounter",str(row))
   pythonDaq.daqSetConfig("digFpga:epix10kpAsic:PixelTest",test)
   pythonDaq.daqSetConfig("digFpga:epix10kpAsic:PixelMask",mask)
   pythonDaq.daqSetConfig("digFpga:epix10kpAsic:PixelG",G)
   pythonDaq.daqSetConfig("digFpga:epix10kpAsic:PixelGA",GA)
   pythonDaq.daqSendCommand("WriteRowData","")
   pythonDaq.daqSendCommand("PrepForRead","")

def WriteCol(pythonDaq, col, test, mask, G, GA):
   pythonDaq.daqSetConfig("digFpga:epix10kpAsic:ColCounter",str(col))
   pythonDaq.daqSetConfig("digFpga:epix10kpAsic:PixelTest",test)
   pythonDaq.daqSetConfig("digFpga:epix10kpAsic:PixelMask",mask)
   pythonDaq.daqSetConfig("digFpga:epix10kpAsic:PixelG",G)
   pythonDaq.daqSetConfig("digFpga:epix10kpAsic:PixelGA",GA)
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
   pixelG  = "False"
   pixelGA = "False"
   pixelTest = "False"
   pixelMask = "False"
   #Initialize full matrix
   WriteMatrix(pythonDaq,pixelTest,pixelMask,pixelG,pixelGA)
   #Mask first row
   WriteRow(pythonDaq,0,pixelTest,"True",pixelG,pixelGA)
   #Prepare for readout, for good measure
   pythonDaq.daqSendCommand("PrepForRead","");

   print "Writing box starting at ("+str(startCol)+","+str(startRow)+"), length "+str(length)+"."

   pixelG  = "False"
   pixelGA = "False"

   #Program the rest of the matrix
   for row in range(0,48):
      if (row >= int(startRow) and row < int(startRow) + int(length)):
         for col in range (0,48):
            if (col >= int(startCol) and col < int(startCol) + int(length)):
               WritePixel(pythonDaq,row,col,"True","False",pixelG,pixelGA)

   print 'Sending prepare for readout'
   pythonDaq.daqSendCommand("PrepForRead","");
            

if __name__ == "__main__":
   main(sys.argv[1:])
          


