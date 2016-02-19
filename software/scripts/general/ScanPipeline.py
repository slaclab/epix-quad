import pythonDaq
import time
import struct
import os
import sys
import getopt

def main(argv):
   pythonDaq.daqOpen("epix",1)


   for i in range(15,26):
      pythonDaq.daqSetConfig("digFpga:adcPipelineDelay",str(i))
      pythonDaq.daqSetRunState("Running")
      print "Current delay setting: "+str(i)
      time.sleep(5)

   pythonDaq.daqSetRunState("Stopped")
            

if __name__ == "__main__":
   main(sys.argv[1:])
          


