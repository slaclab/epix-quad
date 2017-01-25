import time
import daq_client



c = daq_client.DaqClient('localhost',8090)

c.enable()

i = 0
while i < 20:
   s = c.daqReadStatusNode('DataFileCount')
   if s:
      print('s: ' + s)
   else:
      print('s is None')
   time.sleep(1)
   i += 1



c.disable()

