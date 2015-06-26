import pythonDaq
import time
import struct
import os
import sys
import getopt
import time

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

   pythonDaq.daqSetConfig("digFpga:epixSAsic:Test","True")
   pythonDaq.daqSetConfig("digFpga:epixSAsic:ATest","False")
   pythonDaq.daqSetConfig("digFpga:epixSAsic:PulserSync","True")
   pythonDaq.daqSetConfig("digFpga:epixSAsic:HrTest","False")
   pythonDaq.daqSetConfig("digFpga:SyncMode","Adjustable")
   pythonDaq.daqSetConfig("digFpga:syncWidth",str(65535))

   defaultTest   = "False"
   defaultMask   = "False"
   defaultFilter = 0
   WriteMatrix(pythonDaq, defaultTest, defaultMask, defaultFilter)

   pixelTest   = "True"
   pixelMask   = "False"
   #pixelFilter = 0
   col = 5
   row = 5

   for pixelFilter in [0,3]:
      WritePixel(pythonDaq,row,col,pixelTest,pixelMask,pixelFilter)

      for pulser in [0,160,320,480]:
#      for pulser in [480]:
         pythonDaq.daqSetConfig("digFpga:epixSAsic:Pulser",str(pulser))
         resMode = "lr"
         nFiles = 1
         for files in range(0,nFiles):
            this_filename = outputfile+"_"+str(resMode)+"_pixfilter"+str(pixelFilter)+"_pulser"+str(pulser)+"_file"+str(files)+"_nwf.bin"
            print(this_filename)
            pythonDaq.daqOpenData(this_filename)
#            for delay in range(0,12000,12):
            for delay in range(0,7200,3):
               pythonDaq.daqSetConfig("digFpga:syncDelay",str(delay))
               pythonDaq.daqSendCommand("SoftwareTrigger","")
            pythonDaq.daqCloseData(this_filename)
   


if __name__ == "__main__":
   main(sys.argv[1:])
          


