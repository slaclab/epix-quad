import pythonDaq
import time
import struct
import os
import sys
import getopt

def main(argv):
   outputfile = ''
   outputfileTps = ''
   try:
      opts, args = getopt.getopt(argv,"ho:")
   except getopt.GetoptError:
      print 'filterScanDarkFrame -o <base filename for output>'
      sys.exit(2)
   for opt, arg in opts:
      if opt == '-h':
         print 'filterScanDarkFrame -o <base filename for output>'
         sys.exit()
      elif opt in ("-o", "--ofile"):
         outputfile = arg

   pythonDaq.daqOpen("epix",1)

   #Mask matrix
   pythonDaq.daqSetConfig("digFpga:epixAsic:PixelTest","False")
   pythonDaq.daqSetConfig("digFpga:epixAsic:PixelMask","False")
   pythonDaq.daqSendCommand("WriteMatrixData","")
   
   for filter_dac_setting in range(0,64,4):
      pythonDaq.daqSetConfig("digFpga:epixAsic:FilterDac",str(filter_dac_setting))
      f_setting = '%02d' % (filter_dac_setting);
      this_filename = outputfile+"F"+str(f_setting)+".bin"
      print this_filename
      pythonDaq.daqOpenData(this_filename);
      for frame in range(0,10000):
         pythonDaq.daqSendCommand("SoftwareTrigger","")
      pythonDaq.daqCloseData(this_filename);


if __name__ == "__main__":
   main(sys.argv[1:])
          


