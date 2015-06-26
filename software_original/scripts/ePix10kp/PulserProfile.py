import pythonDaq
import time
import struct
import os
import sys
import getopt
import time

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

   #Pulser settings (same for all files)
   pythonDaq.daqSetConfig("digFpga:epix10kpAsic:ATest","False")
   pythonDaq.daqSetConfig("digFpga:epix10kpAsic:Test","True")
   pythonDaq.daqSetConfig("digFpga:epix10kpAsic:HrTest","True")

   #Loop over pulser set value
   for pulserVal in range(20,40):
      pythonDaq.daqSetConfig("digFpga:epix10kpAsic:Pulser",str(pulserVal))

      pythonDaq.daqSetConfig("digFpga:AutoDaqEnable","False")
      pythonDaq.daqSetConfig("digFpga:AutoRunEnable","False")
         
      pythonDaq.daqSetConfig("digFpga:AutoDaqEnable","True");
      pythonDaq.daqSetConfig("digFpga:AutoRunEnable","True");

      time.sleep(1)

      this_filename = outputfile+"_pulser"+str(pulserVal)+".bin"

      print(this_filename)

      pythonDaq.daqOpenData(this_filename)
      time.sleep(10)
      pythonDaq.daqCloseData(this_filename)
      time.sleep(10)

      pythonDaq.daqSetConfig("digFpga:AutoDaqEnable","False")
      pythonDaq.daqSetConfig("digFpga:AutoRunEnable","False")

if __name__ == "__main__":
   main(sys.argv[1:])
          


