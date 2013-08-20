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
   pythonDaq.daqSetConfig("digFpga:epixAsic:PixelTest","False")
   pythonDaq.daqSetConfig("digFpga:epixAsic:PixelMask","False")
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
         pythonDaq.daqSetConfig("digFpga:epixAsic:RowCounter",str(row))
         pythonDaq.daqSendCommand("WriteRowCounter","");
         for col in range(0,this_data.__len__()):
            if this_data[col] == '2':
               pythonDaq.daqSetConfig("digFpga:epixAsic:ColCounter",str(col))
               pythonDaq.daqSetConfig("digFpga:epixAsic:PixelTest","False")
               pythonDaq.daqSetConfig("digFpga:epixAsic:PixelMask","True")
               pythonDaq.daqSendCommand("WritePixelData","");

#   pythonDaq.daqSetConfig("digFpga:epixAsic:RowCounter","43")
#   pythonDaq.daqSendCommand("WriteRowCounter","");
#   pythonDaq.daqSetConfig("digFpga:epixAsic:ColCounter","47")
#   pythonDaq.daqSetConfig("digFpga:epixAsic:PixelTest","False")
#   pythonDaq.daqSetConfig("digFpga:epixAsic:PixelMask","True")
#   pythonDaq.daqSendCommand("WritePixelData","");

#   pythonDaq.daqSetConfig("digFpga:epixAsic:RowCounter","7")
#   pythonDaq.daqSendCommand("WriteRowCounter","");
#   pythonDaq.daqSetConfig("digFpga:epixAsic:ColCounter","12")
#   pythonDaq.daqSetConfig("digFpga:epixAsic:PixelTest","True")
#   pythonDaq.daqSetConfig("digFpga:epixAsic:PixelMask","False")
#   pythonDaq.daqSendCommand("WritePixelData","");

#   pythonDaq.daqSetConfig("digFpga:epixAsic:RowCounter","11")
#   pythonDaq.daqSendCommand("WriteRowCounter","");
#   pythonDaq.daqSetConfig("digFpga:epixAsic:ColCounter","26")
#   pythonDaq.daqSetConfig("digFpga:epixAsic:PixelTest","True")
#   pythonDaq.daqSetConfig("digFpga:epixAsic:PixelMask","False")
#   pythonDaq.daqSendCommand("WritePixelData","");

   print 'Sending prepare for readout'
   pythonDaq.daqSendCommand("PrepForRead","");
            

if __name__ == "__main__":
   main(sys.argv[1:])
          


