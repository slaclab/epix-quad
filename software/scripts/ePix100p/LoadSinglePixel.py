import pythonDaq
import time
import struct
import os
import sys
import getopt

def main(argv):
   row = 0;
   col = 0;
   try:
      opts, args = getopt.getopt(argv,"hr:c:")
   except getopt.GetoptError:
      print 'LoadSinglePixel -r <row> -c <col>'
      sys.exit(2)
   for opt, arg in opts:
      if opt == '-h':
         print 'LoadPixelMap -r <row> -c <col>'
         sys.exit()
      elif opt in ("-r", "--row"):
         row = arg
      elif opt in ("-c", "--col"):
         col = arg

   pythonDaq.daqOpen("epix",1)
   print 'Resetting all pixels to M = 0, T = 0: '
   pythonDaq.daqSetConfig("digFpga:epix100pAsic:PixelTest","False")
   pythonDaq.daqSetConfig("digFpga:epix100pAsic:PixelMask","False")
   pythonDaq.daqSendCommand("WriteMatrixData","0")

   print 'Setting pixel ('+str(row)+','+str(col)+') to M = 0, T = 1: '
   pythonDaq.daqSendCommand("PrepForRead","");
   pythonDaq.daqSetConfig("digFpga:epix100pAsic:RowCounter",str(row))
   pythonDaq.daqSendCommand("WriteRowCounter","");
   pythonDaq.daqSetConfig("digFpga:epix100pAsic:ColCounter",str(col))
   pythonDaq.daqSetConfig("digFpga:epix100pAsic:PixelTest","True")
   pythonDaq.daqSetConfig("digFpga:epix100pAsic:PixelMask","False")
   pythonDaq.daqSendCommand("WritePixelData","");

   print 'Sending prepare for readout'
   pythonDaq.daqSendCommand("PrepForRead","");
            

if __name__ == "__main__":
   main(sys.argv[1:])
          


