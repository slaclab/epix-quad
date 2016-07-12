#!/usr/bin/env python
##############################################################################
## This file is part of 'LCLS2 LLRF Test Software'
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'LCLS LLRF Test Software', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################

import sys, os, csv
from PyQt4.QtCore import *
from PyQt4.QtGui import *
import pythonDaq
import time

import matplotlib
from matplotlib.backends.backend_qt4agg import FigureCanvasQTAgg as FigureCanvas
from matplotlib.backends.backend_qt4agg import NavigationToolbar2QTAgg as NavigationToolbar
from matplotlib.figure import Figure
#import matplotlib.pyplot as plt

class DataReader(QThread):
   def __init__(self, parent=None):
      QThread.__init__(self,parent)
      self.start()

   def run(self):

      pythonDaq.daqSharedDataOpen("epix",1);

      while True:
      
         ret = pythonDaq.daqSharedDataRead();

         if ret[0] == 0:
            time.sleep(.001)
         elif ret[1] == 0 and ret[0] != 0 and ret[2][0] == 2:    # check if VC = 2
            #print ret[0]
            self.emit(SIGNAL("newData"),ret[2], ret[0])
         #else:
         #   print "Got %i %i" % (ret[0],ret[1])

class Form(QMainWindow):
    def __init__(self, period, parent=None):
        super(Form, self).__init__(parent)
        self.period = period
        self.lastTime = time.time()

        self.setWindowTitle('EPIX scope')

        self.main_frame = QWidget()
        
        self.dpi = 100

        self.figA = Figure((6.0, 4.0), dpi=self.dpi)
        self.canvasA = FigureCanvas(self.figA)
        self.canvasA.setParent(self.main_frame)

        self.figB = Figure((6.0, 4.0), dpi=self.dpi)
        self.canvasB = FigureCanvas(self.figB)
        self.canvasB.setParent(self.main_frame)

        self.axesA = self.figA.add_subplot(111)
        self.axesB = self.figB.add_subplot(111)
        
        vbox = QVBoxLayout()
        vbox.addWidget(self.canvasA)
        vbox.addWidget(self.canvasB)

        self.main_frame.setLayout(vbox)

        self.setCentralWidget(self.main_frame)

        self.plotDataA = None
        self.plotDataB = None
        self.on_show()

    def newData(self,data, size):
        chAdata = []
        chBdata = []
        oscWords = size-8-5
         
        # converted to volts
        for val in data[8:8+oscWords/2-1]:
            convHi = -1.0 + ((val >> 16) & 0xFFFF) * (2.0/2**14)
            convLo = -1.0 + (val & 0xFFFF) * (2.0/2**14)
            chAdata.append(convHi)
            chAdata.append(convLo)
        for val in data[8+oscWords/2:8+oscWords-1]:
            convHi = -1.0 + ((val >> 16) & 0xFFFF) * (2.0/2**14)
            convLo = -1.0 + (val & 0xFFFF) * (2.0/2**14)
            chBdata.append(convHi)
            chBdata.append(convLo)
        
        ## raw bit data
        #for val in data[8:8+oscWords/2-1]:
        #    chAdata.append((val >> 16) & 0xFFFF)
        #    chAdata.append(val & 0xFFFF)
        #for val in data[8+oscWords/2:8+oscWords-1]:
        #    chBdata.append((val >> 16) & 0xFFFF)
        #    chBdata.append(val & 0xFFFF)
         
        #print chAdata
        #print chBdata
        #print self.period

        if data[0] == 2:
           self.plotDataA = chAdata
           self.plotDataB = chBdata
        else:
           print "Unknown frame"
           print data
           print size

        if time.time() - self.lastTime > self.period:
           self.lastTime = time.time()
           self.on_show()

    def on_show(self):
        self.axesA.clear()        
        self.axesB.clear()        
        self.axesA.grid(True)
        self.axesB.grid(True)

        if self.plotDataA:
            self.axesA.plot(self.plotDataA)
        if self.plotDataB:
            self.axesB.plot(self.plotDataB)
        self.canvasA.draw()
        self.canvasB.draw()

def main():
    app = QApplication(sys.argv)
    form = Form(0.1)
    form.show()
    dread = DataReader()
    form.connect(dread,SIGNAL('newData'),form.newData)
    app.exec_()

if __name__ == "__main__":
    main()
    
