import pythonDaq
import time
import struct
import os
import sys
import getopt
import time

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

def Setting(trueFalseString):
   if (trueFalseString == "True"):
      return str(1)
   else:
      return str(0)

def main(argv):
   outputfile = ''
   try:
      opts, args = getopt.getopt(argv,"ho:")
   except getopt.GetoptError:
      print '<script_name> -o <base filename for output>'
      sys.exit(2)
   for opt, arg in opts:
      if opt == '-h':
         print '<script_name> -o <base filename for output>'
         sys.exit()
      elif opt in ("-o", "--ofile"):
         outputfile = arg

   pythonDaq.daqOpen("epix",1)

   defaultTest = "False"
   defaultMask = "False"

   #Turn off pulser
   pythonDaq.daqSetConfig("digFpga:epix10kpAsic:Test","False")

   for tcSetting in ("True","False"):
      pythonDaq.daqSetConfig("digFpga:epix10kpAsic:S2dTComp",tcSetting)
      time.sleep(0.5)
      for ppSetting in (0,1):
         pythonDaq.daqSetConfig("digFpga:AsicPpmatControl",str(ppSetting))
         time.sleep(0.5)
         for gSetting in ("True","False"):
            for gaSetting in ("True","False"):
               if (gaSetting == "True"):
                  continue
               WriteMatrix(pythonDaq, defaultTest, defaultMask, gSetting, gaSetting)
               time.sleep(0.5)
               this_filename = outputfile+"_tc"+Setting(tcSetting)+"_pp"+str(ppSetting)+"_ga"+Setting(gaSetting)+"g"+Setting(gSetting)+"_dark.bin"
               print(this_filename)
               pythonDaq.daqOpenData(this_filename)
               time.sleep(10)
               pythonDaq.daqSetRunParameters("120Hz",1000);
               pythonDaq.daqSetRunState("Running");
               while(pythonDaq.daqGetStatus("Run State") == "Running"):
                  time.sleep(0.5) 
               time.sleep(15)
               pythonDaq.daqCloseData(this_filename)
               time.sleep(15)

if __name__ == "__main__":
   main(sys.argv[1:])
          


