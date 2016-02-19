import pythonDaq
import time
import struct
import os
import sys
import getopt

def main(argv):

   pythonDaq.daqOpen("epix",1);

   pythonDaq.daqSetConfig("digFpga:AutoRunEnable","True");
   pythonDaq.daqSetConfig("digFpga:AutoDaqEnable","True");

   for acqWidth in range(3000,750000,1000):
      pythonDaq.daqSetConfig("digFpga:asicAcqWidth",str(acqWidth));
      time.sleep(0.1);

   pythonDaq.daqSetConfig("digFpga:AutoRunEnable","False");
   pythonDaq.daqSetConfig("digFpga:AutoRunEnable","False");

if __name__ == "__main__":
   main(sys.argv[1:])
          


