
import pythonDaq
import time
import struct
import os
import sys
import getopt

def main(argv):

   pythonDaq.daqOpen("epix",1)

   #Poll status registers at a given interval
   while(1):
      pythonDaq.daqReadStatus("")
      time.sleep(2)

if __name__ == "__main__":
   main(sys.argv[1:])

