import pythonDaq
import time
import struct
import os
import sys
import getopt
import time

def WriteMatrix(pythonDaq, test, mask):
   pythonDaq.daqSetConfig("digFpga:epix100aAsic:PixelTest",test)
   pythonDaq.daqSetConfig("digFpga:epix100aAsic:PixelMask",mask)
   pythonDaq.daqSendCommand("WriteMatrixData","")

def WritePixel(pythonDaq, row, col, test, mask):
   pythonDaq.daqSetConfig("digFpga:epix100aAsic:RowCounter",str(row))
   pythonDaq.daqSetConfig("digFpga:epix100aAsic:ColCounter",str(col))
   pythonDaq.daqSetConfig("digFpga:epix100aAsic:PixelTest",test)
   pythonDaq.daqSetConfig("digFpga:epix100aAsic:PixelMask",mask)
   pythonDaq.daqSendCommand("WritePixelData","")
   pythonDaq.daqSendCommand("PrepForRead","")

def WriteRow(pythonDaq, row, test, mask):
   pythonDaq.daqSetConfig("digFpga:epix100aAsic:RowCounter",str(row))
   pythonDaq.daqSetConfig("digFpga:epix100aAsic:PixelTest",test)
   pythonDaq.daqSetConfig("digFpga:epix100aAsic:PixelMask",mask)
   pythonDaq.daqSendCommand("WriteRowData","")
   pythonDaq.daqSendCommand("PrepForRead","")

def WriteCol(pythonDaq, col, test, mask):
   pythonDaq.daqSetConfig("digFpga:epix100aAsic:ColCounter",str(col))
   pythonDaq.daqSetConfig("digFpga:epix100aAsic:PixelTest",test)
   pythonDaq.daqSetConfig("digFpga:epix100aAsic:PixelMask",mask)
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

   pythonDaq.daqSetConfig("digFpga:epix100aAsic:Test","True")
   pythonDaq.daqSetConfig("digFpga:epix100aAsic:ATest","False")
   pythonDaq.daqSetConfig("digFpga:epix100aAsic:PulserSync","True")
   pythonDaq.daqSetConfig("digFpga:epix100aAsic:ro_rst_exten","False")

   pythonDaq.daqSetConfig("digFpga:SyncMode","Adjustable")
   pythonDaq.daqSetConfig("digFpga:syncWidth",str(125000))

   for pulser in [0,100,500,1000]:
      pythonDaq.daqSetConfig("digFpga:epix100aAsic:HrTest","True")
      pythonDaq.daqSetConfig("digFpga:epix100aAsic:Pulser",str(pulser))
      nFiles = 1
      for files in range(0,nFiles):
         this_filename = outputfile+"_pulser"+str(pulser)+"_file"+str(files)+"_nwf.bin"
         print(this_filename)
         pythonDaq.daqOpenData(this_filename)
         for delay in range(0,10000,12):
            pythonDaq.daqSetConfig("digFpga:syncDelay",str(delay))
            time.sleep(0.02);
            pythonDaq.daqSendCommand("SoftwareTrigger","")
         pythonDaq.daqCloseData(this_filename)

if __name__ == "__main__":
   main(sys.argv[1:])
          


