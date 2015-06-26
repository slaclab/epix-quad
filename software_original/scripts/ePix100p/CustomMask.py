import pythonDaq
import time
import struct
import os
import sys
import getopt

def main(argv):
   inputfile = ''
   try:
      opts, args = getopt.getopt(argv,"hi:")
   except getopt.GetoptError:
      print 'LoadPixelMap -i <input tab separated pixel map>'
      sys.exit(2)
   for opt, arg in opts:
      if opt == '-h':
         print 'LoadPixelMap -i <input tab separated pixel map>'
         sys.exit()
      elif opt in ("-i", "--ifile"):
         inputfile = arg

   pythonDaq.daqOpen("epix",1)
   print 'Resetting all pixels '
   pythonDaq.daqSetConfig("digFpga:epix100pAsic:PixelTest","False")
   pythonDaq.daqSetConfig("digFpga:epix100pAsic:PixelMask","False")
   pythonDaq.daqSendCommand("WriteMatrixData","0")

   print 'Loading custom pixel map: "', inputfile
   pythonDaq.daqSendCommand("PrepForRead","");
   for row in range(0,96):
      pythonDaq.daqSetConfig("digFpga:epix100pAsic:RowCounter",str(row))
      pythonDaq.daqSendCommand("WriteRowCounter","");
      for col in range(0,96):
#         if (col >= 35 and col <= 65):
#            pythonDaq.daqSetConfig("digFpga:epix100pAsic:ColCounter",str(col))
#            pythonDaq.daqSetConfig("digFpga:epix100pAsic:PixelTest","True")
#            pythonDaq.daqSetConfig("digFpga:epix100pAsic:PixelMask","False")
#            pythonDaq.daqSendCommand("WritePixelData","");
         if (col == 12 and row == 7):
            pythonDaq.daqSetConfig("digFpga:epix100pAsic:ColCounter",str(col))
            pythonDaq.daqSetConfig("digFpga:epix100pAsic:PixelTest","True")
            pythonDaq.daqSetConfig("digFpga:epix100pAsic:PixelMask","False")
            pythonDaq.daqSendCommand("WritePixelData","");
            pythonDaq.daqSendCommand("WritePixelData","");

   print 'Sending prepare for readout'
   pythonDaq.daqSendCommand("PrepForRead","");
            

if __name__ == "__main__":
   main(sys.argv[1:])
          


