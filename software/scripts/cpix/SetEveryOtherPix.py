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
   asicStr = "digFpga(0):CpixPAsic(0)";
   print 'Resetting all pixels.'
   pythonDaq.daqWriteRegister(asicStr,"PrepareMultiConfig",0x0)
   pythonDaq.daqWriteRegister(asicStr,"WriteMatrixData",0x1C)
   pythonDaq.daqWriteRegister(asicStr,"CmdPrepForRead",0x0)

   print 'Loading pixel map from file: "', inputfile
   logo_in = open(inputfile,"r")
   lines = logo_in.readlines()
   if lines.__len__() != 48:
      print 'Input file only had ', lines.__len__() ,' lines'
      sys.exit(2)
   else:      
      pythonDaq.daqSendCommand("PrepForRead","");
      for row in range(0,lines.__len__()):
         this_line = lines[row]
         this_line.rstrip()
         this_data = this_line.split();
         #pythonDaq.daqSetConfig("digFpga:CpixPAsic:RowCounter",str(row))
         pythonDaq.daqWriteRegister(asicStr,"RowCounter", row)
         #pythonDaq.daqSendCommand("WriteRowCounter","");
         #print "Row %d" %row
         for col in range(0,this_data.__len__()):
            if this_data[col] == '1':
               pythonDaq.daqWriteRegister(asicStr,"ColCounter", col)
               pythonDaq.daqWriteRegister(asicStr,"WritePixelData",0x1D)
               #pythonDaq.daqSetConfig("digFpga:CpixPAsic:ColCounter",str(col))
               #pythonDaq.daqSetConfig("digFpga:CpixPAsic:PixelTest","True")
               #pythonDaq.daqSetConfig("digFpga:CpixPAsic:PixelMask","False")
               #pythonDaq.daqSendCommand("WritePixelData","");
               #print "Col %d" %col

   print 'Sending prepare for readout'
   #pythonDaq.daqSendCommand("PrepForRead","");
   pythonDaq.daqWriteRegister(asicStr,"CmdPrepForRead",0x0)
            

if __name__ == "__main__":
   main(sys.argv[1:])
          


