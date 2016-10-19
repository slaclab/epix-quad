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
      #time.sleep(1)          # uncomment to wait
      sys.stdout.write('.')
      sys.stdout.flush()
   sys.stdout.write('\n')
   print('[daq_worker] : waiting 5 minutes done')
   
   acq_times = [5000, 100000] # 50 us and 1 ms
   save_dir = '/u1/mkwiatko/tmp'
   
   for i in range(len(acq_times)):
      for tc in range (0, 2):
         for ppmat in range (0, 2):
            #print ('acq %(1)d, tc %(2)d, ppmat %(3)d' % {"1":acq_times[i], "2":tc, "3":ppmat} )
            print('[daq_worker] : changing settings')
            asic_set_temp_comp(0, tc)
            asic_set_temp_comp(1, tc)
            asic_set_temp_comp(2, tc)
            asic_set_temp_comp(3, tc)
            set_acq_time(acq_times[i])
            set_power_pulsing(ppmat)
            file_path = save_dir + '/acq' + str(acq_times[i]) + '_tc' + str(tc) + '_ppmat' + str(ppmat)
            # wait 1 minute before saving data
            print('[daq_worker] : waiting 1 minute')
            for j in range(0,60):
               #time.sleep(1)          # uncomment to wait
               sys.stdout.write('.')
               sys.stdout.flush()
            sys.stdout.write('\n')
            print('[daq_worker] : waiting 1 minute done')
            pythonDaq.daqOpenData(file_path)
            pythonDaq.daqSetRunParameters('120Hz', 1100)
            # we should wait here until the state is stopped
            # maybe it should be done other way to avoid stopping (even for just a short time) - see Gabriel's email
            pythonDaq.daqCloseData()
            pythonDaq.daqSetRunParameters('120Hz', 10000000)
            #print file_path
   
if __name__ == "__main__":
   main(sys.argv[1:])
          


