import pythonDaq
import time
import struct
import os
import sys
import getopt

def reset_daq():
   print('[daq_worker] : hard reset')
   pythonDaq.daqHardReset()
   print('[daq_worker] : sleep')
   time.sleep(5)
   print('[daq_worker] : reset counters')
   pythonDaq.daqResetCounters()
   print('[daq_worker] : reset done')

def clear_matrix():
   print('[daq_worker] : clear matrix')
   for asic in range(0,4):
      for i in range(0,96):
         asicStr = "digFpga(0):epix100aAsic("+str(asic)+")";
         pythonDaq.daqWriteRegister(asicStr,"PrepareMultiConfig",0x0)
         pythonDaq.daqWriteRegister(asicStr,"ColCounter",i)
         pythonDaq.daqWriteRegister(asicStr,"WriteColData",0x0)
      pythonDaq.daqWriteRegister(asicStr,"CmdPrepForRead",0x0)
   print('[daq_worker] : clear matrix done')

def set_defaults():
   print('[daq_worker] : loading default settings')
   pythonDaq.daqLoadSettings("/afs/slac.stanford.edu/u/re/mkwiatko/localSVN/epix/trunk/software/xml/epix100a_4.xml")
   
def start_running():
   print('[daq_worker] : start running the camera at 120Hz')
   pythonDaq.daqSetRunParameters('120Hz', 10000000)
   pythonDaq.daqSetRunState("Running")

def asic_set_temp_comp(asic, val):
   asicStr = "digFpga(0):epix100aAsic("+str(asic)+")";
   
   dataRead = pythonDaq.daqReadRegister(asicStr,"Config12")
   #print('[daq_worker] : Read %d' % dataRead)
   
   if val == 0:
      print('[daq_worker] : disabling temperature compensation of ASIC%d' % asic)
      pythonDaq.daqWriteRegister(asicStr,"Config12",dataRead & 0xfffffffe)
   else:
      print('[daq_worker] : enabling temperature compensation of ASIC%d' % asic)
      pythonDaq.daqWriteRegister(asicStr,"Config12",dataRead | 0x01)
   
   #dataRead = pythonDaq.daqReadRegister(asicStr,"Config12")
   #print('[daq_worker] : Read %d' % dataRead)

def set_acq_time(val):
   print('[daq_worker] : set acquisition time to %d' % val)
   pythonDaq.daqWriteRegister("digFpga(0)","asicAcqWidth", val)

def set_power_pulsing(val):
   
   dataRead = pythonDaq.daqReadRegister("digFpga(0)","AsicPins")
   pythonDaq.daqWriteRegister("digFpga(0)","AsicPins", dataRead | 0x8)
   dataRead = pythonDaq.daqReadRegister("digFpga(0)","AsicPinControl")
   if val == 0:
      print('[daq_worker] : disabling power pulsing')
      pythonDaq.daqWriteRegister("digFpga(0)","AsicPinControl", dataRead | 0x8)
   else:
      print('[daq_worker] : enabling power pulsing')
      pythonDaq.daqWriteRegister("digFpga(0)","AsicPinControl", dataRead & 0xfffffff7)

def main(argv):
   pythonDaq.daqOpen("epix",1)
   
   # Reset the DAQ
   reset_daq()
   
   # clear matrix
   clear_matrix()
   
   # set default configuration
   set_defaults()
   
   # start running the camera
   start_running()
   
   # wait 5 minutes
   print('[daq_worker] : waiting 5 minutes')
   for i in range(0,300):
      #time.sleep(1)
      sys.stdout.write('.')
      sys.stdout.flush()
   sys.stdout.write('\n')
   print('[daq_worker] : waiting 5 minutes done')
   
   asic_set_temp_comp(0, 0)
   asic_set_temp_comp(1, 0)
   asic_set_temp_comp(2, 0)
   asic_set_temp_comp(3, 0)
   
   set_acq_time(6000)
   
   set_power_pulsing(1)
   
if __name__ == "__main__":
   main(sys.argv[1:])
          


