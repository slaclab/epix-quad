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
   print 'Resetting all pixels to M = 0, T = 0: '
   pythonDaq.daqSetConfig("digFpga:epix100pAsic:PixelTest","False")
   pythonDaq.daqSetConfig("digFpga:epix100pAsic:PixelMask","False")
   pythonDaq.daqSendCommand("WriteMatrixData","0")

   print 'Loading pixel map from file: "', inputfile
   logo_in = open(inputfile,"r")
   lines = logo_in.readlines()
   if lines.__len__() != 96:
      print 'Input file only had ', lines.__len__() ,' lines'
      sys.exit(2)
   else:      
      pythonDaq.daqSendCommand("PrepForRead","");
      for row in range(0,lines.__len__()):
         this_line = lines[row]
         this_line.rstrip()
         this_data = this_line.split();
         pythonDaq.daqSetConfig("digFpga:epix100pAsic:RowCounter",str(row))
         pythonDaq.daqSendCommand("WriteRowCounter","");
         for col in range(0,this_data.__len__()):
            test = "True"
            mask = "False"
            if (row==0):
               test = "False"
               mask = "True"
               pythonDaq.daqSetConfig("digFpga:epix100pAsic:ColCounter",str(col))
               pythonDaq.daqSetConfig("digFpga:epix100pAsic:PixelTest",test)
               pythonDaq.daqSetConfig("digFpga:epix100pAsic:PixelMask",mask)
               pythonDaq.daqSendCommand("WritePixelData","");
            elif this_data[col] == '1':
               pythonDaq.daqSetConfig("digFpga:epix100pAsic:ColCounter",str(col))
               pythonDaq.daqSetConfig("digFpga:epix100pAsic:PixelTest",test)
               pythonDaq.daqSetConfig("digFpga:epix100pAsic:PixelMask",mask)
               pythonDaq.daqSendCommand("WritePixelData","");

   print 'Sending prepare for readout'
   pythonDaq.daqSendCommand("PrepForRead","");
            

if __name__ == "__main__":
   main(sys.argv[1:])
          


