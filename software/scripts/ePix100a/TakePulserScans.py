import pythonDaq
import time
import struct
import os
import sys
import getopt

def main(argv):
   outputFile = '';
   try:
      opts, args = getopt.getopt(argv,"ho:");
   except getopt.GetoptError:
      print '<executable> -o <base filename for output>'
      sys.exit(2);
   for opt, arg in opts:
      if opt == '-h':
         print '<executable> -o <base filename for output>'
         sys.exit();
      elif opt in ("-o", "--ofile"):
         outputFile = arg;

   pythonDaq.daqOpen("epix",1);

   framesPerSetting = 1024;

   for fileNum in range(0,10):
      pulseFilename = outputFile+"."+str(fileNum)+".bin"

      pythonDaq.daqSetConfig("digFpga:epixAsic:PulserR","False")
      time.sleep(2)
      pythonDaq.daqSetConfig("digFpga:epixAsic:PulserR","True")
      time.sleep(2)
      pythonDaq.daqSetConfig("digFpga:epixAsic:PulserR","False")
      time.sleep(2)

      pythonDaq.daqOpenData(pulseFilename)
      pythonDaq.daqSetRunParameters("10Hz",framesPerSetting)
      time.sleep(5)
      pythonDaq.daqSetRunState("Running")
      time.sleep(120)
      while(pythonDaq.daqGetStatus("Run State") == "Running"):
         time.sleep(10)
      time.sleep(10)
      pythonDaq.daqCloseData(pulseFilename)
      
if __name__ == "__main__":
   main(sys.argv[1:])
          


