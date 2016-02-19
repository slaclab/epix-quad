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
   pythonDaq.daqSetConfig("digFpga:epix10kpAsic:Pulser","75") #32 about right for threshold at ~25
                                                             #75 about right for threshold at ~42

   #Loop over pulser set value
   for comparatorVal in range(25,55):
      pythonDaq.daqSetConfig("digFpga:epix10kpAsic:CompTH_DAC",str(comparatorVal))

      pythonDaq.daqSetConfig("digFpga:AutoDaqEnable","False")
      pythonDaq.daqSetConfig("digFpga:AutoRunEnable","False")
         
      pythonDaq.daqSetConfig("digFpga:AutoDaqEnable","True");
      pythonDaq.daqSetConfig("digFpga:AutoRunEnable","True");

      time.sleep(1)

      this_filename = outputfile+"_compTh"+str(comparatorVal)+".bin"

      print(this_filename)

      pythonDaq.daqOpenData(this_filename)
      time.sleep(10)
      pythonDaq.daqCloseData(this_filename)
      time.sleep(10)

      pythonDaq.daqSetConfig("digFpga:AutoDaqEnable","False")
      pythonDaq.daqSetConfig("digFpga:AutoRunEnable","False")

if __name__ == "__main__":
   main(sys.argv[1:])
          


