#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : local image viewer for the ePix camera images
#-----------------------------------------------------------------------------
# File       : ePixViewer.py
# Author     : Dionisio Doering
# Created    : 2017-02-08
# Last update: 2017-02-08
#-----------------------------------------------------------------------------
# Description:
# Simple image viewer for ePix 100a images that enble a local feedback 
# from data collected using ePix cameras. The initial intent is to use it 
# with stand alone systems
#
#-----------------------------------------------------------------------------
# This file is part of the ePix project. It is subject to 
# the license terms in the LICENSE.txt file found in the top-level directory 
# of this distribution and at: 
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
# No part of the ATLAS CHESS2 DEV, including this file, may be 
# copied, modified, propagated, or distributed except according to the terms 
# contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

import sys
import ePixViewer as vi

try:
    from PyQt5.QtWidgets import *
    from PyQt5.QtCore    import *
    from PyQt5.QtGui     import *
except ImportError:
    from PyQt4.QtCore    import *
    from PyQt4.QtGui     import *

def run():
    sys.exit(app.exec_())

# creates and runs a viewer gui
app = QApplication(sys.argv)

if __name__ == '__main__':
    if (len(sys.argv) > 1):
        gui = vi.Window(cameraType = sys.argv[1])
    else:
        print ('Warning! Opening viewer with default camera: ePix100a')
        gui = vi.Window(cameraType = 'ePix100a')

    run()


