import pythonDaq
import time
import struct
import os
import sys
import getopt

def main(argv):
   outputfile = ''
   try:
      opts, args = getopt.getopt(argv,"ho:")
   except getopt.GetoptError:
      print 'nwfScan -o <base filename for output>'
      sys.exit(2)
   for opt, arg in opts:
      if opt == '-h':
         print 'nwfScan -o <base filename for output>'
         sys.exit()
      elif opt in ("-o", "--ofile"):
         outputfile = arg

   pythonDaq.daqOpen("epix",1)

   #Turn on pulser in manual mode
   pythonDaq.daqSetConfig("digFpga:epix100pAsic:PixelTest","True")
   pythonDaq.daqSetConfig("digFpga:epix100pAsic:ATest","False")
   #Set manual ACQ control
   pythonDaq.daqSetConfig("digFpga:AsicAcq","0")
   pythonDaq.daqSetConfig("digFpga:AsicAcqControl","1")
   #Set gain of test point system
   pythonDaq.daqSetConfig("digFpga:epix100pAsic:TpsGr","0")
   #Turn off temperature compensation
   pythonDaq.daqSetConfig("digFpga:epix100pAsic:TpsTComp","False")
   #Read out tps channel
   pythonDaq.daqSetConfig("digFpga:adcChannelToRead","16")
   pythonDaq.daqSetConfig("digFpga:epix100pAsic:TpsMux","12")
   #Open data file
   pythonDaq.daqOpenData(outputfile);
   #Loop over pulser values
   for pulser_setting in range(0,1024):
      pythonDaq.daqSetConfig("digFpga:epix100pAsic:Pulser",str(pulser_setting))
      pythonDaq.daqSendCommand("SoftwareTrigger","")
   #Close the data file
   pythonDaq.daqCloseData(outputfile);

if __name__ == "__main__":
   main(sys.argv[1:])
          


