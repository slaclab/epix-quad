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

   pythonDaq.daqSetConfig("digFpga:epix10kpAsic:Test","True")
   pythonDaq.daqSetConfig("digFpga:epix10kpAsic:ATest","False")
   pythonDaq.daqSetConfig("digFpga:epix10kpAsic:PulserSync","True")
   pythonDaq.daqSetConfig("digFpga:epix10kpAsic:RO_rst_en","False")
   pythonDaq.daqSetConfig("digFpga:epix10kpAsic:CompEnOn","True")
   pythonDaq.daqSetConfig("digFpga:epix10kpAsic:CompEn",str(0))

   pythonDaq.daqSetConfig("digFpga:asicAcqWidth",str(7000))  #56 us
   pythonDaq.daqSetConfig("digFpga:asicR0ToAsicAcq",str(3125))  #56 us

   pythonDaq.daqSetConfig("digFpga:SyncMode","Adjustable")
   pythonDaq.daqSetConfig("digFpga:syncWidth",str(25000))
   filterDac = 8
   #filterDac = 33
   pythonDaq.daqSetConfig("digFpga:epix10kpAsic:FilterDac",str(filterDac))

   for pulser in (20,20):
      pythonDaq.daqSetConfig("digFpga:epix10kpAsic:Pulser",str(pulser))
      pythonDaq.daqSetConfig("digFpga:epix10kpAsic:HrTest","True")
      resMode = "hr"
      nFiles = 5
#      if (pulser == 10):
#         nFiles = 50
      for files in range(0,nFiles):
#      for files in range(0,1):
         this_filename = outputfile+"_filterDac"+str(filterDac)+"_"+str(resMode)+"_pulser"+str(pulser)+"_file"+str(files)+"_nwf.bin"
         print(this_filename)
#         pythonDaq.daqOpenData(this_filename)
         for delay in range(0,15000,12):
            pythonDaq.daqSetConfig("digFpga:syncDelay",str(delay))
            pythonDaq.daqSendCommand("SoftwareTrigger","")
#         pythonDaq.daqCloseData(this_filename)

if __name__ == "__main__":
   main(sys.argv[1:])
          


