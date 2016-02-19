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
      print 'testBackend -o <base filename for output>'
      sys.exit(2)
   for opt, arg in opts:
      if opt == '-h':
         print 'testBackend -o <base filename for output>'
         sys.exit()
      elif opt in ("-o", "--ofile"):
         outputfile = arg

   pythonDaq.daqOpen("epix",1)

   #Turn off pulser
   pythonDaq.daqSetConfig("digFpga:epix100pAsic:Test","False")
   #Set up matrix for dark frame
   pythonDaq.daqSetConfig("digFpga:epix100pAsic:PixelTest","False")
   pythonDaq.daqSetConfig("digFpga:epix100pAsic:PixelMask","False")
   pythonDaq.daqSendCommand("WriteMatrixData","")

   #Set auto PPmat control
   pythonDaq.daqSetConfig("digFpga:AsicPpmatControl","0")

   #Set up fast power pulsing
   pythonDaq.daqSetConfig("digFpga:epix100pAsic:FastppEnable","True")

   #Scan delay from PPmat L->H to R0 H->L
#   for delay in range(0,12625,125*5):
   for delay in [125*80,125*90,125*95]:
      pythonDaq.daqSetConfig("digFpga:acqToAsicR0Delay",str(delay))
      delay_str = '%03d' % (delay/125);
      filename  = outputfile+"PpmatToR0D"+delay_str+"us.bin"
      print filename
      pythonDaq.daqOpenData(filename);
      for event in range(0,2500):
         pythonDaq.daqSendCommand("SoftwareTrigger","")
      pythonDaq.daqCloseData(filename);

if __name__ == "__main__":
   main(sys.argv[1:])
          


