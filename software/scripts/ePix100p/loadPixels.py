import pythonDaq
import time
import struct
import os
import sys
import getopt
import numpy

def readFile(inputfile,defaultValue,setValue):
   mask = defaultValue * numpy.ones( (96,96) )
   print 'Loading mask from file: ', inputfile
   mask_in = open(inputfile,"r")
   lines = mask_in.readlines()
   if lines.__len__() != 96:
      print 'Input file only had ', lines.__len__() ,' lines'
      sys.exit(2)
   else:
      for row in range(0,lines.__len__()):
         this_line = lines[row]
         if this_line.__len__() != 96:
            print 'Line ',row,' only had ',this_line.__len__(),' lines'
            sys.exit(2)
         else:
            this_line.rstrip()
            this_data = this_line.split();
            for col in range(0,this_data.__len__()):
               if this_data[col] != '0':
                  mask[row][col] = setValue;
   return mask

def main(argv):
   maskfile         = ''
   inputfile        = ''
   defaultValue     = 0
   defaultMapValue  = 1
   defaultMaskValue = 2
   try:
      opts, args = getopt.getopt(argv,"himd:")
   except getopt.GetoptError:
      print 'loadPixels -i <input tab separated pixel map>'
      sys.exit(2)
   for opt, arg in opts:
      if opt == '-h':
         print 'loadPixels -i <input tab separated pixel map>'
         sys.exit()
      elif opt in ("-k", "--maskfile"):
         maskfile = arg
      elif opt in ("-i", "--inputfile"):
         inputfile = arg
      elif opt in ("-d", "--defaultValue"):
         defaultValue = int(arg)
      elif opt in ("-t", "--inputValue"):
         defaultMapValue = int(arg)
      elif opt in ("-m", "--maskValue"):
         defaultMaskValue = int(arg)

   map = defaultValue * numpy.ones( (96,96) );
   if (inputfile != ''):
      map = readFile(inputfile,defaultValue,defaultMapValue);

   mask = defaultValue * numpy.ones( (96,96) );
   if (maskfile != ''):
      mask = readFile(inputfile,defaultValue,defaultMaskvalue);

   defaultMaskString = "False"
   defaultTestString = "False"
   if (defaultValue & 0x1 == 1):
      defaultMaskString 

   pythonDaq.daqOpen("epix",1)
   print 'Resetting all pixels to M = 0, T = 0: '
   pythonDaq.daqSetConfig("digFpga:epix100pAsic:PixelTest","False")
   pythonDaq.daqSetConfig("digFpga:epix100pAsic:PixelMask","False")
   pythonDaq.daqSendCommand("WriteMatrixData","0")

   pythonDaq.daqSendCommand("PrepForRead","");
   for row in range(0,lines.__len__()):
      this_line = lines[row]
      this_line.rstrip()
      this_data = this_line.split();
      pythonDaq.daqSetConfig("digFpga:epix100pAsic:RowCounter",str(row))
      pythonDaq.daqSendCommand("WriteRowCounter","");
      for col in range(0,this_data.__len__()):
         if this_data[col] == '1':
            pythonDaq.daqSetConfig("digFpga:epix100pAsic:ColCounter",str(col))
            pythonDaq.daqSetConfig("digFpga:epix100pAsic:PixelTest","True")
            pythonDaq.daqSetConfig("digFpga:epix100pAsic:PixelMask","False")
            pythonDaq.daqSendCommand("WritePixelData","");

   print 'Sending prepare for readout'
   pythonDaq.daqSendCommand("PrepForRead","");
            

if __name__ == "__main__":
   main(sys.argv[1:])
          


