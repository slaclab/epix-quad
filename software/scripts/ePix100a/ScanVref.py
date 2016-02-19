import pythonDaq
import time
import struct
import os
import sys
import getopt

def main(argv):

   pythonDaq.daqOpen("epix",1);

#   pythonDaq.daqSetConfig("digFpga:AutoRunEnable","True");
#   pythonDaq.daqSetConfig("digFpga:AutoDaqEnable","True");

   for vref in range(0,63):
      pythonDaq.daqSetConfig("digFpga:epix100aAsic:VRef",str(vref));
      for events in range(0,1):
         pythonDaq.daqSendCommand("SoftwareTrigger","");
         #time.sleep(0.01)
         time.sleep(0.1);

#   pythonDaq.daqSetConfig("digFpga:AutoRunEnable","False");
#   pythonDaq.daqSetConfig("digFpga:AutoRunEnable","False");

if __name__ == "__main__":
   main(sys.argv[1:])
          


