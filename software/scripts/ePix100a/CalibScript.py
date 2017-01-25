import pythonDaq
import daq_client
import time
import struct
import os
import sys
import re
import argparse

parser = argparse.ArgumentParser('ePix calibration script.')
parser.add_argument('-s', '--sleepstart', default=5*60, type=int, help='Time in seconds to wait before starting calibration runs.')
parser.add_argument('-t', '--sleep', default=60, type=int, help='Time in seconds to wait between each calibration run.')
parser.add_argument('-d', '--save_dir', default='/u1/phansson/tmp/', type=str, help='Directory where files get saved.')
parser.add_argument('-n', '--events_per_run', default=1100, type=int, help='Number of events per calibration run.')
parser.add_argument('-c', '--config', default='/afs/slac.stanford.edu/u/re/mkwiatko/localSVN/epix/trunk/software/xml/epix100a_4.xml', type=str, help='Default configuration xml file.')
args = parser.parse_args()




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
   pythonDaq.daqLoadSettings(args.config)
   
def start_running():
   print('[daq_worker] : start running the camera at 120Hz')
   #pythonDaq.daqSetRunParameters('120Hz', 10000000)
   #pythonDaq.daqSetRunState("Running")
   # use FPGA auto trigger instead of software trigger
   pythonDaq.daqSetRunState("Stopped")
   pythonDaq.daqWriteRegister("digFpga(0)","AutoRunPeriod", 833333)
   pythonDaq.daqWriteRegister("digFpga(0)","RunTrigEnable", 1)
   pythonDaq.daqWriteRegister("digFpga(0)","DaqTrigEnable", 1)
   pythonDaq.daqWriteRegister("digFpga(0)","AutoRunEnable", 1)
   pythonDaq.daqWriteRegister("digFpga(0)","AutoDaqEnable", 1)
   

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

def sleep(nsec=1, quiet=False):
   if not quiet: print('[daq_worker] : sleeping for ' + str(nsec) + ' seconds')
   for i in range(0,nsec):
      time.sleep(1)          # uncomment to wait
      if not quiet:
         sys.stdout.write('.')
         sys.stdout.flush()
   if not quiet:
      sys.stdout.write('\n')
      print('[daq_worker] : slept for ' + str(nsec) + ' seconds')


def get_processing_status(s):
   """Extracts the number of events and rate (Hz) from string. Returns a tuple."""
   m = None
   n = -1
   r = -1.0
   if s != None:
      m = re.match('(\d+)\s+-\s+(\d+)\s+Hz.*',s)
      if m != None:
         n = int(m.group(1))
         r = float(m.group(2))
   return (n,r)

def main(argv):

   print (args)

   # open shared mem
   pythonDaq.daqOpen("epix",1)

   # open daq client
   tcpDaq = daq_client.DaqClient('localhost',8090,True)
   tcpDaq.enable()
   
   # Reset the DAQ
   reset_daq()
   
   # clear matrix
   clear_matrix()
   
   # set default configuration
   set_defaults()
   
   # start running the camera
   start_running()
   
   # wait before starting
   sleep(nsec=args.sleep, quiet=False)
   
   acq_times = [5000, 100000] # 50 us and 1 ms

   print('[daq_worker] : saving files to '+ args.save_dir)

   print('[daq_worker] : Start calibration loop')

   # for stats
   n_sum = 0

   for ppmat in range (0, 2):
      for tc in range (0, 2):
         for i in range(len(acq_times)):
            #print ('acq %(1)d, tc %(2)d, ppmat %(3)d' % {"1":acq_times[i], "2":tc, "3":ppmat} )
            print('[daq_worker] : changing settings')
            asic_set_temp_comp(0, tc)
            asic_set_temp_comp(1, tc)
            asic_set_temp_comp(2, tc)
            asic_set_temp_comp(3, tc)
            set_acq_time(acq_times[i])
            set_power_pulsing(ppmat)
            # must read the config after changing the registers otherwise 
            # calling daqOpenData will overwrite the settings
            pythonDaq.daqReadConfig()
            
            file_path = args.save_dir + '/acq' + str(acq_times[i]) + '_tc' + str(tc) + '_ppmat' + str(ppmat)

            print('[daq_worker] : file to be processed: ' + file_path)

            # wait before saving data
            sleep(nsec=args.sleep,quiet=False)

            # get the processing status
            events_start = get_processing_status(tcpDaq.daqReadStatusNode('DataFileCount'))[0]
            print('[daq_worker] : Start recording events')
            print('[daq_worker] : event count at start: ' + str(events_start))

            # open the file to start recording events
            pythonDaq.daqOpenData(file_path)

            # check occassionally until desired number of events has been processed
            # the accuracy on number of events is not great ~ 100
            events_processed = 0
            while events_processed < args.events_per_run:
               events_processed  = get_processing_status(tcpDaq.daqReadStatusNode('DataFileCount'))[0] - events_start
               time.sleep(1)
               print('[daq_worker] : processed ' + str(events_processed) + '/' + str(args.events_per_run) + ' events')
            print('[daq_worker] : Stop recording events')

            n_sum += events_processed

            # close data file, don't stop acq
            pythonDaq.daqCloseData()
   
   print('[daq_worker] : Calibration loop done. ')
   print('[daq_worker] : Saved ' + str(n_sum) + ' events to files')
   
   tcpDaq.disable()

   
if __name__ == "__main__":
   main(sys.argv[1:])
          


